-- ============================================================================
-- fix-tc2-mate-sourcetext-drift.sql
-- Repair TranslationCache2 SOURCE_TEXT drift for market-template (MaTe:) rows
-- against the live feed template names (prod MarketLookup.MaTeNa).
--
-- Root cause (2026-07-14, 'Odd Or Even Total' incident): prod TranslationCache2
-- was seeded 2026-07-13 from the staging export; 266 MaTe: rows carry a
-- SOURCE_TEXT that differs from the live feed name ONLY BY CASE (e.g.
-- 'Odd or Even Total' vs the feed's 'Odd Or Even Total'), and 18 more differ
-- in wording. The odds-engine translation cache treated any difference as a
-- rename and never served those rows, so the affected markets rendered in
-- English even though TARGET_TEXT_ZH is populated.
--
-- SECTION A (266 rows): case-only drift -> re-case SOURCE_TEXT to the live
--   feed name, KEEPING the existing targets and PROCESSED flag (translations
--   are case-independent).
-- SECTION B (18 rows): genuine wording drift -> set SOURCE_TEXT to the live
--   feed name, CLEAR the targets and reset PROCESSED = 0 so the external
--   pipeline (update.py) re-translates from the current name and announces
--   the result (OnTranslationChange -> Mongo *NaTr cascade).
--
-- Idempotent: both sections re-run to 0 rows affected. Row lists were
-- generated 2026-07-14 by comparing prod TranslationCache2 against prod
-- MarketLookup; a guard on the current SOURCE_TEXT means a row the feed has
-- renamed again since then is left alone rather than clobbered.
--
-- Runbook:
--   1. Run this script against the PRODUCTION Translation database
--      (requires UPDATE permission; translation_read_only cannot run it).
--   2. SECTION B completes itself: update.py picks up the PROCESSED = 0 rows,
--      re-translates, and its announce step cascades into Mongo.
--   3. Restart OE.Translation.Service (and OE.Adapter.Service) so their
--      in-memory caches re-preload the corrected SOURCE_TEXT; the startup
--      BackfillActiveSnapshot then stamps MaNaTr onto active markets that
--      were missing it. (After the case-insensitivity code fix is deployed,
--      this restart is what makes SECTION A rows flow without waiting for
--      the next market message.)
--   4. Verify: the SELECT at the bottom must return 0 rows.
--
-- Scope: MaTe: rows only. Selection/team/league keys (SeTe:/Co:/Te:/SpId:/
-- SegId:/LeId:) were not audited in this pass; the deployed code fix makes
-- case-only drift harmless for them too.
-- ============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

-- ---------------------------------------------------------------------------
-- SECTION A: case-only drift — re-case SOURCE_TEXT, keep translations
-- ---------------------------------------------------------------------------
DECLARE @caseFix TABLE (STRING_ID NVARCHAR(100) PRIMARY KEY, FEED_TEXT NVARCHAR(250) NOT NULL);

INSERT INTO @caseFix (STRING_ID, FEED_TEXT) VALUES
    (N'MaTe:30', N'Rest Of First Half Result'),
    (N'MaTe:130', N'Race To 3 Runs'),
    (N'MaTe:298', N'Team To Score Next Goal (60 Minutes Betting)'),
    (N'MaTe:6497', N'How Will The Tie Be Decided'),
    (N'MaTe:6606', N'1st Half Odd Or Even Total Points'),
    (N'MaTe:6609', N'Team Not To Score'),
    (N'MaTe:6924', N'First Team To Score'),
    (N'MaTe:7143', N'Player To Receive A Card'),
    (N'MaTe:7240', N'Match Winner (3 Way)'),
    (N'MaTe:7351', N'Odd Or Even Total Points'),
    (N'MaTe:7354', N'Odd Or Even Total'),
    (N'MaTe:7411', N'1st Quarter Odd Or Even Total Points'),
    (N'MaTe:7731', N'Team Of Top Batsman'),
    (N'MaTe:7782', N'Team With Most Shots On Target'),
    (N'MaTe:7797', N'Total Shots On Target Over/Under'),
    (N'MaTe:7934', N'Odd Or Even Total'),
    (N'MaTe:8239', N'Match Result And Total Goals Over/Under'),
    (N'MaTe:8577', N'2nd Half Odd Or Even Total Points'),
    (N'MaTe:8710', N'Rest Of Match Result'),
    (N'MaTe:8719', N'Method Of Victory'),
    (N'MaTe:8720', N'Will The Fight Go The Distance'),
    (N'MaTe:8726', N'Exact Number Of Goals'),
    (N'MaTe:9470', N'Will There Be Overtime?'),
    (N'MaTe:9535', N'Half-time Odd Or Even Total'),
    (N'MaTe:9562', N'Total Cards Odd Or Even'),
    (N'MaTe:9670', N'Match Winner (2 Way)'),
    (N'MaTe:9700', N'2nd Quarter Odd Or Even Total Points'),
    (N'MaTe:9701', N'3rd Quarter Odd Or Even Total Points'),
    (N'MaTe:9702', N'4th Quarter Odd Or Even Total Points'),
    (N'MaTe:9882', N'Highest Individual Score In Match Over/Under'),
    (N'MaTe:10145', N'Second Half Exact Number Of Goals'),
    (N'MaTe:10146', N'Half-time Exact Number Of Goals'),
    (N'MaTe:10467', N'Total Goals Odd Or Even (60 Minute Betting)'),
    (N'MaTe:10474', N'Odd Or Even Total Points (Excluding Overtime)'),
    (N'MaTe:10498', N'Match Result After Extra Time (including Normal Time Goals)'),
    (N'MaTe:10499', N'Correct Score After Extra Time (including Normal Time Goals)'),
    (N'MaTe:10500', N'Asian Handicap After Extra Time (including Normal Time Goals)'),
    (N'MaTe:10501', N'Total Goals After Extra Time Over/Under (including Normal Time Goals)'),
    (N'MaTe:10502', N'Result At Extra Time Half-time (including Normal Time Goals)'),
    (N'MaTe:10503', N'Extra Time Next Team To Score (including Normal Time Goals)'),
    (N'MaTe:10504', N'Extra Time Next GoalScorer (including Normal Time Goals)'),
    (N'MaTe:10540', N'Correct Score At Extra Time Half-time (including Normal Time Goals)'),
    (N'MaTe:10541', N'Asian Handicap At Extra Time Half-time (including Normal Time Goals)'),
    (N'MaTe:10542', N'Total Goals At Extra Time Half-time Over/Under (including Normal Time Goals)'),
    (N'MaTe:10589', N'Half-time Home Team Exact Number Of Goals'),
    (N'MaTe:10590', N'Second Half Home Team Exact Number Of Goals'),
    (N'MaTe:10591', N'Second Half Away Team Exact Number Of Goals'),
    (N'MaTe:10592', N'Half-time Away Team Exact Number Of Goals'),
    (N'MaTe:10755', N'Away Team Total Shots On Target Over/Under'),
    (N'MaTe:10756', N'Home Team Total Shots On Target Over/Under'),
    (N'MaTe:10789', N'Half-time Away Team Exact Number Of Corners'),
    (N'MaTe:10790', N'Half-time Home Team Exact Number Of Corners'),
    (N'MaTe:10869', N'Home Team Exact Number Of Goals'),
    (N'MaTe:10870', N'Away Team Exact Number Of Goals'),
    (N'MaTe:10878', N'Half-time Total Corners Odd Or Even'),
    (N'MaTe:10982', N'Extra Time Result (excluding Normal Time Goals)'),
    (N'MaTe:10983', N'Extra Time Correct Score (excluding Normal Time Goals)'),
    (N'MaTe:10984', N'Extra Time Asian Handicap (excluding Normal Time Goals)'),
    (N'MaTe:10985', N'Extra Time Total Goals Over/Under (excluding Normal Time Goals)'),
    (N'MaTe:10986', N'Extra Time Half-time Result (excluding Normal Time Goals)'),
    (N'MaTe:10989', N'Extra Time Next GoalScorer (excluding Normal Time Goals)'),
    (N'MaTe:10992', N'Extra Time Next Team To Score (excluding Normal Time Goals)'),
    (N'MaTe:10993', N'Extra Time Half-time Correct Score (excluding Normal Time Goals)'),
    (N'MaTe:10994', N'Extra Time Half-time Asian Handicap (excluding Normal Time Goals)'),
    (N'MaTe:10995', N'Extra Time Half-time Total Goals Over/Under (excluding Normal Time Goals)'),
    (N'MaTe:11380', N'1st Innings Away Team 1st Over Total Runs Odd Or Even'),
    (N'MaTe:11381', N'1st Innings Home Team 1st Over Total Runs Odd Or Even'),
    (N'MaTe:11461', N'Both Teams To Score In Both Halves'),
    (N'MaTe:11491', N'Race To 2 Runs'),
    (N'MaTe:11492', N'Race To 4 Runs'),
    (N'MaTe:11493', N'Race To 5 Runs'),
    (N'MaTe:11494', N'Race To 6 Runs'),
    (N'MaTe:11495', N'Race To 7 Runs'),
    (N'MaTe:11544', N'Rest Of Match Total Goals Over/Under'),
    (N'MaTe:11657', N'Away Team To Win Either Half Yes/No'),
    (N'MaTe:11678', N'Match To Go To Extra Time And Goal Scored In Extra Time Yes/No'),
    (N'MaTe:11921', N'Both Teams To Score 2 Or More Goals Yes/No'),
    (N'MaTe:12104', N'Player To Assist'),
    (N'MaTe:12205', N'Player To Receive A Red Card'),
    (N'MaTe:12381', N'Match Result And Both Teams To Score'),
    (N'MaTe:12502', N'Half Time Result And Both Teams To Score'),
    (N'MaTe:12818', N'Team To Score Next Goal (3-way)'),
    (N'MaTe:12860', N'Team To Score Next Touchdown'),
    (N'MaTe:12931', N'Rest Of First Half Total Goals Over / Under'),
    (N'MaTe:13014', N'Both Teams To Score And Total Goals Over/Under'),
    (N'MaTe:13031', N'Match Up Winner (3 Way)'),
    (N'MaTe:13035', N'Map 1 Team To Slay The Next Roshan'),
    (N'MaTe:13036', N'Map 1 Team To Destroy The Next Barracks'),
    (N'MaTe:13091', N'Map 1 Team To Destroy The Next Tower'),
    (N'MaTe:13103', N'Map 1 Team To Score The Next Kill'),
    (N'MaTe:13104', N'Map 1 Team To Score The Most Kills'),
    (N'MaTe:13105', N'Map 1 Team To Score The Most Kills Handicap'),
    (N'MaTe:13135', N'Map 2 Team To Slay The Next Roshan'),
    (N'MaTe:13136', N'Map 3 Team To Slay The Next Roshan'),
    (N'MaTe:13219', N'Map 2 Team To Destroy The Next Tower'),
    (N'MaTe:13220', N'Map 3 Team To Destroy The Next Tower'),
    (N'MaTe:13231', N'Map 2 Team To Score The Next Kill'),
    (N'MaTe:13232', N'Map 3 Team To Score The Next Kill'),
    (N'MaTe:13235', N'Map 2 Team To Score The Most Kills'),
    (N'MaTe:13236', N'Map 3 Team To Score The Most Kills'),
    (N'MaTe:13258', N'Map 2 Team To Destroy The Next Barracks'),
    (N'MaTe:13259', N'Map 3 Team To Destroy The Next Barracks'),
    (N'MaTe:13337', N'Map 2 Team To Score The Most Kills Handicap'),
    (N'MaTe:13338', N'Map 3 Team To Score The Most Kills Handicap'),
    (N'MaTe:13496', N'Rest Of Match Asian Handicap'),
    (N'MaTe:13565', N'Map 1 Total Number Of Rounds'),
    (N'MaTe:13566', N'Map 2 Total Number Of Rounds'),
    (N'MaTe:13567', N'Map 3 Total Number Of Rounds'),
    (N'MaTe:13585', N'Best Of 2 Correct Score'),
    (N'MaTe:13586', N'Best Of 3 Correct Score'),
    (N'MaTe:13681', N'Half-time Result And Total Goals Over/Under'),
    (N'MaTe:13697', N'Half-Time Home Team To Win To Nil Yes/No'),
    (N'MaTe:13698', N'Half-Time Away Team To Win To Nil Yes/No'),
    (N'MaTe:13699', N'Second Half Away Team To Win To Nil Yes/No'),
    (N'MaTe:13700', N'Second Half Home Team To Win To Nil Yes/No'),
    (N'MaTe:13766', N'Rest Of First Half Asian Handicap'),
    (N'MaTe:14308', N'Which Team To Score'),
    (N'MaTe:14309', N'Match Result And First Team To Score'),
    (N'MaTe:14421', N'Home Team Wicket In Next Over Yes/No'),
    (N'MaTe:14422', N'Away Team Wicket In Next Over Yes/No'),
    (N'MaTe:14487', N'Map 1 Race To 5 Kills'),
    (N'MaTe:14488', N'Map 2 Race To 5 Kills'),
    (N'MaTe:14489', N'Map 3 Race To 5 Kills'),
    (N'MaTe:14492', N'Map 1 Race To 10 Kills'),
    (N'MaTe:14493', N'Map 2 Race To 10 Kills'),
    (N'MaTe:14494', N'Map 3 Race To 10 Kills'),
    (N'MaTe:14497', N'Map 1 Race To 15 Kills'),
    (N'MaTe:14498', N'Map 2 Race To 15 Kills'),
    (N'MaTe:14499', N'Map 3 Race To 15 Kills'),
    (N'MaTe:14502', N'Map 1 Race To 20 Kills'),
    (N'MaTe:14503', N'Map 2 Race To 20 Kills'),
    (N'MaTe:14504', N'Map 3 Race To 20 Kills'),
    (N'MaTe:14653', N'Away Team Fall Of Next Wicket Over/Under Runs 1st Inns'),
    (N'MaTe:14654', N'Home Team Fall Of Next Wicket Over/Under Runs 1st Inns'),
    (N'MaTe:14773', N'Goal Scored In The Next Minute Yes/No (1 Minute Intervals)'),
    (N'MaTe:14777', N'Goal Scored In The Next 5 Minutes Yes/No (5 Minute Intervals)'),
    (N'MaTe:14795', N'Corner Awarded In The Next Minute Yes/No (1 Minute Intervals)'),
    (N'MaTe:14799', N'Corner Awarded In The Next 5 Minutes Yes/No (5 Minute Intervals)'),
    (N'MaTe:14837', N'Match To Go To Extra Time Yes/No'),
    (N'MaTe:14838', N'Half-time Double Chance And Both Teams To Score'),
    (N'MaTe:14858', N'Penalty Shootout Total Goals Odd Or Even'),
    (N'MaTe:14859', N'Penalty Shootout Home Team Total Goals Odd Or Even'),
    (N'MaTe:14860', N'Penalty Shootout Away Team Total Goals Odd Or Even'),
    (N'MaTe:14981', N'Second Half Double Chance And Both Teams To Score'),
    (N'MaTe:15053', N'Second Half Result And Both Teams To Score'),
    (N'MaTe:15065', N'Next Home Penalty To Be Scored Yes/No'),
    (N'MaTe:15066', N'Next Away Penalty To Be Scored Yes/No'),
    (N'MaTe:15098', N'Next Home Shoot-out Penalty To Be Scored Yes/No'),
    (N'MaTe:15099', N'Next Away Shoot-out Penalty To Be Scored Yes/No'),
    (N'MaTe:15107', N'Numbered Game Both Teams To Score'),
    (N'MaTe:15133', N'Numbered Game Numbered Half Handicap 2 Way'),
    (N'MaTe:15179', N'Exact Number Of Cards'),
    (N'MaTe:15182', N'Home Team Total Cards Odd Or Even'),
    (N'MaTe:15183', N'Away Team Total Cards Odd Or Even'),
    (N'MaTe:15191', N'Half-time Double Chance And Total Goals Over/Under'),
    (N'MaTe:15199', N'Card Awarded In The Next Minute Yes/No (1 Minute Intervals)'),
    (N'MaTe:15200', N'Card Awarded In The Next 5 Minutes Yes/No (5 Minute Intervals)'),
    (N'MaTe:15261', N'First Quarter Home Team To Score 15 Points Yes/No'),
    (N'MaTe:15262', N'First Quarter Home Team To Score 20 Points Yes/No'),
    (N'MaTe:15263', N'First Quarter Home Team To Score 25 Points Yes/No'),
    (N'MaTe:15264', N'First Quarter Home Team To Score 30 Points Yes/No'),
    (N'MaTe:15265', N'First Quarter Home Team To Score 35 Points Yes/No'),
    (N'MaTe:15266', N'First Quarter Away Team To Score 15 Points Yes/No'),
    (N'MaTe:15267', N'First Quarter Away Team To Score 20 Points Yes/No'),
    (N'MaTe:15268', N'First Quarter Away Team To Score 25 Points Yes/No'),
    (N'MaTe:15269', N'First Quarter Away Team To Score 30 Points Yes/No'),
    (N'MaTe:15270', N'First Quarter Away Team To Score 35 Points Yes/No'),
    (N'MaTe:15271', N'Second Quarter Home Team To Score 15 Points Yes/No'),
    (N'MaTe:15272', N'Second Quarter Home Team To Score 20 Points Yes/No'),
    (N'MaTe:15273', N'Second Quarter Home Team To Score 25 Points Yes/No'),
    (N'MaTe:15274', N'Second Quarter Home Team To Score 30 Points Yes/No'),
    (N'MaTe:15275', N'Second Quarter Home Team To Score 35 Points Yes/No'),
    (N'MaTe:15276', N'Second Quarter Away Team To Score 15 Points Yes/No'),
    (N'MaTe:15277', N'Second Quarter Away Team To Score 20 Points Yes/No'),
    (N'MaTe:15278', N'Second Quarter Away Team To Score 25 Points Yes/No'),
    (N'MaTe:15279', N'Second Quarter Away Team To Score 30 Points Yes/No'),
    (N'MaTe:15280', N'Second Quarter Away Team To Score 35 Points Yes/No'),
    (N'MaTe:15281', N'Third Quarter Home Team To Score 15 Points Yes/No'),
    (N'MaTe:15282', N'Third Quarter Home Team To Score 20 Points Yes/No'),
    (N'MaTe:15283', N'Third Quarter Home Team To Score 25 Points Yes/No'),
    (N'MaTe:15284', N'Third Quarter Home Team To Score 30 Points Yes/No'),
    (N'MaTe:15285', N'Third Quarter Home Team To Score 35 Points Yes/No'),
    (N'MaTe:15286', N'Third Quarter Away Team To Score 15 Points Yes/No'),
    (N'MaTe:15287', N'Third Quarter Away Team To Score 20 Points Yes/No'),
    (N'MaTe:15288', N'Third Quarter Away Team To Score 25 Points Yes/No'),
    (N'MaTe:15289', N'Third Quarter Away Team To Score 30 Points Yes/No'),
    (N'MaTe:15290', N'Third Quarter Away Team To Score 35 Points Yes/No'),
    (N'MaTe:15291', N'Fourth Quarter Home Team To Score 15 Points Yes/No'),
    (N'MaTe:15292', N'Fourth Quarter Home Team To Score 20 Points Yes/No'),
    (N'MaTe:15293', N'Fourth Quarter Home Team To Score 25 Points Yes/No'),
    (N'MaTe:15294', N'Fourth Quarter Home Team To Score 30 Points Yes/No'),
    (N'MaTe:15295', N'Fourth Quarter Home Team To Score 35 Points Yes/No'),
    (N'MaTe:15296', N'Fourth Quarter Away Team To Score 15 Points Yes/No'),
    (N'MaTe:15297', N'Fourth Quarter Away Team To Score 20 Points Yes/No'),
    (N'MaTe:15298', N'Fourth Quarter Away Team To Score 25 Points Yes/No'),
    (N'MaTe:15299', N'Fourth Quarter Away Team To Score 30 Points Yes/No'),
    (N'MaTe:15300', N'Fourth Quarter Away Team To Score 35 Points Yes/No'),
    (N'MaTe:15302', N'Numbered Home Shoot-out Penalty To Be Scored Yes/No'),
    (N'MaTe:15303', N'Numbered Away Shoot-out Penalty To Be Scored Yes/No'),
    (N'MaTe:15682', N'Match Result In The Next 5 Minutes (5 Minute Intervals)'),
    (N'MaTe:15684', N'Team With Most Corners In The Next 5 Minutes (5 Minute Intervals)'),
    (N'MaTe:15686', N'Most Carded Team In The Next 5 Minutes (5 Minute Intervals)'),
    (N'MaTe:15688', N'Next Team To Score In The Next 5 Minutes (5 Minute Intervals)'),
    (N'MaTe:15690', N'Next Corner Team In The Next 5 Minutes (5 Minute Intervals)'),
    (N'MaTe:15692', N'Next Carded Team In The Next 5 Minutes (5 Minute Intervals)'),
    (N'MaTe:15694', N'1st Quarter Money Line And 1st Quarter Total Points Over/Under'),
    (N'MaTe:15697', N'1st Quarter Point Spread And 1st Quarter Total Points Over/Under'),
    (N'MaTe:15748', N'Total Match 4s Odd Or Even'),
    (N'MaTe:15750', N'Total Match 6s Odd Or Even'),
    (N'MaTe:15753', N'Total Match Run Outs Odd Or Even'),
    (N'MaTe:15769', N'Highest Scoring Over In Match Over/Under'),
    (N'MaTe:15858', N'1st Innings Player To Reach 50 Runs Yes/No'),
    (N'MaTe:15861', N'1st Innings Home Team First 6 Overs Total Runs Odd Or Even'),
    (N'MaTe:15862', N'1st Innings Away Team First 6 Overs Total Runs Odd Or Even'),
    (N'MaTe:15863', N'1st Innings Home Team Fall Of 1st Wicket Total Runs Odd Or Even'),
    (N'MaTe:15864', N'1st Innings Away Team Fall Of 1st Wicket Total Runs Odd Or Even'),
    (N'MaTe:15865', N'1st Innings Home Team Fall Of Next Wicket Total Runs Odd Or Even'),
    (N'MaTe:15866', N'1st Innings Away Team Fall Of Next Wicket Total Runs Odd Or Even'),
    (N'MaTe:15867', N'1st Innings Individual Player Total Runs Odd Or Even'),
    (N'MaTe:15900', N'1st Innings Player A And Player B Both To Reach 25'),
    (N'MaTe:15901', N'1st Innings Player A And Player B Both To Reach 50'),
    (N'MaTe:15902', N'1st Innings Player A And Player B Both To Reach 75'),
    (N'MaTe:15903', N'1st Innings Player A And Player B Both To Reach 100'),
    (N'MaTe:15936', N'1st Innings Player A And Player B Both To Hit A Two'),
    (N'MaTe:15937', N'1st Innings Player A And Player B Both To Hit A Three'),
    (N'MaTe:15938', N'1st Innings Player A And Player B Both To Hit A Six'),
    (N'MaTe:15942', N'1st Innings Home Team First 10 Overs Total Runs Odd Or Even'),
    (N'MaTe:15943', N'1st Innings Away Team First 10 Overs Total Runs Odd Or Even'),
    (N'MaTe:15944', N'1st Innings Home Team First N Overs Total Runs Odd Or Even'),
    (N'MaTe:15962', N'1st Innings Home Team Total 4s Odd Or Even'),
    (N'MaTe:15963', N'1st Innings Away Team Total 4s Odd Or Even'),
    (N'MaTe:15982', N'1st Innings Home Team Next Over Total Runs Odd Or Even'),
    (N'MaTe:15983', N'1st Innings Away Team Next Over Total Runs Odd Or Even'),
    (N'MaTe:16002', N'Numbered Game Match Result And Both Teams To Score'),
    (N'MaTe:16016', N'Numbered Game Odd Or Even Total'),
    (N'MaTe:16017', N'Numbered Game 1st Half Odd Or Even Total'),
    (N'MaTe:16023', N'Numbered Game Exact Number Of Goals'),
    (N'MaTe:16024', N'Numbered Game Home Team Exact Number Of Goals'),
    (N'MaTe:16025', N'Numbered Game Away Team Exact Number Of Goals'),
    (N'MaTe:16035', N'Half-time Exact Number Of Cards'),
    (N'MaTe:16059', N'1st Innings Player To Reach 10 Runs Yes/No'),
    (N'MaTe:16060', N'1st Innings Player To Reach 25 Runs Yes/No'),
    (N'MaTe:16061', N'1st Innings Player To Reach 75 Runs Yes/No'),
    (N'MaTe:16062', N'1st Innings Player To Reach 100 Runs Yes/No'),
    (N'MaTe:16063', N'1st Innings Player To Reach 125 Runs Yes/No'),
    (N'MaTe:16064', N'1st Innings Player To Reach 150 Runs Yes/No'),
    (N'MaTe:16065', N'1st Innings Player To Reach 175 Runs Yes/No'),
    (N'MaTe:16107', N'Corner Awarded In The Next 10 Minutes Yes/No (10 Minute Intervals)'),
    (N'MaTe:16108', N'Team With Most Corners In The Next 10 Minutes (10 Minute Intervals)'),
    (N'MaTe:16109', N'Next Corner Team In The Next 10 Minutes (10 Minute Intervals)'),
    (N'MaTe:16116', N'Card Awarded In The Next 10 Minutes Yes/No (10 Minute Intervals)'),
    (N'MaTe:16117', N'Most Carded Team In The Next 10 Minutes (10 Minute Intervals)'),
    (N'MaTe:16118', N'Next Carded Team In The Next 10 Minutes (10 Minute Intervals)'),
    (N'MaTe:16135', N'Player To Have 1 Or More Shots'),
    (N'MaTe:16136', N'Player To Have 2 Or More Shots'),
    (N'MaTe:16137', N'Player To Have 3 Or More Shots'),
    (N'MaTe:16138', N'Player To Have 4 Or More Shots'),
    (N'MaTe:16139', N'Player To Have 5 Or More Shots'),
    (N'MaTe:16140', N'Player To Have 6 Or More Shots'),
    (N'MaTe:16141', N'Player To Have 7 Or More Shots'),
    (N'MaTe:16142', N'Player To Have 8 Or More Shots'),
    (N'MaTe:16143', N'Player To Have 1 Or More Shots On Target'),
    (N'MaTe:16144', N'Player To Have 2 Or More Shots On Target'),
    (N'MaTe:16145', N'Player To Have 3 Or More Shots On Target'),
    (N'MaTe:16146', N'Player To Have 4 Or More Shots On Target'),
    (N'MaTe:16147', N'Player To Have 5 Or More Shots On Target');

UPDATE tc
SET tc.SOURCE_TEXT = f.FEED_TEXT,
    tc.UPDATED_AT  = GETUTCDATE()
FROM dbo.TranslationCache2 tc
JOIN @caseFix f ON tc.STRING_ID = f.STRING_ID
WHERE tc.SOURCE_TEXT COLLATE SQL_Latin1_General_CP1_CI_AS = f.FEED_TEXT   -- same text ignoring case
  AND tc.SOURCE_TEXT COLLATE Latin1_General_BIN           <> f.FEED_TEXT; -- but cased differently

PRINT 'SECTION A (case-only re-case, translations kept): ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' row(s) updated (expected 266 on first run, 0 after).';

-- ---------------------------------------------------------------------------
-- SECTION B: wording drift — adopt feed name, re-open the pipeline worklist
-- ---------------------------------------------------------------------------
DECLARE @textFix TABLE (STRING_ID NVARCHAR(100) PRIMARY KEY, FEED_TEXT NVARCHAR(250) NOT NULL);

INSERT INTO @textFix (STRING_ID, FEED_TEXT) VALUES
    (N'MaTe:42', N'Player To Score A Hat Trick'),
    (N'MaTe:297', N'Team With Most Corners'),
    (N'MaTe:311', N'Game Handicap'),
    (N'MaTe:6631', N'Corners Handicap With Tie'),
    (N'MaTe:6698', N'1st Half Total Points Over / Under'),
    (N'MaTe:6736', N'1st Quarter Total Points Over / Under'),
    (N'MaTe:6851', N'2nd Quarter Total Points Over / Under'),
    (N'MaTe:7086', N'Home Team Goals (Bands)'),
    (N'MaTe:7087', N'Away Team Goals (Bands)'),
    (N'MaTe:7121', N'Player To Score Two Or More Goals'),
    (N'MaTe:7417', N'2nd Half Total Points Over / Under'),
    (N'MaTe:10054', N'Second Half Home Team Total Goals Over / Under'),
    (N'MaTe:10055', N'Second Half Away Team Total Goals Over / Under'),
    (N'MaTe:10781', N'Away Team Corners (Bands)'),
    (N'MaTe:10849', N'Half-time Away Team Goals Over / Under'),
    (N'MaTe:10850', N'Half-time Home Team Goals Over / Under'),
    (N'MaTe:15190', N'Second Half Result And Total Goals Over / Under'),
    (N'MaTe:15192', N'Second Half Double Chance And Total Goals Over / Under');

UPDATE tc
SET tc.SOURCE_TEXT    = f.FEED_TEXT,
    tc.TARGET_TEXT_ZH = N'',
    tc.TARGET_TEXT_ES = N'',
    tc.TARGET_TEXT_FR = N'',
    tc.PROCESSED      = 0,
    tc.UPDATED_AT     = GETUTCDATE()
FROM dbo.TranslationCache2 tc
JOIN @textFix f ON tc.STRING_ID = f.STRING_ID
WHERE tc.SOURCE_TEXT COLLATE SQL_Latin1_General_CP1_CI_AS <> f.FEED_TEXT; -- still carries the old wording

PRINT 'SECTION B (wording drift, re-queued for translation): ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' row(s) updated (expected 18 on first run, 0 after).';

COMMIT TRANSACTION;

-- ---------------------------------------------------------------------------
-- VERIFICATION: must return 0 rows — every listed key now matches the feed
-- name byte-for-byte (SECTION B rows match once this script corrects them;
-- their translations arrive when update.py drains the worklist).
-- ---------------------------------------------------------------------------
SELECT tc.STRING_ID, tc.SOURCE_TEXT, x.FEED_TEXT
FROM dbo.TranslationCache2 tc
JOIN (SELECT STRING_ID, FEED_TEXT FROM @caseFix
      UNION ALL
      SELECT STRING_ID, FEED_TEXT FROM @textFix) x ON tc.STRING_ID = x.STRING_ID
WHERE tc.SOURCE_TEXT COLLATE Latin1_General_BIN <> x.FEED_TEXT;
