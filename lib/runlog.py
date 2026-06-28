#!/usr/bin/env python3
"""Run-logging helpers for the Personalized Learning Agent (stdlib only).

Two subcommands, both driven by run.sh:

  parse  --json RAW --out MD
      Read claude's `--output-format json` output, write the report markdown to MD,
      and print a compact JSON object of token/cost usage to stdout.

  record --file RUNS.jsonl [flat fields...]
      Append one structured JSON record (one line) describing the run.
"""
import argparse
import json
import re
import sys
from pathlib import Path

# Trailing date suffixes we strip from titles so the same topic on different days
# collapses to one entry (e.g. "Idempotent Retries — 2026-06-17" -> "Idempotent Retries").
_DATE_SUFFIX = re.compile(
    r"\s*[\-–—(\[]*\s*\d{4}-\d{2}-\d{2}\s*[)\]]*\s*$"
)


def cmd_parse(args: argparse.Namespace) -> int:
    raw = Path(args.json).read_text(encoding="utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        sys.exit(f"claude output was not valid JSON ({exc}). Raw output saved at {args.json}.")

    if isinstance(data, dict) and data.get("is_error"):
        sys.exit(f"claude reported an error: {data.get('result', '(no detail)')}")

    result = data.get("result") if isinstance(data, dict) else None
    if not result or not str(result).strip():
        sys.exit("claude returned no report text in its JSON 'result' field.")

    Path(args.out).write_text(str(result), encoding="utf-8")

    usage = (data.get("usage") or {}) if isinstance(data, dict) else {}
    inp = int(usage.get("input_tokens", 0) or 0)
    out = int(usage.get("output_tokens", 0) or 0)
    summary = {
        "input_tokens": inp,
        "output_tokens": out,
        "cache_read_input_tokens": int(usage.get("cache_read_input_tokens", 0) or 0),
        "cache_creation_input_tokens": int(usage.get("cache_creation_input_tokens", 0) or 0),
        "total_tokens": inp + out,
        "cost_usd": data.get("total_cost_usd", 0),
        "api_duration_ms": data.get("duration_ms", 0),
        "num_turns": data.get("num_turns", 0),
    }
    print(json.dumps(summary))
    return 0


def _maybe_json(value: str):
    if not value:
        return None
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return None


def cmd_record(args: argparse.Namespace) -> int:
    error = None
    if args.error_what:
        error = {"what": args.error_what, "why": args.error_why or None, "fix": args.error_fix or None}

    record = {
        "run_id": args.run_id,
        "directive": args.directive,
        "status": args.status,
        "timing": {
            "start": args.start,
            "finish": args.finish,
            "duration_s": args.duration_s,
        },
        "steps": [s for s in (args.steps or "").split(",") if s],  # the logic that ran
        "input": {
            "directive": args.directive,
            "prompt_bytes": args.prompt_bytes,
        },
        "output": {
            "title": args.title or None,
            "markdown_bytes": args.md_bytes,
            "pdf_enabled": bool(args.pdf_enabled),
            "pdf_bytes": args.pdf_bytes,
            "pdf_engine": args.pdf_engine or None,
            "recipient": args.recipient or None,
        },
        "tokens": _maybe_json(args.tokens_json),
        "error": error,
    }
    line = json.dumps(record, ensure_ascii=False)
    with open(args.file, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")
    print(line)
    return 0


def cmd_recent(args: argparse.Namespace) -> int:
    """Print recently covered topic titles for a directive (most recent first).

    Reads the durable runs.jsonl so the anti-repetition memory survives even if
    output/*.md files are cleaned up. Prints nothing if there's no history yet.
    """
    path = Path(args.file)
    if not path.exists():
        return 0

    titles: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("directive") != args.directive:
            continue
        if rec.get("status") != "success":
            continue
        title = ((rec.get("output") or {}).get("title") or "").strip()
        title = _DATE_SUFFIX.sub("", title).strip()
        if title:
            titles.append(title)

    # Most recent last in the file -> reverse for most-recent-first, then dedupe
    # (case-insensitively) while preserving order.
    seen: set[str] = set()
    ordered: list[str] = []
    for title in reversed(titles):
        key = title.casefold()
        if key in seen:
            continue
        seen.add(key)
        ordered.append(title)

    for title in ordered[: max(0, args.limit)]:
        print(f"- {title}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run-logging helpers.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("parse", help="Extract report + usage from claude JSON output.")
    p.add_argument("--json", required=True)
    p.add_argument("--out", required=True)
    p.set_defaults(func=cmd_parse)

    r = sub.add_parser("record", help="Append a structured run record (JSONL).")
    r.add_argument("--file", required=True)
    r.add_argument("--run-id", default="")
    r.add_argument("--directive", default="")
    r.add_argument("--status", default="")
    r.add_argument("--start", default="")
    r.add_argument("--finish", default="")
    r.add_argument("--duration-s", type=int, default=0)
    r.add_argument("--steps", default="")
    r.add_argument("--prompt-bytes", type=int, default=0)
    r.add_argument("--md-bytes", type=int, default=0)
    r.add_argument("--pdf-bytes", type=int, default=0)
    r.add_argument("--pdf-enabled", type=int, default=0)
    r.add_argument("--title", default="")
    r.add_argument("--pdf-engine", default="")
    r.add_argument("--recipient", default="")
    r.add_argument("--tokens-json", default="")
    r.add_argument("--error-what", default="")
    r.add_argument("--error-why", default="")
    r.add_argument("--error-fix", default="")
    r.set_defaults(func=cmd_record)

    rc = sub.add_parser("recent", help="List recently covered topic titles for a directive.")
    rc.add_argument("--file", required=True, help="Path to runs.jsonl")
    rc.add_argument("--directive", required=True)
    rc.add_argument("--limit", type=int, default=20)
    rc.set_defaults(func=cmd_recent)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
