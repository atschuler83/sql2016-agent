-- MODULE -- Sample string aggregation via FOR XML PATH (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO

/*
Purpose:
  Demonstrate RTM-safe string aggregation (no STRING_AGG) using:
    - STUFF + FOR XML PATH('') pattern for CSV concatenation
    - LTRIM/RTRIM for trimming (no TRIM())
  This module also shows a clean RTM-safe DROP/CREATE pattern.

Prerequisites:
  - modules/samples/01_Sample_Table_and_FILTD_DATE.sql (provides dbo.Agent_Sample)

Notes:
  - RTM-only: no CREATE OR ALTER, no DROP IF EXISTS, no STRING_AGG/TRIM/TRANSLATE/CONCAT_WS.
  - ORDER is preserved inside the correlated subquery via ORDER BY ... FOR XML PATH('').
*/

--------------------------------------------------------------------------------
-- 1) (Re)Create sample child table for notes/comments
--------------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.Agent_SampleNotes', N'U') IS NOT NULL
    DROP TABLE dbo.Agent_SampleNotes;
GO

CREATE TABLE dbo.Agent_SampleNotes
(
    SampleID  INT            NOT NULL,
    NoteLine  NVARCHAR(200)  NOT NULL
    -- (Optional) FK to dbo.Agent_Sample if desired; omitted to keep sample portable.
    -- CONSTRAINT FK_Agent_SampleNotes_Sample FOREIGN KEY (SampleID) REFERENCES dbo.Agent_Sample(SampleID)
);
GO

--------------------------------------------------------------------------------
-- 2) Seed sample notes
--------------------------------------------------------------------------------
INSERT dbo.Agent_SampleNotes (SampleID, NoteLine)
VALUES
    (1, N' Priority: High '),
    (1, N'Requires special handling'),
    (1, N'  Pack separately  '),
    (2, N'Priority: Medium'),
    (2, N'   Confirm dates  '),
    (3, N'Backlog validation');
GO
--------------------------------------------------------------------------------
-- 3) Create a view that aggregates notes per Sample using FOR XML PATH
--------------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.vw_Agent_Sample_NoteCSV', N'V') IS NOT NULL
    DROP VIEW dbo.vw_Agent_Sample_NoteCSV;
GO

CREATE VIEW dbo.vw_Agent_Sample_NoteCSV
AS
    SELECT
        s.SampleID,
        s.ItemNumber,
        -- CSV of trimmed notes ordered alphabetically (stable order for demo)
        NoteCSV = STUFF((
            SELECT N', ' + LTRIM(RTRIM(n.NoteLine))
            FROM dbo.Agent_SampleNotes AS n
            WHERE n.SampleID = s.SampleID
            ORDER BY LTRIM(RTRIM(n.NoteLine))
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 2, N'')
    FROM dbo.Agent_Sample AS s;
GO

--------------------------------------------------------------------------------
-- 4) Verification
--------------------------------------------------------------------------------
SELECT
    v.SampleID,
    v.ItemNumber,
    v.NoteCSV
FROM dbo.vw_Agent_Sample_NoteCSV AS v
ORDER BY v.SampleID;
GO
