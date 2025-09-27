-- AGENT UTILITIES 06 -- util.fn_SplitToRows (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO

IF OBJECT_ID(N'util.fn_SplitToRows', N'IF') IS NOT NULL
    DROP FUNCTION util.fn_SplitToRows;
GO

/*
Purpose:
  Split a delimited NVARCHAR(MAX) string into rows in a deterministic order (1-based index).
  RTM-safe alternative to STRING_SPLIT, and provides index ordering.

Returns:
  Inline table with:
    - Idx   INT           -- 1-based token index in input order
    - Token NVARCHAR(MAX) -- trimmed token text

Notes:
  - @delimiter is a single NCHAR(1) character.
  - Empty tokens are trimmed to empty strings (''), not NULLs.
*/
CREATE FUNCTION util.fn_SplitToRows
(
    @s NVARCHAR(MAX),
    @delimiter NCHAR(1)
)
RETURNS TABLE
AS
RETURN
WITH E1(N) AS (
    SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1
    UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1
),                 -- 10
E2(N) AS (SELECT 1 FROM E1 a, E1 b),   -- 100
E4(N) AS (SELECT 1 FROM E2 a, E2 b),   -- 10,000
Tally(N) AS (
    SELECT TOP (CASE WHEN @s IS NULL THEN 0 ELSE LEN(@s) END)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
    FROM E4
),
Cuts AS (
    SELECT 1 AS StartPos
    UNION ALL
    SELECT N + 1 FROM Tally WHERE SUBSTRING(@s, N, 1) = @delimiter
),
Segments AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY StartPos) AS Idx,
        LTRIM(RTRIM(SUBSTRING(
            @s,
            StartPos,
            CHARINDEX(@delimiter, @s + @delimiter, StartPos) - StartPos
        ))) AS Token
    FROM Cuts
)
SELECT Idx, Token
FROM Segments;
GO
