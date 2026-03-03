#!/usr/bin/env bash
# TRIAGE: Fix missing intake/master/projection links by updating intake.lifecycle.contract.yaml, master.inventory.registry.yaml, and domain.projection.contract.yaml.
set -euo pipefail

ROOT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${SPINE_ROOT:-$ROOT_DEFAULT}"
if [[ ! -f "$ROOT/ops/bindings/intake.lifecycle.contract.yaml" && -f "$ROOT_DEFAULT/ops/bindings/intake.lifecycle.contract.yaml" ]]; then
  ROOT="$ROOT_DEFAULT"
fi
LIFECYCLE="$ROOT/ops/bindings/intake.lifecycle.contract.yaml"
MASTER="$ROOT/ops/bindings/master.inventory.registry.yaml"
PROJECTION="$ROOT/ops/bindings/domain.projection.contract.yaml"
TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"

fail() {
  echo "D338 FAIL: $*" >&2
  exit 1
}

for file in "$LIFECYCLE" "$MASTER" "$PROJECTION" "$TOPOLOGY"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$ROOT" "$LIFECYCLE" "$MASTER" "$PROJECTION" "$TOPOLOGY" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

root = Path(sys.argv[1]).expanduser().resolve()
lifecycle_path = Path(sys.argv[2]).expanduser().resolve()
master_path = Path(sys.argv[3]).expanduser().resolve()
projection_path = Path(sys.argv[4]).expanduser().resolve()
topology_path = Path(sys.argv[5]).expanduser().resolve()


def load_yaml(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            doc = yaml.safe_load(handle) or {}
    except Exception as exc:  # pragma: no cover - defensive
        raise ValueError(f"{path}: invalid YAML ({exc})") from exc
    if not isinstance(doc, dict):
        raise ValueError(f"{path}: YAML root must be a mapping")
    return doc


def as_list(value) -> list:
    return value if isinstance(value, list) else []


def as_dict(value) -> dict:
    return value if isinstance(value, dict) else {}


violations: list[str] = []

try:
    lifecycle = load_yaml(lifecycle_path)
    master = load_yaml(master_path)
    projection = load_yaml(projection_path)
    topology = load_yaml(topology_path)
except ValueError as exc:
    print(f"D338 FAIL: {exc}", file=sys.stderr)
    raise SystemExit(1)

required_order = as_list(as_dict(lifecycle.get("chain")).get("required_order"))
if required_order != ["intake", "master_registry", "domain_projection"]:
    violations.append(
        "chain.required_order must be exactly ['intake', 'master_registry', 'domain_projection']"
    )

covered_domains = set(as_list(as_dict(lifecycle.get("domain_coverage")).get("applies_to_domain_ids")))
topology_domains = {
    str(as_dict(row).get("domain_id", "")).strip()
    for row in as_list(topology.get("domain_metadata"))
    if isinstance(row, dict)
}
topology_domains.discard("")
if covered_domains != topology_domains:
    missing = sorted(topology_domains - covered_domains)
    extra = sorted(covered_domains - topology_domains)
    if missing:
        violations.append(f"domain coverage missing topology domains: {missing}")
    if extra:
        violations.append(f"domain coverage has unknown domains: {extra}")

rows = as_list(master.get("rows"))
if not rows:
    violations.append("master.inventory.registry rows[] must not be empty")

projection_entries = as_list(projection.get("projections"))
projection_ids: dict[str, dict] = {}
for entry in projection_entries:
    if not isinstance(entry, dict):
        continue
    proj_id = str(entry.get("id", "")).strip()
    if not proj_id:
        violations.append("projection entry missing id")
        continue
    if proj_id in projection_ids:
        violations.append(f"duplicate projection id: {proj_id}")
        continue
    projection_ids[proj_id] = entry

row_ids: set[str] = set()
for row in rows:
    if not isinstance(row, dict):
        violations.append("master row must be a mapping")
        continue
    row_id = str(row.get("id", "")).strip()
    if not row_id:
        violations.append("master row missing id")
        continue
    if row_id in row_ids:
        violations.append(f"duplicate master row id: {row_id}")
        continue
    row_ids.add(row_id)

    domain_id = str(row.get("domain_id", "")).strip()
    if not domain_id:
        violations.append(f"{row_id}: missing domain_id")
    elif domain_id not in covered_domains:
        violations.append(f"{row_id}: domain_id '{domain_id}' not in lifecycle domain coverage")

    authority = as_dict(row.get("authority"))
    authority_path = str(authority.get("path", "")).strip()
    if not authority_path:
        violations.append(f"{row_id}: authority.path missing")
    elif not (root / authority_path).exists():
        violations.append(f"{row_id}: authority.path does not exist: {authority_path}")

    intake_lineage = as_dict(row.get("intake_lineage"))
    envelope_ref = str(intake_lineage.get("envelope_schema_ref", "")).strip()
    if envelope_ref != "ops/bindings/intake.envelope.schema.yaml":
        violations.append(
            f"{row_id}: intake_lineage.envelope_schema_ref must be ops/bindings/intake.envelope.schema.yaml"
        )
    accepted_intake_refs = as_list(intake_lineage.get("accepted_intake_refs"))
    if not accepted_intake_refs:
        violations.append(f"{row_id}: intake_lineage.accepted_intake_refs must be non-empty")

    projection_refs = as_list(row.get("projection_refs"))
    if not projection_refs:
        violations.append(f"{row_id}: projection_refs must be non-empty")
    for proj_ref in projection_refs:
        proj_id = str(proj_ref).strip()
        if not proj_id:
            violations.append(f"{row_id}: projection_refs contains empty id")
            continue
        proj_entry = projection_ids.get(proj_id)
        if not proj_entry:
            violations.append(f"{row_id}: projection ref not found in projection contract: {proj_id}")
            continue
        sources = {str(v).strip() for v in as_list(proj_entry.get("source_master_rows")) if str(v).strip()}
        if row_id not in sources:
            violations.append(f"{row_id}: projection {proj_id} missing source_master_rows link back to row")

for proj_id, entry in projection_ids.items():
    output_path = str(entry.get("output_path", "")).strip()
    if not output_path:
        violations.append(f"{proj_id}: output_path missing")
    elif not (root / output_path).exists():
        violations.append(f"{proj_id}: output_path does not exist: {output_path}")

    generator = str(entry.get("generator_capability", "")).strip()
    if not generator:
        violations.append(f"{proj_id}: generator_capability missing")

    sources = {str(v).strip() for v in as_list(entry.get("source_master_rows")) if str(v).strip()}
    if not sources:
        violations.append(f"{proj_id}: source_master_rows must be non-empty")
    for source_id in sources:
        if source_id not in row_ids:
            violations.append(f"{proj_id}: source_master_rows references unknown row id: {source_id}")

if violations:
    for item in violations:
        print(f"D338 FAIL: {item}", file=sys.stderr)
    print(f"D338 FAIL: lineage completeness violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(
    "D338 PASS: intake->master->projection lineage complete "
    f"(domains={len(covered_domains)} rows={len(row_ids)} projections={len(projection_ids)})"
)
PY
