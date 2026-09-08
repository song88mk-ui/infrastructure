-- GM-796: market template configuration for the odds pages (Sportsbook database).
--
-- Platform.Sportsbook.API/Repository/SportsbookRepository.cs uses the client's ClientSelectorMarketTemplate2
-- rows (GetMainMarketTemplates) as the Mongo filter that decides which markets and selections the fixture-list
-- endpoints return: no rows means fixtures without any odds. platform-web then dereferences the sport's template
-- set while rendering (Components/Shared/FixtureList/Fixture.razor.cs OnInitializedAsync), so every sport that is
-- active in ClientSportOrder must have templates here. SelectorMarketTemplate2 is the global pick-list the
-- backoffice Selector Market Templates page offers (Backoffice.API/Repositories/SportsbookRepository.cs
-- GetSelectorMarketTemplateLookup). MarketTemplateGroup2 / ClientMarketTemplateGroup drive the market tabs on the
-- fixture page (the API falls back to a single "All Markets" group without them).
--
-- MarketTemplateId values are Genius Sports market template ids; they are not derivable from code, so all rows
-- were exported from the STG Sportsbook database on 2026-09-07 (global lookup plus the rows of client G02,
-- FFDECDB4-10A7-4AEC-9D93-40DEC796CBE9, the client the DEV demo site uses). Repeatable and idempotent: every row is
-- inserted only when its key is missing, so changes made in the backoffice are never overwritten.
--
-- The NOT EXISTS key comparisons use COLLATE DATABASE_DEFAULT on the nvarchar columns so the script runs
-- regardless of any collation difference between the table variables and the persistent dbo tables (error 468).

USE Sportsbook;

DECLARE @clientId uniqueidentifier = 'FFDECDB4-10A7-4AEC-9D93-40DEC796CBE9';

