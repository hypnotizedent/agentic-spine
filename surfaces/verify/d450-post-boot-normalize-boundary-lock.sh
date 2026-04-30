#!/usr/bin/env bash
set -euo pipefail

# D450: Post-Boot Normalize Boundary Lock
# Purpose: the post-boot normalize primitive must remain a bounded Stage 0
# normalizer, not admission, role, placement, watcher, backup, or PVE authority.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPS="$ROOT/ops/capabilities.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
SCRIPT="$ROOT/ops/plugins/infra/host/bin/host-operator-hardware-post-boot-normalize"
FIRSTBOOT="$ROOT/ops/plugins/infra/host/bin/host-operator-hardware-firstboot-claim"
HANDOFF="$ROOT/ops/bindings/operator.hardware.bootstrap.handoff.contract.yaml"

fail() { echo "D450 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -x "$SCRIPT" ]] || fail "missing executable post-boot normalize script"
[[ -x "$FIRSTBOOT" ]] || fail "missing executable firstboot claim script"
[[ -f "$HANDOFF" ]] || fail "missing operator hardware bootstrap handoff contract"

python3 - "$CAPS" "$MANIFEST" "$SCRIPT" "$FIRSTBOOT" "$HANDOFF" <<'PY'
import sys
from pathlib import Path

import yaml

caps_path = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
script_path = Path(sys.argv[3])
firstboot_path = Path(sys.argv[4])
handoff_path = Path(sys.argv[5])


def fail(message: str) -> None:
    print(f"D450 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


caps = load_yaml(caps_path)
cap = (caps.get("capabilities") or {}).get("host.operator-hardware.post-boot.normalize")
if not isinstance(cap, dict):
    fail("host.operator-hardware.post-boot.normalize missing from ops/capabilities.yaml")
if cap.get("safety") != "mutating":
    fail("post-boot normalize must declare mutating safety")
if cap.get("script_path") != "./ops/plugins/infra/host/bin/host-operator-hardware-post-boot-normalize":
    fail("post-boot normalize script_path mismatch")
description = str(cap.get("description") or "")
for required in ["Stage 0", "No admission", "role", "placement", "watcher", "backup"]:
    if required not in description:
        fail(f"capability description must name boundary: {required}")

manifest = load_yaml(manifest_path)
plugins = manifest.get("plugins") or []
host = next((item for item in plugins if isinstance(item, dict) and item.get("name") == "host"), None)
if not isinstance(host, dict):
    fail("host plugin missing from manifest")
if "host.operator-hardware.post-boot.normalize" not in (host.get("capabilities") or []):
    fail("post-boot normalize capability missing from host plugin manifest")

text = script_path.read_text(encoding="utf-8")
required_phrases = [
    "Default mode is dry-run",
    "No admission, role, placement, watcher, or backup mutation",
    "host.operator-hardware.firstboot.claim",
    "post-boot-normalize-receipt",
]
for phrase in required_phrases:
    if phrase not in text:
        fail(f"script must preserve boundary phrase: {phrase}")

for forbidden in [
    "provision.operator-hardware.claim.admit",
    "node.admission.status --execute",
    "fleet.admission.classification.yaml",
    "role_promotion",
    "PVE authority",
]:
    if forbidden in text:
        fail(f"script contains forbidden authority promotion marker: {forbidden}")

firstboot_text = firstboot_path.read_text(encoding="utf-8")
for required in [
    "Stage 0 handoff object only",
    "No role or host assignment performed",
    "contract_ref: $contract_ref",
]:
    if required not in firstboot_text:
        fail(f"firstboot claim must preserve boundary phrase: {required}")
for forbidden in [
    "role_candidacy",
    "placement_truth",
    "watcher",
    "backup_admission_state",
    "backup_targets",
    "runtime_obligations",
    "admission_status",
]:
    if forbidden in firstboot_text:
        fail(f"firstboot claim contains forbidden authority field: {forbidden}")

handoff = load_yaml(handoff_path)
contract_text = handoff_path.read_text(encoding="utf-8")
for required in [
    "assign node roles",
    "assign host roles",
    "declare eligibility outcomes",
    "activate any machine",
    "Stage 0",
]:
    if required not in contract_text:
        fail(f"handoff contract must name Stage 0 boundary: {required}")
if handoff.get("scope") != "operator-hardware-bootstrap-handoff-contract":
    fail("handoff contract scope drifted")

print("D450 PASS: post-boot normalize and firstboot claim remain bounded Stage 0 evidence, not admission/role/placement/watcher/backup authority")
PY
