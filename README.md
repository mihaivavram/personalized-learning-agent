# Personalized Learning Agent

A small, self-contained agent that produces a daily "learning" digest. It can be run by
cron or manually. You pick one of several **directives** (what to research and how to
present it); the agent uses the `claude` CLI to research the latest on the web, writes the
result as Markdown, and emails the rendered digest. **By default no PDF is created** and the
email has no attachment (the digest lives in the HTML email body). Pass **`--pdf`** to also
render a PDF and attach it.

## How it works

```
./run.sh [--pdf] <directive>
   │
   ├─ 1. claude -p (web search/fetch) ──► output/<directive>-<ts>.md   (Markdown report)
   ├─ 2. pandoc -s ────────────────────► output/<directive>-<ts>.html  (email body)
   ├─ ( --pdf ) lib/to_pdf.sh (pandoc) ─► output/<directive>-<ts>.pdf   (attachment, optional)
   └─ 3/4. lib/send_email.py ──────────► email to RECIPIENT_EMAIL (PDF attached only with --pdf)

   Every run is logged ──► logs/<directive>-<ts>.log   (human-readable, step-by-step)
                       └─► logs/runs.jsonl             (structured record, one line/run)
```

## Directives

Directives live in [`directives/`](directives/) as Markdown files you can freely edit.
The filename (without `.md`) is the name you pass to `run.sh`. Shipped defaults:

- `latest-sports-summary-of-the-day`
- `popular-software-architecture-tip-of-the-day`
- `recent-ai-agents-and-agentic-systems-tip-of-the-day`
- `recent-or-popular-health-and-longevity-tip-of-the-day`
- `world-fun-fact-of-the-day`

Add your own by dropping a new `<name>.md` into `directives/`.

## Setup

### 1. Dependencies

Already required and assumed present: `claude` (CLI), `python3`, `pandoc`.

A **PDF engine is only needed if you use `--pdf`** (the default run makes no PDF). When you
want PDFs, `tectonic` is recommended (self-contained LaTeX):

- **macOS:** `brew install tectonic`
- **Ubuntu/Debian:** `sudo apt-get install -y tectonic`
  (or use the official installer / `cargo install tectonic`)

Alternatives the agent will auto-detect if present: `xelatex`, `pdflatex`,
`wkhtmltopdf`, or Python `weasyprint`.

The email sender uses **only the Python standard library**, so it runs on any Python 3.
A dedicated virtualenv is still **recommended** so you don't reinstall anything from
scratch each run and have a stable place for optional deps (e.g. `weasyprint` as a PDF
fallback). One has been created at:

```
../environments/personalized-learning-agent     (Python 3.13)
```

`run.sh` automatically uses that venv's interpreter if it exists (cron-safe — no manual
activation needed), falling back to the system `python3` otherwise.

To create/recreate it, or to activate it for interactive work:

```sh
# create (one time)
python3.13 -m venv ../environments/personalized-learning-agent
../environments/personalized-learning-agent/bin/python -m pip install --upgrade pip

# activate when you want to install/run things by hand
source ../environments/personalized-learning-agent/bin/activate
#   ... pip install <whatever> ...
deactivate
```

### 2. Configure secrets

```sh
cp .env.example .env   # if not already present
```

