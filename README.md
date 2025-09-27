# SQL 2016 RTM Coding Agent

Purpose:
- Specialist toolkit and guardrails for authoring complex T‑SQL compatible with **SQL Server 2016 RTM** (no SP1 features).

What this repo provides:
- Agent charter with hard constraints.
- SQL 2016 templates for stored procedures and scalar UDFs (RTM‑safe).
- CI checks to **block** PRs that introduce RTM‑incompatible syntax.
- Issue/PR templates to capture schema and business logic before coding.

Branching:
- Main branch protected. Work in short‑lived feature branches, e.g. `feature/usp_xxx`.
- Pull request required to merge to main; CI must pass.

Getting Started:
1) Create a feature branch.
2) Start from `/templates` for new modules.
3) Commit changes and open a PR with schema details.
4) CI validates RTM compliance.
5) Merge when approved.

Conventions:
- Full scripts only (no diffs).
- Independent modules with clear top labels.
- Deterministic persisted computed columns only (no volatile functions).
- No `MERGE`; use two‑statement UPSERT (UPDATE then INSERT).
- Use `FOR XML PATH` for string aggregation and `LTRIM(RTRIM())` for trimming.
