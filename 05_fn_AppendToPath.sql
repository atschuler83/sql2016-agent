-- AGENT UTILITIES 05 -- util.fn_AppendToPath (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO

IF OBJECT_ID(N'util.fn_AppendToPath', N'FN') IS NOT NULL
    DROP FUNCTION util.fn_AppendToPath;
GO

/*
Purpose:
  Append a segment to a human-readable path using ' | ' as the delimiter.

Notes:
  - Deterministic and SCHEMABINDING to allow usage inside persisted computed columns.
  - Trims incoming segment; preserves existing path as-is.
  - Returns:
      * @segment if @path is NULL or empty
      * @path if @segment is NULL or empty
      * @path + N' | ' + @segment otherwise
*/
CREATE FUNCTION util.fn_AppendToPath
(
    @path    NVARCHAR(4000),
    @segment NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @seg NVARCHAR(4000) = LTRIM(RTRIM(@segment));

    IF @path IS NULL OR LEN(@path) = 0
        RETURN @seg;

    IF @seg IS NULL OR LEN(@seg) = 0
        RETURN @path;

    RETURN (@path + N' | ' + @seg);
END;
GO
