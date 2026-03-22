#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init
SCRIPT="$ROOT/ops/plugins/domains/mint/bin/artwork-place"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/minio/artwork-intake/jobs/13825 Papa/1. Originals"
mkdir -p "$tmpdir/state"
printf 'proof' >"$tmpdir/source.pdf"

dry_run_out="$(
  MINIO_MOUNT_ROOT="$tmpdir/minio" \
  SPINE_STATE="$tmpdir/state" \
  python3 "$SCRIPT" "$tmpdir/source.pdf" --context "13825 Papa" --dry-run --json
)"
assert_contains "$dry_run_out" "\"resolved_target_key\": \"jobs/13825 Papa/1. Originals\"" "existing jobs target selected"

stage_out="$(
  MINIO_MOUNT_ROOT="$tmpdir/minio" \
  SPINE_STATE="$tmpdir/state" \
  python3 "$SCRIPT" "$tmpdir/source.pdf" --context "Unknown Legacy Project" --json
)"
stage_path="$(printf '%s' "$stage_out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["resolved_file_path"])')"
[[ -f "$stage_path" ]] && pass "file copied into resolved target" || fail "file copied into resolved target"
assert_contains "$stage_out" "\"used_staging_fallback\": true" "staging fallback declared when no canonical target exists"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
