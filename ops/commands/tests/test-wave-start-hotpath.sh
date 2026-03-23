#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WAVE_SCRIPT="$ROOT/ops/commands/wave.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (expected: $needle)"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    fail "$label (unexpected: $needle)"
  else
    pass "$label"
  fi
}

assert_not_exists() {
  local path="$1" label="$2"
  if [[ ! -e "$path" ]]; then
    pass "$label"
  else
    fail "$label (found: $path)"
  fi
}

make_fake_repo() {
  local repo="$1"
  mkdir -p "$repo/ops/commands" "$repo/ops/lib" "$repo/ops/bindings"

  cp "$WAVE_SCRIPT" "$repo/ops/commands/wave.sh"

  cat > "$repo/ops/lib/runtime-paths.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
spine_runtime_resolve_paths() {
  export SPINE_REPO="${SPINE_REPO:-$PWD}"
  export SPINE_RUNTIME_ROOT="${SPINE_RUNTIME_ROOT:-$PWD/.runtime}"
  export SPINE_STATE="${SPINE_STATE:-$SPINE_RUNTIME_ROOT/state}"
}
spine_resolve_mailroom_path() {
  local rel="${1:?mailroom path required}"
  printf '%s\n' "${SPINE_RUNTIME_ROOT:-$PWD/.runtime}/${rel}"
}
SH

  cat > "$repo/ops/bindings/terminal.role.contract.yaml" <<'YAML'
runtime_role_defaults:
  by_terminal_id:
    SPINE-CONTROL-01: worker
roles:
  - id: SPINE-CONTROL-01
    type: control-plane
    write_scope:
      - ops/
      - docs/governance/
YAML

  cat > "$repo/ops/bindings/role.runtime.control.contract.yaml" <<'YAML'
runtime_roles:
  canonical: [researcher, worker, qc, close, librarian]
  default_role: researcher
promotion_gates:
  transitions:
    - from: researcher
      to: worker
path_claims:
  state_file: mailroom/state/path.claims.yaml
  default_ttl_minutes: 180
  require_non_overlapping_active_claims: true
wave_packet:
  required_fields:
    - wave_id
    - loop_id
    - owner_terminal
    - current_role
    - next_role
    - deadline_utc
    - horizon
    - execution_readiness
    - claimed_paths
  allowed_horizon: [now, later, future]
  allowed_readiness: [runnable, blocked]
  default_deadline_hours: 24
YAML

  chmod +x "$repo/ops/commands/wave.sh" "$repo/ops/lib/runtime-paths.sh"

  git init "$repo" >/dev/null
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" add .
  git -C "$repo" commit -m "base" >/dev/null
  git -C "$repo" branch -M main >/dev/null
}

echo "wave start hot-path tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/repo"
make_fake_repo "$repo"

runtime_one="$tmpdir/runtime-one"
out_one="$(
  cd "$repo" && \
  env -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_ROLE -u SPINE_TERMINAL_NAME -u SPINE_REPO -u SPINE_STATE -u SPINE_CODE -u SPINE_TARGET_REPO \
    SPINE_REPO="$repo" \
    SPINE_STATE="$runtime_one/state" \
    SPINE_TERMINAL_ID=SPINE-CONTROL-01 \
    SPINE_RUNTIME_ROOT="$runtime_one" \
    bash ops/commands/wave.sh start WAVE-TEST-01 \
      --objective "resolve claimed paths from terminal contract" \
      --loop-id LOOP-TEST-01 \
      --worktree off 2>&1
)"
assert_contains "$out_one" "Wave 'WAVE-TEST-01' created." "known terminal can start wave"
python3 - <<'PY' "$runtime_one/waves/WAVE-TEST-01/state.json"
import json, sys
from pathlib import Path
state = json.loads(Path(sys.argv[1]).read_text())
assert state["packet"]["owner_terminal"] == "SPINE-CONTROL-01"
assert state["packet"]["claimed_paths"] == ["ops/", "docs/governance/"]
PY
pass "known terminal resolves contract write scope"

