#!/usr/bin/env python3
# Intake AutoFix for SQL Server 2016 RTM
# - Parses a single .sql/.txt file under /intake
# - Splits into batches on GO
# - Detects object types and names
# - Applies RTM-safe rewrites for common violations
# - Emits proposed modules under /proposed and a report under /reports
import re, sys, pathlib, os
ROOT = pathlib.Path(__file__).resolve().parents[1]
INTAKE_DIR = ROOT / "intake"
PROPOSED_DIR = ROOT / "proposed"
REPORTS_DIR = ROOT / "reports"

PROPOSED_DIR.mkdir(parents=True, exist_ok=True)
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

warns = []
infos = []
errors = []

# -------------------------------
# Helpers
# -------------------------------

def read_intake_file():
    files = sorted([p for p in INTAKE_DIR.glob("*") if p.suffix.lower() in (".sql", ".txt")])
    if not files:
        errors.append("No .sql or .txt files found in /intake.")
        return None
    # Pick the most recently modified file
    f = max(files, key=lambda p: p.stat().st_mtime)
    infos.append(f"Using intake file: {f.name}")
    return f.read_text(encoding="utf-8", errors="ignore")

def normalize_newlines(s: str) -> str:
    return s.replace("\r\n", "\n").replace("\r", "\n")

def split_batches(text: str):
    # Split on lines that contain only GO (case-insensitive), allowing whitespace
    lines = text.split("\n")
    batches = []
    buf = []
    for ln in lines:
        if re.match(r"^\s*GO\s*$", ln, flags=re.IGNORECASE):
            if buf:
                batches.append("\n".join(buf).strip())
                buf = []
        else:
            buf.append(ln)
    if buf:
        batches.append("\n".join(buf).strip())
    return [b for b in batches if b.strip()]

def _extract_two_part_name(name_token: str):
    # Accept [schema].[name] or schema.name or [name] (assume dbo if missing)
    token = name_token.strip()
    # Remove trailing options like WITH ENCRYPTION, etc. Keep it simple.
    token = re.split(r"\s+", token, 1)[0]
    token = token.rstrip(";")

    # Split by dot not inside brackets
    parts = []
    cur = ""
    depth = 0
    for ch in token:
        if ch == '[':
            depth += 1
            cur += ch
        elif ch == ']':
            depth = max(depth - 1, 0)
            cur += ch
        elif ch == '.' and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    if cur:
        parts.append(cur)

    def strip_brackets(x):
        x = x.strip()
        if x.startswith('[') and x.endswith(']'):
            return x[1:-1]
        return x

    if len(parts) == 1:
        schema, name = "dbo", strip_brackets(parts[0])
    else:
        schema, name = strip_brackets(parts[0]), strip_brackets(parts[1])

    # Return bracketed two-part
    return f"[{schema}].[{name}]", schema, name

def detect_object(batch: str):
    # Return (obj_type, two_part_name, raw_type_token) or (None, None, None)
    # Types: PROCEDURE, FUNCTION, VIEW, TRIGGER, TABLE (for CREATE only)
    patterns = [
        r"^\s*CREATE\s+OR\s+ALTER\s+(PROCEDURE|FUNCTION|VIEW|TRIGGER)\s+([^\s\(;]+)",
        r"^\s*CREATE\s+(PROCEDURE|FUNCTION|VIEW|TRIGGER|TABLE)\s+([^\s\(;]+)",
        r"^\s*ALTER\s+(PROCEDURE|FUNCTION|VIEW|TRIGGER)\s+([^\s\(;]+)",
        r"^\s*DROP\s+(PROCEDURE|FUNCTION|VIEW|TRIGGER|TABLE)\s+IF\s+EXISTS\s+([^\s\(;]+)",
    ]
    for pat in patterns:
        m = re.search(pat, batch, flags=re.IGNORECASE | re.MULTILINE)
        if m:
            typ = m.group(1).upper()
            name_token = m.group(2)
            two, schema, name = _extract_two_part_name(name_token)
            return typ, two, typ
    return None, None, None