------------------------------------------------------------------------------------------------------------
-- SelectorMarketTemplate2: global pick-list (sport, template id, code, sort order)
------------------------------------------------------------------------------------------------------------
DECLARE @lookup TABLE (SportId int NOT NULL, MarketTemplateId nvarchar(50) NOT NULL, MarketTemplateCode nvarchar(50) NOT NULL, SortOrder int NOT NULL);
INSERT INTO @lookup (SportId, MarketTemplateId, MarketTemplateCode, SortOrder) VALUES
    (2, N'14418', N'ML', 1),
    (2, N'6476', N'O/U', 2),
    (2, N'123', N'HDP', 3),
    (3, N'117', N'ML', 1),
    (3, N'335', N'O/U', 2),
    (3, N'97', N'HDP', 3),
    (4, N'115', N'ML', 1),
    (4, N'286', N'O/U', 2),
    (4, N'193', N'HDP', 3),
    (5, N'8857', N'ML', 1),
    (5, N'39', N'O/U', 2),
    (5, N'201', N'1x2', 3),
    (6, N'8884', N'ML', 1),
    (6, N'7240', N'1x2', 2),
    (7, N'6510', N'H2H', 1),
    (8, N'6669', N'1x2', 1),
    (8, N'9670', N'ML', 2),
    (8, N'302', N'Set HDP', 3),
    (8, N'7499', N'Set O/U', 4),
    (10, N'2', N'1x2', 1),
    (10, N'259', N'O/U', 2),
    (10, N'82', N'HDP', 3),
    (12, N'35', N'H2h', 1),
    (12, N'9067', N'H2h 1X2', 2),
    (15, N'183', N'ML', 1),
    (15, N'282', N'O/U', 2),
    (15, N'299', N'HDP', 3),
    (16, N'84', N'H2h', 1),
    (17, N'103', N'ML', 1),
    (17, N'263', N'O/U', 2),
    (17, N'106', N'HDP', 3),
    (22, N'6678', N'1x2', 1),
    (22, N'6672', N'ML', 2),
    (24, N'322', N'ML', 1),
    (24, N'6481', N'Game O/U', 2),
    (24, N'311', N'Game HDP', 3),
    (8554, N'9777', N'ML', 1),
    (8554, N'10229', N'HDP', 2),
    (8554, N'12940', N'O/U', 3),
    (73743, N'8133', N'1x2', 1),
    (73743, N'8152', N'Point O/U', 2),
    (73743, N'8787', N'HDP', 3),
    (73744, N'16106', N'ML', 1),
    (73744, N'6459', N'O/U', 2),
    (73744, N'8783', N'HDP', 3),
    (91189, N'6734', N'ML', 1),
    (91189, N'6942', N'Point O/U', 2),
    (91189, N'7880', N'Point HDP', 3),
    (99614, N'6662', N'1x2', 1),
    (99614, N'6663', N'O/U', 2),
    (99614, N'194', N'HDP', 3),
    (208627, N'6818', N'1x2', 1),
    (208627, N'10495', N'HDP', 2),
    (208627, N'8996', N'O/U', 3),
    (269467, N'6750', N'ML', 1),
    (269467, N'7929', N'Point O/U', 2),
    (269467, N'12797', N'Point HDP', 3),
    (271554, N'6768', N'ML', 1),
    (271554, N'9531', N'Point O/U', 2),
    (271554, N'13361', N'Point HDP', 3),
    (276032, N'8278', N'ML', 1),
    (276032, N'9849', N'HDP', 2),
    (276032, N'7220', N'O/U', 3),
    (300115, N'7659', N'ML', 1),
    (300115, N'10533', N'O/U', 2),
    (300115, N'9471', N'1x2', 3),
    (437727, N'13744', N'ML', 1),
    (437727, N'14016', N'O/U', 2),
    (437727, N'14053', N'HDP', 3),
    (491393, N'7469', N'1x2', 1),
    (491393, N'7470', N'O/U', 2),
    (491393, N'7471', N'HDP', 3),
    (6463040, N'9336', N'1x2', 1),
    (6463040, N'12464', N'HDP', 2),
    (6463040, N'9390', N'O/U', 3),
    (6463041, N'9408', N'1x2', 1),
    (6463041, N'12689', N'HDP', 2),
    (6463041, N'9462', N'O/U', 3),
    (7950337, N'10549', N'ML', 1),
    (7950337, N'13718', N'Point HDP', 2),
    (7950337, N'11345', N'Point O/U', 3),
    (10915624, N'13124', N'ML', 1),
    (10915624, N'13030', N'HDP', 2),
    (10915624, N'14346', N'O/U', 3),
    (10915624, N'13031', N'1x2', 4),
    (11205863, N'14314', N'ML', 1),
    (11205863, N'14316', N'O/U', 2),
    (11205863, N'14315', N'HDP', 3),
    (11205864, N'14736', N'1x2', 1),
    (11205864, N'14743', N'O/U', 2),
    (11205864, N'14738', N'HDP', 3),
    (11205866, N'15142', N'Win', 1),
    (11205868, N'15146', N'Win', 1),
    (11205870, N'16119', N'ML', 1),
    (14103274, N'15333', N'ML', 1),
    (14103274, N'15600', N'Point O/U', 2),
    (14103274, N'15635', N'Point HDP', 3);

INSERT INTO dbo.SelectorMarketTemplate2 (SportId, MarketTemplateId, MarketTemplateCode, SortOrder)
SELECT l.SportId, l.MarketTemplateId, l.MarketTemplateCode, l.SortOrder
FROM @lookup l
WHERE NOT EXISTS (SELECT 1 FROM dbo.SelectorMarketTemplate2 x
                  WHERE x.SportId = l.SportId
                    AND x.MarketTemplateId COLLATE DATABASE_DEFAULT = l.MarketTemplateId COLLATE DATABASE_DEFAULT);

