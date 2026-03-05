#!/usr/bin/env bash
# TRIAGE: Keep local calendar home contract in parity with workbench communications-calendar runtime mapping.
# D198: calendar home runtime lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-/Users/ronnyworks/code/workbench}"
HOME_CONTRACT="$ROOT/ops/bindings/calendar.home.contract.yaml"
SYNC_CONTRACT="$ROOT/ops/bindings/calendar.sync.contract.yaml"
STACK_MAP="$WORKBENCH_ROOT/scripts/root/deploy/stack-map.sh"
STACK_SOURCE="$WORKBENCH_ROOT/infra/compose/communications-stack/calendar/docker-compose.yml"

fail() {
  echo "D198 FAIL: $*" >&2
  exit 1
}

[[ -f "$HOME_CONTRACT" ]] || fail "missing calendar home contract: $HOME_CONTRACT"
[[ -f "$SYNC_CONTRACT" ]] || fail "missing calendar sync contract: $SYNC_CONTRACT"
[[ -f "$STACK_MAP" ]] || fail "missing workbench stack map: $STACK_MAP"
[[ -f "$STACK_SOURCE" ]] || fail "missing workbench stack source compose file: $STACK_SOURCE"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$HOME_CONTRACT" "$SYNC_CONTRACT" "$STACK_MAP" "$STACK_SOURCE" <<'PY'
from __future__ import annotations

from pathlib import Path
import re
import sys

import yaml

home_contract = Path(sys.argv[1]).expanduser().resolve()
sync_contract = Path(sys.argv[2]).expanduser().resolve()
stack_map = Path(sys.argv[3]).expanduser().resolve()
stack_source = Path(sys.argv[4]).expanduser().resolve()


def load_yaml(path: Path):
    payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(payload, dict):
        raise ValueError(f"YAML root must be a mapping: {path}")
    return payload


def parse_stack_map(path: Path, stack_id: str) -> dict[str, str]:
    out: dict[str, str] = {}
    lookup = {
        "METHOD": "method",
        "HOST": "host",
        "PATH": "path",
        "COMPOSE_FILE": "compose_file",
        "ENV_FILE": "env_file",
    }
    pattern = re.compile(r'^DEPLOY_STACK_([A-Z_]+)\[' + re.escape(stack_id) + r'\]="([^"]*)"$')
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = pattern.match(raw.strip())
        if not m:
            continue
        key = lookup.get(m.group(1), "")
        if key:
            out[key] = m.group(2)
    return out


violations: list[str] = []

try:
    home = load_yaml(home_contract)
    sync = load_yaml(sync_contract)
