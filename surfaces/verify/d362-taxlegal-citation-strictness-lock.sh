#!/usr/bin/env bash
# TRIAGE: Research answer paragraphs missing citation anchors. Every claim line in answers.md must have [source_id: ...], (source: ...), citation_anchor:, [UNKNOWN], or status: unknown.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

HITS=0
err() {
  echo "  FAIL: $*" >&2
  HITS=$((HITS + 1))
}

CASE_CONTRACT="$ROOT/ops/bindings/taxlegal.case.lifecycle.contract.yaml"
CASE_BASE="$ROOT/runtime/domain-state/taxlegal/cases"
if command -v yq >/dev/null 2>&1 && [[ -f "$CASE_CONTRACT" ]]; then
  case_root="$(yq -r '.case_pathing.root // ""' "$CASE_CONTRACT" 2>/dev/null || true)"
  if [[ -n "$case_root" && "$case_root" != "null" ]]; then
    CASE_BASE="$ROOT/$case_root"
  fi
fi

# If no case directories exist, nothing to scan
if [[ ! -d "$CASE_BASE" ]]; then
  echo "D360 PASS: taxlegal-citation-strictness-lock (no case directories exist)"
  exit 0
fi

# Find all answers.md files in research/ subdirectories
SCANNED=0
while IFS= read -r -d '' answers_file; do
  SCANNED=$((SCANNED + 1))
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Skip empty/whitespace lines
    [[ -z "${line// /}" ]] && continue

    # Skip header lines (starts with #)
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Skip boundary notice lines
    if echo "$line" | grep -qi "not legal or tax advice"; then
      continue
    fi

    # Check for citation anchors or unknown markers
    has_citation=false

    # [source_id: ...]
    if echo "$line" | grep -qP '\[source_id:' 2>/dev/null; then
      has_citation=true
    fi

    # (source: ...)
    if echo "$line" | grep -qP '\(source:' 2>/dev/null; then
      has_citation=true
    fi

    # citation_anchor:
    if echo "$line" | grep -qP 'citation_anchor:' 2>/dev/null; then
      has_citation=true
    fi

    # [UNKNOWN]
    if echo "$line" | grep -qP '\[UNKNOWN\]' 2>/dev/null; then
      has_citation=true
    fi

    # status: unknown
    if echo "$line" | grep -qP 'status:\s*unknown' 2>/dev/null; then
      has_citation=true
    fi

    if [[ "$has_citation" == "false" ]]; then
      err "$(basename "$(dirname "$(dirname "$answers_file")")")/research/answers.md:$line_num — missing citation or [UNKNOWN] marker"
    fi
  done < "$answers_file"
done < <(find "$CASE_BASE" -type f -name 'answers.md' -path '*/research/*' -print0 2>/dev/null)

if [[ "$SCANNED" -eq 0 ]]; then
  echo "D360 PASS: taxlegal-citation-strictness-lock (no research/answers.md files found)"
  exit 0
fi

# ── Result ──
if [[ "$HITS" -gt 0 ]]; then
  echo "D360 FAIL: $HITS violation(s)"
  exit 1
fi

echo "D360 PASS: taxlegal-citation-strictness-lock ($SCANNED answers files verified)"
exit 0
