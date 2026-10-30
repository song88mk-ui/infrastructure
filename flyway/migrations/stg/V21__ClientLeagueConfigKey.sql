-- BO-140: Trading.dbo.ClientLeagueConfig was created as a heap with every column nullable and ClientCode as
-- nvarchar(MAX), while Back Office (Backoffice.Shared/Data/Trading/TradingContext.cs) keys it on
-- (ClientCode, SportId, SegmentId, LeagueId). Back Office saves which leagues a client can see in this table
-- (BO-139: visible to every client unless a row with IsActive = 0 restricts it), and without a key the same client
-- and league can be saved twice, so which of the two rows wins is accidental. Adding the key Back Office already
-- assumes, so the database rejects the second row.
--
-- A key cannot contain an nvarchar(MAX) column and its columns must be NOT NULL, so this script also:
--   * removes rows that cannot be keyed: a NULL ClientCode, SportId, SegmentId or LeagueId;
--   * removes all but one row of each duplicated key. A restricting row (IsActive = 0) is kept in preference to an
--     active one, so a restriction is never lost; any remaining tie is broken on ClientId;
--   * narrows ClientCode to nvarchar(40), the width of Trading.dbo.Client.ClientCode (Platform.dbo.Client uses 30).
--     It stops with an error if a value is longer, instead of cutting it.
-- The removed rows are not kept. STG was not inspected when this was written (DEV had 0 rows and no key on 2026-10-30),
-- so before applying it run this read-only pre-check, and export what it lists if anything:
--   SELECT COUNT(*) AS TotalRows,
--          SUM(CASE WHEN ClientCode IS NULL OR SportId IS NULL OR SegmentId IS NULL OR LeagueId IS NULL THEN 1 ELSE 0 END) AS NullKeyRows,
--          MAX(DATALENGTH(ClientCode)) / 2 AS LongestClientCode
--   FROM Trading.dbo.ClientLeagueConfig;
--   SELECT ClientCode, SportId, SegmentId, LeagueId, COUNT(*) AS Copies
--   FROM Trading.dbo.ClientLeagueConfig
--   GROUP BY ClientCode, SportId, SegmentId, LeagueId
--   HAVING COUNT(*) > 1;
--
-- Version order: this must run after the BO-128 permission scripts (dev and stg V20, prd V19). Flyway does not run
-- out of order, so a lower version merged later would be refused.
--
-- Rollback (the rows removed above cannot be restored):
--   ALTER TABLE Trading.dbo.ClientLeagueConfig DROP CONSTRAINT PK_ClientLeagueConfig;
--   ALTER TABLE Trading.dbo.ClientLeagueConfig ALTER COLUMN ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL;
--   ALTER TABLE Trading.dbo.ClientLeagueConfig ALTER COLUMN SportId int NULL;
--   ALTER TABLE Trading.dbo.ClientLeagueConfig ALTER COLUMN SegmentId int NULL;
--   ALTER TABLE Trading.dbo.ClientLeagueConfig ALTER COLUMN LeagueId int NULL;
--
-- Idempotent: the clean-up and the column changes run only while the primary key does not exist yet, and the key is
-- added only if it is missing. A run that stopped half way is finished by running it again.

USE Trading;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = N'PK_ClientLeagueConfig'
      AND parent_object_id = OBJECT_ID(N'Trading.dbo.ClientLeagueConfig')
)
BEGIN
    -- nvarchar(40) is 80 bytes. DATALENGTH counts trailing spaces, which the column change would also cut.
    IF EXISTS (SELECT 1 FROM Trading.dbo.ClientLeagueConfig WHERE DATALENGTH(ClientCode) > 80)
        THROW 50140, N'BO-140: Trading.dbo.ClientLeagueConfig has a ClientCode longer than 40 characters. Fix those rows before adding the key.', 1;

    DELETE FROM Trading.dbo.ClientLeagueConfig
    WHERE ClientCode IS NULL OR SportId IS NULL OR SegmentId IS NULL OR LeagueId IS NULL;

    -- Grouping follows the column collation (case-insensitive), the same comparison the key will use.
    WITH Ranked AS (
        SELECT ROW_NUMBER() OVER (
                   PARTITION BY ClientCode, SportId, SegmentId, LeagueId
                   ORDER BY CASE WHEN IsActive = 0 THEN 0 ELSE 1 END, ClientId) AS RowNumber
        FROM Trading.dbo.ClientLeagueConfig
    )
    DELETE FROM Ranked
    WHERE RowNumber > 1;

    ALTER TABLE Trading.dbo.ClientLeagueConfig
        ALTER COLUMN ClientCode nvarchar(40) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL;

    ALTER TABLE Trading.dbo.ClientLeagueConfig
        ALTER COLUMN SportId int NOT NULL;

    ALTER TABLE Trading.dbo.ClientLeagueConfig
        ALTER COLUMN SegmentId int NOT NULL;

    ALTER TABLE Trading.dbo.ClientLeagueConfig
        ALTER COLUMN LeagueId int NOT NULL;
END
GO

-- A separate batch: SQL Server checks the key columns' nullability when the batch is compiled, so the constraint
-- cannot be added in the batch that makes them NOT NULL.
IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = N'PK_ClientLeagueConfig'
      AND parent_object_id = OBJECT_ID(N'Trading.dbo.ClientLeagueConfig')
)
    ALTER TABLE Trading.dbo.ClientLeagueConfig
        ADD CONSTRAINT PK_ClientLeagueConfig PRIMARY KEY CLUSTERED (ClientCode, SportId, SegmentId, LeagueId);
GO
