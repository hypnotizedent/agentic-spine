#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
BUILD="$ROOT/ops/plugins/core/authority/bin/backup-locality-projection-build"
AUDIT="$ROOT/ops/plugins/infra/bin/backup-locality-audit"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s\n' "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (missing '$needle')"
  fi
}

echo "backup locality audit tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/ops/bindings"

cat > "$tmpdir/ops/bindings/topology.sites.yaml" <<'YAML'
sites:
  - id: shop
    proxmox_alias: pve
    host_refs: [pve]
  - id: home
    proxmox_alias: proxmox-home
    host_refs: [proxmox-home, nas]
YAML

cat > "$tmpdir/ops/bindings/vm.lifecycle.yaml" <<'YAML'
vms:
  - hostname: automation-stack
    proxmox_host: pve
YAML

cat > "$tmpdir/ops/bindings/backup.inventory.yaml" <<'YAML'
model:
  destination_lanes:
    nas-home-local-exception:
      host: nas
runtime_units:
  - unit_id: vm-202-automation-stack
    inventory_targets: [vm-202-primary]
targets:
  - name: vm-202-primary
YAML

cat > "$tmpdir/ops/bindings/backup.locality.contract.yaml" <<'YAML'
target_localities:
  - target: vm-202-primary
    source_site: shop
    source_vm: automation-stack
    destination_lane: nas-home-local-exception
    destination_site: shop
    locality: local_hot
YAML

python3 "$BUILD" --root "$tmpdir" >/dev/null

set +e
fail_out="$(python3 "$AUDIT" --root "$tmpdir" --brief --strict 2>&1)"
fail_rc=$?
set -e
if [[ "$fail_rc" -eq 1 ]]; then
  pass "audit fails on locality mismatch"
else
  fail "audit fails on locality mismatch (rc=$fail_rc)"
fi
assert_contains "$fail_out" "FAIL issues=1" "audit reports one issue"

python3 - <<'PY' "$tmpdir/ops/bindings/backup.locality.contract.yaml"
from pathlib import Path
path = Path(__import__("sys").argv[1])
text = path.read_text()
text = text.replace("destination_site: shop", "destination_site: home")
text = text.replace("locality: local_hot", "locality: offsite_warm")
path.write_text(text)
PY

python3 "$BUILD" --root "$tmpdir" >/dev/null
pass_out="$(python3 "$AUDIT" --root "$tmpdir" --brief --strict 2>&1)"
assert_contains "$pass_out" "PASS issues=0" "audit passes when locality matches"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
