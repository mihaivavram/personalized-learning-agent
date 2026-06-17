#!/usr/bin/env bash
# Personalized Learning Agent — daily web digest.
#
# Picks one directive, uses the `claude` CLI to research the latest on the web,
# writes markdown, and emails the rendered digest (optionally also a PDF attachment).
#
# Usage:
#   ./run.sh <directive-name>
#   ./run.sh --directive <directive-name>
#   ./run.sh --pdf <name>           # also generate a PDF and attach it to the email
#   ./run.sh --list                 # list available directives
#   ./run.sh --no-email <name>      # generate artifacts but skip sending the email
#
# By default NO PDF is created and the email has no attachment (the digest is in the
# HTML email body). Pass --pdf to render a PDF and attach it.
#
# Example:
#   ./run.sh latest-sports-summary-of-the-day
#   ./run.sh --pdf latest-sports-summary-of-the-day
#
# Each run writes a human-readable log to logs/<run-id>.log and appends a structured
# JSON summary to logs/runs.jsonl.
set -euo pipefail

# --- Resolve project dir so cron can call this from any cwd ------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIRECTIVES_DIR="$SCRIPT_DIR/directives"
OUTPUT_DIR="$SCRIPT_DIR/output"
LOGS_DIR="$SCRIPT_DIR/logs"
LIB_DIR="$SCRIPT_DIR/lib"

# Prefer the project's virtualenv python if present (cron-safe, no manual activate),
# else fall back to system python3.
VENV_PYTHON="$SCRIPT_DIR/../environments/personalized-learning-agent/bin/python"
if [[ -x "$VENV_PYTHON" ]]; then
  PYTHON="$VENV_PYTHON"
else
  PYTHON="python3"
fi

# shellcheck source=lib/logging.sh
source "$LIB_DIR/logging.sh"

# Console-only error (used before the run log exists: arg/usage errors).
die() { printf '[run] ERROR: %s\n' "$*" >&2; exit 1; }

