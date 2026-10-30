-- BO-128: show the Odds Engine Config tab again (Auth database).
-- The SBC.OE.Config permission row is in CategoryId 99 (hidden), and Auth.Api never puts a category 99 permission into
-- a token, for any role or for Super Admin (Auth.Api AuthRepository.cs GenerateToken). backoffice-final shows the
-- Config tab and gates its pages on that claim (Backoffice.Web/Shared/OddsEngine/HeaderNavMenu.razor,
-- Backoffice.Web/Extensions/WebApplicationBuilderExtensions.cs), so the tab could not appear for anyone. CategoryId 1
-- (SportsbookClient) means Super Admin receives it at its next login, and Manage User Groups can grant it.
-- Only Config changes: the SBC.OE.Monitoring.* rows stay in category 99.
-- Token length: Super Admin gets one more claim, about 27 characters. The STG Super Admin token measured 2993
-- characters on 2026-10-29, and Auth.dbo.ActivityLog.Token stores the whole token, so V15__WidenAuthActivityLogToken
-- (nvarchar(max)) must have run first; it has a lower version, so flyway applies it before this one. Do not apply
-- this one by hand ahead of it: a Super Admin login would fail on the 3000 character limit.
-- Deployment order: apply this once the backoffice-final release that makes the Assigned tab read-only (odds come from
-- the provider as is) is deployed to STG, so the Config tab is not visible with the odds-editing controls still active.
-- Idempotent, target state: a hidden row is moved to category 1, a missing row is inserted, and a row already in
-- another category is left alone.

USE Auth;

IF EXISTS (SELECT 1 FROM dbo.Permission WHERE ClaimType = 'SBC.OE.Config')
BEGIN
    UPDATE dbo.Permission
    SET CategoryId = 1
    WHERE ClaimType = 'SBC.OE.Config'
      AND CategoryId = 99;
END
ELSE
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, CategoryId, CategoryName, SubCategoryName, GroupName, Name, ClaimType, HasReadOnly, SortOrder, IsSubUser, UserGroupTemplateIdRef, Version)
    VALUES
        (NEWID(), 1, 'SportsbookClient', 'Odds Engine', 'Config', 'Config', 'SBC.OE.Config', 1, 24, 1, 0, 2);
END;

-- rollback
-- Hides the permission again. Role grants are untouched, they stay stored by claim type in dbo.AspNetRoleClaims.
-- USE Auth;
--
-- UPDATE dbo.Permission SET CategoryId = 99 WHERE ClaimType = 'SBC.OE.Config';
