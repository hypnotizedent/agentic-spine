#!/usr/bin/env bash
# TRIAGE: MCP runtime drift recurred due to weak linkage between active agents and runtime contract coverage.
# D148: mcp-agent-runtime-binding-lock
# Enforces: canonical Claude Desktop config paths, explicit runtime binding policy for active MCP agents,
# and required contract linkage for agent runtime bindings.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/mcp.runtime.contract.yaml"
REGISTRY="$ROOT/ops/bindings/agents.registry.yaml"
DOC="$ROOT/docs/product/AOF_V1_1_SURFACE_UNIFICATION.md"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

need_file() {
  local file="$1"
  [[ -f "$file" ]] || err "missing file: $file"
}

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || err "missing command: $cmd"
}

need_cmd yq
need_file "$CONTRACT"
need_file "$REGISTRY"
need_file "$DOC"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D148 FAIL: $ERRORS precondition error(s)"
  exit 1
fi

# 1) Canonical Claude Desktop config path linkage in runtime contract.
expected_desktop_path="/Users/ronnyworks/Library/Application Support/Claude/claude_desktop_config.json"
expected_runtime_state_path="/Users/ronnyworks/.claude.json"

desktop_path="$(yq e -r '.surface_paths.claude_desktop // ""' "$CONTRACT")"
runtime_state_path="$(yq e -r '.surface_paths.claude_desktop_runtime_state // ""' "$CONTRACT")"

if [[ "$desktop_path" != "$expected_desktop_path" ]]; then
  err "surface_paths.claude_desktop must be '$expected_desktop_path' (got '$desktop_path')"
else
  ok "claude_desktop config path is canonical"
fi

if [[ "$runtime_state_path" != "$expected_runtime_state_path" ]]; then
  err "surface_paths.claude_desktop_runtime_state must be '$expected_runtime_state_path' (got '$runtime_state_path')"
else
  ok "claude_desktop runtime-state path is canonical"
fi

# 2) Active MCP agents must explicitly declare either runtime_bindings or an exemption reason.
mapfile -t active_mcp_agents < <(
  yq e -r '.agents[] | select(.implementation_status == "active" and (.mcp_server // "") != "") | .id' "$REGISTRY"
)

if [[ "${#active_mcp_agents[@]}" -eq 0 ]]; then
  err "no active MCP agents found in agents.registry.yaml"
fi

for agent_id in "${active_mcp_agents[@]}"; do
  [[ -n "$agent_id" ]] || continue

  binding_count="$(yq e ".agents[] | select(.id == \"$agent_id\") | (.runtime_bindings // []) | length" "$REGISTRY")"
  exempt_reason="$(yq e -r ".agents[] | select(.id == \"$agent_id\") | .runtime_binding_exempt_reason // \"\"" "$REGISTRY")"

  if [[ "$binding_count" -eq 0 && -z "$exempt_reason" ]]; then
    err "agent '$agent_id' is active with mcp_server but has neither runtime_bindings nor runtime_binding_exempt_reason"
    continue
  fi

  if [[ "$binding_count" -gt 0 && -n "$exempt_reason" ]]; then
    err "agent '$agent_id' defines both runtime_bindings and runtime_binding_exempt_reason (choose one)"
    continue
  fi

  if [[ "$binding_count" -eq 0 ]]; then
    ok "agent '$agent_id' has explicit runtime binding exemption"
    continue
  fi

  for ((i=0; i<binding_count; i++)); do
    surface="$(yq e -r ".agents[] | select(.id == \"$agent_id\") | .runtime_bindings[$i].surface // \"\"" "$REGISTRY")"
    server_name="$(yq e -r ".agents[] | select(.id == \"$agent_id\") | .runtime_bindings[$i].server_name // \"\"" "$REGISTRY")"
    required="$(yq e -r ".agents[] | select(.id == \"$agent_id\") | .runtime_bindings[$i].required // true" "$REGISTRY")"

    if [[ -z "$surface" ]]; then
      err "agent '$agent_id' runtime_bindings[$i] missing surface"
      continue
    fi
    if [[ -z "$server_name" ]]; then
      err "agent '$agent_id' runtime_bindings[$i] missing server_name"
      continue
    fi
    if [[ "$required" != "true" && "$required" != "false" ]]; then
      err "agent '$agent_id' runtime_bindings[$i] required must be boolean true/false"
      continue
    fi

    if ! yq e -r '.required_servers_by_surface | keys | .[]' "$CONTRACT" | grep -Fxq "$surface"; then
      err "agent '$agent_id' runtime binding surface '$surface' is not defined in required_servers_by_surface"
      continue
    fi

    if [[ "$required" == "true" ]]; then
      if ! yq e -r ".required_servers_by_surface.\"$surface\"[]?" "$CONTRACT" | grep -Fxq "$server_name"; then
        err "agent '$agent_id' requires '$server_name' on '$surface' but contract required_servers_by_surface is missing it"
      else
        ok "agent '$agent_id' required runtime binding '$surface/$server_name' is linked"
      fi
    else
      if ! yq e -r ".optional_servers.\"$surface\"[]?" "$CONTRACT" | grep -Fxq "$server_name"; then
        err "agent '$agent_id' optional runtime binding '$surface/$server_name' missing in optional_servers"
      else
        ok "agent '$agent_id' optional runtime binding '$surface/$server_name' is linked"
      fi
    fi
  done
done

# 3) Product docs must not advertise stale registration state for activated MCP agents.
if grep -q 'communications-agent: registered' "$DOC"; then
  err "stale status in docs/product/AOF_V1_1_SURFACE_UNIFICATION.md for communications-agent"
fi
if grep -q 'immich-agent: registered' "$DOC"; then
  err "stale status in docs/product/AOF_V1_1_SURFACE_UNIFICATION.md for immich-agent"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D148 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D148 PASS: MCP agent runtime binding lock enforced"
