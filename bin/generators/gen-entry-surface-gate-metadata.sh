#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/entry.surface.gate.metadata.contract.yaml"
MODE="write"
WRITE_SURFACES=0

usage() {
  cat <<'USAGE'
gen-entry-surface-gate-metadata.sh

Usage:
  gen-entry-surface-gate-metadata.sh [--check] [--write-surfaces]

Options:
  --check          Exit non-zero if generated artifact or entry-surface blocks drift.
  --write-surfaces Rewrite AGENTS.md + CLAUDE.md metadata blocks to canonical generated content.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --write-surfaces) WRITE_SURFACES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

fail() { echo "gen-entry-surface-gate-metadata FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"

REGISTRY_REL="$(yq e -r '.source_registry' "$CONTRACT")"
GEN_REL="$(yq e -r '.generated_file' "$CONTRACT")"
MARKER_START="$(yq e -r '.marker_start' "$CONTRACT")"
MARKER_END="$(yq e -r '.marker_end' "$CONTRACT")"

REGISTRY="$ROOT/$REGISTRY_REL"
GEN_FILE="$ROOT/$GEN_REL"

[[ -f "$REGISTRY" ]] || fail "missing source registry: $REGISTRY"

updated="$(yq e -r '.updated // ""' "$REGISTRY")"
total="$(yq e -r '.gate_count.total // 0' "$REGISTRY")"
active="$(yq e -r '.gate_count.active // 0' "$REGISTRY")"
retired="$(yq e -r '.gate_count.retired // 0' "$REGISTRY")"
max_gate="$(yq e -r '.gates[].id' "$REGISTRY" | sed 's/^D//' | sort -n | tail -1)"
[[ -n "$max_gate" ]] || max_gate=0

tmp_block="$(mktemp)"
cat > "$tmp_block" <<EOF_BLOCK
# ENTRY SURFACE GATE METADATA (generated)
source_registry: $REGISTRY_REL
registry_updated: $updated
gate_count_total: $total
gate_count_active: $active
gate_count_retired: $retired
max_gate_id: D$max_gate
EOF_BLOCK

mkdir -p "$(dirname "$GEN_FILE")"
if [[ "$MODE" == "check" ]]; then
  [[ -f "$GEN_FILE" ]] || fail "generated file missing: $GEN_FILE"
  if ! diff -u "$GEN_FILE" "$tmp_block" >/dev/null 2>&1; then
    fail "generated metadata drift: $GEN_REL (run generator)"
  fi
else
  cp "$tmp_block" "$GEN_FILE"
fi

mapfile -t surfaces < <(yq e -r '.surfaces[]' "$CONTRACT")
for rel in "${surfaces[@]}"; do
  [[ -n "$rel" ]] || continue
  path="$ROOT/$rel"
  [[ -f "$path" ]] || fail "missing surface: $path"

  if ! rg -n --fixed-strings "$MARKER_START" "$path" >/dev/null 2>&1; then
    fail "$rel missing marker: $MARKER_START"
  fi
  if ! rg -n --fixed-strings "$MARKER_END" "$path" >/dev/null 2>&1; then
    fail "$rel missing marker: $MARKER_END"
  fi

  existing="$(awk -v s="$MARKER_START" -v e="$MARKER_END" '$0==s{f=1;next}$0==e{f=0;exit}f{print}' "$path")"
  expected="$(cat "$tmp_block")"

  if [[ "$MODE" == "check" || "$WRITE_SURFACES" -eq 0 ]]; then
    if [[ "$existing" != "$expected" ]]; then
      fail "$rel entry-surface metadata drift (run generator with --write-surfaces)"
    fi
  else
    tmp_surface="$(mktemp)"
    awk -v s="$MARKER_START" -v e="$MARKER_END" -v blk="$tmp_block" '
      $0==s {print; while ((getline line < blk) > 0) print line; in_block=1; next}
      $0==e {in_block=0; print; next}
      !in_block {print}
    ' "$path" > "$tmp_surface"
    mv "$tmp_surface" "$path"
  fi
done

rm -f "$tmp_block"

echo "gen-entry-surface-gate-metadata PASS: $GEN_REL"
