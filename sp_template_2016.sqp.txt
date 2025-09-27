-- MODULE TEMPLATE -- Stored Procedure (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO

IF OBJECT_ID(N'dbo.usp_Module_Template_2016', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Module_Template_2016;
GO

CREATE PROCEDURE dbo.usp_Module_Template_2016
(
    @ExampleId INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Purpose:
    --   Baseline stored procedure template for SQL Server 2016 RTM.
    -- Standards:
    --   - RTM-only: no CREATE OR ALTER, no DROP IF EXISTS, no STRING_AGG/TRIM/TRANSLATE/CONCAT_WS.
    --   - Safe dynamic SQL uses sp_executesql with parameters and QUOTENAME for identifiers.
    --   - Deterministic logic required for persisted computed columns when applicable.
    --   - Prefer two-statement UPSERT patterns over MERGE.
    --   - Use human-readable path strings with ' | ' when recursion is implemented.

    BEGIN TRY
        BEGIN TRAN;

        /* Example no-op that compiles cleanly; replace with module logic */
        SELECT @ExampleId AS Echo_Param;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO
