#!/usr/bin/env bash
# TRIAGE: enforce external provider read-only boundary and non-control write exposure lock.
# D203: external-provider-readonly-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CAPS="$ROOT/ops/capabilities.yaml"
ROLES="$ROOT/ops/bindings/terminal.role.contract.yaml"
WORKERS="$ROOT/ops/bindings/terminal.worker.catalog.yaml"
CONTRACT="$ROOT/ops/bindings/calendar.external.providers.contract.yaml"
SYNC_CONTRACT="$ROOT/ops/bindings/calendar.sync.contract.yaml"

fail() {
  echo "D203 FAIL: $*" >&2
  exit 1
}

for path in "$CAPS" "$ROLES" "$WORKERS" "$CONTRACT" "$SYNC_CONTRACT"; do
  [[ -f "$path" ]] || fail "missing required file: $path"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CAPS" "$ROLES" "$WORKERS" "$CONTRACT" "$SYNC_CONTRACT" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

caps_path = Path(sys.argv[1]).expanduser().resolve()
roles_path = Path(sys.argv[2]).expanduser().resolve()
workers_path = Path(sys.argv[3]).expanduser().resolve()
contract_path = Path(sys.argv[4]).expanduser().resolve()
sync_path = Path(sys.argv[5]).expanduser().resolve()


def load_yaml(path: Path):
    payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(payload, dict):
        raise ValueError(f"YAML root must be mapping: {path}")
    return payload


def is_provider_write_cap(capability_id: str, meta: dict) -> bool:
    cap = capability_id.strip()
    safety = str(meta.get("safety", "")).strip().lower()
    write_tokens = (".create", ".update", ".delete", ".write", ".send", ".rsvp")

    if cap.startswith("calendar.icloud.") or cap.startswith("calendar.google."):
        if safety in {"mutating", "destructive"}:
            return True
        return any(token in cap for token in write_tokens)

    if cap.startswith("microsoft.mail.") or cap.startswith("microsoft.calendar."):
        if safety in {"mutating", "destructive"}:
            return True
        return any(token in cap for token in write_tokens)

    return False


try:
    caps = load_yaml(caps_path)
    roles = load_yaml(roles_path)
    workers = load_yaml(workers_path)
    contract = load_yaml(contract_path)
    sync = load_yaml(sync_path)
except Exception as exc:
    print(f"D203 FAIL: parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

provider_mode = contract.get("provider_mode") if isinstance(contract.get("provider_mode"), dict) else {}
if provider_mode.get("external_ingest_mode") != "read-only":
    violations.append("provider_mode.external_ingest_mode must be read-only")
if provider_mode.get("writeback_enabled") is not False:
    violations.append("provider_mode.writeback_enabled must be false")

providers = contract.get("providers") if isinstance(contract.get("providers"), dict) else {}
for provider in ("icloud", "google"):
    block = providers.get(provider)
    if not isinstance(block, dict):
        violations.append(f"providers.{provider} block missing")
        continue
    if block.get("mode") != "read-only":
        violations.append(f"providers.{provider}.mode must be read-only")

capabilities = caps.get("capabilities") if isinstance(caps.get("capabilities"), dict) else {}
provider_write_caps: set[str] = set()
for cap_id, meta in capabilities.items():
    if not isinstance(meta, dict):
        continue
    cap = str(cap_id)
    if is_provider_write_cap(cap, meta):
        provider_write_caps.add(cap)

for cap in sorted(provider_write_caps):
    if cap.startswith("calendar.icloud.") or cap.startswith("calendar.google."):
        violations.append(f"external provider write capability is not allowed: {cap}")

for role in roles.get("roles", []) or []:
    if not isinstance(role, dict):
        continue
    role_id = role.get("id", "<unknown-role>")
    role_type = str(role.get("type", "")).strip()
    for cap in role.get("capabilities", []) or []:
        cap_name = str(cap).strip()
        if cap_name in provider_write_caps and role_type != "control-plane":
            violations.append(
                f"non-control role exposure: {role_id} ({role_type}) exposes write capability {cap_name}"
            )

worker_map = workers.get("workers") if isinstance(workers.get("workers"), dict) else {}
for worker_id, worker in worker_map.items():
    if not isinstance(worker, dict):
        continue
    worker_type = str(worker.get("terminal_type", "")).strip()
    for cap in worker.get("capabilities_scoped", []) or []:
        cap_name = str(cap).strip()
        if cap_name in provider_write_caps and worker_type != "control-plane":
            violations.append(
                f"non-control worker exposure: {worker_id} ({worker_type}) exposes write capability {cap_name}"
            )

sync_caps = (
    ((sync.get("sync_contracts") or {}).get("push_write_capabilities", []))
    if isinstance(sync.get("sync_contracts"), dict)
    else []
)
if not isinstance(sync_caps, list):
    violations.append("calendar.sync.contract sync_contracts.push_write_capabilities must be list")
else:
    blocked = {"microsoft.calendar.create", "microsoft.calendar.update", "microsoft.calendar.rsvp"}
    found = sorted(str(cap) for cap in sync_caps if str(cap) in blocked)
    if found:
        violations.append(f"calendar.sync.contract contains blocked Microsoft writes: {found}")

if violations:
    for item in violations:
        print(f"D203 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D203 PASS: external provider readonly lock enforced (no non-control write exposure)")
PY
