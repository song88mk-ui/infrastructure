-- GM-796: bet stake tiers required by bet placement.
--
-- Platform.Betting.API/Repository/BettingRepository.cs (GetTierMaxStake) resolves a TierId and then dereferences
-- Tier.Find(TierId) with no null check: TierId 1 for eSports, 3 for virtual sports, otherwise League.Tier when a
-- Betting.League row exists, else 2. A missing row is a NullReferenceException on every place-bet and max-stake
-- call. The tier caps the client's own limits from Betting.BetConfig (MaxStake) and supplies the per-fixture cap
-- (MaxPerGame); both are in EUR and multiplied by the ForexEUR rate at runtime.
--
-- Values copied from the STG Betting database (9 tiers) on 2026-09-07. Repeatable and idempotent: rows are
-- inserted only when the TierId is missing, so existing values are never overwritten.

USE Betting;

DECLARE @tiers TABLE (TierId int NOT NULL PRIMARY KEY, MaxStake decimal(30,18) NOT NULL, MaxPerGame decimal(30,18) NOT NULL);
INSERT INTO @tiers (TierId, MaxStake, MaxPerGame) VALUES
    (1,   100,   150),
    (2,   250,   375),
    (3,  1200,  1800),
    (4,  1800,  2700),
    (5,  2400,  3600),
    (6,  4000,  6000),
    (7,  8000, 12000),
    (8, 12000, 18000),
    (9, 50000, 50000);

INSERT INTO dbo.Tier (TierId, MaxStake, MaxPerGame)
SELECT t.TierId, t.MaxStake, t.MaxPerGame
FROM @tiers t
WHERE NOT EXISTS (SELECT 1 FROM dbo.Tier x WHERE x.TierId = t.TierId);
