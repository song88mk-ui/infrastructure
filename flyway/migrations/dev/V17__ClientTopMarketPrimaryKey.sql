-- GM-929: Betting.dbo.ClientTopMarket was created as a heap with no primary key or unique index,
-- while EF (Platform.Shared/Data/Betting/BettingContext.cs) keys it on
-- (FixtureId, MarketId, ClientId, CurrencyCode). Platform.Client.TopMarket ProcessBetPlacement does a
-- non-atomic FindAsync-then-insert, so two consumers (or a manual insert) can write the same key
-- twice, and v1/bet/recommendations then sends that market to Sportsbook.API twice. Adding the key
-- EF already assumes, so the database rejects the second insert.
--
-- FixtureId and MarketId are nullable today (GM-928) and must become NOT NULL to join a primary key.
-- Before that, rows that cannot be keyed are removed:
--   * rows with a NULL FixtureId or MarketId: the bet-placement path never writes them (both are
--     non-nullable on OnClientTopMarketBetPlacement), and since GM-928 recommendations skip them;
--   * all but one row of each duplicated key: the one with the highest BetCount is kept. Once a
--     duplicate exists, every later placement and settlement updates all copies to the same values
--     (EF's UPDATE matches on the key), so the copies are equal or the kept one is the most advanced.
--
-- Idempotent: each batch runs only while the primary key does not exist yet.

USE Betting;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = N'PK_ClientTopMarket'
      AND parent_object_id = OBJECT_ID(N'Betting.dbo.ClientTopMarket')
)
BEGIN
    DELETE FROM Betting.dbo.ClientTopMarket
    WHERE FixtureId IS NULL OR MarketId IS NULL;

    -- Grouping follows the column collation (case-insensitive), the same comparison the key will use.
    WITH Ranked AS (
        SELECT ROW_NUMBER() OVER (
                   PARTITION BY FixtureId, MarketId, ClientId, CurrencyCode
                   ORDER BY BetCount DESC, MarketStatusId DESC) AS RowNumber
        FROM Betting.dbo.ClientTopMarket
    )
    DELETE FROM Ranked
    WHERE RowNumber > 1;

    ALTER TABLE Betting.dbo.ClientTopMarket
        ALTER COLUMN FixtureId bigint NOT NULL;

    ALTER TABLE Betting.dbo.ClientTopMarket
        ALTER COLUMN MarketId bigint NOT NULL;
END
GO

-- A separate batch: SQL Server checks the key columns' nullability when the batch is compiled, so the
-- constraint cannot be added in the batch that makes them NOT NULL.
IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = N'PK_ClientTopMarket'
      AND parent_object_id = OBJECT_ID(N'Betting.dbo.ClientTopMarket')
)
    ALTER TABLE Betting.dbo.ClientTopMarket
        ADD CONSTRAINT PK_ClientTopMarket PRIMARY KEY CLUSTERED (FixtureId, MarketId, ClientId, CurrencyCode);
GO
