#!/usr/bin/env bash
set -euo pipefail

# D442: Node Promotion Stage Truth
# Purpose: operator-owned hardware with a concrete role candidacy must expose a
# machine-readable promotion stage, and pre-materialized candidates must remain
# optional SSH targets so declared inventory cannot read as delivered node truth.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPERATOR_INVENTORY="$ROOT/ops/bindings/operator.hardware.inventory.yaml"
SSH_TARGETS="$ROOT/ops/bindings/ssh.targets.yaml"
LADDER_DOC="$ROOT/docs/governance/NODE_PROMOTION_LADDER.md"

fail() { echo "D442 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

[[ -f "$OPERATOR_INVENTORY" ]] || fail "missing operator hardware inventory: $OPERATOR_INVENTORY"
[[ -f "$SSH_TARGETS" ]] || fail "missing ssh targets: $SSH_TARGETS"
[[ -f "$LADDER_DOC" ]] || fail "missing node promotion ladder: $LADDER_DOC"

python3 - "$OPERATOR_INVENTORY" "$SSH_TARGETS" "$LADDER_DOC" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    print(f"D442 FAIL: missing dependency: {exc.name}", file=sys.stderr)
    raise SystemExit(1)

operator_inventory = Path(sys.argv[1])
ssh_targets = Path(sys.argv[2])
ladder_doc = Path(sys.argv[3])


def fail(message: str) -> None:
    print(f"D442 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        fail(f"invalid YAML object: {path}")
    return data


inventory = load_yaml(operator_inventory)
targets = load_yaml(ssh_targets)
ladder_text = ladder_doc.read_text(encoding="utf-8")

expected_stages = [
    "taxonomy",
    "contracted",
    "workload-backed",
    "candidate-backed",
    "bootstrap-joined",
    "materialized",
    "delivered",
]

for stage in expected_stages:
    if f"`{stage}`" not in ladder_text:
        fail(f"NODE_PROMOTION_LADDER.md missing stage `{stage}`")

declared_stages = inventory.get("promotion_stage_values")
if declared_stages != expected_stages:
    fail(
        "operator.hardware.inventory.yaml promotion_stage_values must mirror "
        "NODE_PROMOTION_LADDER.md canonical order"
    )

machines = inventory.get("machines")
if not isinstance(machines, list):
    fail("operator.hardware.inventory.yaml missing machines list")

target_rows = (targets.get("ssh") or {}).get("targets")
if not isinstance(target_rows, list):
    fail("ssh.targets.yaml missing ssh.targets list")

ssh_by_id = {
    row.get("id"): row
    for row in target_rows
    if isinstance(row, dict) and isinstance(row.get("id"), str)
}

stage_rank = {stage: idx for idx, stage in enumerate(expected_stages)}
materialized_rank = stage_rank["materialized"]

checked = 0
violations: list[str] = []

for machine in machines:
    if not isinstance(machine, dict):
        continue

    device_id = machine.get("device_id")
    if not isinstance(device_id, str) or not device_id:
        violations.append("machine row missing device_id")
        continue

    role_candidacy = machine.get("role_candidacy")
    if not isinstance(role_candidacy, list):
        violations.append(f"{device_id}: role_candidacy must be a list")
        continue

    candidacies = [str(value) for value in role_candidacy]
    has_role_candidacy = any(value != "none" for value in candidacies)

    if not has_role_candidacy:
        if machine.get("promotion_stage") == "delivered":
            violations.append(f"{device_id}: cannot be delivered with role_candidacy [none]")
        continue

    checked += 1
    stage = machine.get("promotion_stage")
    if stage not in stage_rank:
        violations.append(
            f"{device_id}: non-none role_candidacy requires valid promotion_stage "
            f"({expected_stages})"
        )
        continue

    ssh_row = ssh_by_id.get(device_id)
    if ssh_row is None:
        violations.append(f"{device_id}: role candidate missing ssh.targets.yaml row")
        continue

    optional = bool(ssh_row.get("optional", False))
    if stage_rank[stage] < materialized_rank and not optional:
        violations.append(
            f"{device_id}: promotion_stage {stage} is below materialized, "
            "so ssh.targets.yaml must keep optional: true"
        )

    if stage == "delivered" and optional:
        violations.append(
            f"{device_id}: delivered operator hardware cannot remain optional in ssh.targets.yaml"
        )

if violations:
    for violation in violations:
        print(f"D442 FAIL: {violation}", file=sys.stderr)
    raise SystemExit(1)

print(
    f"D442 PASS: {checked} operator hardware role candidate(s) carry "
    "machine-readable promotion stage and pre-materialized candidates remain optional"
)
PY
