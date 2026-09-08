-- GM-796: sport groups used by the fixture-count / fixture-list endpoints.
--
-- Table SportGroup2 is what the EF entity Platform.Shared/Data/Sportsbook/SQLEntities/SportGroup.cs maps to
-- ([Table("SportGroup2")]). Platform.Sportsbook.API/Repository/SportsbookRepository.cs looks the row up with
-- FirstOrDefault(...).Sports.Split(",") whenever a request carries SportGroupId <> 0, with no null check, so
-- every id of Platform.Shared/Enums/SportGroup.cs must have a row (0 = All is handled in code and needs none):
--   1 Sports, 2 eSports, 3 VirtualSports, 4 SportsAndVirtualSports, 5 SimulatedRealitySports.
--
-- Rows copied from the STG Sportsbook database on 2026-09-07 (Sports holds Genius Sports sport ids; group 5
-- carries the sentinel 0 on STG as well). Repeatable and idempotent: rows are inserted only when the
-- SportGroupId is missing.

USE Sportsbook;

DECLARE @groups TABLE (SportGroupId int NOT NULL PRIMARY KEY, SportGroupName nvarchar(100) NOT NULL, Sports nvarchar(max) NOT NULL);
INSERT INTO @groups (SportGroupId, SportGroupName, Sports) VALUES
    (1, N'Sports',                    N'17,2715543,4,11205863,7950337,8554,5,6,7,8,10,491393,6463040,12,99614,208627,6463041,15,300115,16,14103274,73743,73744,22,437727,269467,24,91189,276032'),
    (2, N'eSports',                   N'10915624'),
    (3, N'Virtual Sports',            N'11205864,11205868,11205866'),
    (4, N'Sports and Virtual Sports', N'17,2715543,4,11205863,7950337,8554,5,6,7,8,10,491393,6463040,12,99614,208627,6463041,15,300115,16,14103274,73743,73744,22,437727,269467,24,91189,276032,11205864,11205868,11205866'),
    (5, N'Simulated Reality Sports',  N'0');

INSERT INTO dbo.SportGroup2 (SportGroupId, SportGroupName, Sports)
SELECT g.SportGroupId, g.SportGroupName, g.Sports
FROM @groups g
WHERE NOT EXISTS (SELECT 1 FROM dbo.SportGroup2 x WHERE x.SportGroupId = g.SportGroupId);
