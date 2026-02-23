#!/usr/bin/env bash
# TRIAGE: register missing service homes/agent/deploy stack fields in service.onboarding.contract.yaml before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/service.onboarding.contract.yaml"
AGENTS_REGISTRY="$ROOT/ops/bindings/agents.registry.yaml"
WORKBENCH_STACK_MAP="${SPINE_WORKBENCH:-$HOME/code/workbench}/scripts/root/deploy/stack-map.sh"

fail() {
  echo "D174 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing binding: $CONTRACT"
[[ -f "$AGENTS_REGISTRY" ]] || fail "missing binding: $AGENTS_REGISTRY"
[[ -f "$WORKBENCH_STACK_MAP" ]] || fail "missing workbench stack map: $WORKBENCH_STACK_MAP"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CONTRACT" "$AGENTS_REGISTRY" "$WORKBENCH_STACK_MAP" <<'PY'
from __future__ import annotations

from pathlib import Path
import re
import sys

import yaml

contract_path = Path(sys.argv[1]).expanduser().resolve()
agents_path = Path(sys.argv[2]).expanduser().resolve()
stack_map_path = Path(sys.argv[3]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


errors: list[str] = []
violations: list[tuple[str, str]] = []

try:
    contract = load_yaml(contract_path)
    agents_registry = load_yaml(agents_path)
except Exception as exc:
    print(f"D174 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

for required in ("status", "owner", "last_verified", "scope", "required_fields", "naming_rules", "services"):
    if required not in contract:
        errors.append(f"service.onboarding contract missing required field: {required}")

required_fields = [str(x).strip() for x in (contract.get("required_fields") or []) if str(x).strip()]
if not required_fields:
    errors.append("required_fields must contain at least one field")

services = contract.get("services") if isinstance(contract.get("services"), list) else []
if not services:
    errors.append("services[] must contain at least one service entry")

rules = contract.get("naming_rules") if isinstance(contract.get("naming_rules"), dict) else {}
service_id_regex = re.compile(str(rules.get("service_id_regex", r"^[a-z0-9][a-z0-9-]*$")))
repo_slug_regex = re.compile(str(rules.get("gitea_repo_slug_regex", r"^[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*$")))
infisical_prefix = str(rules.get("infisical_namespace_prefix", "/spine/")).strip()
workbench_home_prefix = str(rules.get("workbench_home_prefix", "agents/")).strip()
runbook_path_prefix = str(rules.get("runbook_path_prefix", "docs/")).strip()

agents = agents_registry.get("agents") if isinstance(agents_registry.get("agents"), list) else []
agent_ids = {
    str(row.get("id", "")).strip()
    for row in agents
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

stack_map_text = stack_map_path.read_text(encoding="utf-8", errors="ignore")
stack_ids = set(re.findall(r"^DEPLOY_STACK_METHOD\[([A-Za-z0-9._-]+)\]=", stack_map_text, flags=re.MULTILINE))
if not stack_ids:
    errors.append("unable to resolve deploy stack IDs from workbench stack-map.sh")

active_count = 0
for row in services:
    if not isinstance(row, dict):
        errors.append("services[] entries must be mappings")
        continue

    service_id = str(row.get("id", "")).strip() or "unknown-service"
    status = str(row.get("status", "")).strip().lower()
    if status != "active":
        continue
    active_count += 1

    for field in required_fields:
        value = row.get(field)
        if not str(value or "").strip():
            violations.append((service_id, f"missing required field: {field}"))

    if service_id and not service_id_regex.match(service_id):
        violations.append((service_id, "id does not match naming_rules.service_id_regex"))

    infisical_namespace = str(row.get("infisical_namespace", "")).strip()
    if infisical_namespace and infisical_prefix and not infisical_namespace.startswith(infisical_prefix):
        violations.append((service_id, f"infisical_namespace must start with {infisical_prefix}"))

    repo_slug = str(row.get("gitea_repo_slug", "")).strip()
    if repo_slug and not repo_slug_regex.match(repo_slug):
        violations.append((service_id, "gitea_repo_slug does not match naming rule"))

    workbench_home_path = str(row.get("workbench_home_path", "")).strip()
    if workbench_home_path and workbench_home_prefix and not workbench_home_path.startswith(workbench_home_prefix):
        violations.append((service_id, f"workbench_home_path must start with {workbench_home_prefix}"))

    runbook_path = str(row.get("runbook_path", "")).strip()
    if runbook_path and runbook_path_prefix and not runbook_path.startswith(runbook_path_prefix):
        violations.append((service_id, f"runbook_path must start with {runbook_path_prefix}"))

    owning_agent_id = str(row.get("owning_agent_id", "")).strip()
    if owning_agent_id and owning_agent_id not in agent_ids:
        violations.append((service_id, f"owning_agent_id not found in agents.registry.yaml: {owning_agent_id}"))

    deploy_stack_id = str(row.get("deploy_stack_id", "")).strip()
    if deploy_stack_id and deploy_stack_id not in stack_ids:
        violations.append((service_id, f"deploy_stack_id not found in workbench stack-map: {deploy_stack_id}"))

if active_count == 0:
    errors.append("services[] must define at least one active service")

if errors:
    for err in errors:
        print(f"D174 FAIL: contract :: {err}", file=sys.stderr)
    raise SystemExit(1)

if violations:
    for service_id, msg in violations:
        print(f"D174 FAIL: services/{service_id} :: {msg}", file=sys.stderr)
    print(f"D174 FAIL: service onboarding parity violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D174 PASS: service onboarding parity valid")
PY
