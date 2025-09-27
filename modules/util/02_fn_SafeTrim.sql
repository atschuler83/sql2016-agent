-- AGENT UTILITIES 02 -- util.fn_SafeTrim (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO

IF OBJECT_ID(N'util.fn_SafeTrim', N'FN') IS NOT NULL
    DROP FUNCTION util.fn_SafeTrim;
GO

-- Purpose: Deterministic trim using LTRIM/RTRIM; schema-bound for use in persisted computed columns.
CREATE FUNCTION util.fn_SafeTrim
(
    @s NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
WITH SCHEMABINDING
AS
BEGIN
    RETURN (LTRIM(RTRIM(@s)));
END;
GO