------------------------------------------------------------------------------------------------------------
-- ClientSelectorMarketTemplate2: the main markets client G02 shows per sport (FT = full time, HT = half time)
------------------------------------------------------------------------------------------------------------
DECLARE @csmt TABLE (SportId int NOT NULL, MarketTemplateId nvarchar(50) NOT NULL, MarketTemplateCode nvarchar(50) NOT NULL, AsiaSortOrder int NOT NULL, EuroSortOrder int NOT NULL, Identifier nvarchar(10) NOT NULL);
INSERT INTO @csmt (SportId, MarketTemplateId, MarketTemplateCode, AsiaSortOrder, EuroSortOrder, Identifier) VALUES
    (2, N'14418', N'ML', 1, 1, N'FT'),
    (2, N'123', N'HDP', 2, 3, N'FT'),
    (2, N'6476', N'O/U', 3, 2, N'FT'),
    (2, N'7325', N'HDP', 2, 2, N'HT'),
    (2, N'9919', N'O/U', 3, 1, N'HT'),
    (3, N'117', N'ML', 1, 1, N'FT'),
    (3, N'97', N'HDP', 2, 3, N'FT'),
    (3, N'335', N'O/U', 3, 2, N'FT'),
    (4, N'115', N'ML', 1, 1, N'FT'),
    (4, N'147', N'HDP', 2, 3, N'FT'),
    (4, N'286', N'O/U', 3, 2, N'FT'),
    (4, N'331', N'ML', 1, 1, N'HT'),
    (4, N'6698', N'O/U', 3, 2, N'HT'),
    (4, N'5', N'1x2', 3, 3, N'HT'),
    (5, N'8857', N'ML', 1, 1, N'FT'),
    (5, N'39', N'O/U', 3, 2, N'FT'),
    (5, N'201', N'1x2', 3, 3, N'FT'),
    (6, N'8884', N'ML', 1, 1, N'FT'),
    (6, N'7240', N'1x2', 2, 2, N'FT'),
    (7, N'6510', N'H2H', 1, 1, N'FT'),
    (8, N'6669', N'1x2', 1, 1, N'FT'),
    (8, N'9670', N'ML', 2, 2, N'FT'),
    (8, N'302', N'Set HDP', 3, 3, N'FT'),
    (8, N'7499', N'Set O/U', 4, 4, N'FT'),
    (10, N'2', N'1x2', 1, 1, N'FT'),
    (10, N'82', N'HDP', 2, 3, N'FT'),
    (10, N'259', N'O/U', 3, 2, N'FT'),
    (10, N'6832', N'1x2', 1, 1, N'HT'),
    (10, N'7871', N'HDP', 2, 3, N'HT'),
    (10, N'7076', N'O/U', 3, 2, N'HT'),
    (12, N'35', N'H2h', 1, 1, N'FT'),
    (12, N'9067', N'H2h 1X2', 2, 2, N'FT'),
    (15, N'183', N'ML', 1, 1, N'FT'),
    (15, N'299', N'HDP', 2, 3, N'FT'),
    (15, N'282', N'O/U', 3, 2, N'FT'),
    (16, N'84', N'H2h', 1, 1, N'FT'),
    (17, N'103', N'ML', 1, 1, N'FT'),
    (17, N'106', N'HDP', 2, 3, N'FT'),
    (17, N'263', N'O/U', 3, 2, N'FT'),
    (17, N'6801', N'ML', 1, 1, N'HT'),
    (17, N'8', N'HDP', 2, 3, N'HT'),
    (17, N'6767', N'O/U', 3, 2, N'HT'),
    (22, N'6678', N'1x2', 1, 1, N'FT'),
    (22, N'6672', N'ML', 2, 2, N'FT'),
    (24, N'322', N'ML', 1, 1, N'FT'),
    (24, N'6481', N'Game O/U', 2, 2, N'FT'),
    (24, N'311', N'Game HDP', 3, 3, N'FT'),
    (8554, N'9777', N'ML', 1, 1, N'FT'),
    (8554, N'10229', N'HDP', 2, 2, N'FT'),
    (8554, N'12940', N'O/U', 3, 3, N'FT'),
    (73743, N'8133', N'1x2', 1, 1, N'FT'),
    (73743, N'8152', N'Point O/U', 2, 2, N'FT'),
    (73743, N'8787', N'HDP', 2, 3, N'FT'),
    (73743, N'8190', N'1x2', 1, 1, N'HT'),
    (73743, N'8786', N'HDP', 2, 3, N'HT'),
    (73743, N'8191', N'Point O/U', 2, 2, N'HT'),
    (73744, N'16106', N'ML', 1, 1, N'FT'),
    (73744, N'8783', N'HDP', 2, 3, N'FT'),
    (73744, N'6459', N'O/U', 3, 2, N'FT'),
    (73744, N'7556', N'O/U', 1, 1, N'HT'),
    (73744, N'8782', N'HDP', 2, 2, N'HT'),
    (91189, N'6734', N'ML', 1, 1, N'FT'),
    (91189, N'6942', N'Point O/U', 2, 2, N'FT'),
    (91189, N'7880', N'Point HDP', 3, 3, N'FT'),
    (99614, N'6662', N'1x2', 1, 1, N'FT'),
    (99614, N'194', N'HDP', 2, 3, N'FT'),
    (99614, N'6663', N'O/U', 3, 2, N'FT'),
    (99614, N'8377', N'1x2', 1, 1, N'HT'),
    (99614, N'6799', N'HDP', 2, 3, N'HT'),
    (99614, N'6855', N'O/U', 3, 2, N'HT'),
    (208627, N'6818', N'1x2', 1, 1, N'FT'),
    (208627, N'10495', N'HDP', 2, 2, N'FT'),
    (208627, N'8996', N'O/U', 3, 3, N'FT'),
    (208627, N'12714', N'1x2', 1, 1, N'HT'),
    (208627, N'12742', N'HDP', 2, 2, N'HT'),
    (269467, N'6750', N'ML', 1, 1, N'FT'),
    (269467, N'7929', N'Point O/U', 2, 2, N'FT'),
    (269467, N'12797', N'Point HDP', 3, 3, N'FT'),
    (271554, N'6768', N'ML', 1, 1, N'FT'),
    (271554, N'9531', N'Point O/U', 2, 2, N'FT'),
    (271554, N'13361', N'Point HDP', 3, 3, N'FT'),
    (276032, N'8278', N'ML', 1, 1, N'FT'),
    (276032, N'9849', N'HDP', 2, 2, N'FT'),
    (276032, N'7220', N'O/U', 3, 3, N'FT'),
    (276032, N'12661', N'1x2', 1, 1, N'HT'),
    (276032, N'12687', N'HDP', 2, 2, N'HT'),
    (300115, N'7659', N'ML', 1, 1, N'FT'),
    (300115, N'10533', N'O/U', 3, 2, N'FT'),
    (300115, N'9471', N'1x2', 3, 3, N'FT'),
    (437727, N'13744', N'ML', 1, 1, N'FT'),
    (437727, N'14053', N'HDP', 2, 3, N'FT'),
    (437727, N'14016', N'O/U', 3, 2, N'FT'),
    (491393, N'7469', N'1x2', 1, 1, N'FT'),
    (491393, N'7471', N'HDP', 2, 3, N'FT'),
    (491393, N'7470', N'O/U', 3, 2, N'FT'),
    (491393, N'10258', N'1x2', 1, 1, N'HT'),
    (491393, N'8427', N'HDP', 2, 3, N'HT'),
    (491393, N'8428', N'O/U', 3, 2, N'HT'),
    (6463040, N'9336', N'1x2', 1, 1, N'FT'),
    (6463040, N'12464', N'HDP', 2, 2, N'FT'),
    (6463040, N'9390', N'O/U', 3, 3, N'FT'),
    (6463040, N'9338', N'1x2', 1, 1, N'HT'),
    (6463040, N'9383', N'HDP', 2, 2, N'HT'),
    (6463040, N'10051', N'O/U', 3, 3, N'HT'),
    (6463041, N'9408', N'1x2', 1, 1, N'FT'),
    (6463041, N'12689', N'HDP', 2, 2, N'FT'),
    (6463041, N'9462', N'O/U', 3, 3, N'FT'),
    (6463041, N'9410', N'1x2', 1, 1, N'HT'),
    (6463041, N'12693', N'HDP', 2, 2, N'HT'),
    (6463041, N'12692', N'O/U', 3, 3, N'HT'),
    (7950337, N'10549', N'ML', 1, 1, N'FT'),
    (7950337, N'13718', N'Point HDP', 2, 2, N'FT'),
    (7950337, N'11345', N'Point O/U', 3, 3, N'FT'),
    (10915624, N'15100', N'ML', 1, 1, N'FT'),
    (10915624, N'15104', N'HDP', 2, 2, N'FT'),
    (10915624, N'15139', N'O/U', 3, 3, N'FT'),
    (10915624, N'15101', N'1x2', 4, 4, N'FT'),
    (11205863, N'14314', N'ML', 1, 1, N'FT'),
    (11205863, N'14315', N'HDP', 2, 3, N'FT'),
    (11205863, N'14316', N'O/U', 3, 2, N'FT'),
    (11205864, N'14736', N'1x2', 1, 1, N'FT'),
    (11205864, N'14738', N'HDP', 2, 3, N'FT'),
    (11205864, N'14743', N'O/U', 3, 2, N'FT'),
    (11205864, N'14745', N'1x2', 1, 1, N'HT'),
    (11205866, N'15142', N'Win', 1, 1, N'FT'),
    (11205868, N'15146', N'Win', 1, 1, N'FT'),
    (11205870, N'16119', N'ML', 1, 1, N'FT'),
    (14103274, N'15333', N'ML', 1, 1, N'FT'),
    (14103274, N'15600', N'Point O/U', 2, 2, N'FT'),
    (14103274, N'15635', N'Point HDP', 3, 3, N'FT');

