-- GM-796: stored procedures of the Sportsbook database used by Platform.Sportsbook.API.
--
-- V1__Baseline.sql only contains tables, so a fresh environment has no programmability objects at all. The four
-- procedures below are the complete set present on STG (exported 2026-09-07); three of them also exist in
-- platform-final Platform.Shared/DatabaseScripts, where InserOrUpdateClientMarketTemplateGroup2 lags behind the
-- STG version (STG wraps it in a transaction with UPDLOCK/HOLDLOCK). They are called from
-- Platform.Sportsbook.API/Repository/SportsbookRepository.cs when operators save market sort orders or market
-- template groups in the backoffice, and DeleteClientSportSettings when client sport settings are reset.
-- The misspelled names ("InserOrUpdate") are the real object names and must not be corrected.
--
-- Repeatable migration with CREATE OR ALTER: re-running converges to the same definition. Each CREATE OR ALTER
-- must be the first statement of its batch, hence the GO separators (Flyway splits SQL Server scripts on GO).

USE Sportsbook;
GO

CREATE OR ALTER PROCEDURE dbo.CopyClientMarketTemplateGroup
(
    @SourceClientId UNIQUEIDENTIFIER,
    @SourceSportId INT,
    @SourceFixtureStatusId INT,
    @TargetClientId UNIQUEIDENTIFIER,
    @TargetSportId INT,
    @TargetFixtureStatusId INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -- Clean target first
        DELETE FROM ClientMarketTemplateGroup
        WHERE ClientId = @TargetClientId
          AND SportId = @TargetSportId
          AND FixtureStatusId = @TargetFixtureStatusId;

        -- Insert copied data
        INSERT INTO ClientMarketTemplateGroup
        (
            ClientId,
            SportId,
            FixtureStatusId,
            Name,
            SortOrder,
            IsActive,
            MarketTemplates
        )
        SELECT
            @TargetClientId,
            @TargetSportId,
            @TargetFixtureStatusId,
            Name,
            SortOrder,
            IsActive,
            MarketTemplates
        FROM ClientMarketTemplateGroup
        WHERE ClientId = @SourceClientId
          AND SportId = @SourceSportId
          AND FixtureStatusId = @SourceFixtureStatusId;

    END TRY
    BEGIN CATCH
        -- Optional: return error info
        DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.DeleteClientSportSettings
    @ClientId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION
    BEGIN TRY
        DELETE FROM ClientLeagueOrder WHERE ClientId = @ClientId
        DELETE FROM ClientSegmentOrder WHERE ClientId = @ClientId
        DELETE FROM ClientSportOrder WHERE ClientId = @ClientId
        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
        THROW
    END CATCH
END

GO

CREATE OR ALTER PROCEDURE dbo.InserOrUpdateClientMarketSortOrder
(
    @ClientId UNIQUEIDENTIFIER,
    @SportId INT,
    @FixtureStatusId INT,
    @Name NVARCHAR(255),
    @MarketTemplates NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -- Check if record exists
        IF EXISTS (
            SELECT 1
            FROM ClientMarketTemplateGroup
            WHERE ClientId = @ClientId
              AND SportId = @SportId
              AND FixtureStatusId = @FixtureStatusId
              AND LOWER(Name) = LOWER(@Name)
        )
        BEGIN
            -- UPDATE existing
            UPDATE ClientMarketTemplateGroup
            SET 
                MarketTemplates = @MarketTemplates,
                -- Optional: maintain sort order if needed
                SortOrder = SortOrder,
                IsActive = 1
            WHERE ClientId = @ClientId
              AND SportId = @SportId
              AND FixtureStatusId = @FixtureStatusId
              AND LOWER(Name) = LOWER(@Name);
        END
        ELSE
        BEGIN
            -- INSERT new
            INSERT INTO ClientMarketTemplateGroup
            (
                ClientId,
                SportId,
                FixtureStatusId,
                Name,
                SortOrder,
                IsActive,
                MarketTemplates
            )
            VALUES
            (
                @ClientId,
                @SportId,
                @FixtureStatusId,
                @Name,
                0,              -- default sort order (can adjust later)
                1,              -- active by default
                @MarketTemplates
            );
        END

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.InserOrUpdateClientMarketTemplateGroup2
(
    @ClientId UNIQUEIDENTIFIER,
    @SportId INT,
    @FixtureStatusId INT,
    @MarketTemplateGroupId INT,
    @Name NVARCHAR(100),
    @SortOrder INT,
    @IsActive BIT,
    @MarketTemplateIds NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExistingId INT;

    BEGIN TRANSACTION;

    BEGIN TRY

        -- Priority: use explicit ID if provided
        IF (@MarketTemplateGroupId IS NOT NULL AND @MarketTemplateGroupId > 0)
        BEGIN
            SELECT @ExistingId = Id
            FROM ClientMarketTemplateGroup WITH (UPDLOCK, HOLDLOCK)
            WHERE Id = @MarketTemplateGroupId
              AND ClientId = @ClientId
              AND SportId = @SportId;
        END
        ELSE
        BEGIN
            SELECT @ExistingId = Id
            FROM ClientMarketTemplateGroup WITH (UPDLOCK, HOLDLOCK)
            WHERE ClientId = @ClientId
              AND SportId = @SportId
              AND FixtureStatusId = @FixtureStatusId
              AND LOWER(Name) = LOWER(@Name);
        END

        IF (@ExistingId IS NOT NULL)
        BEGIN
            UPDATE ClientMarketTemplateGroup
            SET
                Name = @Name,
                SortOrder = @SortOrder,
                IsActive = @IsActive,
                MarketTemplates = @MarketTemplateIds,
                FixtureStatusId = @FixtureStatusId
            WHERE Id = @ExistingId;
        END
        ELSE
        BEGIN
            INSERT INTO ClientMarketTemplateGroup
            (
                ClientId,
                SportId,
                FixtureStatusId,
                Name,
                SortOrder,
                IsActive,
                MarketTemplates
            )
            VALUES
            (
                @ClientId,
                @SportId,
                @FixtureStatusId,
                @Name,
                @SortOrder,
                @IsActive,
                @MarketTemplateIds
            );
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH
END
GO

