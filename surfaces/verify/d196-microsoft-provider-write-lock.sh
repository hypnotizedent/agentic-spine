#!/usr/bin/env bash
# TRIAGE: Keep microsoft provider manual-only and remove microsoft mutating capability exposure from non-control terminals.
# D196: microsoft provider write lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CAPS="$ROOT/ops/capabilities.yaml"
PROVIDERS="$ROOT/ops/bindings/communications.providers.contract.yaml"
CAL_SYNC="$ROOT/ops/bindings/calendar.sync.contract.yaml"
TERMINAL_ROLES="$ROOT/ops/bindings/terminal.role.contract.yaml"
WORKER_CATALOG="$ROOT/ops/bindings/terminal.worker.catalog.yaml"

fail() {
  echo "D196 FAIL: $*" >&2
  exit 1
}

for file in "$CAPS" "$PROVIDERS" "$CAL_SYNC" "$TERMINAL_ROLES" "$WORKER_CATALOG"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CAPS" "$PROVIDERS" "$CAL_SYNC" "$TERMINAL_ROLES" "$WORKER_CATALOG" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

caps_path = Path(sys.argv[1]).expanduser().resolve()
providers_path = Path(sys.argv[2]).expanduser().resolve()
calendar_path = Path(sys.argv[3]).expanduser().resolve()
roles_path = Path(sys.argv[4]).expanduser().resolve()
workers_path = Path(sys.argv[5]).expanduser().resolve()


def load_yaml(path: Path):
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    if doc is None:
        return {}
    if not isinstance(doc, dict):
        raise ValueError(f"expected mapping root: {path}")
    return doc


try:
    caps_doc = load_yaml(caps_path)
    providers_doc = load_yaml(providers_path)
    calendar_doc = load_yaml(calendar_path)
    roles_doc = load_yaml(roles_path)
    workers_doc = load_yaml(workers_path)
except Exception as exc:
    print(f"D196 FAIL: parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

# 1) Provider contract must keep Microsoft in manual-only mode.
provider_microsoft = providers_doc.get("providers", {}).get("microsoft")
if not isinstance(provider_microsoft, dict):
    violations.append("communications.providers.contract missing providers.microsoft mapping")
else:
    mode = provider_microsoft.get("execution_mode")
    if mode != "manual-only":
        violations.append(f"providers.microsoft.execution_mode must be manual-only (actual={mode!r})")

# 2) No customer message type routes to Microsoft provider.
routing = providers_doc.get("routing", {}).get("message_types", {})
if isinstance(routing, dict):
    for message_type, route in routing.items():
        if not isinstance(route, dict):
            continue
        if route.get("email_provider") == "microsoft" or route.get("sms_provider") == "microsoft":
            violations.append(f"routing.message_types.{message_type} routes to microsoft provider")

# 3) No automated calendar provider writes in sync contract.
push_caps = calendar_doc.get("sync_contracts", {}).get("push_write_capabilities", [])
if isinstance(push_caps, list):
    for cap in push_caps:
        cap_name = str(cap).strip()
        if cap_name.startswith("microsoft.calendar."):
            violations.append(f"calendar sync push_write_capabilities contains microsoft write cap: {cap_name}")

# 4) Microsoft write capabilities must stay manual approval.
all_caps = caps_doc.get("capabilities", {})
if not isinstance(all_caps, dict):
    violations.append("capabilities registry missing .capabilities mapping")
    all_caps = {}

microsoft_mutating: set[str] = set()
for cap_id, meta in all_caps.items():
    if not isinstance(meta, dict):
        continue
    if not str(cap_id).startswith("microsoft."):
        continue
    safety = meta.get("safety")
    approval = meta.get("approval")
    if safety == "mutating":
        microsoft_mutating.add(str(cap_id))
        if approval != "manual":
            violations.append(f"{cap_id} must remain manual approval (actual={approval!r})")

# 5) Non-control terminal roles must not expose Microsoft mutating caps.
for role in roles_doc.get("roles", []) or []:
    if not isinstance(role, dict):
        continue
    role_id = role.get("id", "<unknown-role>")
    role_type = role.get("type", "")
    for cap in role.get("capabilities", []) or []:
        cap_name = str(cap)
        if cap_name in microsoft_mutating and role_type != "control-plane":
            violations.append(
                f"terminal.role.contract role {role_id} ({role_type}) exposes microsoft mutating capability {cap_name}"
            )

workers = workers_doc.get("workers", {})
if isinstance(workers, dict):
    for worker_id, worker in workers.items():
        if not isinstance(worker, dict):
            continue
        worker_type = worker.get("terminal_type", "")
        for cap in worker.get("capabilities_scoped", []) or []:
            cap_name = str(cap)
            if cap_name in microsoft_mutating and worker_type != "control-plane":
                violations.append(
                    f"terminal.worker.catalog worker {worker_id} ({worker_type}) exposes microsoft mutating capability {cap_name}"
                )

if violations:
    for item in violations:
        print(f"D196 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D196 PASS: microsoft provider write lock valid (no automated routes, no non-control write exposure)")
PY
