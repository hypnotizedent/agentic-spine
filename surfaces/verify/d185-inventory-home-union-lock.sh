#!/usr/bin/env bash
# TRIAGE: complete required inventory homes (owner/site/location/evidence/runbook + conditional runtime homes) before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
PARTS="$ROOT/ops/bindings/hardware.parts.inventory.yaml"
CATALOG="$ROOT/ops/bindings/business.inventory.catalog.yaml"
INTAKE_DIR="$ROOT/mailroom/outbox/intake"
AGENTS="$ROOT/ops/bindings/agents.registry.yaml"

fail() {
  echo "D185 FAIL: $*" >&2
  exit 1
}

[[ -f "$PARTS" ]] || fail "missing hardware parts binding: $PARTS"
[[ -f "$CATALOG" ]] || fail "missing business inventory binding: $CATALOG"
[[ -f "$AGENTS" ]] || fail "missing agents binding: $AGENTS"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$ROOT" "$PARTS" "$CATALOG" "$INTAKE_DIR" "$AGENTS" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

root = Path(sys.argv[1]).expanduser().resolve()
parts_path = Path(sys.argv[2]).expanduser().resolve()
catalog_path = Path(sys.argv[3]).expanduser().resolve()
intake_dir = Path(sys.argv[4]).expanduser().resolve()
agents_path = Path(sys.argv[5]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


try:
    parts_doc = load_yaml(parts_path)
    catalog_doc = load_yaml(catalog_path)
    agents_doc = load_yaml(agents_path)
except Exception as exc:
    print(f"D185 FAIL: unable to parse required bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

agent_ids = {
    str(row.get("id", "")).strip()
    for row in (agents_doc.get("agents") or [])
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

required_home_keys = ["owner_agent", "site", "location_id", "evidence_refs", "runbook_path"]
runtime_home_keys = ["infisical_namespace", "vaultwarden_item", "gitea_repo", "observability_probe"]
allow_empty_evidence_for = {"draft", "proposed"}
violations: list[tuple[str, str]] = []


def check_row(row: dict, source: Path, id_key: str = "id"):
    row_id = str(row.get(id_key, "")).strip() or "unknown"
    for key in required_home_keys:
        if key not in row:
            violations.append((str(source), f"{row_id}: missing required home field: {key}"))
            continue
        value = row.get(key)
        if key == "evidence_refs":
            if not isinstance(value, list):
                violations.append((str(source), f"{row_id}: evidence_refs must be a list"))
                continue
            status = str(row.get("lifecycle_status", row.get("status", ""))).strip().lower()
            if status not in allow_empty_evidence_for and len(value) == 0:
                violations.append((str(source), f"{row_id}: evidence_refs must be non-empty for status {status or 'unknown'}"))
            continue
        if not str(value or "").strip():
            violations.append((str(source), f"{row_id}: {key} cannot be empty"))

    owner_agent = str(row.get("owner_agent", "")).strip()
    if owner_agent and owner_agent not in agent_ids:
        violations.append((str(source), f"{row_id}: owner_agent not found in agents.registry.yaml: {owner_agent}"))

    runbook_path = str(row.get("runbook_path", "")).strip()
    if runbook_path:
      target = Path(runbook_path) if runbook_path.startswith("/") else (root / runbook_path)
      if not target.exists():
          violations.append((str(source), f"{row_id}: runbook_path does not exist: {runbook_path}"))

    touches_runtime = bool(row.get("touches_runtime", False))
    runtime_homes = row.get("runtime_homes")
    if not isinstance(runtime_homes, dict):
        violations.append((str(source), f"{row_id}: runtime_homes must be a mapping"))
        runtime_homes = {}

    if touches_runtime:
        for key in runtime_home_keys:
            if not str(runtime_homes.get(key, "")).strip():
                violations.append((str(source), f"{row_id}: touches_runtime=true requires runtime_homes.{key}"))


parts_rows = parts_doc.get("parts") if isinstance(parts_doc.get("parts"), list) else []
materials_rows = catalog_doc.get("materials") if isinstance(catalog_doc.get("materials"), list) else []

for row in parts_rows:
    if isinstance(row, dict):
        check_row(row, parts_path)

for row in materials_rows:
    if isinstance(row, dict):
        check_row(row, catalog_path)

if intake_dir.is_dir():
    for path in sorted(intake_dir.glob("ITK-*.yaml")):
        try:
            doc = load_yaml(path)
        except Exception as exc:
            violations.append((str(path), f"invalid YAML: {exc}"))
            continue
        check_row(doc, path, id_key="intake_id")

if violations:
    for path, msg in violations:
        print(f"D185 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D185 FAIL: inventory home union violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D185 PASS: inventory home union lock valid")
PY