INSERT INTO dbo.ClientSelectorMarketTemplate2 (ClientId, SportId, MarketTemplateId, MarketTemplateCode, AsiaSortOrder, EuroSortOrder, Identifier)
SELECT @clientId, t.SportId, t.MarketTemplateId, t.MarketTemplateCode, t.AsiaSortOrder, t.EuroSortOrder, t.Identifier
FROM @csmt t
WHERE NOT EXISTS (SELECT 1 FROM dbo.ClientSelectorMarketTemplate2 x
                  WHERE x.ClientId = @clientId
                    AND x.SportId = t.SportId
                    AND x.MarketTemplateId COLLATE DATABASE_DEFAULT = t.MarketTemplateId COLLATE DATABASE_DEFAULT
                    AND x.Identifier       COLLATE DATABASE_DEFAULT = t.Identifier       COLLATE DATABASE_DEFAULT);

------------------------------------------------------------------------------------------------------------
-- MarketTemplateGroup2: global market tabs (ID is an identity, so the key is sport + fixture status + name)
------------------------------------------------------------------------------------------------------------
DECLARE @mtg TABLE (SportId int NOT NULL, FixtureStatusId int NOT NULL, Name nvarchar(200) NOT NULL, SortOrder int NOT NULL, MarketTemplates nvarchar(max) NOT NULL);
INSERT INTO @mtg (SportId, FixtureStatusId, Name, SortOrder, MarketTemplates) VALUES
    (4, 0, N'Main Market', 1, N'115, 147, 193, 286, 306, 7351, 10203, 14868, 14870, 14871'),
    (4, 1, N'Main Market', 1, N'115, 147, 193, 286, 306, 7351,  14870, 14871, 7479, 9470'),
    (4, 0, N'Team Props', 3, N'6739, 8471, '),
    (4, 1, N'Team Props', 3, N'8421, 8422, 10474, 14301, 14302, 14411, 15695'),
    (4, 0, N'Quarter Markets', 4, N'6598, 6603, 6736, 6848, 6849, 6850, 6851, 6852, 6853, 6854, 6949, 6950, 6982, 6983, 6984, 7411, 14872, 14971, 14972, 14973, 15694'),
    (4, 1, N'Quarter Markets', 4, N'6598, 6603, 6736, 6848, 6849, 6850, 6851, 6852, 6853, 6949, 6950, 6955, 6956, 6982, 6983, 6984, 7411, 8445, 8446, 9179, 9700, 9701, 9702, 9766, 9767, 9768, 10134, 10505, 10507, 10545, 10936, 10936, 10937, 10937, 10938, 10939, 10940, 10941, 10963, 11264, 11379, 11748, 11749, 11750, 11751, 11752, 11753, 11754, 11755, 11756, 11757, 11812, 11813, 12100, 13796, 13797, 13798, 13799, 13803, 13804, 13805, 13806, 13826, 13827, 13828, 13833, 13834, 13835, 13839, 13840, 14347, 14348, 14349, 14350, 14872, 14971, 14972, 14973, 15261, 15262, 15263, 15264, 15265, 15266, 15267, 15268, 15269, 15270, 15271, 15272, 15273, 15274, 15275, 15276, 15277, 15278, 15279, 15280, 15281, 15282, 15283, 15284, 15285, 15286, 15287, 15288, 15289, 15290, 15291, 15292, 15293, 15294, 15295, 15296, 15297, 15298, 15299, 15300, 15694, 15697'),
    (4, 0, N'Halftime Markets', 5, N'5, 331, 6602, 6606, 6698, 6859, 6957, 7393, 11811, 15058, 15259, 15260, 15693'),
    (4, 1, N'Halftime Markets', 5, N'5, 331, 6602, 6606, 6698, 6859, 7416, 7417, 8443, 8555, 8577, 8702,8743,9162,9769,9932,10135,10506,10934,10935,11262,11263,11811,11814,13821,15054,15056,15057,15058,15059,15060,15061,15062,15259,15260, 15696');

