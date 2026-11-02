-- OE Config template schema (Backoffice database), PRD. Read the checks and approvals below before applying this.
--
-- Why: Back Office has code for config templates (the My Templates tab, the margin editor, Copy Client Settings) but no script
-- ever created their tables, types or procedures. DEV and STG have none of them (checked on 2026-10-30 in every database), and
-- this schema was created there first and tested. Templates and margins are switched off for now and will come back.
--
-- PRD was NOT read when this was written, and no script ever defined these objects, so PRD may already have some or all of them
-- (made by hand at some time). So this script is stricter than the DEV and STG one: an object is created only when it is missing,
-- the indexes of a table are created only together with that table, and nothing is ever altered, replaced or dropped. If PRD
-- already has the objects, running it does nothing.
--
-- Before applying it:
--   1. Run this read-only check on PRD. If it returns any row, compare that object with this script first: an existing object is
--      kept as it is, so a different definition would not be corrected, and the application would use it.
--        SELECT 'table' AS kind, name FROM sys.tables WHERE name LIKE 'ConfigTemplate%'
--        UNION ALL SELECT 'type', name FROM sys.table_types WHERE name IN ('IntList', 'ConfigTemplateMarginType')
--        UNION ALL SELECT 'procedure', name FROM sys.procedures WHERE name IN ('GetAssignedConfigTemplates', 'AddOrUpdateConfigTemplateMarginV2');
--   2. A production schema change needs the written approval of its owner and a place in the release (backoffice-final CLAUDE.md,
--      critical rule 5). Apply it by hand with the usual care, in the release that brings the templates back, not before.
--
-- Where the design comes from: the entities in Backoffice.Shared/Data/Backoffice (BackofficeContext), the way
-- BackOfficeRepository, Config.Service and the Web read and write them, and ConfigTemplateModel for the list columns.
-- ConfigTemplateAssignedMapping is not created: the context declares it but nothing reads or writes it. What each index is for
-- is written next to its table, and the two procedures are described above each one.
--
-- Rollback (this loses the data in these tables):
--   DROP PROCEDURE dbo.AddOrUpdateConfigTemplateMarginV2;
--   DROP PROCEDURE dbo.GetAssignedConfigTemplates;
--   DROP TABLE dbo.ConfigTemplateAssigned;
--   DROP TABLE dbo.ConfigTemplateMargin;
--   DROP TABLE dbo.ConfigTemplate;
--   DROP TYPE dbo.ConfigTemplateMarginType;
--   DROP TYPE dbo.IntList;
--
-- Idempotent: every object is created only if it does not exist.

USE Backoffice;
GO

-- ===================================================================================================================
-- 1. Table types
-- ===================================================================================================================

IF TYPE_ID(N'dbo.IntList') IS NULL
    CREATE TYPE dbo.IntList AS TABLE (Value int NOT NULL);
GO

-- The columns are in the order of the DataTable that BackOfficeRepository.AddOrUpdateConfigTemplateMargin builds: SqlClient
-- fills a table-valued parameter by position, not by name, so this order must not change.
IF TYPE_ID(N'dbo.ConfigTemplateMarginType') IS NULL
    CREATE TYPE dbo.ConfigTemplateMarginType AS TABLE
    (
        ConfigTemplateId int NOT NULL,
        FixtureTypeId int NOT NULL,
        FixtureStatusId int NOT NULL,
        MarketTemplateId int NOT NULL,
        SportId int NOT NULL,
        Config nvarchar(max) NULL,
        IsActive bit NOT NULL
    );
GO

-- ===================================================================================================================
-- 2. Tables (each with its indexes, created together and only when the table is missing)
-- ===================================================================================================================

-- One row per template. The name is unique ignoring case (the application checks it, the key also stops two users
-- creating the same name at the same moment).
IF OBJECT_ID(N'dbo.ConfigTemplate', N'U') IS NULL
    CREATE TABLE dbo.ConfigTemplate
    (
        Id bigint IDENTITY(1, 1) NOT NULL,
        Name nvarchar(200) NOT NULL,
        SportId int NOT NULL,
        FixtureTypeId int NOT NULL,
        FixtureStatusId int NOT NULL,
        [Timestamp] datetime2(3) NOT NULL CONSTRAINT DF_ConfigTemplate_Timestamp DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_ConfigTemplate PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_ConfigTemplate_Name UNIQUE (Name)
    );
GO

