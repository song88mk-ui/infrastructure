-- BO-107: widen Auth.dbo.ActivityLog.Token from nvarchar(3000) to nvarchar(max).
-- On every login Auth.Api saves the whole JWT into dbo.ActivityLog.Token (Auth.Api/Repositories/AuthRepository.cs).
-- A Super Admin JWT carries one claim per Permission row, so it grows with every permission that is added. It was
-- 2957 characters on STG and 2977 on DEV, which left almost no room: adding one permission (about 36 more characters)
-- pushed the DEV token past 3000 and every Super Admin login failed with "An error occurred while saving the entity
-- changes". With nvarchar(max) a new permission can no longer break login.
-- Apply it in the same `just migrate prd` run as V13__AddLeagueSortingPermission (flyway applies them in order, seconds
-- apart), or widen the column by hand first: the PRD Super Admin token length was never measured, so do not assume it
-- has the headroom STG has.
-- The collation is kept explicit so the ALTER does not switch it to the database default.
-- Idempotent: it only alters while the column is still fixed-width (max_length <> -1 means not MAX).

USE Auth;

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID(N'dbo.ActivityLog') AND name = N'Token' AND max_length <> -1)
BEGIN
    ALTER TABLE dbo.ActivityLog ALTER COLUMN Token nvarchar(max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL;
END;

-- rollback
-- Only safe while no stored token is longer than 3000 characters, otherwise the ALTER fails with a truncation error.
-- USE Auth;
--
-- SELECT COUNT(*) FROM dbo.ActivityLog WHERE LEN(Token) > 3000;   -- must be 0
-- ALTER TABLE dbo.ActivityLog ALTER COLUMN Token nvarchar(3000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL;
