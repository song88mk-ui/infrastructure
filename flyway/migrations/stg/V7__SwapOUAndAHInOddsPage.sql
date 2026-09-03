-- GM-711
-- Update the market order on the sportsbook website so that Asian Handicap (AH) is displayed before Over/Under (OU).UPDATE [Sportsbook]..ClientSelectorMarketTemplate2

USE Sportsbook;

UPDATE ClientSelectorMarketTemplate2
SET asiasortorder = CASE
    WHEN MarketTemplateCode = 'HDP' AND asiasortorder = 3 THEN 2
    WHEN MarketTemplateCode = 'O/U' AND asiasortorder = 2 THEN 3
    ELSE asiasortorder
END
WHERE (MarketTemplateCode = 'HDP' AND asiasortorder = 3)
    OR (MarketTemplateCode = 'O/U' AND asiasortorder = 2);
