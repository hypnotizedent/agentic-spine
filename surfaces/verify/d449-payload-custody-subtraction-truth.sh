#!/usr/bin/env bash
set -euo pipefail

# D449: Payload Custody Subtraction Truth
# Purpose: canonical payload custody readback must exist, and old storage/media
# surfaces must not remain peer current custody authority.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPS="$ROOT/ops/capabilities.yaml"
SNAPSHOT="$ROOT/ops/bindings/snapshot.surface.contract.yaml"
MASTER="$ROOT/ops/bindings/master.inventory.registry.yaml"
PAYLOAD_CUSTODY="$ROOT/ops/plugins/infra/bin/payload-custody-status"

fail() { echo "D449 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

[[ -x "$PAYLOAD_CUSTODY" ]] || fail "missing executable payload-custody-status"

python3 - "$ROOT" "$CAPS" "$SNAPSHOT" "$MASTER" "$PAYLOAD_CUSTODY" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

import yaml

root = Path(sys.argv[1])
caps_path = Path(sys.argv[2])
snapshot_path = Path(sys.argv[3])
master_path = Path(sys.argv[4])
payload_custody = Path(sys.argv[5])


def fail(message: str) -> None:
    print(f"D449 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


caps = load_yaml(caps_path)
cap = (caps.get("capabilities") or {}).get("payload.custody.status")
if not isinstance(cap, dict):
    fail("payload.custody.status missing from ops/capabilities.yaml")
if cap.get("safety") != "read-only":
    fail("payload.custody.status must be read-only")
if cap.get("script_path") != "./ops/plugins/infra/bin/payload-custody-status":
    fail("payload.custody.status script_path must point at payload-custody-status")

snapshot = load_yaml(snapshot_path)
surfaces = ((snapshot.get("data_heartbeat") or {}).get("surfaces") or [])
by_id = {row.get("surface_id"): row for row in surfaces if isinstance(row, dict)}

canonical = by_id.get("payload.custody.readback")
if not isinstance(canonical, dict):
    fail("snapshot.surface.contract.yaml missing payload.custody.readback")
if canonical.get("authority_layer") != "L2_readmodel":
    fail("payload.custody.readback must be L2_readmodel")
if canonical.get("refresh_binding") != "payload.custody.status":
    fail("payload.custody.readback must refresh from payload.custody.status")

for surface_id in [
    "shop.storage.map",
    "home.storage.map",
    "media.capacity.snapshot",
    "media.content.snapshot",
]:
    row = by_id.get(surface_id)
    if not isinstance(row, dict):
        fail(f"missing {surface_id} in snapshot surface contract")
    if row.get("authority_layer") in {"L1_authority", "L2_authority", "L2_projection"}:
        fail(f"{surface_id} still reads as peer storage/payload authority")
    text = f"{row.get('consumer_policy', '')} {row.get('subtraction_disposition', '')}"
    if "payload.custody.status" not in text and "payload_custody" not in text:
        fail(f"{surface_id} demotion must name payload custody replacement")

master = load_yaml(master_path)
rows = master.get("rows") or []
master_by_id = {row.get("id"): row for row in rows if isinstance(row, dict)}
if not isinstance(master_by_id.get("authority.payload.custody.readback"), dict):
    fail("master inventory missing authority.payload.custody.readback row")

# L1/L3 boundary: D449 validates that SPINE-LOCAL bindings cite the canonical
# payload.custody.status authority. L3 media surfaces (media.capacity.snapshot,
# media.content.snapshot) are already validated for demotion above via
# snapshot.surface.contract.yaml authority_layer + consumer_policy /
# subtraction_disposition checks (the loop over by_id). That is the
# spine-side validation of those L3 surfaces. Whether the L3 media files
# themselves cite payload.custody.status is an L3 verify concern, not a
# spine.verify concern. Spine.verify must not read MacBook-local L3 product
# bodies as a foundational truth dependency. (PACKET-590; see
# root.authority.contract.yaml#storage_evidence_node_canonical.file_plane_policy
# and prior forensic trace
# $SPINE_STATE/domain-state/STORAGE-EVIDENCE-PHASE-E-FORENSIC-DRIFT-TRACE-20260502.md.)
for rel in [
    "ops/bindings/shop.storage.map.yaml",
    "ops/bindings/home.storage.map.yaml",
]:
    text = (root / rel).read_text(encoding="utf-8")
    if "payload.custody.status" not in text:
        fail(f"{rel} must name payload.custody.status as replacement")

proc = subprocess.run([str(payload_custody), "--json"], text=True, capture_output=True)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "payload.custody.status sample failed")
payload = json.loads(proc.stdout)
if payload.get("canonical_authority") != "payload.custody.status":
    fail("payload.custody.status payload missing canonical authority")
rows = payload.get("rows") or []
if not rows:
    fail("payload.custody.status emitted no rows")
required = [
    "custody_id",
    "subject_kind",
    "site",
    "owner_node_id",
    "surface_ref",
    "scaffold_class",
    "custody_state",
    "canonicality",
    "recovery_promise",
    "freshness",
    "deletion_guard",
    "source_surfaces",
    "subtraction_caption",
]
missing = [field for field in required if field not in rows[0]]
if missing:
    fail(f"payload.custody.status row missing fields: {', '.join(missing)}")

by_custody = {row.get("custody_id"): row for row in rows}
for custody_id in [
    "pve:/md1400/archive",
    "pve:/md1400/backups",
    "pve:/md1400/stage",
    "pve:/md1400/tombstones",
    "pve:/media",
    "nas:/volume1/media-staging",
    "nas:/volume1/media-holds",
    "nas:/volume1/backups/proxmox_backups/dump",
    "nas:/volume1/backups/apps/media-config",
    "nas:/volume1/backups/_legacy_tombstones",
    "nas:/volume1/documents",
    "nas:/volume1/homelab",
]:
    if custody_id not in by_custody:
        fail(f"payload.custody.status missing required custody row {custody_id}")
if any(str(row.get("custody_id", "")).startswith("synology918:") for row in rows):
    fail("payload.custody.status must not emit synology918 as a peer custody identity")
for custody_id in [
    "nas:/volume1/media-staging",
    "nas:/volume1/backups/proxmox_backups/dump",
]:
    if by_custody[custody_id].get("owner_node_id") != "nas":
        fail(f"{custody_id} must use nas as canonical owner_node_id")
    if by_custody[custody_id].get("presence_proof_ref") != "site.presence.status:nas":
        fail(f"{custody_id} must join presence through canonical nas identity")
if by_custody["pve:/media"].get("canonicality") == "canonical":
    fail("pve:/media must not be canonical long-term shop payload truth")
if by_custody["pve:/media"].get("deletion_guard", {}).get("state") != "delete_blocked":
    fail("pve:/media deletion must remain blocked until replacement proof/cutover")
for custody_id in [
    "nas:/volume1/media-holds",
    "nas:/volume1/backups/_legacy_tombstones",
    "nas:/volume1/documents",
    "nas:/volume1/homelab",
]:
    if by_custody[custody_id].get("presence_state") != "missing":
        fail(f"{custody_id} must preserve declared custody intent but show missing presence from NAS manifest")

print("D449 PASS: payload custody readback exists and old storage/media authority is demoted")
PY
