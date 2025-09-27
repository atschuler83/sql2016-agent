-- MODULE -- Sample table + deterministic FILTD_DATE (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO

/* 
Purpose:
  Demonstrates how to (a) create a sample table with a CYYMMDD date source,
  (b) enforce a deterministic persisted computed column [FILTD_DATE] as DATETIME2(3)
      using util.usp_AddPersistedFILTD_DATE and util.fn_CYYMMDD_ToDate.

Prerequisites:
  - modules/util/01_EnsureSchema.sql
  - modules/util/02_fn_SafeTrim.sql
  - modules/util/03_fn_NormalizeKey.sql
  - modules/util/04_fn_CYYMMDD_ToDate.sql
  - modules/util/07_usp_AddPersistedFILTD_DATE.sql

Notes:
  - RTM-only: no CREATE OR ALTER, no DROP IF EXISTS.
  - This is a sample object named [dbo].[Agent_Sample]; safe to create in a sandbox.
*/

-- 1) Drop and recreate the sample table (RTM-safe pattern)
IF OBJECT_ID(N'dbo.Agent_Sample', N'U') IS NOT NULL
    DROP TABLE dbo.Agent_Sample;
GO

CREATE TABLE dbo.Agent_Sample
(
    SampleID           INT             NOT NULL CONSTRAINT PK_Agent_Sample PRIMARY KEY,
    ItemNumber         NVARCHAR(100)   NOT NULL,
    -- Source date in CYYMMDD (IBM i format). Example: 1200105 = 2020-01-05
    Sample_CYYMMDD     INT             NOT NULL
    -- [FILTD_DATE] will be added as a persisted computed column by the utility proc.
);
GO

-- 2) Seed a few sample rows
INSERT dbo.Agent_Sample (SampleID, ItemNumber, Sample_CYYMMDD)
VALUES
    (1, N'MEC 3116', 1200105),   -- 2020-01-05
    (2, N'MTZ 5217', 1191231),   -- 2019-12-31
    (3, N'TEST 0001', 1150101);  -- 2015-01-01
GO

-- 3) Add deterministic persisted computed column [FILTD_DATE] as DATETIME2(3)
--    Expression converts CYYMMDD -> DATE via util.fn_CYYMMDD_ToDate, then casts to DATETIME2(3).
EXEC util.usp_AddPersistedFILTD_DATE
     @SchemaName     = N'dbo',
     @TableName      = N'Agent_Sample',
     @DateExpression = N'CONVERT(DATETIME2(3), util.fn_CYYMMDD_ToDate(CONVERT(NVARCHAR(7), Sample_CYYMMDD)))',
     @ForceRecreate  = 1;
GO

-- 4) Quick verification (non-invasive)
SELECT 
    s.SampleID,
    s.ItemNumber,
    s.Sample_CYYMMDD,
    s.FILTD_DATE
FROM dbo.Agent_Sample AS s
ORDER BY s.SampleID;
GO