runtime_two="$tmpdir/runtime-two"
set +e
out_two="$(
  cd "$repo" && \
  env -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_ROLE -u SPINE_TERMINAL_NAME -u SPINE_TERMINAL_ID -u SPINE_REPO -u SPINE_STATE -u SPINE_CODE -u SPINE_TARGET_REPO \
    USER=tester \
    SPINE_REPO="$repo" \
    SPINE_STATE="$runtime_two/state" \
    SPINE_RUNTIME_ROOT="$runtime_two" \
    bash ops/commands/wave.sh start WAVE-TEST-02 \
      --objective "fail closed when terminal scope is unknown" \
      --loop-id LOOP-TEST-02 \
      --worktree off 2>&1
)"
rc_two=$?
set -e
if [[ "$rc_two" -ne 0 ]]; then
  pass "unknown terminal without claimed paths fails closed"
else
  fail "unknown terminal without claimed paths fails closed"
fi
assert_contains "$out_two" "claimed paths unresolved for terminal 'tester'" "unknown terminal reports unresolved scope"
assert_not_contains "$out_two" "unbound variable" "unknown terminal failure does not trip cleanup trap"
assert_not_exists "$runtime_two/waves/WAVE-TEST-02" "failed unresolved-scope start leaves no state dir"

runtime_three="$tmpdir/runtime-three"
out_three_a="$(
  cd "$repo" && \
  env -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_ROLE -u SPINE_TERMINAL_NAME -u SPINE_TERMINAL_ID -u SPINE_REPO -u SPINE_STATE -u SPINE_CODE -u SPINE_TARGET_REPO \
    USER=tester \
    SPINE_REPO="$repo" \
    SPINE_STATE="$runtime_three/state" \
    SPINE_RUNTIME_ROOT="$runtime_three" \
    bash ops/commands/wave.sh start WAVE-TEST-03A \
      --objective "prime active claim" \
      --loop-id LOOP-TEST-03A \
      --claimed-paths "ops/commands/wave.sh" \
      --worktree off 2>&1
)"
assert_contains "$out_three_a" "Wave 'WAVE-TEST-03A' created." "explicit claimed paths can start ad hoc wave"
set +e
out_three_b="$(
  cd "$repo" && \
  env -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_ROLE -u SPINE_TERMINAL_NAME -u SPINE_TERMINAL_ID -u SPINE_REPO -u SPINE_STATE -u SPINE_CODE -u SPINE_TARGET_REPO \
    USER=tester \
    SPINE_REPO="$repo" \
    SPINE_STATE="$runtime_three/state" \
    SPINE_RUNTIME_ROOT="$runtime_three" \
    bash ops/commands/wave.sh start WAVE-TEST-03B \
      --objective "collide on active claim" \
      --loop-id LOOP-TEST-03B \
      --claimed-paths "ops/commands/wave.sh" \
      --worktree off 2>&1
)"
rc_three_b=$?
set -e
if [[ "$rc_three_b" -ne 0 ]]; then
  pass "path collision blocks second wave"
else
  fail "path collision blocks second wave"
fi
assert_contains "$out_three_b" "path claim collision detected" "collision reports claim overlap"
assert_not_contains "$out_three_b" "unbound variable" "collision failure does not trip cleanup trap"
assert_not_exists "$runtime_three/waves/WAVE-TEST-03B" "collision failure cleans transient state dir"

runtime_four="$tmpdir/runtime-four"
mkdir -p "$runtime_four/mailroom/state" "$runtime_four/waves/WAVE-STALE-04"
cat > "$runtime_four/mailroom/state/path.claims.yaml" <<'JSON'
{
  "schema_version": "1.0",
  "updated_at": "2026-03-23T03:00:00Z",
  "claims": [
    {
      "claim_id": "CLM-WAVE-STALE-04-20260323T030000Z",
      "wave_id": "WAVE-STALE-04",
      "loop_id": "LOOP-STALE-04",
      "owner_terminal": "tester",
      "status": "active",
      "claimed_paths": ["ops/commands/wave.sh"],
      "created_at": "2026-03-23T03:00:00Z",
      "expires_at": "2099-03-23T06:00:00Z"
    }
  ]
}
JSON
cat > "$runtime_four/waves/WAVE-STALE-04/state.json" <<'JSON'
{
  "wave_id": "WAVE-STALE-04",
  "status": "active",
  "lifecycle_state": "active",
  "packet": {
    "claimed_paths": []
  }
}
JSON

