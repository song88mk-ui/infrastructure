-- BO-107: League Sorting (Oddstable).
-- Per-client league sort order for the Oddstable, independent from the Sport Tree order
-- stored in dbo.ClientLeagueOrder. Written by Backoffice.API, one full replace per client.
-- Additive only: a new table, nothing existing is changed, and nothing reads or writes it until the
-- matching backoffice-final release runs.
-- Idempotent: guarded by OBJECT_ID, safe to re-run.

USE Sportsbook;

IF OBJECT_ID(N'[dbo].[ClientOddstableLeagueOrder]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[ClientOddstableLeagueOrder]
    (
        [ClientId]    UNIQUEIDENTIFIER NOT NULL,
        [SportId]     INT              NOT NULL,
        [SportName]   NVARCHAR(MAX)    NULL,
        [SegmentId]   INT              NOT NULL,
        [SegmentName] NVARCHAR(MAX)    NULL,
        [LeagueId]    INT              NOT NULL,
        [LeagueName]  NVARCHAR(MAX)    NULL,
        [SortOrder]   INT              NOT NULL,
        CONSTRAINT [PK_ClientOddstableLeagueOrder]
            PRIMARY KEY CLUSTERED ([ClientId], [SportId], [SegmentId], [LeagueId])
    );
END;

-- rollback
-- USE Sportsbook;
--
-- DROP TABLE IF EXISTS [dbo].[ClientOddstableLeagueOrder];
