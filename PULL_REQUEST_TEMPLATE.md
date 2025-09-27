## Summary
- Purpose of change:
- Target database(s):
- New or modified module name(s):

## Schema & Context
- [ ] Included schema(s), table(s), and column definitions relevant to the change.
- [ ] Provided sample data (inline or linked) if transformation logic is nontrivial.

## SQL Server 2016 RTM Compliance
- [ ] No `CREATE OR ALTER`, `DROP IF EXISTS`, `STRING_AGG`, `TRIM()`, `TRANSLATE()`, `CONCAT_WS()`.
- [ ] Deterministic persisted computed columns only (no GETDATE()/NEWID()/RAND()).
- [ ] Safe dynamic SQL uses `sp_executesql` and `QUOTENAME`.
- [ ] No `MERGE` (or justified exceptional use with reasoning).
- [ ] Recursion uses human-readable path delimiter ` | ` where applicable.

## Testing
- [ ] Validated script compiles independently.
- [ ] Verified performance on expected row counts.
- [ ] Added notes on transaction scope and isolation if DML-heavy.

## Additional Notes
- Diagnostics, assumptions, or follow-ups:
