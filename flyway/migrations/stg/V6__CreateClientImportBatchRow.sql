-- GM-728: CSV batch client onboarding tool.
-- Tracks the result of each individual client within an import batch: status, error message,
-- and which steps (Backoffice/Platform/Selector Market Template/Trading DB) completed.

USE Backoffice;

CREATE TABLE [dbo].[ClientImportBatchRow]
(
    [Id]              BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [BatchId]         UNIQUEIDENTIFIER     NOT NULL,
    [RowNumber]       INT                  NOT NULL,
    [ClientCode]      NVARCHAR(10)         NOT NULL,
    [ClientName]      NVARCHAR(200)        NOT NULL,
    [Status]          NVARCHAR(20)         NOT NULL,
    [StepsCompleted]  NVARCHAR(500)        NULL,
    [ErrorMessage]    NVARCHAR(1000)       NULL,
    [ResultClientId]  UNIQUEIDENTIFIER     NULL,
    CONSTRAINT [FK_ClientImportBatchRow_ClientImportBatch]
        FOREIGN KEY ([BatchId]) REFERENCES [dbo].[ClientImportBatch]([BatchId])
);

CREATE INDEX [IX_ClientImportBatchRow_BatchId] ON [dbo].[ClientImportBatchRow] ([BatchId]);
CREATE INDEX [IX_ClientImportBatchRow_ClientCode] ON [dbo].[ClientImportBatchRow] ([ClientCode]);

-- rollback
-- USE Backoffice;
--
-- DROP TABLE [dbo].[ClientImportBatchRow];
