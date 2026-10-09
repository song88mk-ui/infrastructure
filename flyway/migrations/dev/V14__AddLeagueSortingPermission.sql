-- BO-107: League Sorting permission (Auth database).
-- Adds the SBC.OE.LeagueSorting claim that the League Sorting page, its Sports Settings nav entry and its edit
-- actions are gated on (backoffice-final Backoffice.Web/Extensions/WebApplicationBuilderExtensions.cs).
-- The Manage Users and Manage User Groups screens build their permission tree from dbo.Permission, so this row is
-- all it takes for the permission to appear under Odds Engine > Sports Settings with View and Edit. CategoryId 1
-- (SportsbookClient) means Super Admin receives it at its next login; other roles get it through Manage User Groups.
-- Idempotent: the row is inserted only when its ClaimType is missing (dbo.Permission has no unique constraint on
-- ClaimType, so this guard is the only protection against duplicates). Same values as the dev seed
-- R__Seed_010_Auth_Permissions.sql, so whichever runs first wins and the other is a no-op.

USE Auth;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE ClaimType = 'SBC.OE.LeagueSorting')
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, CategoryId, CategoryName, SubCategoryName, GroupName, Name, ClaimType, HasReadOnly, SortOrder, IsSubUser, UserGroupTemplateIdRef, Version)
    VALUES
        (NEWID(), 1, 'SportsbookClient', 'Odds Engine', 'Sports Settings', 'League Sorting', 'SBC.OE.LeagueSorting', 1, 26, 1, 0, 2);
END;

-- rollback
-- Role grants are stored by claim type in dbo.AspNetRoleClaims, so remove them with the permission.
-- USE Auth;
--
-- DELETE FROM dbo.AspNetRoleClaims WHERE ClaimType = 'SBC.OE.LeagueSorting';
-- DELETE FROM dbo.Permission WHERE ClaimType = 'SBC.OE.LeagueSorting';
