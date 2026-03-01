#!/usr/bin/env bash
# TRIAGE: MCP runtime drift recurred due to weak linkage between active agents and runtime contract coverage.
# D148: mcp-agent-runtime-binding-lock
# Enforces: canonical Claude Desktop config paths, explicit runtime binding policy for active MCP agents,
# required contract linkage for agent runtime bindings, and required LaunchAgent scheduler parity.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/mcp.runtime.contract.yaml"
LAUNCHD_CONTRACT="$ROOT/ops/bindings/launchd.runtime.contract.yaml"
LAUNCHD_REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"
REGISTRY="$ROOT/ops/bindings/agents.registry.yaml"
DOC="$ROOT/docs/product/AOF_V1_1_SURFACE_UNIFICATION.md"
SKIP_LIVE_LAUNCHCTL="${D148_SKIP_LIVE_LAUNCHCTL:-0}"

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
need_cmd jq
need_cmd plutil
need_file "$CONTRACT"
need_file "$LAUNCHD_CONTRACT"
need_file "$LAUNCHD_REGISTRY"
need_file "$REGISTRY"
need_file "$DOC"
if [[ "$SKIP_LIVE_LAUNCHCTL" != "1" ]]; then
  need_cmd launchctl
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D148 FAIL: $ERRORS precondition error(s)"
  exit 1
fi

plist_schedule_fingerprint() {
  local plist_path="$1"
  plutil -convert json -o - "$plist_path" 2>/dev/null \
    | jq -c '{
        StartInterval: (.StartInterval // null),
        StartCalendarInterval: (.StartCalendarInterval // null)
      }'
}

plist_label() {
  local plist_path="$1"
  plutil -convert json -o - "$plist_path" 2>/dev/null \
    | jq -r '.Label // ""'
}

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

# Pre-cache contract surface data to avoid repeated yq calls (prevents flaky yq races).
_cached_surface_keys="$(yq e -r '.required_servers_by_surface | keys | .[]' "$CONTRACT")"
_cached_required_servers="$(yq e -r '.required_servers_by_surface | to_entries[] | .key + "/" + (.value[]?)' "$CONTRACT")"
_cached_optional_servers="$(yq e -r '.optional_servers | to_entries[] | .key + "/" + (.value[]?)' "$CONTRACT")"

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

    if ! echo "$_cached_surface_keys" | grep -Fxq "$surface"; then
      err "agent '$agent_id' runtime binding surface '$surface' is not defined in required_servers_by_surface"
      continue
    fi

    if [[ "$required" == "true" ]]; then
      if ! echo "$_cached_required_servers" | grep -Fxq "$surface/$server_name"; then
        err "agent '$agent_id' requires '$server_name' on '$surface' but contract required_servers_by_surface is missing it"
      else
        ok "agent '$agent_id' required runtime binding '$surface/$server_name' is linked"
      fi
    else
      if ! echo "$_cached_optional_servers" | grep -Fxq "$surface/$server_name"; then
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

# 4) Required LaunchAgents must exist in governed source templates, be installed in user launchd,
# and preserve schedule parity. Live load-state checks are mandatory unless explicitly skipped in tests.
source_dir="$(yq e -r '.paths.source_dir // ""' "$LAUNCHD_CONTRACT")"
install_dir="$(yq e -r '.paths.user_launchagents_dir // ""' "$LAUNCHD_CONTRACT")"
log_root="$(yq e -r '.paths.canonical_log_root // ""' "$LAUNCHD_CONTRACT")"
required_env_key="$(yq e -r '.required_env[0] // "SPINE_ROOT"' "$LAUNCHD_CONTRACT")"

if [[ -z "$source_dir" ]]; then
  err "launchd.runtime.contract paths.source_dir is required"
fi
if [[ -z "$install_dir" ]]; then
  err "launchd.runtime.contract paths.user_launchagents_dir is required"
fi
if [[ -z "$log_root" ]]; then
  err "launchd.runtime.contract paths.canonical_log_root is required"
fi

mapfile -t required_labels < <(yq e -r '.required_labels[]?' "$LAUNCHD_CONTRACT")
if [[ "${#required_labels[@]}" -eq 0 ]]; then
  err "launchd.runtime.contract required_labels[] must list at least one LaunchAgent label"
fi

if [[ "$SKIP_LIVE_LAUNCHCTL" != "1" ]]; then
  uid_val="$(id -u)"
fi

for label in "${required_labels[@]}"; do
  [[ -n "$label" ]] || continue

  src_plist="$source_dir/$label.plist"
  dst_plist="$install_dir/$label.plist"

  if [[ ! -f "$src_plist" ]]; then
    err "required launchagent '$label' missing governed template: $src_plist"
    continue
  fi
  if [[ ! -f "$dst_plist" ]]; then
    err "required launchagent '$label' not installed at: $dst_plist"
    continue
  fi

  src_label="$(plist_label "$src_plist")"
  dst_label="$(plist_label "$dst_plist")"
  if [[ "$src_label" != "$label" ]]; then
    err "template plist label mismatch for '$label' (got '$src_label')"
  fi
  if [[ "$dst_label" != "$label" ]]; then
    err "installed plist label mismatch for '$label' (got '$dst_label')"
  fi

  src_schedule="$(plist_schedule_fingerprint "$src_plist")"
  dst_schedule="$(plist_schedule_fingerprint "$dst_plist")"
  if [[ "$src_schedule" != "$dst_schedule" ]]; then
    err "launchagent '$label' schedule drift: installed plist does not match governed template"
  else
    ok "launchagent '$label' schedule matches governed template"
  fi

  src_out_path="$(plutil -convert json -o - "$src_plist" 2>/dev/null | jq -r '.StandardOutPath // ""')"
  src_err_path="$(plutil -convert json -o - "$src_plist" 2>/dev/null | jq -r '.StandardErrorPath // ""')"
  if [[ "$src_out_path" != "$log_root"* ]]; then
    err "launchagent '$label' StandardOutPath must live under '$log_root' (got '$src_out_path')"
  fi
  if [[ "$src_err_path" != "$log_root"* ]]; then
    err "launchagent '$label' StandardErrorPath must live under '$log_root' (got '$src_err_path')"
  fi

  src_env_spine="$(plutil -convert json -o - "$src_plist" 2>/dev/null | jq -r ".EnvironmentVariables.${required_env_key} // \"\"")"
  if [[ "$src_env_spine" != "$ROOT" ]]; then
    err "launchagent '$label' missing canonical ${required_env_key}=$ROOT in template env"
  fi

  registry_count="$(yq e ".labels[] | select(.label == \"$label\") | length" "$LAUNCHD_REGISTRY" 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$registry_count" == "0" ]]; then
    err "launchagent '$label' missing from launchd.scheduler.registry.yaml"
  fi

  if [[ "$SKIP_LIVE_LAUNCHCTL" == "1" ]]; then
    ok "launchagent '$label' live launchctl check skipped"
    continue
  fi

  if ! launchctl print "gui/$uid_val/$label" >/dev/null 2>&1; then
    err "launchagent '$label' is not loaded in launchctl"
  else
    ok "launchagent '$label' is loaded in launchctl"
  fi
done

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D148 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D148 PASS: MCP runtime + LaunchAgent scheduler binding lock enforced"
