-- GM-796: EUR exchange rates required by bet configuration and bet placement.
--
-- ForexEUR holds "units of currency per 1 EUR", keyed by CurrencyCode. Platform.API/Repository/PlatformRepository.cs
-- (GetExchangeRate) reads it: GetBetConfig answers Unsupported_CurrencyCode for any currency without a row and
-- PlaceBet would silently use a rate of 0, so every currency a client trades in needs a row before the first bet.
-- USDT is aliased to USD in code and needs no row of its own.
--
-- Platform.Job.ForexEUR refreshes every row from openexchangerates.org (base EUR) on its schedule, so the numbers
-- below are rounded bootstrap placeholders only; they cover the codes in Platform.Shared/Enums/CurrencyCode.cs and
-- are replaced by live rates as soon as the job runs. Repeatable and idempotent: a row is inserted only when its
-- CurrencyCode is missing, so live rates are never overwritten by a re-run.

USE Platform;

DECLARE @rates TABLE (CurrencyCode nvarchar(16) NOT NULL PRIMARY KEY, ExchangeRate decimal(26,12) NOT NULL);

INSERT INTO @rates (CurrencyCode, ExchangeRate) VALUES
    (N'EUR', 1),
    (N'USD', 1.08),
    (N'GBP', 0.85),
    (N'KRW', 1450),
    (N'VND', 27000),
    (N'THB', 38),
    (N'CNY', 7.8),
    (N'MYR', 4.9),
    (N'KHR', 4400),
    (N'IDR', 17000),
    (N'INR', 90),
    (N'JPY', 160),
    (N'MMK', 2300),
    (N'HKD', 8.4),
    (N'PHP', 61),
    (N'AED', 3.97),
    (N'TRY', 36),
    (N'TWD', 35),
    (N'NZD', 1.78),
    (N'ZAR', 19.5),
    (N'KES', 140),
    (N'TZS', 2800),
    (N'GHS', 15),
    (N'ZMW', 28),
    (N'MZN', 69),
    (N'CDF', 3000),
    (N'ETB', 130),
    (N'MWK', 1880),
    (N'XAF', 655.957),
    (N'NGN', 1650),
    (N'BTC', 0.000016),
    (N'ETH', 0.0004),
    (N'PKR', 300),
    (N'BRL', 6),
    (N'CLP', 1000),
    (N'PEN', 4),
    (N'MXN', 20),
    (N'BDT', 128),
    (N'LKR', 320),
    (N'UZS', 13500),
    (N'MNT', 3700),
    (N'SGD', 1.45),
    (N'NPR', 144),
    (N'EGP', 53),
    (N'AUD', 1.65),
    (N'CAD', 1.48),
    (N'COP', 4500),
    (N'ARS', 1100),
    (N'SEK', 11.3);

INSERT INTO dbo.ForexEUR (CurrencyCode, ExchangeRate)
SELECT r.CurrencyCode, r.ExchangeRate
FROM @rates r
WHERE NOT EXISTS (SELECT 1 FROM dbo.ForexEUR f WHERE f.CurrencyCode = r.CurrencyCode);
