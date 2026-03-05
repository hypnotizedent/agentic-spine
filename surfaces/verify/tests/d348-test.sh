#!/usr/bin/env bash
# Tests for D348: bootstrap reproducibility lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d348-bootstrap-reproducibility-lock.sh"

PASS=0
FAIL_COUNT=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1" >&2; }

setup_mock() {
  local tmp init_payload doctor_payload
  tmp="$(mktemp -d)"
  init_payload="${1:-deterministic}"
  doctor_payload="${2:-deterministic}"

  mkdir -p \
    "$tmp/surfaces/verify" \
    "$tmp/ops/plugins/session/bin"
  cp "$GATE" "$tmp/surfaces/verify/d348-bootstrap-reproducibility-lock.sh"
  chmod +x "$tmp/surfaces/verify/d348-bootstrap-reproducibility-lock.sh"

  case "$init_payload" in
    deterministic)
      cat > "$tmp/ops/plugins/session/bin/spine-init" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{"capability":"spine.init","status":"ok","dry_run":true}
JSON
EOF
      ;;
    nondeterministic)
      cat > "$tmp/ops/plugins/session/bin/spine-init" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '{"capability":"spine.init","status":"ok","nonce":"%s"}\n' "$(date +%s%N)"
EOF
      ;;
    mutating)
      cat > "$tmp/ops/plugins/session/bin/spine-init" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "changed" >> .environment.yaml
cat <<'JSON'
{"capability":"spine.init","status":"ok","dry_run":true}
JSON
EOF
      ;;
    *)
      echo "unknown init payload: $init_payload" >&2
      return 1
      ;;
  esac

  case "$doctor_payload" in
    deterministic)
      cat > "$tmp/ops/plugins/session/bin/spine-doctor" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{"capability":"spine.doctor","status":"ok"}
JSON
EOF
      ;;
    *)
      echo "unknown doctor payload: $doctor_payload" >&2
      return 1
      ;;
  esac

  chmod +x "$tmp/ops/plugins/session/bin/spine-init" "$tmp/ops/plugins/session/bin/spine-doctor"
  cat > "$tmp/.environment.yaml" <<'EOF'
version: "1.0"
environment:
  name: test
EOF
  cat > "$tmp/.identity.yaml" <<'EOF'
version: "1.0"
identity:
  node_id: test
EOF
  echo "$tmp"
}

cleanup_mock() {
  [[ -n "${1:-}" && -d "$1" ]] && rm -rf "$1" || true
}

echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D348 passes on current repo state"
else
  fail "D348 should pass on current repo state"
fi

echo "--- Test 2: nondeterministic init output FAIL ---"
MOCK="$(setup_mock nondeterministic deterministic)"
trap 'cleanup_mock "$MOCK"' EXIT
output=$(bash "$MOCK/surfaces/verify/d348-bootstrap-reproducibility-lock.sh" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D348 correctly fails for nondeterministic dry-run output (rc=$rc)"
else
  fail "D348 should fail for nondeterministic output (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

echo "--- Test 3: dry-run mutation FAIL ---"
MOCK="$(setup_mock mutating deterministic)"
trap 'cleanup_mock "$MOCK"' EXIT
output=$(bash "$MOCK/surfaces/verify/d348-bootstrap-reproducibility-lock.sh" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D348 correctly fails when dry-run mutates state (rc=$rc)"
else
  fail "D348 should fail when dry-run mutates state (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