-- The margin and the on/off flag of every market template of a template. The clustered key starts with the template id, so
-- reading or saving one template is a range seek, and deleting a template removes its rows through the foreign key.
-- MarketTemplateId is nvarchar to match the string that Entity Framework sends: a varchar column would make every
-- comparison convert the column side and scan instead of seek. Config is the JSON of the margin points, for example
-- [{"T":691200,"M":101}]; it is not part of any key.
IF OBJECT_ID(N'dbo.ConfigTemplateMargin', N'U') IS NULL
    CREATE TABLE dbo.ConfigTemplateMargin
    (
        ConfigTemplateId bigint NOT NULL,
        SportId int NOT NULL,
        FixtureTypeId int NOT NULL,
        FixtureStatusId int NOT NULL,
        MarketTemplateId nvarchar(20) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_ConfigTemplateMargin_IsActive DEFAULT 0,
        Config nvarchar(max) NULL,
        CONSTRAINT PK_ConfigTemplateMargin PRIMARY KEY CLUSTERED (ConfigTemplateId, SportId, FixtureTypeId, FixtureStatusId, MarketTemplateId),
        CONSTRAINT FK_ConfigTemplateMargin_ConfigTemplate FOREIGN KEY (ConfigTemplateId) REFERENCES dbo.ConfigTemplate (Id) ON DELETE CASCADE
    );
GO

