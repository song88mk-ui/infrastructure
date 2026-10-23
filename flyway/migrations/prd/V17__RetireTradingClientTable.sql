-- BO-42: Retire Trading.dbo.Client.
--
-- Backoffice read its clients for the Add Boosted Odds dialog and the Boosted Settings list from this table,
-- while the rest of Backoffice and the Web take them from the Platform API client list. The table is a copy
-- that holds only some of the clients (DEV 3 of 5, STG 12 of 62, checked October 23, 2026), so a client
-- missing from it got no row in the dialog: 0.00 odds and a disabled input. Backoffice now reads the
-- Platform client list, the one source of truth, and nothing else reads this table: no flyway script or
-- stored procedure (only the CREATE TABLE of V1__Baseline) and no code of backoffice-final, odds-engine-2,
-- platform-final or bet-genius references it. The ids of the clients it holds are identical to the ones in
-- the Platform list (checked on DEV and STG, so the caps saved in BoostedSettings keep matching). Not
-- checked on PRD: compare the two lists there before applying this to prd.
--
-- APPLY ONLY AFTER the backoffice-final release that reads the client list from the Platform API (BO-42)
-- is running in this environment. Until then bo-api still reads this table, and renaming it makes the
-- price boost list and the Boosted Settings list fail.
--
-- The table is RENAMED, not dropped, so it stays as the rollback path. A later migration drops it once a
-- full release has run clean, the same two steps as the other BO-42 tables.
--
-- Rollback: EXEC sp_rename N'dbo.Client_DELETE_AFTER_BO42', N'Client';   (while connected to Trading)
--
-- Idempotent: the rename runs only while dbo.Client exists and the new name is free, so re-running it,
-- or running it after the rename, changes nothing.

USE Trading;
GO

IF OBJECT_ID(N'dbo.Client', N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.Client_DELETE_AFTER_BO42', N'U') IS NULL
BEGIN
    EXEC sp_rename N'dbo.Client', N'Client_DELETE_AFTER_BO42';
END
GO
