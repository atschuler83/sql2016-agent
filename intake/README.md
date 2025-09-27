# Intake Workflow (Autofix for SQL 2016 RTM)

Purpose
- Accept a single text/SQL file containing one or many T-SQL modules.
- Parse batches, extract object names and types, apply RTM-compatible fixes, and emit proposed modules and a report.

Usage
1) Place a file in this folder, for example:
   - `intake/ProjectDump.sql` or `intake/ProjectDump.txt`
2) Commit to a branch or to main (if unprotected).
3) GitHub Actions will run the Intake workflow:
   - Creates `proposed/` with RTM-fixed modules organized by object type.
   - Creates `reports/` with `intake_report.md` and a summary.
   - Uploads both as workflow artifacts.
   - Posts a job summary in the Actions run.

Scope of Autofix
- Converts `CREATE OR ALTER` into RTM-safe drop-then-create pattern.
- Converts `DROP … IF EXISTS` into RTM-safe `IF OBJECT_ID(...) IS NOT NULL DROP …`.
- Rewrites `TRIM(expr)` to `LTRIM(RTRIM(expr))`.
- Flags unsupported constructs (e.g., `STRING_AGG`, `TRANSLATE`, `CONCAT_WS`, JSON features) for manual follow-up.

Notes
- SQL parsing is heuristic and safe by design; when unsure, emits warnings instead of breaking code.
- Index drops are flagged for manual update due to syntax differences (`DROP INDEX` requires index/table context).
- No runtime SQL execution is performed in CI.