reconcile_out="$(
  cd "$repo" && \
  env -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_ROLE -u SPINE_TERMINAL_NAME -u SPINE_TERMINAL_ID -u SPINE_REPO -u SPINE_STATE -u SPINE_CODE -u SPINE_TARGET_REPO \
    USER=tester \
    SPINE_REPO="$repo" \
    SPINE_STATE="$runtime_four/state" \
    SPINE_RUNTIME_ROOT="$runtime_four" \
    bash ops/commands/wave.sh claims-reconcile --json 2>&1
)"
python3 - <<'PY' "$reconcile_out"
import json, sys
payload = json.loads(sys.argv[1])
assert payload["summary"]["expired"] == 1, payload
assert payload["summary"]["updated"] == 1, payload
PY
pass "claims-reconcile expires stale active claim when wave scope is missing"
python3 - <<'PY' "$runtime_four/mailroom/state/path.claims.yaml"
import json, sys
claims = json.loads(open(sys.argv[1]).read())["claims"]
claim = claims[0]
assert claim["status"] == "expired", claim
assert claim["reconciled_reason"] == "wave_scope_missing", claim
PY
pass "claims ledger records canonical stale-claim expiry"

runtime_five="$tmpdir/runtime-five"
mkdir -p "$runtime_five/mailroom/state"
cat > "$runtime_five/mailroom/state/path.claims.yaml" <<'JSON'
{
  "schema_version": "1.0",
  "updated_at": "2026-03-23T03:00:00Z",
  "claims": [
    {
      "claim_id": "CLM-WAVE-STALE-05-20260323T030000Z",
      "wave_id": "WAVE-STALE-05",
      "loop_id": "LOOP-STALE-05",
      "owner_terminal": "tester",
      "status": "active",
      "claimed_paths": ["ops/commands/wave.sh"],
      "created_at": "2026-03-23T03:00:00Z",
      "expires_at": "2099-03-23T06:00:00Z"
    }
  ]
}
JSON

out_five="$(
  cd "$repo" && \
  env -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_ROLE -u SPINE_TERMINAL_NAME -u SPINE_TERMINAL_ID -u SPINE_REPO -u SPINE_STATE -u SPINE_CODE -u SPINE_TARGET_REPO \
    USER=tester \
    SPINE_REPO="$repo" \
    SPINE_STATE="$runtime_five/state" \
    SPINE_RUNTIME_ROOT="$runtime_five" \
    bash ops/commands/wave.sh start WAVE-TEST-05 \
      --objective "auto-reconcile stale claim before overlap check" \
      --loop-id LOOP-TEST-05 \
      --claimed-paths "ops/commands/wave.sh" \
      --worktree off 2>&1
)"
assert_contains "$out_five" "Wave 'WAVE-TEST-05' created." "wave start auto-reconciles stale claim residue"
python3 - <<'PY' "$runtime_five/mailroom/state/path.claims.yaml"
import json, sys
claims = json.loads(open(sys.argv[1]).read())["claims"]
stale = next(c for c in claims if c["claim_id"] == "CLM-WAVE-STALE-05-20260323T030000Z")
fresh = next(c for c in claims if c["wave_id"] == "WAVE-TEST-05")
assert stale["status"] == "expired", stale
assert stale["reconciled_reason"] == "wave_state_missing", stale
assert fresh["status"] == "active", fresh
assert fresh["claimed_paths"] == ["ops/commands/wave.sh"], fresh
PY
pass "wave start leaves new claim active after expiring stale residue"

echo
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
