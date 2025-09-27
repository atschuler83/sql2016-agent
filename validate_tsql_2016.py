#!/usr/bin/env python3
# RTM Validator: Blocks forbidden features in SQL Server 2016 RTM code.

import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
ALLOW_PRAGMA = r"AGENT:ALLOW\s+([A-Z_]+)"  # e.g., -- AGENT:ALLOW OPENJSON

BANNED = {
    r"\bCREATE\s+OR\s+ALTER\b": "CREATE OR ALTER is not allowed (RTM).",
    r"\bDROP\s+(TABLE|PROCEDURE|FUNCTION|VIEW|INDEX)\s+IF\s+EXISTS\b": "DROP IF EXISTS is not allowed (RTM).",
    r"\bSTRING_AGG\b": "STRING_AGG is not allowed (use FOR XML PATH).",
    r"\bTRIM\s*\(": "TRIM() is not allowed (use LTRIM/RTRIM).",
    r"\bTRANSLATE\s*\(": "TRANSLATE() is not allowed.",
    r"\bCONCAT_WS\s*\(": "CONCAT_WS() is not allowed.",
    r"\bOPENJSON\b": "OPENJSON is disallowed unless explicitly permitted with pragma.",
}

WARN = {
    r"\bMERGE\b": "MERGE has known issues; prefer two-statement UPSERT (UPDATE then INSERT).",
    r"\bGETDATE\s*\(": "GETDATE() is nondeterministic; avoid in persisted computed columns.",
    r"\bNEWID\s*\(": "NEWID() is nondeterministic; avoid in persisted computed columns.",
    r"\bRAND\s*\(": "RAND() is nondeterministic; avoid in persisted computed columns.",
}

HEADER_REQ = re.compile(r"^\s*--\s*(MODULE|AGENT)\b", re.IGNORECASE)

def strip_comments_and_strings(sql):
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)  # block comments
    sql = re.sub(r"--.*?$", "", sql, flags=re.MULTILINE)  # line comments
    sql = re.sub(r"\'(?:\'\'|[^'])*\'", "''", sql)        # string literals
    return sql

def find_pragmas(text):
    return set(x.upper() for x in re.findall(ALLOW_PRAGMA, text))

def should_scan(path):
    p = str(path).replace("\\", "/")
    if "/.github/" in p:
        return False
    if "/tools/" in p:
        return False
    return path.suffix.lower() == ".sql"

def main():
    errors = []
    warnings = []
    files = [p for p in ROOT.rglob("*.sql") if should_scan(p)]

    if not files:
        print("No .sql files found to validate.")
        return 0

    for f in files:
        text = f.read_text(encoding="utf-8", errors="ignore")
        pragmas = find_pragmas(text)
        body = strip_comments_and_strings(text)

        first_lines = text.splitlines()[:5]
        if not any(HEADER_REQ.search(line or "") for line in first_lines):
            warnings.append(f"{f}: Missing top module/agent label comment (starts with `-- MODULE` or `-- AGENT`).")

        for pat, msg in BANNED.items():
            if "OPENJSON" in pat:
                if "OPENJSON" in pragmas and re.search(pat, body, flags=re.IGNORECASE):
                    continue
            if re.search(pat, body, flags=re.IGNORECASE):
                errors.append(f"{f}: {msg}")

        for pat, msg in WARN.items():
            if re.search(pat, body, flags=re.IGNORECASE):
                warnings.append(f"{f}: {msg}")

    for w in warnings:
        print(f"WARNING: {w}")

    if errors:
        for e in errors:
            print(f"ERROR: {e}")
        print(f"\nFailing due to {len(errors)} RTM violation(s).")
        return 1

    print("SQL 2016 RTM validation passed.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
