#!/usr/bin/env bash
# D.3c routing behavior self-check.
#
# Exercises _route_to_db_authority_if_needed in cap.sh under controlled
# contracts/capabilities.yaml fixtures. Verifies:
#   - enabled=false → return 126 (stay local) for any cap
#   - enabled=true, authority host → return 126 (this IS authority)
#   - enabled=true, non-authority, mutating cap → attempts to route (no key/no-op SSH path)
#   - enabled=true, non-authority, read-only DB-backed cap → attempts to route
#   - enabled=true, non-authority, read-only non-DB cap → return 126 (stay local)
#   - enabled=true, non-authority, destructive cap → attempts to route
#
# We can't actually SSH out in this self-check — we set host_addr empty so
# the function returns rc=1 ("host_addr empty") right before SSH, which
# proves the function reached the routing branch. Together with the 126
# branches, this covers the decision logic without live network.
#
# Run: bash surfaces/verify/d447-d3c-routing-behavior-self-check.sh
# Exit 0 = PASS, non-zero = FAIL.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/d3c-routing-check.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/ops/bindings" "$TMP/ops/commands" "$TMP/ops"

# Copy real cap.sh into the fixture so we exercise the actual code under test.
cp "$ROOT/ops/commands/cap.sh" "$TMP/ops/commands/cap.sh"

write_contract() {
    local enabled="$1"
    local host_addr="${2:-}"
    cat > "$TMP/ops/bindings/runtime.bootstrap.contract.yaml" <<EOF
db_authority:
  enabled: $enabled
  host: pve
  user: root
  host_addr_lan: "$host_addr"
  code_path: /opt/agentic-spine
  authority_hostnames:
    - pve
    - pve.local
  per_host_ssh_key:
    test-host: ""
  routing_safety_classes:
    - mutating
    - destructive
  routing_local_safety_classes:
    - read-only
    - read-only-with-cache
  ssh_connect_timeout_seconds: 10
  fail_closed_on_unreachable: true
  no_silent_fallback_to_local_db_writes: true
  read_routing:
    db_backed_caps_must_route_when_enabled: true
    non_db_caps_stay_local: true
    consumer_db_open_must_fail_closed: true
    state_authority_field_required_for_db_caps: true
EOF
}

write_capabilities() {
    cat > "$TMP/ops/capabilities.yaml" <<EOF
version: '1.0'
capabilities:
  test.read.db:
    safety: read-only
    state_authority: shared_authority_db
  test.read.nondb:
    safety: read-only
  test.mutate.db:
    safety: mutating
    state_authority: shared_authority_db
  test.destroy.db:
    safety: destructive
    state_authority: shared_authority_db
EOF
}

call_router() {
    # Exercise the function inside a subshell with controlled SPINE_CODE.
    # We use `hostname -s` override via /usr/bin/env vars — bash's hostname
    # command is the system one, so we cannot easily inject. Instead, the
    # test sets up a custom PATH with a fake hostname binary.
    local fake_host="$1"
    local cap_name="$2"

    local fake_path="$TMP/fake-bin"
    mkdir -p "$fake_path"
    cat > "$fake_path/hostname" <<EOF2
#!/bin/sh
case "\$1" in
  -s|"") echo "$fake_host" ;;
  *) echo "$fake_host" ;;
esac
EOF2
    chmod +x "$fake_path/hostname"

    set +e
    (
        export SPINE_CODE="$TMP"
        export PATH="$fake_path:$PATH"
        # Source cap.sh in a fresh subshell. Stub the SPINE_REPO + functions
        # cap.sh imports at sourcing time.
        export SPINE_REPO="$ROOT"
        # Source enough of cap.sh to get the routing function.
        # Use bash function extraction trick: pipe cap.sh through a filter.
        # Simplest: define needed external funcs as no-ops, then source.
        cat > "$TMP/route-shim.sh" <<'SHIM'
# Stubs for functions sourced indirectly that aren't relevant here.
spine_runtime_resolve_paths() { :; }
SHIM
        # Extract just the function definition via a delimited region read.
        awk '/^_route_to_db_authority_if_needed\(\) \{/,/^\}$/' "$TMP/ops/commands/cap.sh" > "$TMP/just-route.sh"
        # shellcheck disable=SC1090
        source "$TMP/route-shim.sh"
        # shellcheck disable=SC1090
        source "$TMP/just-route.sh"
        _route_to_db_authority_if_needed "$cap_name"
    )
    local rc=$?
    set -e
    echo "$rc"
}

