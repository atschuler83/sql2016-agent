-- AGENT UTILITIES 04 -- util.fn_CYYMMDD_ToDate (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO

IF OBJECT_ID(N'util.fn_CYYMMDD_ToDate', N'FN') IS NOT NULL
    DROP FUNCTION util.fn_CYYMMDD_ToDate;
GO

/*
Purpose:
  Convert IBM i (AS/400) CYYMMDD (e.g., 1200105 or '1200105') to DATE deterministically.

Notes:
  - C = 0 => 1900s, C = 1 => 2000s. Year = 1900 + C*100 + YY.
  - Returns NULL on invalid inputs (non-digits, bad month/day).
  - Schema-bound & deterministic to allow use inside persisted computed columns.
*/
CREATE FUNCTION util.fn_CYYMMDD_ToDate
(
    @cyymmdd NVARCHAR(20)
)
RETURNS DATE
WITH SCHEMABINDING
AS
BEGIN
    DECLARE 
        @s NVARCHAR(20) = LTRIM(RTRIM(@cyymmdd)),
        @c INT,
        @yy INT,
        @mm INT,
        @dd INT,
        @yyyy INT;

    -- Basic validation: length 7 and all digits
    IF @s IS NULL OR LEN(@s) <> 7 OR @s LIKE N'%[^0-9]%'
        RETURN NULL;

    SET @c  = TRY_CONVERT(INT, SUBSTRING(@s, 1, 1));
    SET @yy = TRY_CONVERT(INT, SUBSTRING(@s, 2, 2));
    SET @mm = TRY_CONVERT(INT, SUBSTRING(@s, 4, 2));
    SET @dd = TRY_CONVERT(INT, SUBSTRING(@s, 6, 2));

    IF @c IS NULL OR @yy IS NULL OR @mm IS NULL OR @dd IS NULL
        RETURN NULL;

    SET @yyyy = 1900 + (@c * 100) + @yy;

    -- DATEFROMPARTS validates month/day ranges; returns NULL if invalid
    RETURN DATEFROMPARTS(@yyyy, @mm, @dd);
END;
GO