except Exception as exc:
    print(f"D198 FAIL: parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

home_section = home.get("home") if isinstance(home.get("home"), dict) else {}
endpoint = home_section.get("endpoint") if isinstance(home_section.get("endpoint"), dict) else {}
local_store = (
    home_section.get("local_writable_store")
    if isinstance(home_section.get("local_writable_store"), dict)
    else {}
)

if home_section.get("provider") != "communications-calendar":
    violations.append("home.provider must be communications-calendar")
if home_section.get("host") != "communications-stack":
    violations.append("home.host must be communications-stack")
if home_section.get("stack_id") != "communications-calendar":
    violations.append("home.stack_id must be communications-calendar")
if home_section.get("write_mode") != "local-only":
    violations.append("home.write_mode must be local-only")
if home_section.get("remote_stack_path") != "/opt/stacks/communications-stack/calendar":
    violations.append("home.remote_stack_path must be /opt/stacks/communications-stack/calendar")
if not str(endpoint.get("base_url", "")).strip():
    violations.append("home.endpoint.base_url is required")
if not str(endpoint.get("calendar_collection", "")).strip():
    violations.append("home.endpoint.calendar_collection is required")

sync_home = sync.get("local_calendar_home") if isinstance(sync.get("local_calendar_home"), dict) else {}
if sync_home.get("contract_ref") != "ops/bindings/calendar.home.contract.yaml":
    violations.append("calendar.sync.contract local_calendar_home.contract_ref mismatch")
if sync_home.get("provider") != "communications-calendar":
    violations.append("calendar.sync.contract local_calendar_home.provider mismatch")
if sync_home.get("write_mode") != "local-only":
    violations.append("calendar.sync.contract local_calendar_home.write_mode must be local-only")

sync_local_path = str((sync.get("local_calendar_store") or {}).get("path", "")).strip()
home_local_path = str(local_store.get("path", "")).strip()
if not home_local_path:
    violations.append("calendar.home.contract home.local_writable_store.path is required")
elif sync_local_path != home_local_path:
    violations.append(
        f"local writable store mismatch: sync={sync_local_path!r} home={home_local_path!r}"
    )

push_caps = (sync.get("sync_contracts") or {}).get("push_write_capabilities", [])
if not isinstance(push_caps, list):
    violations.append("calendar.sync.contract sync_contracts.push_write_capabilities must be a list")
elif push_caps:
    violations.append("calendar.sync.contract push_write_capabilities must be empty")

stack = parse_stack_map(stack_map, "communications-calendar")
if stack.get("method") != "docker_compose_ssh":
    violations.append("stack-map communications-calendar method must be docker_compose_ssh")
if stack.get("host") != "communications-stack":
    violations.append("stack-map communications-calendar host must be communications-stack")
if stack.get("path") != "/opt/stacks/communications-stack/calendar":
    violations.append("stack-map communications-calendar path mismatch")
if stack.get("compose_file") != "docker-compose.yml":
    violations.append("stack-map communications-calendar compose_file must be docker-compose.yml")

secrets = home.get("secrets") if isinstance(home.get("secrets"), dict) else {}
if secrets.get("provider") != "infisical":
    violations.append("calendar.home.contract secrets.provider must be infisical")
refs = secrets.get("refs") if isinstance(secrets.get("refs"), dict) else {}
for key in (
    "radicale_admin_username",
    "radicale_admin_password",
    "radicale_users_htpasswd",
    "icloud_username",
    "icloud_app_password",
    "google_oauth_client_id",
    "google_oauth_client_secret",
    "google_oauth_refresh_token",
):
    val = str(refs.get(key, "")).strip()
    if not val.startswith("infisical://"):
        violations.append(f"secrets.refs.{key} must use infisical:// reference")

external = home.get("external_ingest") if isinstance(home.get("external_ingest"), dict) else {}
if external.get("mode") != "read-only":
    violations.append("external_ingest.mode must be read-only")
for provider in ("icloud", "google"):
    block = external.get(provider)
    if not isinstance(block, dict):
        violations.append(f"external_ingest.{provider} block missing")
        continue
    if not isinstance(block.get("enabled"), bool):
        violations.append(f"external_ingest.{provider}.enabled must be boolean")
    if not isinstance(block.get("allowlist_calendar_ids"), list):
        violations.append(f"external_ingest.{provider}.allowlist_calendar_ids must be list")

ha = home.get("home_assistant_ingest") if isinstance(home.get("home_assistant_ingest"), dict) else {}
if not isinstance(ha.get("enabled"), bool):
    violations.append("home_assistant_ingest.enabled must be boolean")
if ha.get("mode") != "read-only":
    violations.append("home_assistant_ingest.mode must be read-only")
if not isinstance(ha.get("allowlist_event_types"), list):
    violations.append("home_assistant_ingest.allowlist_event_types must be list")
fresh = ha.get("freshness_window_minutes")
if not isinstance(fresh, int) or fresh <= 0:
    violations.append("home_assistant_ingest.freshness_window_minutes must be positive integer")

if violations:
    for item in violations:
        print(f"D198 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D198 PASS: calendar home runtime lock valid (contract + stack map parity + ingest controls)")
PY
