-- GM-596: sports-tree segments showing the globe instead of a country flag.
--
-- platform-web renders {CDN}/images/flags/{CountryId}.svg for every segment; 0.svg is the globe.
-- Platform.Sportsbook.API (SportsbookRepository.cs, GetSports) resolves CountryId by an exact
-- trim/lower match of the English segment name against dbo.Country.Name and returns 0 when no row
-- matches. Fixture and league endpoints resolve it through dbo.Country.SportSegmentIds, a comma
-- separated list of "sportId:segmentId" pairs that is split with Convert.ToInt32 and no null check,
-- so SportSegmentIds must always be non-null and parseable.
--
-- The numeric Id is also the SVG file name in platform-web wwwroot/images/flags (0-159 exist as of
-- 2026-09-14). 73.svg is already the Kazakhstan flag; 160-169 are new files added on the FE side:
--   160 England, 161 Scotland, 162 Northern Ireland, 163 Europe, 164 Kosovo, 165 Montenegro,
--   166 Bhutan, 167 Ecuador, 168 Puerto Rico, 169 Great Britain and Northern Ireland (copy of 150).
-- Great Britain and Northern Ireland gets its own Id on purpose: the existing row 150 (UK flag) is
-- left untouched because its current Name may already serve another segment.
--
-- Idempotent: a row is inserted only when neither its Id nor its Name exists yet, so an Id in
-- 160-169 that is already taken by another name is skipped (check dbo.Country by hand in that case).
-- Kazakhstan is the one exception: when a row with Id 73 exists under another Name and no row is
-- named Kazakhstan, that row is renamed, since 73.svg can only be the Kazakhstan flag.
-- SportSegmentIds is derived from the segment names already stored in the Sportsbook ordering tables
-- (ClientSegmentOrder, ClientLeagueOrder, ClientSegmentLeagueOrder, ClientTopLeague, TierLeagueOrder);
-- when a name is not found there the placeholder '0:0' is used, which parses and matches nothing.
-- Platform.Sportsbook.API caches dbo.Country in memory for 24 hours (cache key "sc"); restart the
-- sportsbook API pods or wait for expiry after this migration runs.

USE Sportsbook;

DECLARE @countries TABLE (
    Id   int NOT NULL PRIMARY KEY,
    Name nvarchar(200) COLLATE Latin1_General_CI_AS NOT NULL
);
INSERT INTO @countries (Id, Name) VALUES
    (73,  N'Kazakhstan'),
    (160, N'England'),
    (161, N'Scotland'),
    (162, N'Northern Ireland'),
    (163, N'Europe'),
    (164, N'Kosovo'),
    (165, N'Montenegro'),
    (166, N'Bhutan'),
    (167, N'Ecuador'),
    (168, N'Puerto Rico'),
    (169, N'Great Britain and Northern Ireland');

-- sport:segment pairs already known for each name, taken from the ordering tables
DECLARE @segments TABLE (
    Name      nvarchar(200) COLLATE Latin1_General_CI_AS NOT NULL,
    SportId   int NOT NULL,
    SegmentId int NOT NULL,
    PRIMARY KEY (Name, SportId, SegmentId)
);
INSERT INTO @segments (Name, SportId, SegmentId)
SELECT DISTINCT c.Name, s.SportId, s.SegmentId
FROM @countries c
JOIN (
    SELECT SportId, SegmentId, SegmentName FROM dbo.ClientSegmentOrder
    UNION SELECT SportId, SegmentId, SegmentName FROM dbo.ClientLeagueOrder
    UNION SELECT SportId, SegmentId, SegmentName FROM dbo.ClientSegmentLeagueOrder
    UNION SELECT SportId, SegmentId, SegmentName FROM dbo.ClientTopLeague
    UNION SELECT SportId, SegmentId, SegmentName FROM dbo.TierLeagueOrder
) s ON s.SportId IS NOT NULL
   AND s.SegmentId IS NOT NULL
   AND LTRIM(RTRIM(s.SegmentName)) COLLATE Latin1_General_CI_AS = c.Name;

DECLARE @rows TABLE (
    Id              int NOT NULL PRIMARY KEY,
    Name            nvarchar(200) COLLATE Latin1_General_CI_AS NOT NULL,
    SportSegmentIds nvarchar(max) NOT NULL
);
INSERT INTO @rows (Id, Name, SportSegmentIds)
SELECT c.Id,
       c.Name,
       ISNULL(STUFF((SELECT ',' + CAST(s.SportId AS varchar(20)) + ':' + CAST(s.SegmentId AS varchar(20))
                     FROM @segments s
                     WHERE s.Name = c.Name
                     ORDER BY s.SportId, s.SegmentId
                     FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, ''), N'0:0')
FROM @countries c;

-- Kazakhstan: reuse the existing 73.svg. Rename a mislabelled row 73 only when no row already carries the name.
UPDATE co
SET co.Name            = r.Name,
    co.SportSegmentIds = CASE WHEN co.SportSegmentIds IS NULL OR LTRIM(RTRIM(co.SportSegmentIds)) = N''
                              THEN r.SportSegmentIds ELSE co.SportSegmentIds END
FROM dbo.Country co
JOIN @rows r ON r.Id = co.Id
WHERE r.Id = 73
  AND NOT EXISTS (SELECT 1 FROM dbo.Country x WHERE LTRIM(RTRIM(x.Name)) COLLATE Latin1_General_CI_AS = r.Name);

-- Everything else: insert only when neither the Id nor the Name is present.
INSERT INTO dbo.Country (Id, Name, SportSegmentIds)
SELECT r.Id, r.Name, r.SportSegmentIds
FROM @rows r
WHERE NOT EXISTS (SELECT 1 FROM dbo.Country x WHERE x.Id = r.Id)
  AND NOT EXISTS (SELECT 1 FROM dbo.Country x WHERE LTRIM(RTRIM(x.Name)) COLLATE Latin1_General_CI_AS = r.Name);

-- rollback
-- USE Sportsbook;
-- DELETE FROM dbo.Country WHERE Id BETWEEN 160 AND 169;
-- (the row 73 rename is not reverted automatically; restore the previous Name by hand if needed)
