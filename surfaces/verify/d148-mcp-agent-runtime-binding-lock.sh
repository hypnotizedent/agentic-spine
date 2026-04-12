#!/usr/bin/env bash
# D148: mcp-agent-runtime-binding-lock
# Enforces canonical MCP runtime contract linkage across the governed config
# surfaces that still exist after the spine-lite registry reduction.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/mcp.runtime.contract.yaml"
TERMINAL_CONTRACT="$ROOT/ops/bindings/terminal.role.contract.yaml"
AGENT_PROFILES="$ROOT/ops/bindings/gate.agent.profiles.yaml"
TENANT_PROFILE="$ROOT/ops/bindings/tenant.profile.yaml"

fail() {
  echo "D148 FAIL: $*" >&2
  exit 1
}

for file in "$CONTRACT" "$TERMINAL_CONTRACT" "$AGENT_PROFILES" "$TENANT_PROFILE"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done

command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CONTRACT" "$TERMINAL_CONTRACT" "$AGENT_PROFILES" "$TENANT_PROFILE" <<'PY'
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

import yaml

contract_path = Path(sys.argv[1])
terminal_contract_path = Path(sys.argv[2])
agent_profiles_path = Path(sys.argv[3])
tenant_profile_path = Path(sys.argv[4])


def fail(msg: str) -> None:
    print(f"D148 FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            doc = yaml.safe_load(handle) or {}
    except Exception as exc:
        fail(f"{path}: invalid YAML ({exc})")
    if not isinstance(doc, dict):
        fail(f"{path}: YAML root must be a mapping")
    return doc


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"{path}: invalid JSON ({exc})")


contract = load_yaml(contract_path)
terminal_contract = load_yaml(terminal_contract_path)
agent_profiles = load_yaml(agent_profiles_path)
tenant_profile = load_yaml(tenant_profile_path)

surface_paths = contract.get("surface_paths") or {}
required_servers_by_surface = contract.get("required_servers_by_surface") or {}
optional_servers = contract.get("optional_servers") or {}
supplemental_defs = contract.get("supplemental_server_definitions") or {}
gateway = contract.get("gateway") or {}
aliases = contract.get("aliases") or {}

expected_desktop = "/Users/ronnyworks/Library/Application Support/Claude/claude_desktop_config.json"
expected_runtime_state = "/Users/ronnyworks/.claude.json"
if surface_paths.get("claude_desktop") != expected_desktop:
    fail(f"surface_paths.claude_desktop must be '{expected_desktop}'")
if surface_paths.get("claude_desktop_runtime_state") != expected_runtime_state:
    fail(f"surface_paths.claude_desktop_runtime_state must be '{expected_runtime_state}'")

gateway_server = str(gateway.get("server_name") or "").strip()
if gateway_server != "spine":
    fail("gateway.server_name must be 'spine'")

codex_required = required_servers_by_surface.get("codex") or []
claude_required = required_servers_by_surface.get("claude_desktop") or []
opencode_required = required_servers_by_surface.get("opencode") or []
if "spine" not in codex_required:
    fail("codex required server set must include spine")
if "spine" not in claude_required:
    fail("claude_desktop required server set must include spine")
if "spine" not in opencode_required:
    fail("opencode required server set must include spine")

claude_path = Path(surface_paths["claude_desktop"])
claude_state_path = Path(surface_paths["claude_desktop_runtime_state"])
opencode_path = Path(surface_paths["opencode"])

for path in (claude_path, claude_state_path, opencode_path):
    if not path.is_file():
        fail(f"required runtime surface missing: {path}")

claude_cfg = load_json(claude_path)
claude_servers = claude_cfg.get("mcpServers") or {}
if not isinstance(claude_servers, dict):
    fail(f"{claude_path}: mcpServers must be an object")

runtime_state = load_json(claude_state_path)
runtime_servers = runtime_state.get("mcpServers") or {}
if not isinstance(runtime_servers, dict):
    fail(f"{claude_state_path}: mcpServers must be an object when present")

opencode_cfg = load_json(opencode_path)
opencode_servers = opencode_cfg.get("mcp") or {}
if not isinstance(opencode_servers, dict):
    fail(f"{opencode_path}: mcp must be an object")

for server in claude_required:
    if server not in claude_servers:
        alias_hits = [alias for alias, targets in aliases.items() if server in (targets or []) and alias in claude_servers]
        if not alias_hits:
            fail(f"claude_desktop missing required MCP server '{server}'")

for server in opencode_required:
    entry = opencode_servers.get(server)
    if not isinstance(entry, dict):
        fail(f"opencode missing required MCP server '{server}'")
    if entry.get("enabled") is not True:
        fail(f"opencode server '{server}' must be enabled")

if "spine" not in runtime_servers:
    fail("claude runtime state must retain spine MCP registration")

supplemental_seen = set()
for name, payload in supplemental_defs.items():
    if not isinstance(payload, dict):
        fail(f"supplemental server '{name}' must be a mapping")
    command = str(payload.get("command") or "").strip()
    if not command:
        fail(f"supplemental server '{name}' missing command")
    health_check = str(payload.get("health_check") or "").strip()
    if health_check == "binary_exists":
        if os.path.isabs(command):
            if not Path(command).exists():
                fail(f"supplemental server '{name}' command missing: {command}")
        elif shutil.which(command) is None:
            fail(f"supplemental server '{name}' binary not found: {command}")
    supplemental_seen.add(name)

tenant_mcp_servers = ((tenant_profile.get("surfaces") or {}).get("mcp_servers") or [])
if not isinstance(tenant_mcp_servers, list):
    fail("tenant.profile runtime.mcp_servers must be a list")
tenant_mcp_names = {
    str(item.get("name") or "").strip()
    for item in tenant_mcp_servers
    if isinstance(item, dict)
}
if "spine" not in tenant_mcp_names:
    fail("tenant.profile surfaces.mcp_servers must include spine")

profiles = agent_profiles.get("profiles") or []
profile_ids = {str(item.get("agent_id")) for item in profiles if isinstance(item, dict)}
for expected in ("communications-agent", "immich-agent"):
    if expected not in profile_ids:
        fail(f"gate.agent.profiles missing expected MCP-facing profile '{expected}'")

role_ids = {str(item.get("id")) for item in (terminal_contract.get("roles") or []) if isinstance(item, dict)}
for expected in ("DOMAIN-COMMS-01", "RUNTIME-IMMICH-01"):
    if expected not in role_ids:
        fail(f"terminal.role.contract missing runtime role '{expected}'")

print(
    "D148 PASS: MCP runtime binding lock enforced "
    f"(claude_required={len(claude_required)}, opencode_required={len(opencode_required)}, "
    f"supplemental={len(supplemental_seen)})"
)
PY
