-- AGENT UTILITIES 03 -- util.fn_NormalizeKey (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO

IF OBJECT_ID(N'util.fn_NormalizeKey', N'FN') IS NOT NULL
    DROP FUNCTION util.fn_NormalizeKey;
GO
-- Purpose: Normalize keys: TRIM + UPPER; deterministic; schema-bound to allow use in persisted computed columns.
CREATE FUNCTION util.fn_NormalizeKey
(
    @s NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
WITH SCHEMABINDING
AS
BEGIN
    RETURN (UPPER(LTRIM(RTRIM(@s))));
END;
GO
