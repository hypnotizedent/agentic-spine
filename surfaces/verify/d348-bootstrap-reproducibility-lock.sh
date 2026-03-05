#!/usr/bin/env bash
# TRIAGE: Ensure spine.init dry-run output is deterministic and does not mutate bootstrap contract files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INIT_SCRIPT="$ROOT/ops/plugins/session/bin/spine-init"
DOCTOR_SCRIPT="$ROOT/ops/plugins/session/bin/spine-doctor"
ENV_FILE="$ROOT/.environment.yaml"
IDENTITY_FILE="$ROOT/.identity.yaml"
ACK_FILE="$ROOT/.contract_read_$(date +%Y%m%d)"

fail() { echo "D348 FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "required tool missing: jq"
[[ -x "$INIT_SCRIPT" ]] || fail "missing/non-executable script: $INIT_SCRIPT"
[[ -x "$DOCTOR_SCRIPT" ]] || fail "missing/non-executable script: $DOCTOR_SCRIPT"

cd "$ROOT"

hash_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing"
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
    return 0
  fi
  fail "missing hash tool (need shasum or sha256sum)"
}

before_env="$(hash_file "$ENV_FILE")"
before_identity="$(hash_file "$IDENTITY_FILE")"
before_ack="$(hash_file "$ACK_FILE")"

tmp1="$(mktemp)"
tmp2="$(mktemp)"
tmpd="$(mktemp)"
trap 'rm -f "$tmp1" "$tmp2" "$tmpd"' EXIT

"$INIT_SCRIPT" --dry-run --json | jq -S . >"$tmp1"
"$INIT_SCRIPT" --dry-run --json | jq -S . >"$tmp2"
"$DOCTOR_SCRIPT" --json | jq -S . >"$tmpd"

if ! diff -u "$tmp1" "$tmp2" >/dev/null 2>&1; then
  echo "---- run#1 ----" >&2
  cat "$tmp1" >&2
  echo "---- run#2 ----" >&2
  cat "$tmp2" >&2
  fail "spine.init --dry-run output is non-deterministic"
fi

after_env="$(hash_file "$ENV_FILE")"
after_identity="$(hash_file "$IDENTITY_FILE")"
after_ack="$(hash_file "$ACK_FILE")"

[[ "$before_env" == "$after_env" ]] || fail ".environment.yaml changed during dry-run"
[[ "$before_identity" == "$after_identity" ]] || fail ".identity.yaml changed during dry-run"
[[ "$before_ack" == "$after_ack" ]] || fail "contract ack marker changed during dry-run"

echo "D348 PASS: bootstrap dry-run is deterministic and mutation-free"
