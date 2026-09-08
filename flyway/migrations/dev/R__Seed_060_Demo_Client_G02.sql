-- GM-796: the demo sportsbook client (code G02) the DEV front end is hard-wired to.
--
-- argocd apps/platform/song88/dev.yaml (and stg.yaml) configure the demo site with
--   Custom__SB__ClientId      FFDECDB4-10A7-4AEC-9D93-40DEC796CBE9   (client code G02)
--   Custom__SB__UserId        DA75B8EA-6ECA-43BB-F97E-08DA017C44E6
--   Custom__SB__OperatorToken 01936327-EF9C-4A6D-88F2-F11D8BD724C7
--   Custom__SB__Currency      USD
-- and platform-web forwards those ids as x-client-id / x-operator-token on every call. The rows below are what
-- platform-final resolves them against. None of them can be produced through the normal APIs with these exact
-- ids: Platform.Operator.API AddUser always generates a new OperatorToken and UserId
-- (Platform.Operator.API/Repository/PlatformRepository.cs AddUser), and the backoffice client wizard assigns a
-- new ClientId.
--
-- Values mirror the STG rows of the same client (exported 2026-09-07) with three DEV-specific changes: the client
-- name, the operator endpoint host (operator-api.dev.song88.com, argocd apps/platform/operator-api/dev.yaml) and
-- the demo operator's starting balance. LimitId 10939 is the Genius Sports bookmaker id
-- (Custom__GTSBookmakerId in the DEV betting manifests); bet placement rejects 0 or empty as "Missing LimitId".
--
-- Why each row is needed (platform-final, verified in code):
--   Platform.Client            Platform.API GetClient / ClientSportsbook.API AuthorizationFilter reject unknown or
--                              inactive clients.
--   Platform.Operator          v1/authentication and v1/wallet/balance resolve the operator token to this row and
--                              debit Balance on placement (Platform.Operator.API/Repository/PlatformRepository.cs).
--   Betting.BetConfig          bet placement dereferences the (ClientId, CurrencyCode) row and deserializes
--                              DefaultConfig / OverrideConfig / ParlayConfig without null checks
--                              (Platform.Betting.API/Repository/BettingRepository.cs).
--   Sportsbook.ClientSportOrder Platform.Sportsbook.API GetSports only returns sports that have an active row for
--                              the client; with none the sport tree is empty. Every sport listed here also has
--                              selector market templates in R__Seed_070 (platform-web dereferences them per sport).
--   Backoffice.ClientInformation + ClientBetSetting  make the client visible and editable in the backoffice
--                              (SBC -> Clients); JSON is PascalCase because Backoffice.API deserializes it with
--                              default System.Text.Json options.
-- STG has no Trading.Client row for this client, so none is created here either.
--
-- Repeatable and idempotent: every row is inserted only when missing, so values changed through the backoffice
-- are never overwritten.

DECLARE @clientId      uniqueidentifier = 'FFDECDB4-10A7-4AEC-9D93-40DEC796CBE9';
DECLARE @clientCode    nvarchar(40)     = N'G02';
DECLARE @clientName    nvarchar(255)    = N'GIMLIDEV';
DECLARE @operatorUser  uniqueidentifier = 'DA75B8EA-6ECA-43BB-F97E-08DA017C44E6';
DECLARE @operatorToken nvarchar(100)    = N'01936327-EF9C-4A6D-88F2-F11D8BD724C7';
DECLARE @currency      nvarchar(16)     = N'USD';
DECLARE @now           datetime2        = SYSUTCDATETIME();

