#!/usr/bin/env bash
# TRIAGE: Direct Twilio/Resend API usage must be centralized in spine communications execution surface.
# D147: Communications canonical routing lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-$HOME/code/workbench}"
ALLOWED_SPINE_PREFIX="$ROOT/ops/plugins/communications/"

fail() {
  echo "D147 FAIL: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

need_cmd rg

SCAN_DIRS=(
  "$ROOT/ops/plugins"
  "$ROOT/surfaces"
  "$ROOT/bin"
  "$WORKBENCH_ROOT/agents"
  "$WORKBENCH_ROOT/scripts/agents"
)

RG_GLOBS=(
  "--glob=*.sh"
  "--glob=*.py"
  "--glob=*.ts"
  "--glob=*.tsx"
  "--glob=*.js"
  "--glob=*.mjs"
  "--glob=*.cjs"
)

PATTERNS=(
  "api\\.resend\\.com"
  "api\\.twilio\\.com"
  "Messages\\.json"
  "new[[:space:]]+Resend\\("
  "from[[:space:]]+['\"]resend['\"]"
  "require\\(['\"]resend['\"]\\)"
  "from[[:space:]]+['\"]twilio['\"]"
  "require\\(['\"]twilio['\"]\\)"
  "twilio\\.rest\\.Client"
)

existing_dirs=()
for dir in "${SCAN_DIRS[@]}"; do
  [[ -d "$dir" ]] && existing_dirs+=("$dir")
done

[[ ${#existing_dirs[@]} -gt 0 ]] || fail "no scan directories found"

scan_files_count=0
for dir in "${existing_dirs[@]}"; do
  dir_count="$(rg --files "${RG_GLOBS[@]}" "$dir" 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$dir_count" =~ ^[0-9]+$ ]] || dir_count=0
  scan_files_count=$((scan_files_count + dir_count))
done

hits_file="$(mktemp)"
violations_file="$(mktemp)"
trap 'rm -f "$hits_file" "$violations_file"' EXIT

rg_args=(--no-heading -n -S)
for g in "${RG_GLOBS[@]}"; do
  rg_args+=("$g")
done
for p in "${PATTERNS[@]}"; do
  rg_args+=(-e "$p")
done

rg "${rg_args[@]}" "${existing_dirs[@]}" >"$hits_file" || true

while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  file_path="${line%%:*}"

  # Canonical allowlist: only communications plugin may call providers directly.
  if [[ "$file_path" == "$ALLOWED_SPINE_PREFIX"* ]]; then
    continue
  fi

  # Ignore this gate script if pattern literals are ever expanded in future edits.
  if [[ "$file_path" == "$ROOT/surfaces/verify/d147-communications-canonical-routing-lock.sh" ]]; then
    continue
  fi

  echo "$line" >>"$violations_file"
done <"$hits_file"

if [[ -s "$violations_file" ]]; then
  echo "D147 FAIL: direct Twilio/Resend usage detected outside canonical communications surface" >&2
  sed 's/^/  /' "$violations_file" >&2
  exit 1
fi

echo "D147 PASS: communications direct-provider routing lock valid (files_scanned=$scan_files_count, roots=${#existing_dirs[@]})"
