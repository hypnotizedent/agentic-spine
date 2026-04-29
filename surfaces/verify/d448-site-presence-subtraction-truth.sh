#!/usr/bin/env bash
set -euo pipefail

# D448: Site Presence Subtraction Truth
# Purpose: canonical site presence readback must exist, and old UniFi/home
# device surfaces must not remain peer current presence authority.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPS="$ROOT/ops/capabilities.yaml"
SNAPSHOT="$ROOT/ops/bindings/snapshot.surface.contract.yaml"
MASTER="$ROOT/ops/bindings/master.inventory.registry.yaml"
SITE_PRESENCE="$ROOT/ops/plugins/infra/bin/site-presence-status"

fail() { echo "D448 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

[[ -x "$SITE_PRESENCE" ]] || fail "missing executable site-presence-status"

python3 - "$ROOT" "$CAPS" "$SNAPSHOT" "$MASTER" "$SITE_PRESENCE" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

import yaml

root = Path(sys.argv[1])
caps_path = Path(sys.argv[2])
snapshot_path = Path(sys.argv[3])
master_path = Path(sys.argv[4])
site_presence = Path(sys.argv[5])


def fail(message: str) -> None:
    print(f"D448 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


caps = load_yaml(caps_path)
cap = (caps.get("capabilities") or {}).get("site.presence.status")
if not isinstance(cap, dict):
    fail("site.presence.status missing from ops/capabilities.yaml")
if cap.get("safety") != "read-only":
    fail("site.presence.status must be read-only")
if cap.get("script_path") != "./ops/plugins/infra/bin/site-presence-status":
    fail("site.presence.status script_path must point at site-presence-status")

snapshot = load_yaml(snapshot_path)
surfaces = ((snapshot.get("data_heartbeat") or {}).get("surfaces") or [])
by_id = {row.get("surface_id"): row for row in surfaces if isinstance(row, dict)}

canonical = by_id.get("site.presence.readback")
if not isinstance(canonical, dict):
    fail("snapshot.surface.contract.yaml missing site.presence.readback")
if canonical.get("authority_layer") != "L2_readmodel":
    fail("site.presence.readback must be L2_readmodel")
if canonical.get("refresh_binding") != "site.presence.status":
    fail("site.presence.readback must refresh from site.presence.status")

for surface_id in [
    "home.device.registry",
    "network.unifi.home.clients.observed",
    "network.unifi.shop.clients.observed",
]:
    row = by_id.get(surface_id)
    if not isinstance(row, dict):
        fail(f"missing {surface_id} in snapshot surface contract")
    if row.get("authority_layer") in {"L1_authority", "L2_authority"}:
        fail(f"{surface_id} still reads as peer authority")
    text = f"{row.get('consumer_policy', '')} {row.get('subtraction_disposition', '')}"
    if "site_presence" not in text and "site.presence.status" not in text:
        fail(f"{surface_id} demotion must name site presence replacement")

master = load_yaml(master_path)
rows = master.get("rows") or []
master_by_id = {row.get("id"): row for row in rows if isinstance(row, dict)}
if not isinstance(master_by_id.get("authority.site.presence.readback"), dict):
    fail("master inventory missing authority.site.presence.readback row")
for old_id in [
    "authority.home.device.registry",
    "authority.network.unifi.home.clients.observed",
    "authority.network.unifi.shop.clients.observed",
]:
    row = master_by_id.get(old_id)
    if not isinstance(row, dict):
        fail(f"master inventory missing {old_id}")
    authority = row.get("authority") or {}
    if authority.get("expected_authority_state") == "authoritative":
        fail(f"{old_id} still authoritative in master inventory")

for rel in [
    "ops/bindings/home.device.registry.yaml",
    "ops/bindings/network.unifi.home.clients.observed.yaml",
    "ops/bindings/network.unifi.shop.clients.observed.yaml",
]:
    text = (root / rel).read_text(encoding="utf-8")
    if "site.presence.status" not in text:
        fail(f"{rel} must name site.presence.status as replacement")

proc = subprocess.run([str(site_presence), "--site", "home", "--json"], text=True, capture_output=True)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "site.presence.status sample failed")
payload = json.loads(proc.stdout)
if payload.get("canonical_authority") != "site.presence.status":
    fail("site.presence.status payload missing canonical authority")
rows = payload.get("rows") or []
if not rows:
    fail("site.presence.status --site home emitted no rows")
required = [
    "presence_id",
    "site",
    "network_scope",
    "subject",
    "identity",
    "presence_state",
    "match_state",
    "proof_channels",
    "freshness",
    "source_surfaces",
    "actions_allowed",
    "subtraction_caption",
]
missing = [field for field in required if field not in rows[0]]
if missing:
    fail(f"site.presence.status row missing fields: {', '.join(missing)}")
if rows[0].get("actions_allowed", {}).get("may_create_node") is not False:
    fail("site.presence.status must not allow node creation")

print("D448 PASS: site presence readback exists and old network/device authority is demoted")
PY
