-- GM-796: stored procedure used by Platform.Betting.API (bet recommendations / top markets).
--
-- V1__Baseline.sql contains tables only. GetTopMarketBets is called through FromSqlRaw in
-- Platform.Betting.API/Repository/BettingRepository.cs; its source is not kept in any repository, so the body
-- below was exported from the STG Betting database on 2026-09-07. Repeatable migration with CREATE OR ALTER
-- (first statement of its batch, hence the GO separators; Flyway splits SQL Server scripts on GO).

USE Betting;
GO

CREATE OR ALTER PROCEDURE dbo.GetTopMarketBets
  @ClientId nvarchar(40),
  @Currency nvarchar(15),
  @TopX int
AS 
BEGIN
	SET NOCOUNT ON;

    SELECT TOP(@TopX) *    
    FROM ClientTopMarket
    WHERE ClientId = @ClientId
    AND CurrencyCode = @Currency
    ORDER BY BetCount DESC
END
GO
