-- GM-728: CSV batch client onboarding tool.
-- Tracks each import run: environment, who started it, and whether one is still in progress.
-- The unique filtered index enforces "only one import running per environment at a time".

USE Backoffice;

CREATE TABLE [dbo].[ClientImportBatch]
(
    [BatchId]           UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    [Environment]       NVARCHAR(20)     NOT NULL,
    [Status]            NVARCHAR(20)     NOT NULL,
    [StartedByUserId]   NVARCHAR(50)     NULL,
    [StartedByUserName] NVARCHAR(200)    NULL,
    [StartedAt]         DATETIME2        NOT NULL,
    [CompletedAt]       DATETIME2        NULL,
    [TotalRows]         INT              NOT NULL DEFAULT 0,
    [SucceededRows]     INT              NOT NULL DEFAULT 0,
    [FailedRows]        INT              NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX [UX_ClientImportBatch_RunningPerEnvironment]
    ON [dbo].[ClientImportBatch] ([Environment])
    WHERE [Status] = 'Running';

-- rollback
-- USE Backoffice;
--
-- DROP TABLE [dbo].[ClientImportBatch];
