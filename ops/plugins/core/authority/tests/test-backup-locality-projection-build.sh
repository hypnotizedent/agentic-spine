#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
BUILD="$ROOT/ops/plugins/core/authority/bin/backup-locality-projection-build"

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

echo "backup locality projection build tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/ops/bindings"

cat > "$tmpdir/ops/bindings/topology.sites.yaml" <<'YAML'
sites:
  - id: shop
    proxmox_alias: pve
    tailscale_anchor: pve
    host_refs: [pve]
  - id: home
    proxmox_alias: proxmox-home
    tailscale_anchor: proxmox-home
    host_refs: [proxmox-home, nas]
YAML

cat > "$tmpdir/ops/bindings/vm.lifecycle.yaml" <<'YAML'
vms:
  - hostname: automation-stack
    proxmox_host: pve
  - hostname: media-home
    proxmox_host: proxmox-home
YAML

cat > "$tmpdir/ops/bindings/backup.inventory.yaml" <<'YAML'
model:
  destination_lanes:
    pve-vzdump-primary:
      host: pve
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
    destination_lane: pve-vzdump-primary
    destination_site: shop
    locality: local_hot
YAML

build_out="$(python3 "$BUILD" --root "$tmpdir" 2>&1)"
assert_contains "$build_out" "backup.locality.projection.build" "builder announces capability"

projected="$tmpdir/ops/bindings/backup.locality.projected.yaml"
if [[ -f "$projected" ]]; then
  pass "projection written"
else
  fail "projection written"
fi

projected_body="$(cat "$projected")"
assert_contains "$projected_body" "derived:" "projection emits derived section"
assert_contains "$projected_body" "source_site_match: true" "projection derives source site"
assert_contains "$projected_body" "destination_site_match: true" "projection derives destination site"
assert_contains "$projected_body" "locality_consistent: true" "projection derives locality consistency"

check_out="$(python3 "$BUILD" --root "$tmpdir" --check 2>&1)"
assert_contains "$check_out" "PASS" "builder parity check passes"

printf '\n# drift\n' >> "$projected"
set +e
drift_out="$(python3 "$BUILD" --root "$tmpdir" --check 2>&1)"
drift_rc=$?
set -e
if [[ "$drift_rc" -eq 1 ]]; then
  pass "builder parity check fails on drift"
else
  fail "builder parity check fails on drift (rc=$drift_rc)"
fi
assert_contains "$drift_out" "projection drift" "builder reports drift"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
