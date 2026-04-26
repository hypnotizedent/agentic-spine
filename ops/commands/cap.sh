#!/usr/bin/env bash
set -euo pipefail

SCRIPT_CODE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAP_FILE_REL="ops/capabilities.yaml"
ACTIVE_REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
ACTIVE_CODE_ROOT=""
VALID_AMBIENT_TARGET_REPO=""
AMBIENT_TARGET_GIT_ROOT=""

if [[ -n "$ACTIVE_REPO_ROOT" && -f "$ACTIVE_REPO_ROOT/$CAP_FILE_REL" ]]; then
    ACTIVE_CODE_ROOT="$ACTIVE_REPO_ROOT"
fi

if [[ -n "${SPINE_TARGET_REPO:-}" ]]; then
    AMBIENT_TARGET_GIT_ROOT="$(git -C "$SPINE_TARGET_REPO" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$AMBIENT_TARGET_GIT_ROOT" ]]; then
        VALID_AMBIENT_TARGET_REPO="$AMBIENT_TARGET_GIT_ROOT"
    elif [[ -f "$SPINE_TARGET_REPO/$CAP_FILE_REL" ]]; then
        VALID_AMBIENT_TARGET_REPO="$SPINE_TARGET_REPO"
    fi
fi

SPINE_TARGET_REPO="${VALID_AMBIENT_TARGET_REPO:-${ACTIVE_REPO_ROOT:-${SPINE_REPO:-${SPINE_CODE:-$SCRIPT_CODE_ROOT}}}}"
if [[ -n "$ACTIVE_CODE_ROOT" ]]; then
    SPINE_CODE="$ACTIVE_CODE_ROOT"
else
    SPINE_CODE="${SPINE_CODE:-$SCRIPT_CODE_ROOT}"
fi
SPINE_REPO="$SPINE_TARGET_REPO"

_SP_LIB_DIR="${BASH_SOURCE%/*}"
[[ "$_SP_LIB_DIR" == "${BASH_SOURCE}" ]] && _SP_LIB_DIR="$(pwd)"
source "$_SP_LIB_DIR/../lib/yaml.sh"
source "$_SP_LIB_DIR/../lib/runtime-paths.sh"
spine_runtime_resolve_paths
export SPINE_INBOX SPINE_OUTBOX SPINE_STATE SPINE_LOCKS SPINE_LOGS SPINE_RECEIPTS SPINE_VERIFY_ROOT SPINE_DOMAIN_STATE SPINE_TARGET_REPO

CAP_FILE="$SPINE_CODE/$CAP_FILE_REL"
ROLE_POLICY_CONTRACT_REL="ops/bindings/role.runtime.control.contract.yaml"
ROLE_POLICY_CONTRACT="$SPINE_CODE/$ROLE_POLICY_CONTRACT_REL"
TERMINAL_ROLE_CONTRACT_REL="ops/bindings/terminal.role.contract.yaml"
TERMINAL_ROLE_CONTRACT="$SPINE_CODE/$TERMINAL_ROLE_CONTRACT_REL"

CAP_BLOCKER_REASON="none"
CAP_ROLE_POLICY_ENFORCED="false"
CAP_ROLE_POLICY_OVERRIDE_USED="false"
CAP_ROLE_POLICY_OVERRIDE_REF="none"
CAP_ROLE_POLICY_OVERRIDE_REASON="none"
CAP_ROLE_POLICY_BLOCK_REASON="none"
CAP_ROLE_POLICY_BLOCK_MESSAGE=""

usage() {
    cat <<'EOF'
ops cap - Execute runtime capabilities

Usage:
  ops cap list                    List available capabilities
  ops cap run <name> [args...]    Execute a capability
  ops cap show <name>             Show capability details

Examples:
  ops cap list
  ops cap run spine.verify
  ops cap run monolith.search "TODO" agentic-spine
  ops cap show infra.docker_ps
EOF
}

check_deps() {
    if ! command -v yq >/dev/null 2>&1; then
        echo "ERROR: yq required for YAML parsing"
        echo "Install: brew install yq"
        exit 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq required for YAML parsing"
        echo "Install: brew install jq"
        exit 1
    fi
}

reset_role_policy_state() {
    CAP_BLOCKER_REASON="none"
    CAP_ROLE_POLICY_ENFORCED="false"
    CAP_ROLE_POLICY_OVERRIDE_USED="false"
    CAP_ROLE_POLICY_OVERRIDE_REF="none"
    CAP_ROLE_POLICY_OVERRIDE_REASON="none"
    CAP_ROLE_POLICY_BLOCK_REASON="none"
    CAP_ROLE_POLICY_BLOCK_MESSAGE=""
}

cap_safety_requires_mutation_policy() {
    case "${1:-}" in
        mutating|destructive) return 0 ;;
        *) return 1 ;;
    esac
}

# Detect a pending delegation with wave_kind_intent=proof.
# Returns 0 and sets CAP_PROOF_DELEGATION_ID if one exists.
pending_proof_delegation() {
    local spine_state="${SPINE_STATE:-}"
    [[ -n "$spine_state" ]] || return 1
    local del_dir="${spine_state}/delegations"
    [[ -d "$del_dir" ]] || return 1

    local del_file del_state wk_intent del_id
    for del_file in "$del_dir"/DEL-*.yaml; do
        [[ -f "$del_file" ]] || continue
        del_state="$(python3 -c "
import yaml,sys
d=yaml.safe_load(open(sys.argv[1]))
print(d.get('delegation_state',''), d.get('wave_kind_intent',''), d.get('delegation_id',''))
" "$del_file" 2>/dev/null || true)"
        IFS=' ' read -r ds wki did <<< "$del_state"
        [[ "$wki" == "proof" ]] || continue
        [[ "$ds" == "delegated" || "$ds" == "picked_up" || "$ds" == "executing" ]] || continue
        [[ -n "$did" ]] || continue
        CAP_PROOF_DELEGATION_ID="$did"
        return 0
    done
    return 1
}

# Detect an active proof wave in the runtime state directory.
# Returns 0 and sets CAP_PROOF_WAVE_ID if a proof wave is active.
active_proof_wave_id() {
    local spine_state="${SPINE_STATE:-}"
    [[ -n "$spine_state" ]] || return 1
    local waves_dir
    waves_dir="$(dirname "$spine_state")/waves"
    [[ -d "$waves_dir" ]] || return 1

    local state_file wave_kind lifecycle_state wave_id
    for state_file in "$waves_dir"/WAVE-*/state.json; do
        [[ -f "$state_file" ]] || continue
        wave_kind="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('wave_kind',''))" "$state_file" 2>/dev/null || true)"
        [[ "$wave_kind" == "proof" ]] || continue
        lifecycle_state="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('lifecycle_state',''))" "$state_file" 2>/dev/null || true)"
        [[ "$lifecycle_state" == "active" ]] || continue
        wave_id="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('wave_id',''))" "$state_file" 2>/dev/null || true)"
        [[ -n "$wave_id" ]] || continue
        CAP_PROOF_WAVE_ID="$wave_id"
        return 0
    done
    return 1
}