INSERT INTO dbo.MarketTemplateGroup2 (SportId, FixtureStatusId, Name, SortOrder, MarketTemplates)
SELECT g.SportId, g.FixtureStatusId, g.Name, g.SortOrder, g.MarketTemplates
FROM @mtg g
WHERE NOT EXISTS (SELECT 1 FROM dbo.MarketTemplateGroup2 x
                  WHERE x.SportId = g.SportId
                    AND x.FixtureStatusId = g.FixtureStatusId
                    AND x.Name COLLATE DATABASE_DEFAULT = g.Name COLLATE DATABASE_DEFAULT);

------------------------------------------------------------------------------------------------------------
-- ClientMarketTemplateGroup: client G02's market tabs (Id is an identity, key is client + sport + status + name)
------------------------------------------------------------------------------------------------------------
DECLARE @cmtg TABLE (SportId int NOT NULL, FixtureStatusId int NOT NULL, Name nvarchar(200) NOT NULL, SortOrder int NOT NULL, IsActive bit NOT NULL, MarketTemplates nvarchar(max) NOT NULL);
INSERT INTO @cmtg (SportId, FixtureStatusId, Name, SortOrder, IsActive, MarketTemplates) VALUES
    (269467, 0, N'All Markets', 0, 1, N''),
    (269467, 1, N'All Markets', 0, 1, N''),
    (10, 1, N'All Markets', 0, 1, N'2,3,12,13,14,17,19,20,25,30,42,56,59,60,62,66,82,91,104,105,122,168,170,253,259,262,295,297,362,6491,6497,6609,6631,6765,6832,6911,7052,7075,7076,7079,7081,7084,7086,7087,7100,7105,7106,7108,7121,7136,7143,7202,7247,7354,7466,7478,7574,7591,7703,7706,7739,7769,7782,7783,7793,7797,7809,7871,8239,8479,8480,8481,8682,8683,8684,8710,8726,8770,8804,8863,8864,9497,9498,9535,9536,9559,9560,9562,9579,9580,9966,10031,10053,10054,10055,10145,10146,10162,10448,10453,10459,10479,10480,10481,10498,10499,10500,10501,10502,10503,10523,10540,10541,10542,10576,10577,10578,10579,10580,10582,10583,10589,10590,10591,10592,10615,10616,10747,10748,10755,10756,10766,10768,10769,10779,10781,10782,10789,10790,10792,10839,10849,10850,10869,10870,10878,10887,10888,10982,10983,10984,10985,10986,10992,10993,10994,10995,11012,11013,11044,11138,11145,11148,11392,11393,11461,11544,11656,11657,11678,11679,11680,11681,11682,11767,11768,11921,12104,12189,12190,12205,12381,12402,12502,12931,13014,13496,13649,13650,13651,13655,13681,13694,13695,13696,13697,13698,13699,13700,13707,13766,14308,14309,14312,14313,14329,14330,14415,14773,14777,14795,14799,14837,14838,14855,14856,14857,14858,14859,14860,14863,14866,14867,14981,15053,15064,15065,15066,15098,15099,15150,15154,15179,15180,15181,15182,15183,15184,15185,15186,15187,15188,15189,15190,15191,15192,15194,15199,15200,15302,15303,15682,15684,15686,15688,15690,15692,16032,16033,16034,16035,16055,16056,16057,16058,16101,16107,16108,16109,16116,16117,16118,16135,16136,16137,16138,16139,16140,16141,16142,16143,16144,16145,16146,16147'),
    (4, 0, N'All Markets', 1, 1, N'147,193,7479,10474,14411,306,8743,5,115,14302,11812,11814,14301,6603,6736,6851,6848,6859,6982,7416,6950,7417,9766,9769,11811,16150,6698,8737,8735,8738,6602,10134,13803,14872,15263,6949,9179,7411,331,10135,6606,6598,9700,13799,15694,15272,14971,14871,13796,13797,13827,13798,13828,13839,15273,13804,15274,13805,15276,13806,15264,15277,13826,15278,15265,15262,15279,15266,15280,14972,11813,15267,15271,15281,15268,15282,15269,15283,15270,15284,8577,15285,15286,9470,15287,15261,9701,15288,15289,15290,9767,6983,15275,6849,6955,6852,13821,15061,11262,11263,15059,6853,15060,15062,9932,6850,6984,9702,7351,9768,12100,8471,15697,15259,15695,15696,15300,15296,15298,6956,13835,15297,15299,13833,15291,13840,15292,13834,15293,15294,14973,15295,6739'),
    (4, 0, N'Main Market', 2, 1, N'193,7479,115'),
    (4, 0, N'Team Props', 3, 1, N'147,6739'),
    (4, 0, N'Quarter Markets', 4, 1, N'6598'),
    (4, 0, N'Halftime Markets', 5, 1, N'5'),
    (17, 0, N'All Markets', 0, 1, N'6788,9248,8616,9247,6808,6801,9249,6806,9246,6640,10050,6807,6551,6805,6656,6539,6809,11593,6793,6792,6559,6811,6789,16084,10622,10621,6571,10042,9484,8386,15206,15746,15204,16083,6644,106,11647,8259,8252,15212,8385,16081,15202,263,8253,267,11646,8251,11641,103,12860,6574,6834,6552,9481,6572,9482,9483,11639,11643,11640,8,11514,264,6767,11642,11513,6573,11645,265,266,11644'),
    (4, 0, N'Adren basketball', 6, 1, N'147,193,7479,5,115'),
    (10, 0, N'All Markets', 0, 0, N'2,3,12,13,14,17,19,20,25,30,42,56,59,60,62,66,82,91,104,105,122,168,170,253,259,262,295,297,362,6491,6497,6609,6631,6765,6832,6911,7052,7075,7076,7079,7081,7084,7086,7087,7100,7105,7106,7108,7121,7136,7143,7202,7247,7354,7466,7478,7574,7591,7703,7706,7739,7769,7782,7783,7793,7797,7809,7871,8239,8479,8480,8481,8682,8683,8684,8710,8726,8770,8804,8863,8864,9497,9498,9535,9536,9559,9560,9562,9579,9580,9966,10031,10053,10054,10055,10145,10146,10162,10448,10453,10459,10479,10480,10481,10498,10499,10500,10501,10502,10503,10504,10523,10540,10541,10542,10576,10577,10578,10579,10580,10582,10583,10589,10590,10591,10592,10615,10616,10747,10748,10755,10756,10766,10768,10769,10779,10781,10782,10789,10790,10792,10839,10849,10850,10869,10870,10878,10887,10888,10982,10983,10984,10985,10986,10989,10992,10993,10994,10995,11012,11013,11044,11138,11145,11148,11392,11393,11461,11544,11656,11657,11678,11679,11680,11681,11682,11767,11768,11921,12104,12189,12190,12205,12381,12402,12502,12931,13014,13496,13649,13650,13651,13655,13681,13694,13695,13696,13697,13698,13699,13700,13707,13766,14308,14309,14312,14313,14329,14330,14415,14773,14777,14795,14799,14837,14838,14855,14856,14857,14858,14859,14860,14863,14866,14867,14981,15053,15064,15065,15066,15098,15099,15150,15154,15179,15180,15181,15182,15183,15184,15185,15186,15187,15188,15189,15190,15191,15192,15194,15199,15200,15302,15303,15682,15684,15686,15688,15690,15692,16032,16033,16034,16035,16055,16056,16057,16058,16101,16107,16108,16109,16116,16117,16118,16135,16136,16137,16138,16139,16140,16141,16142,16143,16144,16145,16146,16147'),
    (11205863, 0, N'All Markets', 0, 1, N'14314,14317,14315,14316');

INSERT INTO dbo.ClientMarketTemplateGroup (ClientId, SportId, FixtureStatusId, Name, SortOrder, IsActive, MarketTemplates)
SELECT @clientId, g.SportId, g.FixtureStatusId, g.Name, g.SortOrder, g.IsActive, g.MarketTemplates
FROM @cmtg g
WHERE NOT EXISTS (SELECT 1 FROM dbo.ClientMarketTemplateGroup x
                  WHERE x.ClientId = @clientId
                    AND x.SportId = g.SportId
                    AND x.FixtureStatusId = g.FixtureStatusId
                    AND x.Name COLLATE DATABASE_DEFAULT = g.Name COLLATE DATABASE_DEFAULT);