def apply_rtm_fixes(batch: str, obj_type: str, two_part_name: str):
    original = batch

    # 1) CREATE OR ALTER  -> Drop-if-exists + CREATE
    def repl_create_or_alter(m):
        typ = m.group(1).upper()
        name = m.group(2)
        two, schema, nm = _extract_two_part_name(name)
        drop_stmt = f"IF OBJECT_ID(N'{two}') IS NOT NULL\n    DROP {typ} {two};\nGO\n\nCREATE {typ} {two}"
        return drop_stmt

    batch = re.sub(
        r"(?i)^\s*CREATE\s+OR\s+ALTER\s+(PROCEDURE|FUNCTION|VIEW|TRIGGER)\s+([^\s\(;]+)",
        repl_create_or_alter,
        batch,
        count=1,
        flags=re.MULTILINE
    )

    # 2) DROP ... IF EXISTS  -> IF OBJECT_ID(...) IS NOT NULL DROP ...
    def repl_drop_if_exists(m):
        typ = m.group(1).upper()
        name = m.group(2)
        two, schema, nm = _extract_two_part_name(name)
        return f"IF OBJECT_ID(N'{two}') IS NOT NULL DROP {typ} {two};"

    # Warn on INDEX drops (syntax requires table context)
    if re.search(r"(?i)\bDROP\s+INDEX\s+IF\s+EXISTS\b", batch):
        warns.append("DROP INDEX IF EXISTS detected; requires manual conversion to RTM pattern with table context.")
    batch = re.sub(
        r"(?i)\bDROP\s+(PROCEDURE|FUNCTION|VIEW|TRIGGER|TABLE)\s+IF\s+EXISTS\s+([^\s\(;]+)",
        repl_drop_if_exists,
        batch
    )

    # 3) TRIM(x) -> LTRIM(RTRIM(x))  (best-effort, non-nested)
    batch, n_trim = re.subn(r"(?i)\bTRIM\s*\(\s*([^)]+?)\s*\)", r"LTRIM(RTRIM(\1))", batch)
    if n_trim:
        infos.append(f"Rewrote {n_trim} TRIM(...) occurrence(s).")

    # 4) Forbidden constructs -> warn
    for pat, label in [
        (r"\bSTRING_AGG\b", "STRING_AGG"),
        (r"\bTRANSLATE\s*\(", "TRANSLATE()"),
        (r"\bCONCAT_WS\s*\(", "CONCAT_WS()"),
        (r"\bOPENJSON\b", "OPENJSON (disallowed unless explicitly permitted)"),
    ]:
        if re.search(pat, batch, flags=re.IGNORECASE):
            warns.append(f"Forbidden or risky construct detected: {label}.")

    # 5) Add header if missing
    header_line = None
    if obj_type and two_part_name:
        header_line = f"-- MODULE -- AutoFix {obj_type} {two_part_name} (SQL Server 2016 RTM)"
    else:
        header_line = f"-- MODULE -- AutoFix Script Batch (SQL Server 2016 RTM)"

    if not re.search(r"^\s*--\s*MODULE\b", batch, flags=re.IGNORECASE | re.MULTILINE):
        batch = header_line + "\n" + batch

    # 6) Ensure USE and GO boundaries pattern consistent if object creation detected
    if obj_type in ("PROCEDURE", "FUNCTION", "VIEW", "TRIGGER", "TABLE"):
        if not re.search(r"(?im)^\s*USE\s+\[TMS-ContractData\]\s*;\s*^GO\s*$", batch):
            batch = "USE [TMS-ContractData];\nGO\n\n" + batch

    # 7) Final consistency comment
    if batch != original:
        batch = batch + "\n\n-- AGENT AUTO-FIX: Applied RTM compatibility rewrites where applicable."

    return batch

def filename_for(obj_type: str, two_part_name: str, idx: int):
    # Build deterministic filename
    if obj_type and two_part_name:
        safe = two_part_name.replace("[", "").replace("]", "").replace(".", "_")
        return PROPOSED_DIR / f"{obj_type}_{safe}.sql"
    else:
        return PROPOSED_DIR / f"SCRIPT_{idx:03d}.sql"

def write_report(modules_info):
    rpt = REPORTS_DIR / "intake_report.md"
    with rpt.open("w", encoding="utf-8") as f:
        f.write("# Intake AutoFix Report (SQL Server 2016 RTM)\n\n")
        f.write("## Modules Emitted\n")
        for i, info in enumerate(modules_info, 1):
            f.write(f"- {info}\n")
        f.write("\n## Info\n")
        if infos:
            for x in infos:
                f.write(f"- {x}\n")
        else:
            f.write("- None\n")
        f.write("\n## Warnings\n")
        if warns:
            for w in warns:
                f.write(f"- {w}\n")
        else:
            f.write("- None\n")
        f.write("\n## Errors\n")
        if errors:
            for e in errors:
                f.write(f"- {e}\n")
        else:
            f.write("- None\n")

    # Write short summary for job summary
    summ = REPORTS_DIR / "summary.md"
    with summ.open("w", encoding="utf-8") as s:
        s.write("### Intake AutoFix Summary (SQL Server 2016 RTM)\n\n")
        s.write(f"- Modules emitted: {len(modules_info)}\n")
        s.write(f"- Infos: {len(infos)} | Warnings: {len(warns)} | Errors: {len(errors)}\n")
        if warns:
            s.write("\n**Warnings**\n")
            for w in warns[:10]:
                s.write(f"- {w}\n")

# -------------------------------
# Main
# -------------------------------
def main():
    text = read_intake_file()
    if text is None:
        write_report([])
        # Exit non-zero to surface error in CI if no intake
        print("No intake file found.")
        sys.exit(1)

    text = normalize_newlines(text)
    batches = split_batches(text)
    if not batches:
        warns.append("No batches detected; entire file treated as a single script.")
        batches = [text]

    modules_written = []
    for idx, batch in enumerate(batches, 1):
        obj_type, two, typ_tok = detect_object(batch)
        fixed = apply_rtm_fixes(batch, obj_type, two)
        out_path = filename_for(obj_type, two, idx)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(fixed, encoding="utf-8")
        if obj_type and two:
            modules_written.append(f"{obj_type} {two} -> {out_path.relative_to(ROOT)}")
        else:
            modules_written.append(f"Script Batch {idx} -> {out_path.relative_to(ROOT)}")

    write_report(modules_written)
    print(f"Emitted {len(modules_written)} module file(s).")
    if errors:
        sys.exit(1)

if __name__ == "__main__":
    main()