PASS=0
FAIL=0
note() {
    if [[ "$1" == "PASS" ]]; then
        echo "  PASS: $2"
        PASS=$((PASS+1))
    else
        echo "  FAIL: $2"
        FAIL=$((FAIL+1))
    fi
}

echo "=== D.3c routing behavior self-check ==="

# Case 1: enabled=false → always 126 regardless of cap
write_contract "false" ""
write_capabilities
rc=$(call_router "test-host" "test.mutate.db")
[[ "$rc" == "126" ]] && note PASS "enabled=false, mutating cap → 126 (stay local)" || note FAIL "expected 126, got $rc (enabled=false, mutating)"

# Case 2: enabled=true, authority host → 126
write_contract "true" "192.168.1.184"
rc=$(call_router "pve" "test.mutate.db")
[[ "$rc" == "126" ]] && note PASS "enabled=true, authority host → 126 (this IS authority)" || note FAIL "expected 126, got $rc (enabled=true, on pve)"

# Case 3: enabled=true, non-authority, mutating cap → reaches routing branch
# (host_addr empty would yield rc=1; we set a fake addr but no-key SSH so
# function attempts SSH and likely fails — accept any non-126 as "routed".)
write_contract "true" ""  # empty host_addr → function returns 1 BEFORE SSH
rc=$(call_router "test-host" "test.mutate.db")
[[ "$rc" == "1" ]] && note PASS "enabled=true, non-auth, mutating, empty host_addr → 1 (routing reached)" || note FAIL "expected 1, got $rc (mutating routing)"

# Case 4: enabled=true, non-auth, read-only DB-backed → routing reached
rc=$(call_router "test-host" "test.read.db")
[[ "$rc" == "1" ]] && note PASS "enabled=true, non-auth, read-only DB-backed → 1 (routing reached)" || note FAIL "expected 1, got $rc (read-only DB routing)"

# Case 5: enabled=true, non-auth, read-only non-DB → 126 (stay local)
rc=$(call_router "test-host" "test.read.nondb")
[[ "$rc" == "126" ]] && note PASS "enabled=true, non-auth, read-only non-DB → 126 (stay local)" || note FAIL "expected 126, got $rc (read-only non-DB)"

# Case 6: enabled=true, non-auth, destructive → routing reached
rc=$(call_router "test-host" "test.destroy.db")
[[ "$rc" == "1" ]] && note PASS "enabled=true, non-auth, destructive → 1 (routing reached)" || note FAIL "expected 1, got $rc (destructive routing)"

# Case 7: db_authority_guard fails closed when enabled=true and DB missing on consumer
echo "=== guard test (lib-level empty-stub prevention) ==="
guard_test_rc=0
GUARD_LIB="$ROOT/ops/plugins/core/lifecycle/lib"
SPINE_CODE="$TMP" python3 - <<PY || guard_test_rc=$?
import sys, os
sys.path.insert(0, '$GUARD_LIB')
from db_authority_guard import assert_db_open_safe, DbAuthorityRoutingRequired
from pathlib import Path
# Use the test contract with enabled=true (already written above)
try:
    assert_db_open_safe(Path('/tmp/d3c-self-check-no-such-db.db'))
    print('FAIL: expected DbAuthorityRoutingRequired on missing DB')
    sys.exit(2)
except DbAuthorityRoutingRequired:
    print('PASS: guard fails closed on missing DB')
PY
if [[ $guard_test_rc -eq 0 ]]; then
    note PASS "lib guard refuses to auto-create empty stub when enabled=true on consumer"
else
    note FAIL "lib guard did not fail closed (rc=$guard_test_rc)"
fi

echo "=== D.3c self-check summary: $PASS pass, $FAIL fail ==="
[[ $FAIL -eq 0 ]] || exit 1
exit 0
