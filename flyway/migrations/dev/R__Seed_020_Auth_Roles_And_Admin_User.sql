-- GM-796: bootstrap identity data so a brand-new environment has a working backoffice login.
--
-- Repeatable migration (R__): Flyway re-runs it whenever the file changes. Every statement is guarded, so
-- re-running converges to the same end state and never overwrites rows that already exist (a changed
-- password, renamed role or extra users are left untouched).
--
-- What it creates in the Auth database:
--   AspNetRoles     'Super Admin' - Auth.Api grants this role every Permission row with CategoryId <> 99 at login
--                                   (Auth.Api/Repositories/AuthRepository.cs, GenerateToken), and the backoffice refuses
--                                   to create a user group with that name, so it must pre-exist.
--                   'Default'     - fallback role used by Auth.Shared/Services/AuthService.cs (AddAspNetUsers when no
--                                   role is given, DeleteAspNetRoles when a role is removed).
--   AspNetUsers     'admin'       - one bootstrap operator in the Super Admin role, so someone can log in to the
--                                   backoffice and create the real users, user groups and clients through the UI.
--                                   AppId 3 = Backoffice.Shared/Enums/Application2.BO, the Provider value the backoffice
--                                   sends to v1/login (Auth.Api rejects a login whose Provider differs from AppId).
--                   'superadmin'  - second bootstrap operator in the Super Admin role, mirroring the login name used on
--                                   STG so people can use the account name they already know.
--
-- The hashes below are ASP.NET Core Identity V3 values (the format Auth.Api verifies at login). 'admin' uses the DEV
-- bootstrap login handed over with GM-796; 'superadmin' uses the same password as the STG 'superadmin' account (hash
-- copied from STG Auth.dbo.AspNetUsers on 2026-09-09). Change both after the first login (Administration -> Manage Users).
-- DEV and new non-production environments only: never copy this script to migrations/stg or migrations/prd.
-- For another environment generate a fresh value with PasswordHasher<T>.HashPassword and replace it below.

USE Auth;

DECLARE @superAdminRoleId nvarchar(50) = N'8f0a5c1e-0d5b-4b3a-9c0e-6f4c7d1a2b30';
DECLARE @defaultRoleId    nvarchar(50) = N'3d9b7e42-6a1f-4c58-b2d0-9e8f1a2c3d41';
DECLARE @adminUserId      varchar(36)  = 'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';
DECLARE @superAdminUserId varchar(36)  = '307bf1aa-a59d-434f-923c-24d297bcdce3'; -- same Id as the STG 'superadmin' row

IF NOT EXISTS (SELECT 1 FROM dbo.AspNetRoles WHERE NormalizedName = N'SUPER ADMIN')
BEGIN
    INSERT INTO dbo.AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp, UserGroupIdRef)
    VALUES (@superAdminRoleId, N'Super Admin', N'SUPER ADMIN', CONVERT(nvarchar(50), NEWID()), 1677637552924); -- UserGroupIdRef as on STG
END;

IF NOT EXISTS (SELECT 1 FROM dbo.AspNetRoles WHERE NormalizedName = N'DEFAULT')
BEGIN
    INSERT INTO dbo.AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp, UserGroupIdRef)
    VALUES (@defaultRoleId, N'Default', N'DEFAULT', CONVERT(nvarchar(50), NEWID()), 1677637682594); -- UserGroupIdRef as on STG
END;

IF NOT EXISTS (SELECT 1 FROM dbo.AspNetUsers WHERE NormalizedUserName = N'ADMIN')
BEGIN
    INSERT INTO dbo.AspNetUsers
        (Id, UserName, NormalizedUserName, Email, NormalizedEmail, EmailConfirmed,
         PasswordHash, SecurityStamp, ConcurrencyStamp,
         PhoneNumber, PhoneNumberConfirmed, TwoFactorEnabled, LockoutEnd, LockoutEnabled, AccessFailedCount,
         NickName, MainUserId, AppId, AppName, CreatedDate, IdRef)
    VALUES
        (@adminUserId, N'admin', N'ADMIN', NULL, NULL, 1,
         N'AQAAAAIAAYagAAAAEGDBqZWX2qc0E7YWfwCze/31uZfVu1BrDhvUaIziv6kt0AVRaJ+bPpNQbCN3c2/b9w==',
         CONVERT(nvarchar(50), NEWID()), CONVERT(nvarchar(50), NEWID()),
         NULL, 0, 0, NULL, 0, 0,
         N'Administrator', N'', 3, N'BO', SYSUTCDATETIME(), 1);
END;

-- IdRef mirrors Auth.Shared/Services/AuthService.cs (AddAspNetUsers): MAX(IdRef) + 1 over the existing users.
IF NOT EXISTS (SELECT 1 FROM dbo.AspNetUsers WHERE NormalizedUserName = N'SUPERADMIN')
BEGIN
    INSERT INTO dbo.AspNetUsers
        (Id, UserName, NormalizedUserName, Email, NormalizedEmail, EmailConfirmed,
         PasswordHash, SecurityStamp, ConcurrencyStamp,
         PhoneNumber, PhoneNumberConfirmed, TwoFactorEnabled, LockoutEnd, LockoutEnabled, AccessFailedCount,
         NickName, MainUserId, AppId, AppName, CreatedDate, IdRef)
    VALUES
        (@superAdminUserId, N'superadmin', N'SUPERADMIN', NULL, NULL, 1,
         N'AQAAAAIAAYagAAAAECIz2g/qEGLHHZAtDSujYvTf/0Yambi/YBdfb4a212fJm0WmWquZri5disyDiCbEKw==',
         CONVERT(nvarchar(50), NEWID()), CONVERT(nvarchar(50), NEWID()),
         NULL, 0, 0, NULL, 0, 0,
         N'Super Administrator', N'', 3, N'BO', SYSUTCDATETIME(),
         (SELECT ISNULL(MAX(IdRef), 0) + 1 FROM dbo.AspNetUsers));
END;

-- Link the bootstrap users to Super Admin. Ids are resolved by name so this also works when any row
-- pre-existed with a different id.
INSERT INTO dbo.AspNetUserRoles (UserId, RoleId)
SELECT u.Id, r.Id
FROM dbo.AspNetUsers u
CROSS JOIN dbo.AspNetRoles r
WHERE u.NormalizedUserName IN (N'ADMIN', N'SUPERADMIN')
  AND r.NormalizedName = N'SUPER ADMIN'
  AND NOT EXISTS (SELECT 1 FROM dbo.AspNetUserRoles ur WHERE ur.UserId = u.Id AND ur.RoleId = r.Id);
