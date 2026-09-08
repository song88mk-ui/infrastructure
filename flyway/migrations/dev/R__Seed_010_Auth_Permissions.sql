-- GM-796: backoffice permission catalogue (Auth database).
--
-- Auth.Api has no migration or seed mechanism for dbo.Permission, yet the backoffice cannot be used without it:
-- at login Auth.Api turns Permission rows into JWT claims (Auth.Api/Repositories/AuthRepository.cs GenerateToken;
-- a 'Super Admin' receives every row with CategoryId <> 99), the backoffice authorizes every page against those
-- claim types (Backoffice.Web/Extensions/WebApplicationBuilderExtensions.cs), builds its navigation from
-- SubCategoryName/GroupName (Backoffice.Web/Shared/LayoutBase.cs) and refuses a login without any claim
-- (Backoffice.Web/Pages/Authentication/Login.cshtml.cs).
--
-- The rows below are the complete catalogue of the STG Auth database as exported on 2026-09-07 (72 rows: categories
-- 0 Admin, 1 SportsbookClient, 2 PartnerManagement, 4 Translations, 10 AgentManagement and 99 hidden), copied
-- verbatim except for PermissionId, which is generated (grants reference it per environment).
-- Admin.Settlements.MessageSettlement is absent on STG as well (removed by V4__DisableMessageSettlementPermission).
--
-- Repeatable and idempotent: a row is inserted only when its ClaimType is missing, so renames or SortOrder changes
-- made by operators are never overwritten. dbo.Permission has no unique constraint on ClaimType, so this guard is
-- the only protection against duplicates.

USE Auth;

DECLARE @seed TABLE
(
    CategoryId             int         NOT NULL,
    CategoryName           varchar(50) NOT NULL,
    SubCategoryName        varchar(50) NOT NULL,
    GroupName              varchar(50) NOT NULL,
    Name                   varchar(50) NOT NULL,
    ClaimType              varchar(50) NOT NULL PRIMARY KEY,
    HasReadOnly            bit         NOT NULL,
    SortOrder              int         NOT NULL,
    IsSubUser              bit         NOT NULL,
    UserGroupTemplateIdRef int         NOT NULL,
    Version                int         NOT NULL
);

