-- BO-42: Create Backoffice.dbo.GetActivityLogs under flyway.
--
-- Every View Logs screen of Backoffice (Manage Boost, Client Site Config, market groups, cancel bet history and
-- the others) reads Backoffice.dbo.ActivityLog2 through this stored procedure (BackOfficeRepository.GetActivityLogs,
-- GetPriceboostActivityLogs and the manual bet settlement history, and the same calls in Backoffice.Utility).
-- STG has the procedure, created by hand on 2026-06-19, but no flyway script ever defined it, so an environment
-- built from flyway does not have it: the call fails and the screens show "No Record Found!" even though the
-- rows are saved in ActivityLog2 (DEV, checked October 23, 2026).
--
-- The body is the definition found on STG: the entries of one page whose payload matches the pattern and whose
-- timestamp is within the two dates, newest first. Page, payload pattern and dates are passed as text and the
-- dates are cast to datetime2, exactly as the application calls it.
--
-- Idempotent: CREATE OR ALTER creates the procedure when it is missing and replaces it with this same
-- definition when it exists, so running it again, or running it on STG, leaves the same end state. Compare an
-- environment that already has a procedure of this name (STG does, PRD may) before applying this to it, because
-- a hand-edited version would be replaced.
--
-- Rollback: DROP PROCEDURE dbo.GetActivityLogs;   (only where the procedure did not exist before this script)

USE Backoffice;
GO

CREATE OR ALTER PROCEDURE [dbo].[GetActivityLogs]
    @Page NVARCHAR(100),
    @Payload NVARCHAR(500),
    @From NVARCHAR(50),
    @To NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Page, Payload, Activity, [From], [To], UserId, UserName, TimeStamp
    FROM ActivityLog2
    WHERE Page = @Page
      AND Payload LIKE @Payload
      AND TimeStamp >= CAST(@From AS datetime2)
      AND TimeStamp <= CAST(@To AS datetime2)
    ORDER BY TimeStamp DESC;
END
GO
