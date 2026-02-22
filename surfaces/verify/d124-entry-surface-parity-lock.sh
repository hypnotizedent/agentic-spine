#!/usr/bin/env bash
# TRIAGE: Keep startup block identical across AGENTS/CLAUDE/OPENCODE/home-CLAUDE and route launches through spine entry.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/entry.surface.contract.yaml"

fail() {
  echo "D124 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
yq e '.' "$CONTRACT" >/dev/null 2>&1 || fail "invalid YAML: $CONTRACT"

marker_start="$(yq e -r '.startup_block.marker_start // ""' "$CONTRACT")"
marker_end="$(yq e -r '.startup_block.marker_end // ""' "$CONTRACT")"
[[ -n "$marker_start" ]] || fail "missing startup_block.marker_start"
[[ -n "$marker_end" ]] || fail "missing startup_block.marker_end"

canonical_block=""
errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

extract_block() {
  local file="$1"
  local start="$2"
  local stop="$3"
  awk -v s="$start" -v e="$stop" '
    $0 == s {capture=1; next}
    $0 == e {capture=0; next}
    capture {print}
  ' "$file"
}

while IFS=$'\t' read -r sid path; do
  [[ -z "$sid" || -z "$path" ]] && continue

  abs="$path"
  # Expand leading tilde to $HOME
  if [[ "$abs" == "~/"* ]]; then
    abs="$HOME/${abs#\~/}"
  elif [[ "$abs" != /* ]]; then
    abs="$ROOT/$abs"
  fi

  [[ -f "$abs" ]] || {
    err "surface '$sid' missing file: $path"
    continue
  }

  grep -qF "$marker_start" "$abs" || { err "surface '$sid' missing marker_start"; continue; }
  grep -qF "$marker_end" "$abs" || { err "surface '$sid' missing marker_end"; continue; }

  block="$(extract_block "$abs" "$marker_start" "$marker_end")"
  [[ -n "$block" ]] || {
    err "surface '$sid' startup block is empty"
    continue
  }

  while IFS= read -r required; do
    [[ -z "$required" ]] && continue
    if ! printf '%s\n' "$block" | grep -Fq "$required"; then
      err "surface '$sid' missing required startup line: $required"
    fi
  done < <(yq e -r '.startup_block.required_lines[]?' "$CONTRACT" 2>/dev/null || true)

  if [[ -z "$canonical_block" ]]; then
    canonical_block="$block"
  elif [[ "$block" != "$canonical_block" ]]; then
    err "surface '$sid' startup block differs from canonical block"
  fi

done < <(yq e -r '.surfaces[] | [.id, .path] | @tsv' "$CONTRACT" 2>/dev/null)

if [[ "$errors" -gt 0 ]]; then
  fail "$errors parity issue(s) detected"
fi

echo "D124 PASS: entry surface startup parity enforced"