------------------------------------------------------------------------------------------------------------
-- Backoffice: client record and per-category bet settings (values as on STG)
------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Backoffice.dbo.ClientInformation WHERE Brand = @clientCode AND IsDeleted = 0)
BEGIN
    INSERT INTO Backoffice.dbo.ClientInformation
        (Name, TelephoneNumber, Website, StatusId, MonthlyFee, ApplicationId, CompanyShare, SportsbookShare,
         JackpotShare, RevenueShareSportsbook, RevenueShareJackpot, IsTierRevenueShare, ClientShare, SetupFee,
         UserId, Brand, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, TaxConfig, Region, Email,
         IsEmailNotification, BetSlipMaxSelection, IsDeleted)
    VALUES
        (@clientName, NULL, NULL,
         100,                       -- ClientStatus.Normal
         0,
         2,                         -- Application2.SB (Sportsbook)
         0, 0, 0, NULL, NULL, 0, 0, 0,
         0, @clientCode, 0, @now, 0, @now,
         N'{"StakeTax":0.0,"WinningsTax":0.0,"ExcludeStakeSportTypes":"","ExcludeWinningsSportTypes":""}',
         N'HK', NULL, 0,
         0,
         0);
END;

DECLARE @clientIdRef int = (SELECT TOP (1) ClientId FROM Backoffice.dbo.ClientInformation WHERE Brand = @clientCode AND IsDeleted = 0 ORDER BY ClientId);

DECLARE @betSettings TABLE (CategoryId int NOT NULL PRIMARY KEY, Setting nvarchar(max) NOT NULL);
INSERT INTO @betSettings (CategoryId, Setting) VALUES
    (1,  N'{"MinPerTicket":1.20,"MaxPerTicket":1180.07,"MaxPerGame":1180.07}'),                                     -- Soccer
    (2,  N'{"MinPerTicket":1.18,"MaxPerTicket":1180.07,"MaxPerGame":1180.07}'),                                     -- Other sports
    (3,  N'{"MinPerTicket":1.18,"MaxPerTicket":1180.07,"MaxPayoutPerTicket":1180.07,"MaxWinningsBonus":1180.07}'), -- Parlay
    (8,  N'{"MinPerTicket":1.80,"MaxPerTicket":1180.07,"MaxPerGame":1180.07}'),                                     -- Cricket
    (9,  N'{"MaxStake":1180.07}'),                                                                                   -- Price boost
    (10, N'{"MinStake":1.18,"MaxStake":1180.07}');                                                                   -- Bet builder

INSERT INTO Backoffice.dbo.ClientBetSetting
    (ClientId, CategoryId, Setting, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, CurrencyCode)
SELECT @clientIdRef, s.CategoryId, s.Setting, 0, @now, 0, @now, @currency
FROM @betSettings s
WHERE @clientIdRef IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM Backoffice.dbo.ClientBetSetting b
                  WHERE b.ClientId = @clientIdRef AND b.CategoryId = s.CategoryId AND b.CurrencyCode = @currency);

------------------------------------------------------------------------------------------------------------
-- Platform: client and the demo operator (player) with a starting balance
------------------------------------------------------------------------------------------------------------
-- Guarded on the id AND the code: an environment that already has a G02 client under another id keeps it,
-- a second client with the same code is never created.
IF NOT EXISTS (SELECT 1 FROM Platform.dbo.Client WHERE ClientId = @clientId OR ClientCode = @clientCode)
BEGIN
    INSERT INTO Platform.dbo.Client
        (ClientId, ClientName, ClientCode, LimitId, IsActive, CurrentCompanyShare, EffectiveDate, NextCompanyShare,
         Endpoint, CreatedDate, ClientIdRef, MonthlyFee, IsAgent)
    VALUES
        (@clientId, @clientName, @clientCode,
         N'10939',                  -- Genius Sports bookmaker id, as on STG
         1, 0, DATEFROMPARTS(YEAR(@now), MONTH(@now), 1), 0,
         N'https://operator-api.dev.song88.com', @now, @clientIdRef, 0, 0);
END;

IF NOT EXISTS (SELECT 1 FROM Platform.dbo.Operator
               WHERE UserId = @operatorUser AND OperatorToken = @operatorToken
                 AND ClientId = @clientId AND CurrencyCode = @currency)
