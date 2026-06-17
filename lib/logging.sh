#!/usr/bin/env bash
# Human-readable run logging. Source this file, then call log_init once $LOG_FILE is set.
# Every line is written to both the console and $LOG_FILE (if set).

_log_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Write a raw line to console + logfile.
log_raw() {
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%s\n' "$*" | tee -a "$LOG_FILE"
  else
    printf '%s\n' "$*"
  fi
}

# Timestamped event line.
log_line() { log_raw "[$(_log_now)] $*"; }

# Step header (blank line + "STEP <n/total> — <desc>").
log_step() { log_raw ""; log_raw "[$(_log_now)] STEP $1 — $2"; }

# Indented key/value detail under a step.
log_kv() { log_raw "             $1: $2"; }

# Header block at the start of a run.
log_init() {
  local run_id="$1" directive="$2" start="$3"
  log_raw "========================================================================"
  log_raw "RUN ${run_id}"
  log_raw "directive : ${directive}"
  log_raw "start     : ${start}"
  log_raw "========================================================================"
}

# Footer block at the end of a run.
log_finish() {
  local status="$1" duration="$2" finish="$3"
  log_raw "------------------------------------------------------------------------"
  log_raw "status    : ${status}"
  log_raw "duration  : ${duration}s"
  log_raw "finish    : ${finish}"
  log_raw "========================================================================"
}
