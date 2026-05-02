#!/usr/bin/env bash
set -euo pipefail

# D459: Operator Linux Control Baseline Readback Lock
# Purpose: make terminal operability drift visible without widening admission,
# recovery, role, root SSH, or lab/k3s authority.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTROL_BASELINE="$ROOT/ops/plugins/infra/bin/node-control-baseline-status"
CAPABILITIES="$ROOT/ops/capabilities.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
GATE_REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
GATE_TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"

fail() {
  echo "D459 FAIL: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"

[[ -x "$CONTROL_BASELINE" ]] || fail "missing executable node-control-baseline-status"
[[ -f "$CAPABILITIES" ]] || fail "missing ops/capabilities.yaml"
[[ -f "$MANIFEST" ]] || fail "missing ops/plugins/MANIFEST.yaml"
[[ -f "$GATE_REGISTRY" ]] || fail "missing gate.registry.yaml"
[[ -f "$GATE_TOPOLOGY" ]] || fail "missing gate.execution.topology.yaml"

bash -n "$CONTROL_BASELINE"

tmp_self_check="$(mktemp)"
trap 'rm -f "$tmp_self_check"' EXIT

SPINE_ROOT="$ROOT" "$CONTROL_BASELINE" --self-check --json >"$tmp_self_check"
jq -e '
  .capability == "node.control-baseline.status"
  and .status == "ok"
  and .boundary.admission_authority == "node.admission.status"
  and .boundary.recovery_authority == "node.recovery.status"
  and .boundary.mutation == "none"
' "$tmp_self_check" >/dev/null || fail "self-check must prove read-only admission/recovery boundary"

python3 - "$ROOT" "$CONTROL_BASELINE" "$CAPABILITIES" "$MANIFEST" "$GATE_REGISTRY" "$GATE_TOPOLOGY" <<'PY'
import sys
from pathlib import Path

import yaml


def fail(message: str) -> None:
    print(f"D459 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


root, script_path, caps_path, manifest_path, registry_path, topology_path = map(Path, sys.argv[1:])


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


script = script_path.read_text(encoding="utf-8")
caps = load_yaml(caps_path)
manifest = load_yaml(manifest_path)
registry = load_yaml(registry_path)
topology = load_yaml(topology_path)

capability = (caps.get("capabilities") or {}).get("node.control-baseline.status")
if not capability:
    fail("node.control-baseline.status must be registered in ops/capabilities.yaml")
if capability.get("safety") != "read-only":
    fail("node.control-baseline.status must be read-only")
if capability.get("layer") != "L2_shared_infrastructure":
    fail("node.control-baseline.status must remain L2 shared infrastructure")
if capability.get("script_path") != "./ops/plugins/infra/bin/node-control-baseline-status":
    fail("node.control-baseline.status must point at node-control-baseline-status")

manifest_text = manifest_path.read_text(encoding="utf-8")
for needle in ["bin/node-control-baseline-status", "node.control-baseline.status"]:
    if needle not in manifest_text:
        fail(f"plugin manifest must include {needle}")

for required in [
    "sudo -n true",
    "NumberOfPasswordPrompts=0",
    "node.admission.status",
    "node.recovery.status",
    "lab_or_k3s_facts",
    "generic_baseline_requirement:\"not_required\"",
]:
    if required not in script:
        fail(f"control baseline script missing boundary/probe phrase: {required!r}")

for forbidden in [
    "printf '%q'",
    "/tmp/node-control-baseline",
    "sudo -S",
    "passwd ",
    "usermod ",
    "tee /etc/sudoers",
    "PermitRootLogin yes",
    "kubectl ",
    "systemctl status k3s",
    "k3s kubectl",
]:
    if forbidden in script:
        fail(f"control baseline script must not contain mutating/lab-specific phrase: {forbidden!r}")

entries = registry.get("gates") if isinstance(registry.get("gates"), list) else None
if entries is None:
    # This registry is a top-level list after the metadata mapping.
    entries = [item for item in yaml.safe_load_all(registry_path.read_text(encoding="utf-8")) if isinstance(item, list)]
    entries = entries[0] if entries else []
if not entries:
    # PyYAML loads the whole file as a mapping with list-like tail unavailable,
    # so use text checks for this legacy registry shape.
    registry_text = registry_path.read_text(encoding="utf-8")
    for needle in [
        "- id: D459",
        "operator-linux-control-baseline-readback-lock",
        "node.control-baseline.status",
        "must not be inferred from admission",
    ]:
        if needle not in registry_text:
            fail(f"gate registry missing {needle!r}")

if "D1-D459" not in str(registry.get("description") or ""):
    fail("gate registry description must name current D range through D459")
counts = registry.get("gate_count") or {}
if counts.get("total") != 93 or counts.get("active") != 76 or counts.get("active_blocking") != 75:
    fail("gate_count must include D459 active blocking gate")

core_ids = ((topology.get("core_mode") or {}).get("core_gate_ids") or [])
if len(core_ids) > int((topology.get("core_mode") or {}).get("core_count_limit") or 0):
    fail("core gate ids exceed core_count_limit")

print("D459 PASS: operator Linux control-baseline readback is read-only, non-promoting, and visible before mutation")
PY
