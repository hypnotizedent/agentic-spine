#!/usr/bin/env bash
# TRIAGE: PII token detected in case output files. Remove or redact SSN, EIN, and raw account numbers. Use ref:infisical: references or [REDACTED] placeholders instead.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

HITS=0
err() {
  echo "  FAIL: $*" >&2
  HITS=$((HITS + 1))
}

CASE_BASE="$ROOT/mailroom/state/cases/tax-legal"

# If no case directories exist, nothing to scan
if [[ ! -d "$CASE_BASE" ]]; then
  echo "D361 PASS: taxlegal-privacy-redaction-lock (no case directories exist)"
  exit 0
fi

SCANNED=0
while IFS= read -r -d '' file; do
  filename="$(basename "$file")"

  # Exclude *.lock.yaml files (may contain SHA-256 hashes)
  if [[ "$filename" == *.lock.yaml ]]; then
    continue
  fi

  SCANNED=$((SCANNED + 1))
  rel_path="${file#"$CASE_BASE"/}"

  # ── SSN pattern: \d{3}-\d{2}-\d{4} (exclude date-like patterns YYYY-MM-DD) ──
  while IFS= read -r match_line; do
    # Extract line number and content
    line_num="${match_line%%:*}"
    line_content="${match_line#*:}"

    # Skip exclusion lines
    if echo "$line_content" | grep -qP 'pattern_hint|example|ref:infisical:' 2>/dev/null; then
      continue
    fi

    # Verify it's not a date (dates are YYYY-MM-DD where first group is 4 digits)
    # SSN is NNN-NN-NNNN where first group is exactly 3 digits
    if echo "$line_content" | grep -qP '(?<!\d)\d{3}-\d{2}-\d{4}(?!\d)' 2>/dev/null; then
      err "$rel_path:$line_num — possible SSN detected"
    fi
  done < <(grep -nP '\b\d{3}-\d{2}-\d{4}\b' "$file" 2>/dev/null || true)

  # ── EIN pattern: \d{2}-\d{7} ──
  while IFS= read -r match_line; do
    line_num="${match_line%%:*}"
    line_content="${match_line#*:}"

    if echo "$line_content" | grep -qP 'pattern_hint|example|ref:infisical:' 2>/dev/null; then
      continue
    fi

    err "$rel_path:$line_num — possible EIN detected"
  done < <(grep -nP '\b\d{2}-\d{7}\b' "$file" 2>/dev/null || true)

  # ── Raw account numbers: \d{10,17} ──
  while IFS= read -r match_line; do
    line_num="${match_line%%:*}"
    line_content="${match_line#*:}"

    if echo "$line_content" | grep -qP 'pattern_hint|example|ref:infisical:' 2>/dev/null; then
      continue
    fi

    err "$rel_path:$line_num — possible raw account number detected"
  done < <(grep -nP '\b\d{10,17}\b' "$file" 2>/dev/null || true)

done < <(find "$CASE_BASE" -type f -print0 2>/dev/null)

if [[ "$SCANNED" -eq 0 ]]; then
  echo "D361 PASS: taxlegal-privacy-redaction-lock (no scannable case files found)"
  exit 0
fi

# ── Result ──
if [[ "$HITS" -gt 0 ]]; then
  echo "D361 FAIL: $HITS violation(s)"
  exit 1
fi

echo "D361 PASS: taxlegal-privacy-redaction-lock ($SCANNED files scanned, 0 PII tokens)"
exit 0
