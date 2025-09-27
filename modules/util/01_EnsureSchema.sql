-- AGENT UTILITIES 01 -- Ensure [util] schema exists (SQL Server 2016 RTM)
USE [TMS-ContractData];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'util')
    EXEC(N'CREATE SCHEMA util AUTHORIZATION dbo;');
GO