-- The templates assigned to a league of a client. A template id of -1 means no template for that scope, so there is no
-- foreign key (Config.Service clears or removes these rows when a template is deleted). The names are copied from the
-- lists at the time of the assignment, to show the page without joins.
-- A client has one row per league (the unique index, also the lookup of a client's leagues). Finding the rows of one
-- template (the template counts, deleting a template, recalculating its margins) filters on one of the two template
-- columns, and these indexes carry what those queries read, so none of them touches the table.
IF OBJECT_ID(N'dbo.ConfigTemplateAssigned', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ConfigTemplateAssigned
    (
        Id bigint IDENTITY(1, 1) NOT NULL,
        ClientId uniqueidentifier NOT NULL,
        ClientCode nvarchar(40) NOT NULL,
        ClientName nvarchar(200) NULL,
        SportId int NOT NULL,
        SportName nvarchar(100) NULL,
        SegmentId int NOT NULL,
        SegmentName nvarchar(200) NULL,
        LeagueId int NOT NULL,
        LeagueName nvarchar(300) NULL,
        PrematchConfigTemplateId bigint NOT NULL CONSTRAINT DF_ConfigTemplateAssigned_Prematch DEFAULT -1,
        LiveConfigTemplateId bigint NOT NULL CONSTRAINT DF_ConfigTemplateAssigned_Live DEFAULT -1,
        CONSTRAINT PK_ConfigTemplateAssigned PRIMARY KEY CLUSTERED (Id)
    );

    CREATE UNIQUE NONCLUSTERED INDEX UX_ConfigTemplateAssigned_Client_League
        ON dbo.ConfigTemplateAssigned (ClientCode, SportId, SegmentId, LeagueId);

    CREATE NONCLUSTERED INDEX IX_ConfigTemplateAssigned_PrematchTemplate
        ON dbo.ConfigTemplateAssigned (PrematchConfigTemplateId)
        INCLUDE (ClientCode, SportId, SegmentId, LeagueId);

    CREATE NONCLUSTERED INDEX IX_ConfigTemplateAssigned_LiveTemplate
        ON dbo.ConfigTemplateAssigned (LiveConfigTemplateId)
        INCLUDE (ClientCode, SportId, SegmentId, LeagueId);
END
GO

-- ===================================================================================================================
-- 3. Stored procedures
-- ===================================================================================================================

-- The My Templates list: each template with how many clients and how many leagues it is assigned to. Empty lists mean
-- every sport or every scope. The counts are one grouped pass over the two template indexes, not a subquery per row. The
-- search uses CHARINDEX, so a % or _ typed by the user is text, not a wildcard. The columns are those of ConfigTemplateModel.
IF OBJECT_ID(N'dbo.GetAssignedConfigTemplates', N'P') IS NULL
    EXEC sys.sp_executesql N'
CREATE PROCEDURE dbo.GetAssignedConfigTemplates
    @SearchText nvarchar(200) = NULL,
    @SportIds dbo.IntList READONLY,
    @ScopeIds dbo.IntList READONLY
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AnySport bit = CASE WHEN EXISTS (SELECT 1 FROM @SportIds) THEN 0 ELSE 1 END;
    DECLARE @AnyScope bit = CASE WHEN EXISTS (SELECT 1 FROM @ScopeIds) THEN 0 ELSE 1 END;
    DECLARE @Search nvarchar(200) = LTRIM(RTRIM(@SearchText));

    WITH Assignments AS
    (
        SELECT PrematchConfigTemplateId AS ConfigTemplateId, ClientCode, SportId, SegmentId, LeagueId
        FROM dbo.ConfigTemplateAssigned
        WHERE PrematchConfigTemplateId > 0
        UNION ALL
        SELECT LiveConfigTemplateId, ClientCode, SportId, SegmentId, LeagueId
        FROM dbo.ConfigTemplateAssigned
        WHERE LiveConfigTemplateId > 0
    ),
    ClientCounts AS
    (
        SELECT ConfigTemplateId, COUNT(DISTINCT ClientCode) AS ClientsCount
        FROM Assignments
        GROUP BY ConfigTemplateId
    ),
    LeagueCounts AS
    (
        SELECT ConfigTemplateId, COUNT(*) AS LeaguesCount
        FROM (SELECT DISTINCT ConfigTemplateId, SportId, SegmentId, LeagueId FROM Assignments) AS DistinctLeagues
        GROUP BY ConfigTemplateId
    )
    SELECT t.Id,
           t.Name,
           t.SportId,
           t.FixtureTypeId,
           t.FixtureStatusId,
           ISNULL(c.ClientsCount, 0) AS ClientsCount,
           ISNULL(l.LeaguesCount, 0) AS LeaguesCount,
           t.[Timestamp] AS [Timestamp]
    FROM dbo.ConfigTemplate AS t
    LEFT JOIN ClientCounts AS c ON c.ConfigTemplateId = t.Id
    LEFT JOIN LeagueCounts AS l ON l.ConfigTemplateId = t.Id
    WHERE (@Search IS NULL OR LEN(@Search) = 0 OR CHARINDEX(@Search, t.Name) > 0)
      AND (@AnySport = 1 OR t.SportId IN (SELECT Value FROM @SportIds))
      AND (@AnyScope = 1 OR t.FixtureStatusId IN (SELECT Value FROM @ScopeIds))
    ORDER BY t.Name;
END';
GO

-- Saves the margins of one template. It only adds and changes rows, it never deletes the ones it is not sent, so a
-- partial save (for example turning markets on or off) cannot lose the rest. A row is written only when its flag or margin
-- changed, so saving an unchanged template writes nothing. The existence probe holds its range lock until the commit, so
-- two saves at the same time cannot both insert the same market template. A template id that does not exist fails on
-- the foreign key. A key sent twice counts once.
IF OBJECT_ID(N'dbo.AddOrUpdateConfigTemplateMarginV2', N'P') IS NULL
    EXEC sys.sp_executesql N'
CREATE PROCEDURE dbo.AddOrUpdateConfigTemplateMarginV2
    @ConfigTemplateId bigint,
    @ConfigTemplateMargins dbo.ConfigTemplateMarginType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Incoming TABLE
    (
        SportId int NOT NULL,
        FixtureTypeId int NOT NULL,
        FixtureStatusId int NOT NULL,
        MarketTemplateId nvarchar(20) NOT NULL,
        IsActive bit NOT NULL,
        Config nvarchar(max) NULL,
        PRIMARY KEY (SportId, FixtureTypeId, FixtureStatusId, MarketTemplateId)
    );

    INSERT @Incoming (SportId, FixtureTypeId, FixtureStatusId, MarketTemplateId, IsActive, Config)
    SELECT SportId, FixtureTypeId, FixtureStatusId, CONVERT(nvarchar(20), MarketTemplateId), IsActive, Config
    FROM
    (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY SportId, FixtureTypeId, FixtureStatusId, MarketTemplateId ORDER BY (SELECT NULL)) AS RowNumber
        FROM @ConfigTemplateMargins
    ) AS Sent
    WHERE RowNumber = 1;

    BEGIN TRANSACTION;

    UPDATE m
    SET m.IsActive = i.IsActive,
        m.Config = i.Config
    FROM dbo.ConfigTemplateMargin AS m
    JOIN @Incoming AS i
        ON i.SportId = m.SportId
       AND i.FixtureTypeId = m.FixtureTypeId
       AND i.FixtureStatusId = m.FixtureStatusId
       AND i.MarketTemplateId = m.MarketTemplateId
    WHERE m.ConfigTemplateId = @ConfigTemplateId
      AND EXISTS (SELECT i.IsActive, i.Config EXCEPT SELECT m.IsActive, m.Config);

    INSERT dbo.ConfigTemplateMargin (ConfigTemplateId, SportId, FixtureTypeId, FixtureStatusId, MarketTemplateId, IsActive, Config)
    SELECT @ConfigTemplateId, i.SportId, i.FixtureTypeId, i.FixtureStatusId, i.MarketTemplateId, i.IsActive, i.Config
    FROM @Incoming AS i
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.ConfigTemplateMargin AS m WITH (UPDLOCK, HOLDLOCK)
        WHERE m.ConfigTemplateId = @ConfigTemplateId
          AND m.SportId = i.SportId
          AND m.FixtureTypeId = i.FixtureTypeId
          AND m.FixtureStatusId = i.FixtureStatusId
          AND m.MarketTemplateId = i.MarketTemplateId
    );

    COMMIT TRANSACTION;
END';
GO
