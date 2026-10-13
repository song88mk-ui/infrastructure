-- BO-112: CSV client export + bulk update tool.
-- Distinguishes a Create-mode batch from an Update-mode batch, sharing the same
-- lock/tracking infrastructure as the existing CSV create tool.
-- Must be applied before the backoffice build that writes OperationType is deployed.

USE Backoffice;

IF COL_LENGTH(N'dbo.ClientImportBatch', N'OperationType') IS NULL
BEGIN
    ALTER TABLE [dbo].[ClientImportBatch] ADD [OperationType] NVARCHAR(20) NOT NULL DEFAULT 'Create';
END;

-- rollback
-- USE Backoffice;
--
-- ALTER TABLE [dbo].[ClientImportBatch] DROP COLUMN [OperationType];