BEGIN
    INSERT INTO Platform.dbo.Operator (UserId, OperatorToken, ClientId, Balance, CurrencyCode, CreatedDate)
    VALUES (@operatorUser, @operatorToken, @clientId, 10000, @currency, @now);
END;

------------------------------------------------------------------------------------------------------------
-- Betting: stake configuration for (client, USD), JSON as on STG
------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Betting.dbo.BetConfig WHERE ClientId = @clientId AND CurrencyCode = @currency)
BEGIN
    INSERT INTO Betting.dbo.BetConfig
        (ClientId, CurrencyCode, StakeLimitFixture, MaxParlayPayout, DefaultConfig, OverrideConfig, ParlayConfig,
         CreatedDate, TaxConfig, PriceboostConfig, BetBuilderConfig)
    VALUES
        (@clientId, @currency, 10000, 10000,
         N'{"minStake":1.18,"maxStake":1180.07,"stakeLimitFixture":1180.07}',
         N'[{"sportId":10,"sportName":"Soccer","minStake":1.20,"maxStake":1180.07,"stakeLimitFixture":1180.07},{"sportId":6,"sportName":"Cricket","minStake":1.80,"maxStake":1180.07,"stakeLimitFixture":1180.07}]',
         N'{"minStake":1.18,"maxStake":1180.07,"maxPayout":1180.07,"parlayBonusMaxWinnings":1180.07,"parlayBonusMinOdds":1.20,"parlayBonusConfig":[{"SelectionCount":3,"ParlayBonus":0.0255},{"SelectionCount":4,"ParlayBonus":0.06},{"SelectionCount":5,"ParlayBonus":0.08},{"SelectionCount":6,"ParlayBonus":0.10},{"SelectionCount":7,"ParlayBonus":0.12},{"SelectionCount":8,"ParlayBonus":0.14},{"SelectionCount":9,"ParlayBonus":0.15}]}',
         @now,
         N'{"stakeTax":0.0,"winningsTax":0.0,"excludeStakeSportTypes":"","excludeWinningsSportTypes":""}',
         N'{"MaxStake":1180.07}',
         N'{"MinStake":1.18,"MaxStake":1180.07}');
END;

------------------------------------------------------------------------------------------------------------
-- Sportsbook: the sports the client shows, in STG order (Genius Sports sport ids)
------------------------------------------------------------------------------------------------------------
DECLARE @sports TABLE (SportId int NOT NULL PRIMARY KEY, SportName nvarchar(100) NOT NULL, SortOrder int NOT NULL, IsActive bit NOT NULL);
INSERT INTO @sports (SportId, SportName, SortOrder, IsActive) VALUES
    (10,       N'Football',          1, 1),
    (10915624, N'eSports',           2, 1),
    (6,        N'Cricket',           3, 1),
    (4,        N'Basketball',        4, 1),
    (24,       N'Tennis',            5, 1),
    (3,        N'Baseball',          6, 1),
    (17,       N'American Football', 7, 1),
    (73744,    N'Rugby Union',       8, 1),
    (8,        N'Darts',             9, 1),
    (269467,   N'Table Tennis',     10, 1),
    (99614,    N'Handball',         11, 1),
    (91189,    N'Volleyball',       12, 1),
    (15,       N'Ice Hockey',       13, 1),
    (491393,   N'Futsal',           14, 1),
    (5,        N'Boxing',           15, 1),
    (300115,   N'Martial Arts/UFC', 16, 1),
    (437727,   N'Squash',           17, 1);

INSERT INTO Sportsbook.dbo.ClientSportOrder (ClientId, SportId, SportName, SortOrder, IsActive)
SELECT @clientId, s.SportId, s.SportName, s.SortOrder, s.IsActive
FROM @sports s
WHERE NOT EXISTS (SELECT 1 FROM Sportsbook.dbo.ClientSportOrder c WHERE c.ClientId = @clientId AND c.SportId = s.SportId);
