#!/usr/bin/env bash
# Convert a markdown file to PDF via pandoc, auto-detecting an available PDF engine.
# Cross-platform (macOS + Ubuntu/Linux). Usage: to_pdf.sh <input.md> <output.pdf>
set -euo pipefail

IN="${1:-}"
OUT="${2:-}"

if [[ -z "$IN" || -z "$OUT" ]]; then
  echo "Usage: to_pdf.sh <input.md> <output.pdf>" >&2
  exit 2
fi

if ! command -v pandoc >/dev/null 2>&1; then
  echo "[to_pdf] pandoc not found. Install it (macOS: 'brew install pandoc'; Ubuntu: 'sudo apt-get install -y pandoc')." >&2
  exit 1
fi

# Pick the first available PDF engine, in order of preference.
if command -v tectonic >/dev/null 2>&1; then
  ENGINE=tectonic
elif command -v xelatex >/dev/null 2>&1; then
  ENGINE=xelatex
elif command -v pdflatex >/dev/null 2>&1; then
  ENGINE=pdflatex
elif command -v wkhtmltopdf >/dev/null 2>&1; then
  ENGINE=wkhtmltopdf
elif command -v weasyprint >/dev/null 2>&1; then
  ENGINE=weasyprint
else
  cat >&2 <<'EOF'
[to_pdf] No PDF engine found. Install one of the following:
  - tectonic   (recommended, self-contained LaTeX)
      macOS:  brew install tectonic
      Ubuntu: sudo apt-get install -y tectonic   (or: cargo install tectonic / official installer)
  - wkhtmltopdf
      macOS:  brew install --cask wkhtmltopdf
      Ubuntu: sudo apt-get install -y wkhtmltopdf
  - weasyprint
      pip install weasyprint   (needs pango/cairo system libs)
EOF
  exit 1
fi

echo "[to_pdf] Rendering PDF with engine: $ENGINE"
pandoc "$IN" -o "$OUT" --pdf-engine="$ENGINE" -V geometry:margin=1in
echo "[to_pdf] Wrote $OUT"