INSERT INTO @seed (CategoryId, CategoryName, SubCategoryName, GroupName, Name, ClaimType, HasReadOnly, SortOrder, IsSubUser, UserGroupTemplateIdRef, Version) VALUES
    (0, 'Admin', 'Dashboard', '', 'Dashboard', 'Admin.Dashboard', 0, 1, 0, 27, 0),
    (0, 'Admin', 'User & User Groups', '', 'Create User', 'Admin.CreateUser', 0, 2, 0, 28, 1),
    (0, 'Admin', 'User & User Groups', '', 'Manage Users', 'Admin.ManageUsers', 0, 2, 0, 29, 0),
    (0, 'Admin', 'User & User Groups', '', 'Create User Group', 'Admin.CreateUserGroup', 0, 3, 0, 30, 1),
    (0, 'Admin', 'User & User Groups', '', 'Manage User Groups', 'Admin.ManageUserGroups', 0, 3, 0, 31, 0),
    (0, 'Admin', 'Settlements', '', 'Manual Bet Settlement', 'Admin.Settlements.ManualBetSettlement', 0, 4, 0, 1101, 0),
    (0, 'Admin', 'Settlements', '', 'Manual Bet Settlement History', 'Admin.Settlements.ManualBetSettlementHistory', 0, 5, 0, 1100, 1),
    (0, 'Admin', 'Settlements', '', 'Resend Settlement', 'Admin.Settlements.ResendSettlement', 0, 6, 0, 1103, 2),
    (0, 'Admin', 'Settlements', '', 'Market Settlement', 'Admin.Settlements.MarketSettlement', 0, 7, 0, 0, 2),
    (0, 'Admin', 'Cancel Bets', '', 'Cancel Bets', 'Admin.CancelBets', 0, 9, 0, 1095, 0),
    (0, 'Admin', 'Cancel Bets', '', 'Cancel Bets History', 'Admin.CancelBetsHistory', 0, 10, 0, 1096, 0),
    (0, 'Admin', '', '', 'Client Site Config', 'Admin.ClientSiteConfig', 1, 10, 0, 0, 0),
    (0, 'Admin', 'Maintenance', '', 'Maintenance', 'Admin.Maintenance', 0, 11, 0, 40, 0),
    (1, 'SportsbookClient', 'Dashboard', '', 'Dashboard', 'SBC.Dashboard', 0, 1, 1, 32, 0),
    (1, 'SportsbookClient', 'Reports', '', 'Drill Down Report', 'SBC.Reports.DrillDownReport', 0, 2, 1, 0, 2),
    (1, 'SportsbookClient', 'Reports', '', 'Open Bets', 'SBC.Reports.OpenBets', 0, 3, 1, 0, 2),
    (1, 'SportsbookClient', 'Reports', '', 'Search BetId', 'SBC.Reports.SearchBetId', 0, 4, 1, 0, 2),
    (1, 'SportsbookClient', 'Reports', '', 'Search UserId', 'SBC.Reports.SearchUserId', 0, 5, 1, 0, 2),
    (1, 'SportsbookClient', 'Reports', '', 'Search Event', 'SBC.Reports.SearchEvent', 0, 6, 1, 0, 2),
    (1, 'SportsbookClient', 'Reports', '', 'Monitor Users', 'SBC.Reports.MonitorUsers', 0, 7, 1, 0, 2),
    (1, 'SportsbookClient', 'Reports', '', 'Sports', 'SBC.Reports.Sports', 0, 8, 1, 0, 2),
    (1, 'SportsbookClient', 'Reports', '', 'Market Report', 'SBC.Reports.MarketReport', 0, 9, 1, 0, 2),
    (1, 'SportsbookClient', 'Settings', '', 'Top Leagues', 'SBC.Settings.TopLeagues', 1, 16, 1, 92, 0),
    (1, 'SportsbookClient', 'Settings', '', 'Top Fixtures', 'SBC.Settings.TopFixtures', 1, 17, 1, 91, 0),
    (1, 'SportsbookClient', 'Settings', '', 'Parlay Bonus', 'SBC.Settings.ParlayBonus', 1, 18, 1, 101, 0),
    (1, 'SportsbookClient', 'Settings', '', 'Announcements', 'SBC.Settings.Announcements', 1, 19, 1, 0, 0),
    (1, 'SportsbookClient', 'Sub Users', '', 'Sub Users', 'SBC.SubUsers', 1, 19, 0, 98, 0),
    (1, 'SportsbookClient', 'Clients', '', 'Clients', 'SBC.Clients', 1, 20, 0, 34, 0),
    (1, 'SportsbookClient', 'Clients', '', 'Clients Access', 'SBC.Clients.Access', 0, 20, 0, 0, 0),
    (1, 'SportsbookClient', 'Odds Engine', '', 'Odds Engine', 'SBC.OE', 0, 21, 1, 0, 2),
    (1, 'SportsbookClient', 'Odds Engine', 'Sports Settings', 'Sports Settings', 'SBC.OE.SportsSettings', 1, 25, 1, 0, 2),
    (1, 'SportsbookClient', 'Odds Engine', 'Market Settings', 'Market Sort Order', 'SBC.OE.MarketSetting.SortOrder', 1, 26, 1, 0, 2),
    (1, 'SportsbookClient', 'Odds Engine', 'Market Settings', 'Market Group', 'SBC.OE.MarketSetting.Group', 0, 27, 1, 0, 2),
    (1, 'SportsbookClient', 'Odds Engine', 'Market Settings', 'Selector Market Templates', 'SBC.OE.MarketSetting.SelectorTemplates', 1, 27, 1, 0, 2),
    (1, 'SportsbookClient', 'Odds Engine', 'Price Boost', 'Manage Price Boost', 'SBC.OE.PriceBoost.Manage', 1, 28, 1, 0, 2),
    (1, 'SportsbookClient', 'Odds Engine', 'Price Boost', 'Boosted Settings', 'SBC.OE.PriceBoost.Settings', 1, 29, 1, 0, 2),
    (1, 'SportsbookClient', 'Deeplink Generator', '', 'Deeplink Generator', 'SBC.DeeplinkGenerator', 0, 30, 0, 90, 1),
    (1, 'SportsbookClient', 'Reports', '', 'Win Loss', 'SBC.WinLoss', 0, 31, 0, 57, 1),
    (1, 'SportsbookClient', 'Reports', '', 'Profit Loss', 'SBC.ProfitLoss', 1, 32, 0, 35, 1),
    (1, 'SportsbookClient', 'Reports', '', 'GGR', 'SBC.GGR', 1, 33, 0, 1089, 1),
    (1, 'SportsbookClient', 'Revenue Settlement', '', 'Monthly GGR', 'SBC.MonthlyGGR', 1, 34, 0, 44, 1),
    (1, 'SportsbookClient', 'Revenue Settlement', '', 'Monthly Settlement', 'SBC.MonthlySettlement', 1, 35, 0, 48, 1),
    (1, 'SportsbookClient', 'Total Bets', '', 'All Bets', 'SBC.AllBets', 1, 36, 0, 68, 1),
    (2, 'PartnerManagement', 'Reports', '', 'Agent Win Loss', 'PM.AgentWinLoss', 1, 1, 0, 8, 1),
    (2, 'PartnerManagement', 'Dashboard', '', 'Dashboard', 'PM.Dashboard', 0, 1, 0, 1, 1),
    (2, 'PartnerManagement', 'Total Bets', '', 'HDP, OU & 1x2', 'PM.Hdpou', 1, 1, 0, 12, 1),
    (2, 'PartnerManagement', 'Payments', '', 'Payment Transfer', 'PM.PaymentTransfer', 1, 1, 0, 20, 1),
    (2, 'PartnerManagement', 'Partners & Members', '', 'Create Partner', 'PM.CreatePartner', 0, 2, 0, 3, 1),
    (2, 'PartnerManagement', 'Total Bets', '', 'Parlay', 'PM.Parlay', 1, 2, 0, 14, 1),
    (2, 'PartnerManagement', 'Reports', '', 'Win Loss Details', 'PM.WinLossDetails', 1, 2, 0, 9, 1),
    (2, 'PartnerManagement', 'Total Bets', '', 'All Bets', 'PM.Allbets', 1, 3, 0, 15, 1),
    (2, 'PartnerManagement', 'Partners & Members', '', 'Manage Partners', 'PM.ManagePartners', 1, 3, 0, 4, 1),
    (2, 'PartnerManagement', 'Payments', '', 'Payment History', 'PM.PaymentHistory', 1, 3, 0, 22, 1),
    (2, 'PartnerManagement', 'Reports', '', 'P/L (EUR)', 'PM.ProfitLoss', 1, 3, 0, 10, 1),
    (2, 'PartnerManagement', 'Reports', '', 'Gross Gaming Revenue', 'PM.GGR', 1, 4, 0, 76, 1),
    (2, 'PartnerManagement', 'Partners & Members', '', 'PT Setting', 'PM.PTSetting', 1, 4, 0, 6, 1),
    (2, 'PartnerManagement', 'Payments', '', 'Monthly Revenue Settlement', 'PM.WLMonthlySettlement', 1, 4, 0, 78, 1),
    (2, 'PartnerManagement', 'Reports', '', 'Monthly Gross Gaming Revenue', 'PM.MonthlyGGR', 1, 5, 0, 84, 1),
    (2, 'PartnerManagement', 'Payments', '', 'Settlement History', 'PM.SettlementHistory', 1, 5, 0, 80, 1),
    (4, 'Translations', 'Translation Management', '', 'Static Translation', 'Translations.Static', 1, 1, 0, 0, 0),
    (4, 'Translations', 'Translation Management', '', 'Dynamic Translation', 'Translations.Dynamic', 1, 2, 0, 0, 0),
    (10, 'AgentManagement', '', '', 'Dashboard', 'AMS.Dashboard', 0, 1, 1, 0, 1),
    (10, 'AgentManagement', '', '', 'Accounts', 'AMS.Accounts', 0, 2, 1, 0, 1),
    (10, 'AgentManagement', '', '', 'Announcement', 'AMS.Announcement', 0, 3, 1, 0, 1),
    (10, 'AgentManagement', '', '', 'Member Management', 'AMS.MemberManagement', 1, 4, 1, 0, 1),
    (10, 'AgentManagement', '', '', 'Forecast', 'AMS.Forecast', 0, 5, 1, 0, 1),
    (10, 'AgentManagement', '', '', 'Total Bets', 'AMS.TotalBets', 0, 6, 1, 0, 1),
    (10, 'AgentManagement', '', '', 'Reports', 'AMS.Reports', 0, 7, 1, 0, 1),
    (10, 'AgentManagement', '', '', 'Payments', 'AMS.Payments', 0, 8, 1, 0, 1),
    (99, 'SportsbookClient', 'Odds Engine', 'Monitoring', 'Match Type', 'SBC.OE.Monitoring.MatchType', 1, 22, 1, 0, 2),
    (99, 'SportsbookClient', 'Odds Engine', 'Monitoring', 'Outright', 'SBC.OE.Monitoring.Outright', 0, 23, 1, 0, 2),
    (99, 'SportsbookClient', 'Odds Engine', 'Config', 'Config', 'SBC.OE.Config', 1, 24, 1, 0, 2);

INSERT INTO dbo.Permission
    (PermissionId, CategoryId, CategoryName, SubCategoryName, GroupName, Name, ClaimType, HasReadOnly, SortOrder, IsSubUser, UserGroupTemplateIdRef, Version)
SELECT
    NEWID(), s.CategoryId, s.CategoryName, s.SubCategoryName, s.GroupName, s.Name, s.ClaimType, s.HasReadOnly, s.SortOrder, s.IsSubUser, s.UserGroupTemplateIdRef, s.Version
FROM @seed s
WHERE NOT EXISTS (SELECT 1 FROM dbo.Permission p WHERE p.ClaimType = s.ClaimType)
  -- An environment that still carries the pre-GM-693 name must be renamed by backoffice-final
  -- scripts/sql/rename-feature-flags-to-client-site-config.sql instead of receiving a second row.
  AND NOT (s.ClaimType = 'Admin.ClientSiteConfig'
           AND EXISTS (SELECT 1 FROM dbo.Permission p WHERE p.ClaimType = 'Admin.FeatureFlags'));
