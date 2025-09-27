-- MODULE TEMPLATE -- Scalar UDF (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO

IF OBJECT_ID(N'dbo.fn_Template_SafeTrim', N'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_Template_SafeTrim;
GO

-- Purpose:
--   Deterministic scalar function compatible with persisted computed columns.
-- Notes:
--   - Uses LTRIM/RTRIM to remain RTM-compatible (no TRIM()).
--   - SCHEMABINDING enables use inside PERSISTED computed columns.
CREATE FUNCTION dbo.fn_Template_SafeTrim(@input NVARCHAR(4000))
RETURNS NVARCHAR(4000)
WITH SCHEMABINDING
AS
BEGIN
    RETURN (LTRIM(RTRIM(@input)));
END;
GO
