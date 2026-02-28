#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/entry.boot.surface.contract.yaml"
MODE="write"
WRITE_SURFACES=0

usage() {
  cat <<'USAGE'
gen-boot-entry-surface.sh

Usage:
  gen-boot-entry-surface.sh [--check] [--write-surfaces]

Options:
  --check          Exit non-zero if generated artifact or startup projection blocks drift.
  --write-surfaces Rewrite startup blocks in AGENTS.md + CLAUDE.md from contract.
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

fail() { echo "gen-boot-entry-surface FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"

GEN_REL="$(yq e -r '.generated_file' "$CONTRACT")"
START_MARKER="$(yq e -r '.startup_block.marker_start' "$CONTRACT")"
END_MARKER="$(yq e -r '.startup_block.marker_end' "$CONTRACT")"
START_HEADING="$(yq e -r '.startup_block.heading' "$CONTRACT")"
START_SHELL="$(yq e -r '.startup_block.shell // "bash"' "$CONTRACT")"
UPDATED="$(yq e -r '.updated // ""' "$CONTRACT")"

[[ -n "$GEN_REL" && "$GEN_REL" != "null" ]] || fail "contract missing generated_file"
GEN_FILE="$ROOT/$GEN_REL"

tmp_startup="$(mktemp)"
{
  echo "$START_HEADING"
  echo
  echo "\`\`\`${START_SHELL}"
  yq e -r '.startup_block.commands[]' "$CONTRACT"
  echo "\`\`\`"
} > "$tmp_startup"

tmp_generated="$(mktemp)"
{
  echo "# BOOT ENTRY SURFACE (generated)"
  echo "source_contract: ops/bindings/entry.boot.surface.contract.yaml"
  echo "contract_updated: ${UPDATED}"
  echo "startup_command_count: $(yq e '.startup_block.commands | length' "$CONTRACT")"
  echo "post_work_verify_count: $(yq e '.post_work_verify.commands | length' "$CONTRACT")"
  echo "release_certification_count: $(yq e '.release_certification.commands | length' "$CONTRACT")"
  echo
  cat "$tmp_startup"
  echo
  echo "$(yq e -r '.post_work_verify.heading' "$CONTRACT")"
  echo
  echo "\`\`\`$(yq e -r '.post_work_verify.shell // "bash"' "$CONTRACT")"
  yq e -r '.post_work_verify.commands[]' "$CONTRACT"
  echo "\`\`\`"
  echo
  echo "$(yq e -r '.release_certification.heading' "$CONTRACT")"
  echo
  echo "\`\`\`$(yq e -r '.release_certification.shell // "bash"' "$CONTRACT")"
  yq e -r '.release_certification.commands[]' "$CONTRACT"
  echo "\`\`\`"
} > "$tmp_generated"

mkdir -p "$(dirname "$GEN_FILE")"
if [[ "$MODE" == "check" ]]; then
  [[ -f "$GEN_FILE" ]] || fail "generated file missing: $GEN_FILE"
  if ! diff -u "$GEN_FILE" "$tmp_generated" >/dev/null 2>&1; then
    fail "generated boot entry surface drift: $GEN_REL"
  fi
else
  cp "$tmp_generated" "$GEN_FILE"
fi

mapfile -t surfaces < <(yq e -r '.surfaces[]' "$CONTRACT")
for rel in "${surfaces[@]}"; do
  [[ -n "$rel" ]] || continue
  path="$ROOT/$rel"
  [[ -f "$path" ]] || fail "missing surface: $path"

  rg -n --fixed-strings "$START_MARKER" "$path" >/dev/null 2>&1 || fail "$rel missing marker: $START_MARKER"
  rg -n --fixed-strings "$END_MARKER" "$path" >/dev/null 2>&1 || fail "$rel missing marker: $END_MARKER"

  existing="$(awk -v s="$START_MARKER" -v e="$END_MARKER" '$0==s{f=1;next}$0==e{f=0;exit}f{print}' "$path")"
  expected="$(cat "$tmp_startup")"

  if [[ "$MODE" == "check" || "$WRITE_SURFACES" -eq 0 ]]; then
    [[ "$existing" == "$expected" ]] || fail "$rel startup block drift (run generator with --write-surfaces)"
  else
    tmp_surface="$(mktemp)"
    awk -v s="$START_MARKER" -v e="$END_MARKER" -v blk="$tmp_startup" '
      $0==s {print; while ((getline line < blk) > 0) print line; in_block=1; next}
      $0==e {in_block=0; print; next}
      !in_block {print}
    ' "$path" > "$tmp_surface"
    mv "$tmp_surface" "$path"
  fi
done

rm -f "$tmp_startup" "$tmp_generated"

echo "gen-boot-entry-surface PASS: $GEN_REL"