list_directives() {
  echo "Available directives:"
  for f in "$DIRECTIVES_DIR"/*.md; do
    [[ -e "$f" ]] || { echo "  (none found in $DIRECTIVES_DIR)"; return; }
    echo "  - $(basename "$f" .md)"
  done
}

usage() {
  sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  echo
  list_directives
}

# --- Parse args -------------------------------------------------------------
SEND_EMAIL=1
GEN_PDF=0          # off by default; --pdf turns on PDF render + email attachment
DIRECTIVE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) list_directives; exit 0 ;;
    --no-email) SEND_EMAIL=0; shift ;;
    --pdf|--with-pdf) GEN_PDF=1; shift ;;
    --directive) DIRECTIVE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "Unknown option: $1 (try --help)" ;;
    *) DIRECTIVE="$1"; shift ;;
  esac
done

[[ -n "$DIRECTIVE" ]] || { usage; exit 2; }

DIRECTIVE_FILE="$DIRECTIVES_DIR/$DIRECTIVE.md"
[[ -f "$DIRECTIVE_FILE" ]] || { echo; list_directives; die "No directive named '$DIRECTIVE'."; }

# --- Load .env --------------------------------------------------------------
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
  set +a
fi

mkdir -p "$OUTPUT_DIR" "$LOGS_DIR"

# --- Run identity, timing, and artifact paths -------------------------------
START_EPOCH="$(date +%s)"
START_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TS="$(date -u +%Y%m%d-%H%M%SZ)"
TODAY="$(date +%Y-%m-%d)"
RUN_ID="$DIRECTIVE-$TS"
LOG_FILE="$LOGS_DIR/$RUN_ID.log"
RUNS_JSONL="$LOGS_DIR/runs.jsonl"
MD_FILE="$OUTPUT_DIR/$RUN_ID.md"
HTML_FILE="$OUTPUT_DIR/$RUN_ID.html"
PDF_FILE="$OUTPUT_DIR/$RUN_ID.pdf"
RAW_JSON="$OUTPUT_DIR/$RUN_ID.claude.json"
ERR_FILE="$OUTPUT_DIR/$RUN_ID.stderr"
MODEL="${CLAUDE_MODEL:-opus}"

# --- Run state (for the structured record) ----------------------------------
STEPS=""            # the "logic that was followed"
PROMPT_BYTES=0
MD_BYTES=0
PDF_BYTES=0
TITLE=""
PDF_ENGINE=""
TOKENS_JSON=""
ERR_WHAT=""; ERR_WHY=""; ERR_FIX=""

add_step() { STEPS="${STEPS:+$STEPS,}$1"; }
elapsed()  { echo $(( $(date +%s) - START_EPOCH )); }

# Step numbering adapts to whether the optional PDF step runs.
STEP_TOTAL=3
[[ "$GEN_PDF" -eq 1 ]] && STEP_TOTAL=4
STEP_I=0
# Increment the step counter (in this shell, not a subshell) and log the step header.
log_step_n() { STEP_I=$((STEP_I + 1)); log_step "$STEP_I/$STEP_TOTAL" "$1"; }

write_record() {
  local status="$1"
  "$PYTHON" "$LIB_DIR/runlog.py" record \
    --file "$RUNS_JSONL" \
    --run-id "$RUN_ID" --directive "$DIRECTIVE" --status "$status" \
    --start "$START_TS" --finish "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --duration-s "$(elapsed)" \
    --steps "$STEPS" \
    --prompt-bytes "$PROMPT_BYTES" --md-bytes "$MD_BYTES" --pdf-bytes "$PDF_BYTES" \
    --pdf-enabled "$GEN_PDF" \
    --title "$TITLE" --pdf-engine "$PDF_ENGINE" --recipient "${RECIPIENT_EMAIL:-}" \
    --tokens-json "${TOKENS_JSON:-}" \
    --error-what "${ERR_WHAT:-}" --error-why "${ERR_WHY:-}" --error-fix "${ERR_FIX:-}" \
    >/dev/null || log_line "WARN: could not write structured record to $RUNS_JSONL"
}

# Actionable failure: log what happened + why + how to fix, record it, and exit.
fail() {
  trap - ERR
  local step="$1" what="$2" why="$3" fix="$4"
  ERR_WHAT="$what"; ERR_WHY="$why"; ERR_FIX="$fix"
  log_line "ERROR at ${step}"
  log_kv "what" "$what"
  log_kv "why " "${why:-(no further detail)}"
  log_kv "fix " "$fix"
  write_record "failed"
  log_finish "failed" "$(elapsed)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  exit 1
}

# Safety net for any unguarded command that fails unexpectedly.
trap 'fail "an unexpected point (line $LINENO)" "A command failed unexpectedly." "See the log lines above for the last step that started." "Re-run with: bash -x \"$0\" \"$DIRECTIVE\" to pinpoint the failing command, then fix it."' ERR

# --- Start logging ----------------------------------------------------------
log_init "$RUN_ID" "$DIRECTIVE" "$START_TS"

# Preconditions (logged + actionable).
command -v claude >/dev/null 2>&1 || fail "preflight" \
  "The 'claude' CLI is not on PATH." "PATH=$PATH" \
  "Install/locate Claude Code and ensure it is on PATH. In cron, set PATH (see README)."
command -v pandoc >/dev/null 2>&1 || fail "preflight" \
  "'pandoc' is not on PATH." "PATH=$PATH" \
  "Install pandoc (macOS: 'brew install pandoc'; Ubuntu: 'sudo apt-get install -y pandoc')."

# --- Build the prompt envelope (framing + directive contents) ---------------
DIRECTIVE_BODY="$(cat "$DIRECTIVE_FILE")"
PROMPT="You are a research assistant producing a daily digest. Today's date is $TODAY.

Use web search and web fetch to gather the LATEST, most current and accurate information,
verifying important claims against multiple reputable sources. Cite sources with their URLs.

Follow this directive:

--- DIRECTIVE START ---
$DIRECTIVE_BODY
--- DIRECTIVE END ---

OUTPUT REQUIREMENTS:
- Output ONLY the final report as clean GitHub-flavored Markdown. No preamble, no
  meta-commentary, no notes about your process.
- Start with a single H1 title that includes today's date ($TODAY).
- Use clear sections and concise bullets.
- End with a '## Sources' section listing the URLs you used."
PROMPT_BYTES=${#PROMPT}

# --- STEP: Research with claude (JSON output → markdown + token usage) -------
log_step_n "Research with claude (model=$MODEL, effort=low)"
log_kv "input" "directive '$DIRECTIVE' (prompt ${PROMPT_BYTES} bytes)"
if ! claude -p "$PROMPT" \
      --model "$MODEL" \
      --effort low \
      --allowedTools "WebSearch" "WebFetch" \
      --dangerously-skip-permissions \
      --output-format json \
      > "$RAW_JSON" 2> "$ERR_FILE"; then
  fail "step (research)" \
    "The 'claude' CLI exited non-zero." \
    "$(tail -n 3 "$ERR_FILE" 2>/dev/null | tr '\n' ' ')" \
    "Run 'claude' once interactively to confirm you're authenticated and model '$MODEL' is available; check network; then re-run. Raw output: $RAW_JSON"
fi
if ! TOKENS_JSON="$("$PYTHON" "$LIB_DIR/runlog.py" parse --json "$RAW_JSON" --out "$MD_FILE" 2> "$ERR_FILE")"; then
  fail "step (parse)" \
    "Could not parse claude's JSON output or it contained no report." \
    "$(cat "$ERR_FILE" 2>/dev/null)" \
    "Inspect $RAW_JSON. Confirm your claude CLI supports '--output-format json' (update it if not)."
fi
MD_BYTES="$(wc -c < "$MD_FILE" | tr -d ' ')"
TITLE="$(grep -m1 '^# ' "$MD_FILE" 2>/dev/null | sed 's/^# //' || true)"
add_step research
log_kv "output" "${MD_BYTES} bytes markdown — title: ${TITLE:-(none)}"
log_kv "tokens" "${TOKENS_JSON}"

# --- STEP: Render HTML body (for the email) ---------------------------------
log_step_n "Render HTML body"
if ! pandoc "$MD_FILE" -s --metadata title="$DIRECTIVE ($TODAY)" -o "$HTML_FILE" 2> "$ERR_FILE"; then
  fail "step (html)" \
    "pandoc failed to render the HTML body." \
    "$(cat "$ERR_FILE" 2>/dev/null)" \
    "Check the markdown in $MD_FILE and that pandoc works ('pandoc --version')."
fi
add_step html
log_kv "output" "$HTML_FILE ($(wc -c < "$HTML_FILE" | tr -d ' ') bytes)"

# --- STEP (optional): Render PDF --------------------------------------------
# Off by default; enabled with --pdf. When off, no PDF is created and the email
# is sent without an attachment (the digest lives in the HTML body).
if [[ "$GEN_PDF" -eq 1 ]]; then
  log_step_n "Render PDF"
  if ! PDF_LOG="$(bash "$LIB_DIR/to_pdf.sh" "$MD_FILE" "$PDF_FILE" 2>&1)"; then
    fail "step (pdf)" \
      "PDF rendering failed (no PDF engine, or a pandoc error)." \
      "$(printf '%s' "$PDF_LOG" | tr '\n' ' ')" \
      "Install a PDF engine — macOS: 'brew install tectonic'; Ubuntu: 'sudo apt-get install -y tectonic'. See README. (Or drop --pdf to skip PDF entirely.)"
  fi
  log_raw "$PDF_LOG"
  PDF_ENGINE="$(printf '%s' "$PDF_LOG" | sed -n 's/.*engine: //p' | head -1 || true)"
  PDF_BYTES="$(wc -c < "$PDF_FILE" | tr -d ' ')"
  add_step pdf
  log_kv "output" "$PDF_FILE (${PDF_BYTES} bytes, engine=${PDF_ENGINE:-unknown})"
fi

# --- STEP: Email ------------------------------------------------------------
SUBJECT="Daily Digest: $DIRECTIVE — $TODAY"
if [[ "$SEND_EMAIL" -eq 1 ]]; then
  log_step_n "Send email → ${RECIPIENT_EMAIL:-<unset>} (python: $PYTHON)"
  EMAIL_ARGS=(--subject "$SUBJECT" --html "$HTML_FILE" --text "$MD_FILE")
  if [[ "$GEN_PDF" -eq 1 ]]; then
    EMAIL_ARGS+=(--attach "$PDF_FILE")
  fi
  if ! "$PYTHON" "$LIB_DIR/send_email.py" "${EMAIL_ARGS[@]}" 2> "$ERR_FILE"; then
    fail "step (email)" \
      "Sending the email failed." \
      "$(cat "$ERR_FILE" 2>/dev/null)" \
      "Verify SMTP settings in .env (Gmail needs a 16-char App Password); confirm outbound port 587 is reachable."
  fi
  add_step email
  if [[ "$GEN_PDF" -eq 1 ]]; then ATTACH_NOTE="PDF attached"; else ATTACH_NOTE="no attachment"; fi
  log_kv "output" "sent to ${RECIPIENT_EMAIL:-<unset>} ($ATTACH_NOTE; subject: $SUBJECT)"
else
  log_step_n "Skipped email (--no-email)"
  log_kv "output" "artifacts in $OUTPUT_DIR"
fi

# --- Done -------------------------------------------------------------------
trap - ERR
write_record "success"
log_finish "success" "$(elapsed)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
