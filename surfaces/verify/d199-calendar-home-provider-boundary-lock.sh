#!/usr/bin/env bash
# TRIAGE: Enforce local calendar home provider boundary and keep Microsoft calendar writes blocked.
# D199: calendar home provider boundary lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CAPS="$ROOT/ops/capabilities.yaml"
HOME_CONTRACT="$ROOT/ops/bindings/calendar.home.contract.yaml"
SYNC_CONTRACT="$ROOT/ops/bindings/calendar.sync.contract.yaml"
PROVIDERS="$ROOT/ops/bindings/communications.providers.contract.yaml"
TERMINAL_ROLES="$ROOT/ops/bindings/terminal.role.contract.yaml"
WORKER_CATALOG="$ROOT/ops/bindings/terminal.worker.catalog.yaml"

fail() {
  echo "D199 FAIL: $*" >&2
  exit 1
}

for path in "$CAPS" "$HOME_CONTRACT" "$SYNC_CONTRACT" "$PROVIDERS" "$TERMINAL_ROLES" "$WORKER_CATALOG"; do
  [[ -f "$path" ]] || fail "missing required file: $path"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CAPS" "$HOME_CONTRACT" "$SYNC_CONTRACT" "$PROVIDERS" "$TERMINAL_ROLES" "$WORKER_CATALOG" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

caps_path = Path(sys.argv[1]).expanduser().resolve()
home_path = Path(sys.argv[2]).expanduser().resolve()
sync_path = Path(sys.argv[3]).expanduser().resolve()
providers_path = Path(sys.argv[4]).expanduser().resolve()
roles_path = Path(sys.argv[5]).expanduser().resolve()
workers_path = Path(sys.argv[6]).expanduser().resolve()


def load_yaml(path: Path):
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    if doc is None:
        return {}
    if not isinstance(doc, dict):
        raise ValueError(f"expected mapping root: {path}")
    return doc


try:
    caps = load_yaml(caps_path)
    home = load_yaml(home_path)
    sync = load_yaml(sync_path)
    providers = load_yaml(providers_path)
    roles = load_yaml(roles_path)
    workers = load_yaml(workers_path)
except Exception as exc:
    print(f"D199 FAIL: parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

home_section = home.get("home") if isinstance(home.get("home"), dict) else {}
if home_section.get("provider") != "communications-calendar":
    violations.append("calendar.home.contract home.provider must be communications-calendar")
if home_section.get("write_mode") != "local-only":
    violations.append("calendar.home.contract home.write_mode must be local-only")

sync_contracts = sync.get("sync_contracts") if isinstance(sync.get("sync_contracts"), dict) else {}
push_caps = sync_contracts.get("push_write_capabilities", [])
if not isinstance(push_caps, list):
    violations.append("calendar.sync.contract sync_contracts.push_write_capabilities must be list")
else:
    blocked = {"microsoft.calendar.create", "microsoft.calendar.update", "microsoft.calendar.rsvp"}
    for cap in push_caps:
        if str(cap) in blocked:
            violations.append(f"calendar.sync.contract push_write_capabilities contains blocked cap: {cap}")
    if push_caps:
        violations.append("calendar.sync.contract push_write_capabilities must remain empty")

capabilities = caps.get("capabilities") if isinstance(caps.get("capabilities"), dict) else {}
calendar_home_create = capabilities.get("calendar.home.event.create")
if not isinstance(calendar_home_create, dict):
    violations.append("capabilities missing calendar.home.event.create")
else:
    command = str(calendar_home_create.get("command", "")).strip()
    if command != "./ops/plugins/calendar/bin/calendar-home-event-create":
        violations.append(
            f"calendar.home.event.create command mismatch: expected ./ops/plugins/calendar/bin/calendar-home-event-create actual={command!r}"
        )
    if "microsoft" in command or "graph" in command:
        violations.append("calendar.home.event.create command must not target microsoft/graph")
    if calendar_home_create.get("safety") != "mutating":
        violations.append("calendar.home.event.create safety must be mutating")
    if calendar_home_create.get("approval") != "manual":
        violations.append("calendar.home.event.create approval must be manual")
    if calendar_home_create.get("domain") != "communications":
        violations.append("calendar.home.event.create domain must be communications")

# Any calendar.home mutating capability must not be exposed to non-control terminal roles/workers.
calendar_home_mutating: set[str] = set()
for cap_id, meta in capabilities.items():
    if not isinstance(meta, dict):
        continue
    if not str(cap_id).startswith("calendar.home."):
        continue
    if meta.get("safety") == "mutating":
        calendar_home_mutating.add(str(cap_id))

for role in roles.get("roles", []) or []:
    if not isinstance(role, dict):
        continue
    role_id = role.get("id", "<unknown-role>")
    role_type = role.get("type", "")
    for cap in role.get("capabilities", []) or []:
        cap_name = str(cap)
        if cap_name in calendar_home_mutating and role_type != "control-plane":
            violations.append(
                f"terminal.role.contract role {role_id} ({role_type}) exposes local calendar mutating capability {cap_name}"
            )

worker_map = workers.get("workers") if isinstance(workers.get("workers"), dict) else {}
for worker_id, worker in worker_map.items():
    if not isinstance(worker, dict):
        continue
    worker_type = worker.get("terminal_type", "")
    for cap in worker.get("capabilities_scoped", []) or []:
        cap_name = str(cap)
        if cap_name in calendar_home_mutating and worker_type != "control-plane":
            violations.append(
                f"terminal.worker.catalog worker {worker_id} ({worker_type}) exposes local calendar mutating capability {cap_name}"
            )

# Enforce communications routing never points automated writes back to Microsoft.
routing = (providers.get("routing") or {}).get("message_types", {})
if isinstance(routing, dict):
    for msg_type, route in routing.items():
        if not isinstance(route, dict):
            continue
        if route.get("email_provider") == "microsoft" or route.get("sms_provider") == "microsoft":
            violations.append(f"communications routing routes {msg_type} to microsoft provider")

ms_provider = (providers.get("providers") or {}).get("microsoft", {})
if isinstance(ms_provider, dict):
    if ms_provider.get("execution_mode") != "manual-only":
        violations.append("providers.microsoft.execution_mode must remain manual-only")

if violations:
    for item in violations:
        print(f"D199 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D199 PASS: calendar home provider boundary lock valid (local-only writes, microsoft write route blocked)")
PY
