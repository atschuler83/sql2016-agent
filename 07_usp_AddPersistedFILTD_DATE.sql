-- AGENT UTILITIES 07 -- util.usp_AddPersistedFILTD_DATE (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO
IF OBJECT_ID(N'util.usp_AddPersistedFILTD_DATE', N'P') IS NOT NULL
    DROP PROCEDURE util.usp_AddPersistedFILTD_DATE;
GO

/*
Purpose:
  Add or recreate a deterministic persisted computed column [FILTD_DATE] (DATETIME2(3)) on a target table.

Parameters:
  @SchemaName      NVARCHAR(128)  -- e.g., N'dbo'
  @TableName       NVARCHAR(128)  -- e.g., N'CODATAU'
  @DateExpression  NVARCHAR(4000) -- Deterministic expression convertible to DATETIME2(3).
                                   -- Example:
                                   --   N'CONVERT(DATETIME2(3), util.fn_CYYMMDD_ToDate(CONVERT(NVARCHAR(7), CYYMMDD)))'
  @ForceRecreate   BIT            -- 1 = DROP existing [FILTD_DATE] then ADD; 0 = ADD only if missing.

Behavior:
  - Validates target table existence.
  - If @ForceRecreate=1 and column exists, drops and recreates it.
  - If column does not exist, adds it.
  - Does not attempt to parse or compare existing definitions on RTM.

Constraints:
  - @DateExpression must be deterministic (no GETDATE/NEWID/RAND).
  - Expression must be valid inside a persisted computed column.
  - No SQL Server 2016 SP1 features used.

Examples:
  EXEC util.usp_AddPersistedFILTD_DATE
       @SchemaName     = N'dbo',
       @TableName      = N'CODATAU',
       @DateExpression = N'CONVERT(DATETIME2(3), util.fn_CYYMMDD_ToDate(CONVERT(NVARCHAR(7), CYYMMDD)))',
       @ForceRecreate  = 1;
*/
CREATE PROCEDURE util.usp_AddPersistedFILTD_DATE
    @SchemaName     NVARCHAR(128),
    @TableName      NVARCHAR(128),
    @DateExpression NVARCHAR(4000),
    @ForceRecreate  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @SchemaName IS NULL OR @TableName IS NULL OR @DateExpression IS NULL
    BEGIN
        RAISERROR('All parameters are required: @SchemaName, @TableName, @DateExpression.', 16, 1);
        RETURN;
    END

    DECLARE 
        @fqtn SYSNAME = QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName),
        @exists BIT,
        @sql NVARCHAR(MAX);

    IF NOT EXISTS (
        SELECT 1
        FROM sys.tables t
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = @SchemaName AND t.name = @TableName
    )
    BEGIN
        RAISERROR('Target table %s.%s does not exist.', 16, 1, @SchemaName, @TableName);
        RETURN;
    END

    SELECT @exists = CASE WHEN EXISTS (
        SELECT 1
        FROM sys.columns c
        JOIN sys.tables t ON t.object_id = c.object_id
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = @SchemaName
          AND t.name = @TableName
          AND c.name = N'FILTD_DATE'
    ) THEN 1 ELSE 0 END;

    BEGIN TRY
        BEGIN TRAN;

        IF @exists = 1 AND @ForceRecreate = 1
        BEGIN
            SET @sql = N'ALTER TABLE ' + @fqtn + N' DROP COLUMN [FILTD_DATE];';
            EXEC sys.sp_executesql @sql;
            SET @exists = 0;
        END
        IF @exists = 0
        BEGIN
            -- Add persisted computed column using the provided deterministic expression
            SET @sql = N'ALTER TABLE ' + @fqtn + N' ADD [FILTD_DATE] AS (' + @DateExpression + N') PERSISTED;';
            EXEC sys.sp_executesql @sql;
        END
        -- If @exists = 1 and @ForceRecreate = 0, no action is taken.

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO
