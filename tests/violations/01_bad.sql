-- MODULE -- Test Violations (intentional) for SQL Server 2016 RTM guard
USE [TMS-ContractData];
GO
-- Forbidden: CREATE OR ALTER
CREATE OR ALTER PROCEDURE dbo.usp_Bad_Example
AS
BEGIN
    -- Forbidden: TRIM() and STRING_AGG()
    SELECT 
        TRIM('  hello  ')      AS Should_Flag_Trim,
        STRING_AGG('a', ',')   AS Should_Flag_StringAgg;
END;
GO