role_policy_override_env_name() {
    local field="$1"
    local default_value="$2"

    if [[ ! -f "$ROLE_POLICY_CONTRACT" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    yq e -r "$field // \"$default_value\"" "$ROLE_POLICY_CONTRACT" 2>/dev/null || printf '%s\n' "$default_value"
}

current_terminal_id() {
    printf '%s\n' "${SPINE_TERMINAL_ID:-${OPS_TERMINAL_ID:-${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ROLE:-${SPINE_TERMINAL_NAME:-}}}}}"
}

current_execution_class() {
    printf '%s\n' "${SPINE_EXECUTION_CLASS:-${SPINE_RUNTIME_ROLE:-researcher}}"
}

execution_class_is_read_only() {
    local execution_class="$1"
    local read_only_roles=""
    [[ -f "$ROLE_POLICY_CONTRACT" ]] || return 1

    read_only_roles="$(yq e -r '.runtime_roles.read_only_roles[]?' "$ROLE_POLICY_CONTRACT" 2>/dev/null || true)"
    if printf '%s\n' "$read_only_roles" | grep -Fxq -- "$execution_class"; then
        return 0
    fi

    return 1
}

capability_in_execution_class_mutation_allowlist() {
    local execution_class="$1"
    local capability_name="$2"
    local allowlist=""
    [[ -f "$ROLE_POLICY_CONTRACT" ]] || return 1

    allowlist="$(yq e -r ".runtime_roles.mutating_capability_allowlist_by_role.\"$execution_class\"[]?" "$ROLE_POLICY_CONTRACT" 2>/dev/null || true)"
    if printf '%s\n' "$allowlist" | grep -Fxq -- "$capability_name"; then
        return 0
    fi

    return 1
}

evaluate_role_policy() {
    local capability_name="$1"
    local safety="$2"
    local override_env override_reason_env override_ref override_reason
    local session_posture execution_class enforce_mutation_block terminal_id

    reset_role_policy_state

    CAP_ROLE_POLICY_ENFORCED="true"
    override_env="$(role_policy_override_env_name '.runtime_roles.execution_policy.override_env' 'SPINE_ROLE_POLICY_OVERRIDE_REF')"
    override_reason_env="$(role_policy_override_env_name '.runtime_roles.execution_policy.override_reason_env' 'SPINE_ROLE_POLICY_OVERRIDE_REASON')"
    override_ref="$(printenv "$override_env" 2>/dev/null || true)"
    override_reason="$(printenv "$override_reason_env" 2>/dev/null || true)"

    if [[ -n "$override_ref" || -n "$override_reason" ]]; then
        CAP_ROLE_POLICY_OVERRIDE_REF="${override_ref:-none}"
        CAP_ROLE_POLICY_OVERRIDE_REASON="${override_reason:-none}"
        if [[ -z "$override_ref" || -z "$override_reason" ]]; then
            CAP_BLOCKER_REASON="role_policy_override_incomplete"
            CAP_ROLE_POLICY_BLOCK_REASON="$CAP_BLOCKER_REASON"
            CAP_ROLE_POLICY_BLOCK_MESSAGE="override requires both $override_env and $override_reason_env"
            return 1
        fi
        CAP_ROLE_POLICY_OVERRIDE_USED="true"
    fi

    # ── Translator posture: full execution block ──────────────────────────
    # translator.authority.contract.yaml forbids ALL capability execution,
    # verification authority, loop advancement, and dispatch — not just
    # mutating caps. This gate fires before the safety-class check so that
    # translator sessions cannot run ANY cap without explicit override.
    session_posture="${SPINE_SESSION_POSTURE:-}"
    if [[ "$session_posture" == "translator" && "$CAP_ROLE_POLICY_OVERRIDE_USED" != "true" ]]; then
        CAP_BLOCKER_REASON="translator_posture_execution_forbidden"
        CAP_ROLE_POLICY_BLOCK_REASON="$CAP_BLOCKER_REASON"
        CAP_ROLE_POLICY_BLOCK_MESSAGE="session posture 'translator' cannot execute capabilities — re-enter on a controller or worker surface"
        return 1
    fi

    if ! cap_safety_requires_mutation_policy "$safety"; then
        return 0
    fi

    # ── Unbound identity check ────────────────────────────────────────────
    # Mutating capabilities require bound terminal identity (set by terminal
    # launch). Canonical identity is SPINE_TERMINAL_ID with compatibility
    # fallbacks. If identity is unset, the caller did not go through governed
    # admission. Block unless explicitly overridden.
    terminal_id="$(current_terminal_id)"
    if [[ -z "$terminal_id" && "$CAP_ROLE_POLICY_OVERRIDE_USED" != "true" ]]; then
        CAP_BLOCKER_REASON="unbound_terminal_identity"
        CAP_ROLE_POLICY_BLOCK_REASON="$CAP_BLOCKER_REASON"
        CAP_ROLE_POLICY_BLOCK_MESSAGE="mutating capability '$capability_name' requires bound terminal identity — use 'ops terminal launch' for governed admission"
        return 1
    fi

    if [[ ! -f "$ROLE_POLICY_CONTRACT" ]]; then
        CAP_BLOCKER_REASON="role_policy_contract_missing"
        CAP_ROLE_POLICY_BLOCK_REASON="$CAP_BLOCKER_REASON"
        CAP_ROLE_POLICY_BLOCK_MESSAGE="role policy contract missing: $ROLE_POLICY_CONTRACT"
        return 1
    fi

    if [[ "$CAP_ROLE_POLICY_OVERRIDE_USED" == "true" ]]; then
        return 0
    fi

    enforce_mutation_block="$(yq e -r '.runtime_roles.execution_policy.enforce_read_only_mutation_block // "false"' "$ROLE_POLICY_CONTRACT" 2>/dev/null || echo "false")"
    if [[ "$enforce_mutation_block" != "true" ]]; then
        CAP_ROLE_POLICY_ENFORCED="false"
        return 0
    fi

    execution_class="$(current_execution_class)"
    if ! execution_class_is_read_only "$execution_class"; then
        return 0
    fi

    if capability_in_execution_class_mutation_allowlist "$execution_class" "$capability_name"; then
        return 0
    fi

    # Proof auto-override: when a proof wave is active OR a pending delegation
    # declares proof intent, worker-custody capabilities are allowed from
    # read-only roles without manual override envs. Bounded to proof lifecycle
    # and logged in the capability receipt.
    if active_proof_wave_id; then
        CAP_ROLE_POLICY_OVERRIDE_USED="true"
        CAP_ROLE_POLICY_OVERRIDE_REF="proof-wave:${CAP_PROOF_WAVE_ID}"
        CAP_ROLE_POLICY_OVERRIDE_REASON="auto-override: active proof wave permits worker-custody capabilities"
        return 0
    fi
    if pending_proof_delegation; then
        CAP_ROLE_POLICY_OVERRIDE_USED="true"
        CAP_ROLE_POLICY_OVERRIDE_REF="proof-delegation:${CAP_PROOF_DELEGATION_ID}"
        CAP_ROLE_POLICY_OVERRIDE_REASON="auto-override: pending proof-intended delegation permits pre-wave worker-custody capabilities"
        return 0
    fi

    CAP_BLOCKER_REASON="execution_class_mutation_forbidden"
    CAP_ROLE_POLICY_BLOCK_REASON="$CAP_BLOCKER_REASON"
    CAP_ROLE_POLICY_BLOCK_MESSAGE="execution class '$execution_class' is read-only and '$capability_name' is not allowlisted for mutation"
    return 1
}

emit_role_policy_stop() {
    local capability_name="$1"
    local safety="$2"
    local override_env override_reason_env execution_class session_posture terminal_id next_step

    override_env="$(role_policy_override_env_name '.runtime_roles.execution_policy.override_env' 'SPINE_ROLE_POLICY_OVERRIDE_REF')"
    override_reason_env="$(role_policy_override_env_name '.runtime_roles.execution_policy.override_reason_env' 'SPINE_ROLE_POLICY_OVERRIDE_REASON')"
    execution_class="$(current_execution_class)"
    session_posture="${SPINE_SESSION_POSTURE:-unset}"
    terminal_id="$(current_terminal_id)"

    next_step="rerun from a worker-bound execution surface or set $override_env and $override_reason_env with governed justification"
    if [[ "$session_posture" == "translator" ]]; then
        next_step="re-enter on a controller or worker surface; translator posture cannot execute any capability. Override only with governed justification via $override_env and $override_reason_env"
    fi

    cat <<EOF
STOP: execution class policy blocked capability execution
  capability: $capability_name
  safety:     $safety
  execution:  $execution_class
  posture:    $session_posture
  terminal:   ${terminal_id:-unset}
  reason:     ${CAP_ROLE_POLICY_BLOCK_MESSAGE:-execution class policy blocked capability execution}
  next:       $next_step
EOF
}

ensure_runtime_dirs() {
    mkdir -p \
        "$SPINE_STATE" \
        "$SPINE_TMP" \
        "$SPINE_LOGS" \
        "$SPINE_LOCKS" \
        "$SPINE_INBOX" \
        "$SPINE_OUTBOX" \
        "$SPINE_VERIFY_ROOT" \
        "$SPINE_DOMAIN_STATE"
}

list_caps() {
    echo "=== AVAILABLE CAPABILITIES ==="
    echo ""
    yq e -r '.capabilities | to_entries[] | [.key, (.value.safety // ""), (.value.description // "")] | @tsv' "$CAP_FILE" \
      | LC_ALL=C sort -t $'\t' -k1,1 \
      | while IFS=$'\t' read -r cap safety desc; do
          printf "  %-25s [%s] %s\n" "$cap" "$safety" "$desc"
        done
    echo ""
    echo "Run: ops cap run <name> [args...]"
}

expand_runtime_value() {
    local raw="${1:-}"
    [[ -n "$raw" && "$raw" != "null" ]] || return 0
    eval echo "$raw"
}

derive_command_target() {
    local command_str="${1:-}"
    local script_path="${2:-}"

    python3 - "$command_str" "$script_path" <<'PY'
import shlex
import sys

command_str = sys.argv[1]
script_path = sys.argv[2]

if script_path and script_path != "null":
    print(script_path)
    raise SystemExit(0)

try:
    tokens = shlex.split(command_str)
except ValueError:
    print("")
    raise SystemExit(0)

if not tokens:
    print("")
    raise SystemExit(0)

interpreters = {
    "python", "python3", "bash", "sh", "zsh", "node", "ruby", "perl",
}

head = tokens[0]
if "/" in head or head.startswith(".") or head.startswith("$"):
    print(head)
elif head in interpreters and len(tokens) > 1:
    print(tokens[1])
else:
    print("")
PY
}

validate_cap_target() {
    local name="$1"
    local command_str="$2"
    local script_path="$3"
    local cwd="$4"
    local target=""

    target="$(derive_command_target "$command_str" "$script_path")"
    [[ -n "$target" ]] || return 0
    target="$(expand_runtime_value "$target")"
    [[ -n "$target" ]] || return 0

    if [[ "$target" != /* ]]; then
        target="$cwd/$target"
    fi

    if [[ ! -e "$target" ]]; then
        echo "ERROR: capability '$name' target not found: $target"
        echo "Check ops/capabilities.yaml registration for command/script_path drift."
        exit 1
    fi
}

show_cap() {
    local name="$1"

    if ! yaml_query -e "$CAP_FILE" ".capabilities.\"$name\"" 2>/dev/null; then
        echo "ERROR: Unknown capability: $name"
        echo "Run 'ops cap list' to see available capabilities."
        exit 1
    fi

    echo "=== CAPABILITY: $name ==="
    yq e ".capabilities.\"$name\"" "$CAP_FILE"
}

resolve_terminal_type_for_telemetry() {
    local terminal_id="${1:-}"
    [[ -n "$terminal_id" ]] || return 0
    [[ -f "$TERMINAL_ROLE_CONTRACT" ]] || return 0
    command -v yq >/dev/null 2>&1 || return 0

    yq e ".roles[] | select(.id == \"$terminal_id\") | .type" "$TERMINAL_ROLE_CONTRACT" 2>/dev/null || true
}

resolve_lane_type_for_telemetry() {
    local checkout_root="${1:-}"
    local branch="${2:-unknown}"
    local main_root="${3:-}"

    if [[ -n "$checkout_root" && -n "$main_root" && "$checkout_root" == "$main_root" ]]; then
        if [[ "$branch" == "<detached>" ]]; then
            printf 'root_checkout_detached\n'
        elif [[ "$branch" == "main" ]]; then
            printf 'root_main_integration\n'
        else
            printf 'root_checkout_non_main\n'
        fi
        return 0
    fi

    printf 'managed_worktree_or_branch\n'
}

loop_id_is_live_for_custody() {
    local loop_id="${1:-}"
    [[ -n "$loop_id" ]] || return 1

    python3 - "$SPINE_STATE" "$loop_id" <<'PY'
import sqlite3
import sys
from pathlib import Path

state_root = Path(sys.argv[1])
loop_id = sys.argv[2]
db_path = state_root / "shared_authority.db"
if not db_path.is_file():
    raise SystemExit(1)

conn = sqlite3.connect(str(db_path))
try:
    row = conn.execute(
        "SELECT status FROM loops WHERE loop_id = ?",
        (loop_id,),
    ).fetchone()
finally:
    conn.close()

if not row:
    raise SystemExit(1)

status = str(row[0] or "").strip().lower()
raise SystemExit(0 if status in {"active", "draft", "open"} else 1)
PY
}

write_terminal_custody_heartbeat() {
    local terminal_id="${1:-}"
    [[ -n "$terminal_id" ]] || return 0

    local heartbeat_dir="$SPINE_STATE/terminal-heartbeats"
    local heartbeat_file="${SPINE_HEARTBEAT_FILE:-$heartbeat_dir/${terminal_id}.yaml}"
    local now_utc expires_at
    local execution_class
    execution_class="$(current_execution_class)"
    local loop_id="${SPINE_LOOP_ID:-}"
    local terminal_type="${SPINE_TERMINAL_TYPE:-}"
    local terminal_scope="${SPINE_TERMINAL_SCOPE:-}"
    local normalized_scope="${SPINE_TERMINAL_SCOPE:-}"
    local protected_hotspot_scope="${SPINE_TERMINAL_PROTECTED_HOTSPOT_SCOPE:-}"
    local target_repo="${SPINE_TARGET_REPO:-${SPINE_REPO:-$PWD}}"
    local checkout_root repo_root branch main_root lane_type git_common_dir git_index_path
    local pid_value="${TERMINAL_PID:-${PPID:-$$}}"
    local hostname_value

    mkdir -p "$heartbeat_dir" 2>/dev/null || true

    if [[ -z "$terminal_type" || "$terminal_type" == "null" ]]; then
        terminal_type="$(resolve_terminal_type_for_telemetry "$terminal_id")"
    fi
    [[ -n "$terminal_type" && "$terminal_type" != "null" ]] || terminal_type="unknown"
    if [[ -z "$loop_id" && "${OPS_WORKTREE_IDENTITY:-}" == LOOP-* ]]; then
        loop_id="${OPS_WORKTREE_IDENTITY:-}"
    fi
    if [[ -n "$loop_id" ]] && ! loop_id_is_live_for_custody "$loop_id"; then
        loop_id=""
    fi

    if [[ -f "$heartbeat_file" ]]; then
        if [[ -z "$terminal_scope" ]]; then
            terminal_scope="$(awk -F': ' '/^scope:/{print $2; exit}' "$heartbeat_file" 2>/dev/null | tr -d '"')"
        fi
        if [[ -z "$normalized_scope" ]]; then
            normalized_scope="$(awk -F': ' '/^normalized_scope:/{print $2; exit}' "$heartbeat_file" 2>/dev/null | tr -d '"')"
        fi
        if [[ -z "$protected_hotspot_scope" ]]; then
            protected_hotspot_scope="$(awk -F': ' '/^protected_hotspot_scope:/{print $2; exit}' "$heartbeat_file" 2>/dev/null | tr -d '"')"
        fi
    fi
    [[ -n "$normalized_scope" ]] || normalized_scope="$terminal_scope"

    checkout_root="$(git -C "$target_repo" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$checkout_root" ]] || checkout_root="$target_repo"
    repo_root="$checkout_root"
    branch="$(git -C "$checkout_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    [[ "$branch" == "HEAD" ]] && branch="<detached>"
    main_root="$(git -C "$SPINE_CODE" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$SPINE_CODE")"
    lane_type="$(resolve_lane_type_for_telemetry "$checkout_root" "$branch" "$main_root")"
    git_common_dir="$(git -C "$checkout_root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [[ -n "$git_common_dir" ]]; then
        git_index_path="${GIT_INDEX_FILE:-$git_common_dir/index}"
    else
        git_index_path=""
    fi

    now_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    expires_at="$(python3 - "$now_utc" <<'PY'
from datetime import datetime, timedelta, timezone
import sys

raw = (sys.argv[1] or "").strip()
dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
if dt.tzinfo is None:
    dt = dt.replace(tzinfo=timezone.utc)
print((dt.astimezone(timezone.utc) + timedelta(minutes=45)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
    hostname_value="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"

    {
        printf 'version: 1\n'
        printf 'terminal_id: "%s"\n' "$terminal_id"
        printf 'role: "%s"\n' "$terminal_type"
        printf 'execution_class: "%s"\n' "$execution_class"
        printf 'runtime_role: "%s"\n' "$execution_class"
        printf 'scope: "%s"\n' "$terminal_scope"
        printf 'normalized_scope: "%s"\n' "$normalized_scope"
        printf 'protected_hotspot_scope: "%s"\n' "$protected_hotspot_scope"
        printf 'loop_id: "%s"\n' "$loop_id"
        printf 'repo_root: "%s"\n' "$repo_root"
        printf 'checkout_root: "%s"\n' "$checkout_root"
        printf 'branch: "%s"\n' "$branch"
        printf 'lane_type: "%s"\n' "$lane_type"
        printf 'git_common_dir: "%s"\n' "$git_common_dir"
        printf 'git_index_path: "%s"\n' "$git_index_path"
        printf 'status: "active"\n'
        printf 'pid: %s\n' "$pid_value"
        printf 'hostname: "%s"\n' "$hostname_value"
        printf 'heartbeat_at: "%s"\n' "$now_utc"
        printf 'expires_at: "%s"\n' "$expires_at"
    } > "$heartbeat_file" 2>/dev/null || \
        echo "WARN: failed to write terminal custody heartbeat for $terminal_id" >&2
}

append_telemetry() {
    local name="$1"
    local safety="$2"
    local exit_code="$3"
    local telemetry_dir="$SPINE_STATE/telemetry"
    local terminals_dir="$SPINE_STATE/terminals"
    local session_boundary="${SPINE_SESSION_ID:-}"
    local terminal_id="${TERMINAL_ID:-$(current_terminal_id)}"

    if [[ -z "$session_boundary" && "$safety" == "mutating" ]]; then
        session_boundary="$(current_terminal_id)"
    fi
    [[ -n "$session_boundary" ]] || session_boundary="nosession"

    if [[ -z "$terminal_id" ]]; then
        local host_part pid_part identity_class
        host_part="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"
        host_part="$(printf '%s' "$host_part" | tr '[:space:]/' '__')"
        pid_part="$$"
        # Classify the caller: service/automation (launchd/systemd/cron parent)
        # vs ad-hoc shell invocation. This prevents service execution from
        # polluting terminal telemetry with pseudo-terminal identity.
        if [[ -n "${SPINE_SERVICE_ID:-}" ]]; then
            identity_class="service-${SPINE_SERVICE_ID}"
        elif [[ -n "${SPINE_SCHEDULER_LABEL:-}" ]]; then
            # Governed launchd/systemd scheduled job
            identity_class="scheduled-${SPINE_SCHEDULER_LABEL}"
        elif [[ -n "${INVOCATION_ID:-}" || -n "${SPINE_AUTONOMOUS_EXECUTION_CONTEXT:-}" ]]; then
            # INVOCATION_ID = systemd, SPINE_AUTONOMOUS_EXECUTION_CONTEXT = governed job wrapper
            identity_class="automation-${host_part}"
        else
            identity_class="adhoc-${host_part}"
        fi
        terminal_id="${identity_class}-${pid_part}"
    fi

    terminal_id="$(printf '%s' "$terminal_id" | tr '[:space:]/' '__')"

    mkdir -p "$telemetry_dir" 2>/dev/null || true
    mkdir -p "$terminals_dir" 2>/dev/null || true
    {
        printf 'terminal_id: %s\n' "$terminal_id"
        printf 'last_heartbeat_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'last_capability: %s\n' "$name"
        printf 'last_exit_code: %s\n' "$exit_code"
        printf 'source: cap.run\n'
    } > "$terminals_dir/$terminal_id.heartbeat" 2>/dev/null || \
        echo "WARN: failed to write terminal heartbeat for $terminal_id" >&2
    write_terminal_custody_heartbeat "$terminal_id"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$name" \
      "$safety" \
      "$exit_code" \
      "$session_boundary" \
      >> "$telemetry_dir/cap-usage.tsv" 2>/dev/null || true
}

resolve_prompt_lineage() {
    local capability_name="$1"
    local prompt_registry="$SPINE_CODE/ops/bindings/prompt.registry.yaml"
    local prompt_override_exists=""
    local prompt_ref=""
    local prompt_abs=""
    local prompt_ref_hash=""

    PROMPT_LINEAGE_SET="unregistered"
    PROMPT_LINEAGE_VERSION="none"
    PROMPT_LINEAGE_HASH="none"
    PROMPT_LINEAGE_RESOLUTION="missing_registry"
    PROMPT_LINEAGE_REGISTRY_REL="ops/bindings/prompt.registry.yaml"
    PROMPT_LINEAGE_SOURCE_REFS=()
    PROMPT_LINEAGE_SOURCE_HASH_LINES=()
    PROMPT_LINEAGE_SOURCE_HASH_PAIRS=()

    if ! command -v yq >/dev/null 2>&1 || [[ ! -f "$prompt_registry" ]]; then
        return 0
    fi

    prompt_override_exists="$(yq e -r ".capability_overrides.\"$capability_name\" != null" "$prompt_registry" 2>/dev/null || echo "false")"
    if [[ "$prompt_override_exists" == "true" ]]; then
        PROMPT_LINEAGE_RESOLUTION="capability_override"
    else
        PROMPT_LINEAGE_RESOLUTION="defaults"
    fi

    PROMPT_LINEAGE_SET="$(yq e -r ".capability_overrides.\"$capability_name\".prompt_set_id // .defaults.prompt_set_id // \"unregistered\"" "$prompt_registry" 2>/dev/null || echo "unregistered")"
    PROMPT_LINEAGE_VERSION="$(yq e -r ".capability_overrides.\"$capability_name\".version // .defaults.version // \"none\"" "$prompt_registry" 2>/dev/null || echo "none")"

    while IFS= read -r prompt_ref; do
        [[ -z "${prompt_ref:-}" || "${prompt_ref:-}" == "null" ]] && continue
        PROMPT_LINEAGE_SOURCE_REFS+=("$prompt_ref")
        prompt_abs="$SPINE_CODE/$prompt_ref"
        if [[ -f "$prompt_abs" ]]; then
            prompt_ref_hash="$(shasum -a 256 "$prompt_abs" | awk '{print $1}')"
        else
            prompt_ref_hash="missing"
        fi
        PROMPT_LINEAGE_SOURCE_HASH_LINES+=("$prompt_ref:$prompt_ref_hash")
        PROMPT_LINEAGE_SOURCE_HASH_PAIRS+=("$prompt_ref"$'\t'"$prompt_ref_hash")
    done < <(yq e -r "(.capability_overrides.\"$capability_name\".source_refs // .defaults.source_refs // [])[]?" "$prompt_registry" 2>/dev/null || true)

    if (( ${#PROMPT_LINEAGE_SOURCE_HASH_LINES[@]} > 0 )); then
        PROMPT_LINEAGE_HASH="$(printf '%s\n' "${PROMPT_LINEAGE_SOURCE_HASH_LINES[@]}" | shasum -a 256 | awk '{print $1}')"
    fi
}

write_cap_receipt() {
    local capability_name="$1"
    local safety="$2"
    local cmd="$3"
    local cwd="$4"
    local run_key="$5"
    local start_time="$6"
    local end_time="$7"
    local exit_code="$8"
    local output_file="$9"
    shift 9
    # Bash 3.2 + nounset can trip on local array assignment with zero args.
    local -a args=()
    local arg_count=0
    if [[ "$#" -gt 0 ]]; then
        args=("$@")
        arg_count=${#args[@]}
    fi

    local receipt_dir="$SPINE_RECEIPTS/R${run_key}"
    local receipt_path="$receipt_dir/receipt.md"
    local output_path="$receipt_dir/output.txt"
    local exec_receipt_path="$receipt_dir/receipt.exec.json"
    local attestation_path="$receipt_dir/receipt.attestation.json"
    local receipt_status="failed"
    local blocker_class="deterministic"
    local ready_for_verify="false"
    local output_hash=""
    local receipt_hash=""
    local exec_receipt_hash=""
    local execution_class
    execution_class="$(current_execution_class)"
    local terminal_id="${TERMINAL_ID:-$(current_terminal_id)}"
    local lane_id="${SPINE_LANE:-execution}"
    local args_display="none"
    local source_refs_csv="none"
    local governance_version="SPINE.md@unknown"
    local governance_last_verified=""
    local execution_host=""
    local execution_mode="${SPINE_EXECUTION_MODE:-capability}"
    local blocker_reason="${CAP_BLOCKER_REASON:-none}"
    local role_policy_enforced="${CAP_ROLE_POLICY_ENFORCED:-false}"
    local role_policy_override_used="${CAP_ROLE_POLICY_OVERRIDE_USED:-false}"
    local role_policy_override_ref="${CAP_ROLE_POLICY_OVERRIDE_REF:-none}"
    local role_policy_override_reason="${CAP_ROLE_POLICY_OVERRIDE_REASON:-none}"

    mkdir -p "$receipt_dir"
    cp "$output_file" "$output_path"

    if [[ "$exit_code" -eq 0 ]]; then
        receipt_status="done"
        blocker_class="none"
        ready_for_verify="true"
    fi

    if (( ${#args[@]} > 0 )); then
        args_display="${args[*]}"
    fi
    if (( ${#PROMPT_LINEAGE_SOURCE_REFS[@]} > 0 )); then
        source_refs_csv="$(IFS=,; echo "${PROMPT_LINEAGE_SOURCE_REFS[*]}")"
    fi

    output_hash="$(shasum -a 256 "$output_path" | awk '{print $1}')"

    cat > "$receipt_path" <<EOF
# Receipt: $run_key

| Field | Value |
|-------|-------|
| Run ID | \`$run_key\` |
| Capability | \`$capability_name\` |
| Status | $receipt_status |
| Exit Code | $exit_code |
| Generated | $end_time |
| Model | local (capability) |
| Context | $safety |
| Blocker Reason | $blocker_reason |
| Execution Class | ${execution_class:-unknown} |
| Role Policy Enforced | $role_policy_enforced |
| Role Policy Override Used | $role_policy_override_used |
| Role Policy Override Ref | $role_policy_override_ref |
| Role Policy Override Reason | $role_policy_override_reason |
| Prompt Set ID | ${PROMPT_LINEAGE_SET:-unregistered} |
| Prompt Version | ${PROMPT_LINEAGE_VERSION:-none} |
| Prompt Source Hash | ${PROMPT_LINEAGE_HASH:-none} |
| Prompt Resolution | ${PROMPT_LINEAGE_RESOLUTION:-missing_registry} |
| Prompt Registry | ${PROMPT_LINEAGE_REGISTRY_REL:-none} |

## Inputs

| Field | Value |
|-------|-------|
| Command | \`$cmd ${args[*]:-}\` |
| CWD | \`$cwd\` |
| Args | \`$args_display\` |
| Prompt Sources | \`$source_refs_csv\` |

## Outputs

| File | Hash |
|------|------|
| output.txt | \`$output_hash\` |

## Timestamps

| Event | Time |
|-------|------|
| Start | $start_time |
| End | $end_time |

---

_Receipt written by ops cap_
EOF

    case "$lane_id" in
        control|execution|audit|watcher) ;;
        *) lane_id="execution" ;;
    esac
    if [[ -f "$SPINE_CODE/docs/governance/SPINE.md" ]]; then
        governance_last_verified="$(awk '/^last_verified:/{print $2; exit}' "$SPINE_CODE/docs/governance/SPINE.md" 2>/dev/null | tr -d '"')"
        if [[ -n "$governance_last_verified" ]]; then
            governance_version="SPINE.md@${governance_last_verified}"
        fi
    fi
    execution_host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"

    CAP_TASK_ID="$capability_name" \
    CAP_TERMINAL_ID="$terminal_id" \
    CAP_LANE="$lane_id" \
    CAP_STATUS="$receipt_status" \
    CAP_RECEIPT_PATH="$receipt_path" \
    CAP_OUTPUT_PATH="$output_path" \
    CAP_EXEC_RECEIPT_PATH="$exec_receipt_path" \
    CAP_ATTESTATION_PATH="$attestation_path" \
    CAP_RUN_KEY="$run_key" \
    CAP_TIMESTAMP_UTC="$end_time" \
    CAP_READY_FOR_VERIFY="$ready_for_verify" \
    CAP_BLOCKER_CLASS="$blocker_class" \
    CAP_LOOP_ID="${SPINE_LOOP_ID:-}" \
    CAP_WAVE_ID="${SPINE_WAVE_ID:-}" \
    CAP_EXECUTION_HOST="$execution_host" \
    CAP_EXECUTION_MODE="$execution_mode" \
    CAP_EXECUTION_CLASS="$execution_class" \
    CAP_RUNTIME_ROLE="$execution_class" \
    CAP_GOVERNANCE_VERSION="$governance_version" \
    CAP_ENTRY_PACKET_PATH="${SPINE_ENTRY_PACKET_PATH:-}" \
    CAP_ENTRY_PACKET_HASH="${SPINE_ENTRY_PACKET_HASH:-none}" \
    CAP_PROMPT_SET_ID="${PROMPT_LINEAGE_SET:-unregistered}" \
    CAP_PROMPT_VERSION="${PROMPT_LINEAGE_VERSION:-none}" \
    CAP_PROMPT_SOURCE_HASH="${PROMPT_LINEAGE_HASH:-none}" \
    CAP_PROMPT_REGISTRY_PATH="${PROMPT_LINEAGE_REGISTRY_REL:-ops/bindings/prompt.registry.yaml}" \
    CAP_PROMPT_RESOLUTION="${PROMPT_LINEAGE_RESOLUTION:-missing_registry}" \
    CAP_PROMPT_SOURCE_REFS_NL="$(printf '%s\n' "${PROMPT_LINEAGE_SOURCE_REFS[@]:-}")" \
    CAP_PROMPT_SOURCE_HASH_PAIRS_NL="$(printf '%s\n' "${PROMPT_LINEAGE_SOURCE_HASH_PAIRS[@]:-}")" \
    python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path

receipt_path = Path(os.environ["CAP_RECEIPT_PATH"])
output_path = Path(os.environ["CAP_OUTPUT_PATH"])
exec_receipt_path = Path(os.environ["CAP_EXEC_RECEIPT_PATH"])
attestation_path = Path(os.environ["CAP_ATTESTATION_PATH"])

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()

source_refs = [row for row in os.environ.get("CAP_PROMPT_SOURCE_REFS_NL", "").splitlines() if row]
source_hashes = {}
for row in os.environ.get("CAP_PROMPT_SOURCE_HASH_PAIRS_NL", "").splitlines():
    if not row:
        continue
    key, _, value = row.partition("\t")
    if key:
        source_hashes[key] = value or "missing"

status = os.environ["CAP_STATUS"]
checks_passed = ["receipt_markdown_present", "receipt_exec_present", "output_present"]
checks_passed.append(f"verdict_{status}")

exec_payload = {
    "task_id": os.environ["CAP_TASK_ID"],
    "terminal_id": os.environ["CAP_TERMINAL_ID"],
    "lane": os.environ["CAP_LANE"],
    "status": status,
    "files_changed": [str(receipt_path), str(output_path)],
    "run_keys": [os.environ["CAP_RUN_KEY"]],
    "blockers": [],
    "ready_for_verify": os.environ["CAP_READY_FOR_VERIFY"].lower() == "true",
    "timestamp_utc": os.environ["CAP_TIMESTAMP_UTC"],
    "evidence_refs": {
        "run_key_refs": [os.environ["CAP_RUN_KEY"]],
        "file_refs": [str(receipt_path), str(output_path)],
        "commit_refs": [],
        "blocker_class": os.environ["CAP_BLOCKER_CLASS"],
    },
    "prompt_lineage": {
        "prompt_set_id": os.environ["CAP_PROMPT_SET_ID"],
        "version": os.environ["CAP_PROMPT_VERSION"],
        "source_refs": source_refs,
        "source_hash": os.environ["CAP_PROMPT_SOURCE_HASH"],
        "source_hashes": source_hashes,
        "registry_path": os.environ["CAP_PROMPT_REGISTRY_PATH"],
        "resolution": os.environ["CAP_PROMPT_RESOLUTION"],
    },
}

# Canonical outcome — maps status to outcome vocabulary
# Authority: closeout.disposition.contract.yaml outcome_vocabulary
_STATUS_OUTCOME = {"done": "success", "failed": "failure", "blocked": "blocked"}
exec_payload["outcome"] = _STATUS_OUTCOME.get(status, "failure")

loop_id = os.environ.get("CAP_LOOP_ID", "").strip()
if loop_id:
    exec_payload["loop_id"] = loop_id
wave_id = os.environ.get("CAP_WAVE_ID", "").strip()
if wave_id:
    exec_payload["wave_id"] = wave_id

exec_receipt_path.write_text(json.dumps(exec_payload, indent=2) + "\n", encoding="utf-8")

# Attestation is a derived governance envelope around exec.json.
# Authority hierarchy: exec.json is canonical for execution truth
# (status, outcome, evidence_refs, prompt_lineage). Attestation adds
# governance context (host, role, checks, packet provenance) and
# references exec.json by hash. It does NOT duplicate exec fields.
attestation_payload = {
    "schema_version": "1.1",
    "request_id": os.environ["CAP_RUN_KEY"],
    "capability": os.environ["CAP_TASK_ID"],
    "generated_at_utc": os.environ["CAP_TIMESTAMP_UTC"],
    "loop_id": loop_id,
    "entry_packet_path": os.environ.get("CAP_ENTRY_PACKET_PATH", ""),
    "entry_packet_hash": os.environ.get("CAP_ENTRY_PACKET_HASH", "none"),
    "governance_version": os.environ.get("CAP_GOVERNANCE_VERSION", "SPINE.md@unknown"),
    "execution_host": os.environ.get("CAP_EXECUTION_HOST", "unknown-host"),
    "execution_mode": os.environ.get("CAP_EXECUTION_MODE", "capability"),
    "execution_class": os.environ.get("CAP_EXECUTION_CLASS", os.environ.get("CAP_RUNTIME_ROLE", "worker")),
    "runtime_role": os.environ.get("CAP_RUNTIME_ROLE", "worker"),
    "completion_level": "",
    "checks_passed": checks_passed,
    "checks_failed": [],
    "receipts": {
        "markdown": {"path": str(receipt_path), "sha256": sha256(receipt_path)},
        "exec": {"path": str(exec_receipt_path), "sha256": sha256(exec_receipt_path)},
        "output": {"path": str(output_path), "sha256": sha256(output_path)},
    },
}
attestation_path.write_text(json.dumps(attestation_payload, indent=2) + "\n", encoding="utf-8")
PY

    receipt_hash="$(shasum -a 256 "$receipt_path" | awk '{print $1}')"
    exec_receipt_hash="$(shasum -a 256 "$exec_receipt_path" | awk '{print $1}')"

    if [[ -z "$receipt_hash" || -z "$exec_receipt_hash" ]]; then
        echo "WARN: cap receipt hashing incomplete for $run_key" >&2
    fi
}

build_command_string() {
    local base="$1"
    shift || true
    local full="$base"
    local arg

    for arg in "$@"; do
        full+=" $(printf '%q' "$arg")"
    done

    printf '%s\n' "$full"
}

execute_command() {
    local command_string="$1"
    local cwd="$2"
    local run_key="$3"

    (
        cd "$cwd"
        export SPINE_TARGET_REPO="$SPINE_TARGET_REPO"
        export SPINE_REPO="$SPINE_REPO"
        export SPINE_CODE="$SPINE_CODE"
        export SPINE_ROOT="$SPINE_CODE"
        export SPINE_CAP_RUN_KEY="$run_key"
        eval "$command_string"
    )
}

run_cap() {
    local name="$1"
    shift || true

    # Bash 3.2 + nounset can trip on local array assignment with zero args.
    local -a args=()
    local arg_count=0
    if [[ "$#" -gt 0 ]]; then
        args=("$@")
        arg_count=${#args[@]}
    fi
    if [[ "${#args[@]}" -gt 0 && "${args[0]}" == "--" ]]; then
        args=("${args[@]:1}")
        arg_count=${#args[@]}
    fi

    ensure_runtime_dirs

    if ! yaml_query -e "$CAP_FILE" ".capabilities.\"$name\"" 2>/dev/null; then
        echo "ERROR: Unknown capability: $name"
        echo "Run 'ops cap list' to see available capabilities."
        exit 1
    fi

    local requires_list=()
    local requires_json
    requires_json="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".requires")"
    while IFS= read -r req; do
        [[ -z "${req:-}" || "${req:-}" == "null" ]] && continue
        requires_list+=("$req")
    done < <(printf '%s\n' "${requires_json:-[]}" | jq -r '.[]?' 2>/dev/null || true)

    local cmd
    cmd="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".command")"
    local script_path
    script_path="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".script_path")"
    local cwd
    cwd="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".cwd")"
    [[ -z "$cwd" || "$cwd" == "null" ]] && cwd="$HOME"
    cwd="$(expand_runtime_value "$cwd")"

    local safety
    safety="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".safety")"
    local approval
    approval="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".approval")"
    local desc
    desc="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".description")"
    local arg_protocol
    arg_protocol="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".arg_protocol")"
    [[ -n "$arg_protocol" && "$arg_protocol" != "null" ]] || arg_protocol="passthrough"
    local post_action
    post_action="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".post_action")"

    case "$arg_protocol" in
      passthrough|argparse|positional|none) ;;
      *)
        echo "ERROR: capability '$name' has invalid arg_protocol '$arg_protocol' (expected passthrough|argparse|positional|none)"
        exit 1
        ;;
    esac

    if [[ "$arg_protocol" == "none" && "${#args[@]}" -gt 0 ]]; then
        echo "ERROR: capability '$name' declares arg_protocol=none but received args: ${args[*]}"
        exit 2
    fi

    if [[ "$arg_protocol" == "positional" ]]; then
        local positional_arg
        for positional_arg in "${args[@]:-}"; do
            if [[ "$positional_arg" == -* ]]; then
                echo "ERROR: capability '$name' declares arg_protocol=positional and does not accept flag arg '$positional_arg'"
                exit 2
            fi
        done
    fi

    validate_cap_target "$name" "$cmd" "$script_path" "$cwd"

    local ts rand run_key
    ts="$(date +%Y%m%d-%H%M%S)"
    rand="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 4 || echo "$$")"
    run_key="CAP-${ts}__${name}__R${rand}"
    local start_time end_time output_file receipt_path output_path
    start_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    output_file="$(mktemp "${TMPDIR:-/tmp}/cap_${run_key}.XXXXXX")"

    echo "════════════════════════════════════════"
    echo "CAPABILITY: $name"
    echo "════════════════════════════════════════"
    echo "Description: $desc"
    echo "Safety:      $safety"
    echo "Approval:    $approval"
    echo "Arg Protocol:$arg_protocol"
    echo "Run Key:     $run_key"
    echo "Command:     $cmd ${args[*]:-}"
    echo "CWD:         $cwd"
    echo ""

    if ! evaluate_role_policy "$name" "$safety"; then
        rc=3
        emit_role_policy_stop "$name" "$safety" | tee "$output_file"
        end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        resolve_prompt_lineage "$name"
        if (( arg_count > 0 )); then
            write_cap_receipt "$name" "$safety" "$cmd" "$cwd" "$run_key" "$start_time" "$end_time" "$rc" "$output_file" "${args[@]}"
        else
            write_cap_receipt "$name" "$safety" "$cmd" "$cwd" "$run_key" "$start_time" "$end_time" "$rc" "$output_file"
        fi
        receipt_path="$SPINE_RECEIPTS/R${run_key}/receipt.md"
        output_path="$SPINE_RECEIPTS/R${run_key}/output.txt"
        rm -f "$output_file"
        append_telemetry "$name" "$safety" "$rc"

        echo ""
        echo "════════════════════════════════════════"
        echo "FAILED"
        echo "════════════════════════════════════════"
        echo "Run Key:  $run_key"
        echo "Receipt:  $receipt_path"
        echo "Output:   $output_path"
        echo "Exit:     $rc"

        return "$rc"
    fi

    local previous_stack="${OPS_CAP_STACK:-}"
    local cycle_stack=",${previous_stack},${name},"
    local req rc

    if (( ${#requires_list[@]} > 0 )); then
        export OPS_CAP_STACK="${previous_stack:+$previous_stack,}$name"
        for req in "${requires_list[@]}"; do
            if [[ "$cycle_stack" == *",${req},"* ]]; then
                export OPS_CAP_STACK="$previous_stack"
                echo "ERROR: requires cycle detected: ${name} -> ${req}"
                exit 1
            fi

            echo "== PRECONDITION: ${req} =="
            set +e
            "$SPINE_CODE/bin/ops" cap run "$req"
            rc=$?
            set -e
            if [[ "$rc" -ne 0 ]]; then
                export OPS_CAP_STACK="$previous_stack"
                echo "STOP: precondition failed: ${req} (exit=$rc)"
                append_telemetry "$name" "$safety" "$rc"
                return "$rc"
            fi
            echo ""
        done
        export OPS_CAP_STACK="$previous_stack"
    fi

    local command_string
    if (( arg_count > 0 )); then
        command_string="$(build_command_string "$cmd" "${args[@]}")"
    else
        command_string="$(build_command_string "$cmd")"
    fi

    echo "Executing..."
    echo "────────────────────────────────────────"
    set +e
    execute_command "$command_string" "$cwd" "$run_key" 2>&1 | tee "$output_file"
    rc=$?
    set -e
    echo "────────────────────────────────────────"

    if [[ "$rc" -eq 0 && -n "${post_action:-}" && "$post_action" != "null" ]]; then
        echo ""
        echo "== POST-ACTION: ${post_action} =="
        echo "────────────────────────────────────────"
        set +e
        "$SPINE_CODE/bin/ops" cap run "$post_action" 2>&1 | tee -a "$output_file"
        local post_rc=$?
        set -e
        if [[ "$post_rc" -eq 0 ]]; then
            echo "POST-ACTION OK: ${post_action}"
        else
            echo "POST-ACTION WARN: ${post_action} failed (non-blocking)"
        fi
        echo "────────────────────────────────────────"
    fi

    end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    resolve_prompt_lineage "$name"
    if (( arg_count > 0 )); then
        write_cap_receipt "$name" "$safety" "$cmd" "$cwd" "$run_key" "$start_time" "$end_time" "$rc" "$output_file" "${args[@]}"
    else
        write_cap_receipt "$name" "$safety" "$cmd" "$cwd" "$run_key" "$start_time" "$end_time" "$rc" "$output_file"
    fi
    receipt_path="$SPINE_RECEIPTS/R${run_key}/receipt.md"
    output_path="$SPINE_RECEIPTS/R${run_key}/output.txt"
    rm -f "$output_file"

    append_telemetry "$name" "$safety" "$rc"

    echo ""
    echo "════════════════════════════════════════"
    if [[ "$rc" -eq 0 ]]; then
        echo "DONE"
    else
        echo "FAILED"
    fi
    echo "════════════════════════════════════════"
    echo "Run Key:  $run_key"
    echo "Receipt:  $receipt_path"
    echo "Output:   $output_path"
    echo "Exit:     $rc"

    return "$rc"
}

main() {
    check_deps

    case "${1:-}" in
        list)
            shift
            list_caps "$@"
            ;;
        run)
            shift
            [[ $# -ge 1 ]] || { usage >&2; exit 2; }
            run_cap "$@"
            ;;
        show)
            shift
            [[ $# -ge 1 ]] || { usage >&2; exit 2; }
            show_cap "$@"
            ;;
        -h|--help|"")
            usage
            ;;
        *)
            echo "ops cap: unknown subcommand '${1:-}'" >&2
            echo >&2
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