Edit `.env` and set your SMTP values. For Gmail, `SENDER_PASSWORD` must be a 16-character
[App Password](https://support.google.com/accounts/answer/185833), not your login password.
`.env` is gitignored.

Optional Claude settings (see `.env.example`):

- **`CLAUDE_MODEL`** — model for research (default: `opus`).
- **`CLAUDE_EFFORT`** — effort level passed to `claude --effort` (default: `low`). Values:
  `low`, `medium`, `high`, `xhigh`, `max`. Higher effort usually means deeper research and
  higher token cost; use `low` for cron-friendly daily runs.

### 3. Make scripts executable (first time only)

```sh
chmod +x run.sh lib/to_pdf.sh
```

## Usage

```sh
./run.sh latest-sports-summary-of-the-day        # research + email (no PDF, default)
./run.sh --pdf latest-sports-summary-of-the-day  # also render a PDF and attach it
./run.sh --list                                   # show available directives
./run.sh --no-email popular-software-architecture-tip-of-the-day   # generate artifacts, skip email
```

**`--pdf`** is the only flag that controls PDF/attachment. Without it, no PDF is created and
the email is sent with the digest in the HTML body and no attachment. `--pdf` and
`--no-email` can be combined (e.g. generate the PDF artifact without sending).

Generated files land in [`output/`](output/) with UTC timestamps.

## Logs

Every run is logged to [`logs/`](logs/) (gitignored):

- **`logs/<run-id>.log`** — a human-readable, timestamped trace of the run: the logic that
  was followed (each step), brief input (directive + prompt size), brief output (markdown
  title/size, PDF size/engine, recipient), **token usage** (input/output/cache/total +
  cost), start/finish timestamps, total duration, and — on failure — an **actionable error**
  block (`what` happened, `why`, and how to `fix` it).
- **`logs/runs.jsonl`** — one structured JSON object per run (append-only), suitable for
  scripting/metrics. Fields: `run_id`, `directive`, `status`, `timing` (start/finish/
  duration_s), `steps`, `input`, `output` (incl. `pdf_enabled`), `tokens`, and `error`.

Step count adapts to the flags: a default run logs 3 steps (research → html → email); with
`--pdf` it logs 4 (research → html → pdf → email).

The same trace is printed to the console, so under cron you can also redirect it to a file
(see below). Token usage and cost come from `claude`'s `--output-format json` output.

Example (success) tail of a `.log`:

```
[2026-06-17T07:00:41Z] STEP 1/3 — Research with claude (model=opus, effort=max)
             input: directive 'latest-sports-summary-of-the-day' (1180 bytes)
             output: 3421 bytes markdown — title: Daily Sports Summary — 2026-06-17
             tokens: {"input_tokens":1820,"output_tokens":1456,"total_tokens":3276,"cost_usd":0.06,...}
...
status    : success
duration  : 58s
finish    : 2026-06-17T07:01:39Z
```

## Scheduling with cron

Cron runs with a minimal environment, so use **absolute paths** and set `PATH` so `claude`
and `pandoc` are found (plus a PDF engine **only if** you schedule with `--pdf`). Find the
paths with `which claude pandoc tectonic`.

Edit your crontab (`crontab -e`) and add, for example — daily at 07:00 (no PDF, the default):

```cron
# Make tools discoverable (adjust to your `which` output)
PATH=/Users/mavram/.nvm/versions/node/v22.4.0/bin:/opt/homebrew/bin:/usr/bin:/bin

0 7 * * * cd /Users/mavram/Repositories/Agents/LearningAutomationAgent/personalized-learning-agent && ./run.sh recent-ai-agents-and-agentic-systems-tip-of-the-day >> output/cron.log 2>&1
```

To include a PDF attachment, add `--pdf` (and make sure a PDF engine is on `PATH`):

```cron
0 7 * * * cd /Users/mavram/Repositories/Agents/LearningAutomationAgent/personalized-learning-agent && ./run.sh --pdf recent-ai-agents-and-agentic-systems-tip-of-the-day >> output/cron.log 2>&1
```

Run different directives on different days/times by adding more lines. Check `output/cron.log`
for results.

## Notes

- **`--dangerously-skip-permissions`**: `run.sh` invokes `claude` non-interactively, so it
  passes this flag (cron has no TTY to approve tool use). Tools are restricted to
  `WebSearch` and `WebFetch` (read-only web access), keeping the blast radius small.
- **PDF is opt-in**: default runs produce only Markdown + an HTML-body email (no PDF, no
  attachment, no PDF-engine dependency). Add `--pdf` to render and attach a PDF.
- **Model / effort**: defaults to `--model opus` and `--effort low`. Override with
  `CLAUDE_MODEL` and `CLAUDE_EFFORT` in `.env` (e.g. `CLAUDE_EFFORT=max` for deeper research).
- **Security**: `.env` holds your SMTP app password in plaintext (gitignored). Rotate it if
  it has been shared anywhere.
```
