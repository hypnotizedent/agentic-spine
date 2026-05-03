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

SPINE_TARGET_REPO="${VALID_AMBIENT_TARGET_REPO:-${ACTIVE_CODE_ROOT:-${SPINE_REPO:-${SPINE_CODE:-$SCRIPT_CODE_ROOT}}}}"
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
  ops cap list [options]          List available capabilities
  ops cap run <name> [args...]    Execute a capability
  ops cap show <name>             Show capability details

Examples:
  ops cap list
  ops cap list --all
  ops cap list --execution-class worker
  ops cap run spine.verify
  ops cap run monolith.search "TODO" agentic-spine
  ops cap show infra.docker_ps

List options:
  --all                           Show all live capabilities, not just those legal for the current execution class
  --include-retired               Include retired historical registry rows
  --execution-class <id>          Resolve visibility as if running under a different execution class
  --json                          Machine-readable capability list
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

    # ── Membrane/translator compatibility posture: full execution block ───
    # membrane.authority.contract.yaml forbids ALL capability execution,
    # verification authority, loop advancement, and dispatch — not just
    # mutating caps. This gate fires before the safety-class check so that
    # translator compatibility sessions cannot run ANY cap without explicit override.
    session_posture="${SPINE_SESSION_POSTURE:-}"
    if [[ "$session_posture" == "translator" && "$CAP_ROLE_POLICY_OVERRIDE_USED" != "true" ]]; then
        CAP_BLOCKER_REASON="translator_posture_execution_forbidden"
        CAP_ROLE_POLICY_BLOCK_REASON="$CAP_BLOCKER_REASON"
        CAP_ROLE_POLICY_BLOCK_MESSAGE="session posture 'translator' (membrane compatibility role) cannot execute capabilities — re-enter on a controller or worker surface"
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
        next_step="re-enter on a controller or worker surface; translator/membrane posture cannot execute any capability. Override only with governed justification via $override_env and $override_reason_env"
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
    local show_all=0
    local include_retired=0
    local json_mode=0
    local requested_execution_class=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                show_all=1
                shift
                ;;
            --include-retired)
                include_retired=1
                shift
                ;;
            --execution-class)
                requested_execution_class="${2:?--execution-class requires a value}"
                shift 2
                ;;
            --json)
                json_mode=1
                shift
                ;;
            -h|--help)
                usage
                return 0
                ;;
            *)
                echo "ops cap list: unknown argument '$1'" >&2
                return 2
                ;;
        esac
    done

    local execution_class="${requested_execution_class:-$(current_execution_class)}"

    python3 - "$CAP_FILE" "$ROLE_POLICY_CONTRACT" "$execution_class" "$show_all" "$include_retired" "$json_mode" <<'PY'
import json
import sys
from pathlib import Path

import yaml

cap_file = Path(sys.argv[1])
policy_file = Path(sys.argv[2])
execution_class = sys.argv[3] or "researcher"
show_all = sys.argv[4] == "1"
include_retired = sys.argv[5] == "1"
json_mode = sys.argv[6] == "1"

reg = yaml.safe_load(cap_file.read_text(encoding="utf-8")) or {}
caps = reg.get("capabilities") or {}
policy = {}
if policy_file.is_file():
    policy = yaml.safe_load(policy_file.read_text(encoding="utf-8")) or {}
runtime_roles = policy.get("runtime_roles") or {}
read_only_roles = set(runtime_roles.get("read_only_roles") or [])
allowlist_by_role = runtime_roles.get("mutating_capability_allowlist_by_role") or {}
allowlist = set(allowlist_by_role.get(execution_class) or [])

rows = []
hidden_blocked = 0
hidden_retired = 0
live_total = 0
retired_total = 0

for name in sorted(caps):
    payload = caps.get(name) or {}
    if not isinstance(payload, dict):
        payload = {}
    lifecycle = str(payload.get("lifecycle") or "ready").strip() or "ready"
    safety = str(payload.get("safety") or "").strip()
    desc = str(payload.get("description") or "").strip()
    retired = lifecycle.lower() == "retired"
    if retired:
        retired_total += 1
    else:
        live_total += 1

    legal = True
    visibility_reason = "readable"
    allowlisted_mutation = False
    if safety in {"mutating", "destructive"} and execution_class in read_only_roles:
        if name in allowlist:
            allowlisted_mutation = True
            visibility_reason = "allowlisted_mutation"
        else:
            legal = False
            visibility_reason = "blocked_by_execution_class"

    if retired and not include_retired:
        hidden_retired += 1
        continue
    if not show_all and not legal:
        hidden_blocked += 1
        continue

    rows.append(
        {
            "name": name,
            "safety": safety,
            "description": desc,
            "lifecycle": lifecycle,
            "retired": retired,
            "legal_for_execution_class": legal,
            "allowlisted_mutation": allowlisted_mutation,
            "visibility_reason": visibility_reason,
        }
    )

if json_mode:
    print(
        json.dumps(
            {
                "execution_class": execution_class,
                "view": (
                    "all_with_retired"
                    if show_all and include_retired
                    else "all_live"
                    if show_all
                    else "legal_live_only"
                ),
                "counts": {
                    "shown": len(rows),
                    "live_total": live_total,
                    "retired_total": retired_total,
                    "hidden_blocked": hidden_blocked,
                    "hidden_retired": hidden_retired,
                },
                "capabilities": rows,
            },
            indent=2,
            sort_keys=True,
        )
    )
    raise SystemExit(0)

view = (
    "all live + retired"
    if show_all and include_retired
    else "all live"
    if show_all
    else "live + legal for current execution class"
)

print("=== AVAILABLE CAPABILITIES ===")
print("")
print(f"Execution Class: {execution_class}")
print(f"View:            {view}")
print(f"Shown:           {len(rows)}")
print(f"Live Registry:   {live_total}")
if hidden_blocked or hidden_retired or retired_total:
    print(
        "Hidden:          "
        f"{hidden_blocked} blocked by execution class, "
        f"{hidden_retired} retired"
    )
print("")

for row in rows:
    label = row["safety"] or "unknown"
    if row["retired"]:
        label += " retired"
    elif row["allowlisted_mutation"]:
        label += " allowlisted"
    elif show_all and not row["legal_for_execution_class"]:
        label += f" blocked:{execution_class}"
    print(f"  {row['name']:<25} [{label}] {row['description']}")

print("")
print("Run: ops cap run <name> [args...]")
if not show_all or not include_retired:
    print("Full registry: ops cap list --all --include-retired")
PY
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
    # Mid-session claim preservation: a non-empty loop_id already on disk
    # represents the most recent governed claim (terminal.loop.claim) and
    # outranks the launch-time env. The liveness guard below still fires.
    if [[ -f "$heartbeat_file" ]]; then
        local file_loop_id
        file_loop_id="$(awk -F': ' '/^loop_id:/{gsub(/"/,"",$2); print $2; exit}' "$heartbeat_file" 2>/dev/null)"
        if [[ -n "$file_loop_id" ]]; then
            loop_id="$file_loop_id"
        fi
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

# Phase D.3a: DB authority routing (INERT BY DEFAULT).
#
# Reads runtime.bootstrap.contract.yaml#db_authority. When `enabled: false`
# (the D.3a default state), this function returns 126 immediately and all
# capabilities run locally — identical to pre-D.3 behavior.
#
# When the operator flips db_authority.enabled to true (Phase D.3b cutover),
# this function evaluates whether the local host should route the cap:
#   - If local hostname matches any entry in db_authority.authority_hostnames,
#     the local host IS the authority; runs locally (return 126).
#   - If the cap's safety class is read-only or read-only-with-cache, runs
#     locally (return 126).
#   - Otherwise, executes the cap on the authority host via SSH and returns
#     the routed cap's exit code. The remote host writes its own RCAP receipt
#     locally on the authority host.
#
# Return code convention:
#   126 = NOT routed (caller should run locally — fall through to existing path)
#   any other code = routed; this is the routed-cap's actual exit code; caller
#   should propagate it without writing a local receipt.
#
# Failure semantics: if all declared SSH authority routes are unreachable AND
# db_authority.enabled is true, this function returns a non-126 non-zero code
# and the caller propagates it — there is NO silent fallback to local DB writes.
_route_to_db_authority_if_needed() {
    local cap_name="$1"
    shift || true
    local cap_args=("$@")

    local contract="$SPINE_CODE/ops/bindings/runtime.bootstrap.contract.yaml"
    if [[ ! -f "$contract" ]]; then
        return 126
    fi
    if ! command -v yq >/dev/null 2>&1; then
        return 126
    fi

    local enabled
    enabled="$(yq e '.db_authority.enabled // false' "$contract" 2>/dev/null)"
    if [[ "$enabled" != "true" ]]; then
        return 126
    fi

    local local_hostname
    local_hostname="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "")"

    local authority_hostnames
    authority_hostnames="$(yq e '.db_authority.authority_hostnames // [] | join(",")' "$contract" 2>/dev/null)"
    if [[ -n "$authority_hostnames" && "$authority_hostnames" != "null" \
          && ",${authority_hostnames}," == *",${local_hostname},"* ]]; then
        return 126
    fi

    local cap_safety
    cap_safety="$(yq e ".capabilities.\"${cap_name}\".safety // \"\"" \
        "$SPINE_CODE/ops/capabilities.yaml" 2>/dev/null)"

    # Routing decision (D.3c read-path extension):
    # - mutating/destructive: always route (writes need authority), UNLESS the
    #   cap declares routing.db_authority: skip — used by mutating caps that
    #   target an external system (e.g., gitea API) and do not touch
    #   shared_authority.db. Default for mutating remains route-to-authority.
    # - read-only/read-only-with-cache: route only if cap.state_authority == "shared_authority_db"
    # - other: stay local
    # Caps without state_authority declared default to local for read-only — but
    # any DB-backed cap that lacks the annotation will be caught by the
    # lib-level db_authority_guard and fail closed at sqlite open time, so the
    # disease cannot land silently. D447 verify enforces the annotation.
    if [[ "$cap_safety" == "mutating" || "$cap_safety" == "destructive" ]]; then
        local cap_db_routing
        cap_db_routing="$(yq e ".capabilities.\"${cap_name}\".routing.db_authority // \"\"" \
            "$SPINE_CODE/ops/capabilities.yaml" 2>/dev/null)"
        if [[ "$cap_db_routing" == "skip" ]]; then
            return 126
        fi
        : # route (fall through to SSH dispatch below)
    elif [[ "$cap_safety" == "read-only" || "$cap_safety" == "read-only-with-cache" ]]; then
        local cap_state_authority
        cap_state_authority="$(yq e ".capabilities.\"${cap_name}\".state_authority // \"\"" \
            "$SPINE_CODE/ops/capabilities.yaml" 2>/dev/null)"
        if [[ "$cap_state_authority" != "shared_authority_db" ]]; then
            return 126
        fi
    else
        return 126
    fi

    local user host_addr host_addr_tailscale code_path key_path
    user="${SPINE_DB_AUTHORITY_USER:-$(yq e '.db_authority.user // "root"' "$contract" 2>/dev/null)}"
    host_addr="${SPINE_DB_AUTHORITY_HOST_ADDR:-$(yq e '.db_authority.host_addr_lan // ""' "$contract" 2>/dev/null)}"
    host_addr_tailscale="${SPINE_DB_AUTHORITY_HOST_ADDR_TAILSCALE:-$(yq e '.db_authority.host_addr_tailscale // ""' "$contract" 2>/dev/null)}"
    code_path="${SPINE_DB_AUTHORITY_CODE:-$(yq e '.db_authority.code_path // "/opt/agentic-spine"' "$contract" 2>/dev/null)}"
    key_path="${SPINE_DB_AUTHORITY_SSH_KEY:-$(yq e ".db_authority.per_host_ssh_key.\"${local_hostname}\" // \"\"" "$contract" 2>/dev/null)}"
    local connect_timeout
    connect_timeout="$(yq e '.db_authority.ssh_connect_timeout_seconds // 10' "$contract" 2>/dev/null)"

    if [[ -z "$host_addr" || "$host_addr" == "null" ]]; then
        echo "cap.sh: db_authority routing enabled but host_addr is empty (db_authority.host_addr_lan)" >&2
        return 1
    fi

    local quoted_args=""
    local arg
    for arg in "${cap_args[@]}"; do
        quoted_args+=" $(printf %q "$arg")"
    done

    # B2.5: forward canonical admission identity across SSH dispatch so the
    # remote admission guard reads the same bound badge as the caller. Per
    # role.runtime.control.contract.yaml, the role-policy guard checks
    # SPINE_TERMINAL_ID, SPINE_EXECUTION_CLASS, and SPINE_SESSION_POSTURE.
    # Only those canonical admission vars are forwarded; aliases, broad shell
    # env, and secrets stay local. Forwarded only when set locally — never
    # invents identity, so unbound callers still hit the unbound-identity gate
    # on the remote. Distinct from the SPINE_ROLE_POLICY_OVERRIDE_* path below,
    # which is the governed override channel, not the normal admission badge.
    local admission_prefix=""
    local _resolved_terminal_id _resolved_execution_class
    _resolved_terminal_id="$(current_terminal_id)"
    _resolved_execution_class="${SPINE_EXECUTION_CLASS:-${SPINE_RUNTIME_ROLE:-}}"
    if [[ -n "$_resolved_terminal_id" ]]; then
        admission_prefix+="export SPINE_TERMINAL_ID=$(printf %q "$_resolved_terminal_id") && "
    fi
    if [[ -n "$_resolved_execution_class" ]]; then
        admission_prefix+="export SPINE_EXECUTION_CLASS=$(printf %q "$_resolved_execution_class") && "
    fi
    if [[ -n "${SPINE_SESSION_POSTURE:-}" ]]; then
        admission_prefix+="export SPINE_SESSION_POSTURE=$(printf %q "$SPINE_SESSION_POSTURE") && "
    fi

    # PACKET-592 Phase 2: forward SPINE_ROLE_POLICY_OVERRIDE_* env vars across
    # the SSH dispatch so admission overrides set by the caller (e.g., the
    # PACKET-592 clerk filing friction records) reach the routed cap on the
    # authority host. Without this, mutating routed caps fail with admission
    # gate refused even when the caller had a governed override locally.
    # Only the named override env vars are forwarded — no wildcard env leak.
    local override_prefix=""
    if [[ -n "${SPINE_ROLE_POLICY_OVERRIDE_REF:-}" ]]; then
        override_prefix+="export SPINE_ROLE_POLICY_OVERRIDE_REF=$(printf %q "$SPINE_ROLE_POLICY_OVERRIDE_REF") && "
    fi
    if [[ -n "${SPINE_ROLE_POLICY_OVERRIDE_REASON:-}" ]]; then
        override_prefix+="export SPINE_ROLE_POLICY_OVERRIDE_REASON=$(printf %q "$SPINE_ROLE_POLICY_OVERRIDE_REASON") && "
    fi

    local remote_cmd
    remote_cmd="cd $(printf %q "$code_path") && ${admission_prefix}${override_prefix}./bin/ops cap run $(printf %q "$cap_name")${quoted_args}"

    local routed_rc=0 route_addr route_label attempted_routes=()
    local route_addrs=("$host_addr")
    local route_labels=("lan")
    if [[ -n "$host_addr_tailscale" && "$host_addr_tailscale" != "null" && "$host_addr_tailscale" != "$host_addr" ]]; then
        route_addrs+=("$host_addr_tailscale")
        route_labels+=("tailscale")
    fi

    local preferred_route
    preferred_route="${SPINE_DB_AUTHORITY_ROUTE:-$(yq e '.db_authority.preferred_route // "auto"' "$contract" 2>/dev/null)}"

    if [[ "$preferred_route" == "tailscale" && "${#route_addrs[@]}" -gt 1 ]]; then
        route_addrs=("$host_addr_tailscale" "$host_addr")
        route_labels=("tailscale" "lan")
    elif [[ "$preferred_route" == "lan" ]]; then
        : # contract default order already tries LAN first
    elif [[ "$preferred_route" == "auto" && "${#route_addrs[@]}" -gt 1 ]]; then
        # If the LAN address would route through a tunnel interface, the client
        # is off-LAN. Try Tailscale first so normal routed caps do not sit on a
        # LAN connect timeout before doing the only reachable thing.
        local lan_route=""
        if command -v route >/dev/null 2>&1; then
            lan_route="$(route get "$host_addr" 2>/dev/null || true)"
        elif command -v ip >/dev/null 2>&1; then
            lan_route="$(ip route get "$host_addr" 2>/dev/null || true)"
        fi
        if [[ "$lan_route" == *"utun"* || "$lan_route" == *"tailscale"* || "$lan_route" == *"tailscale0"* ]]; then
            route_addrs=("$host_addr_tailscale" "$host_addr")
            route_labels=("tailscale" "lan")
        fi
    fi

    local idx
    for idx in "${!route_addrs[@]}"; do
        route_addr="${route_addrs[$idx]}"
        route_label="${route_labels[$idx]}"
        attempted_routes+=("${route_label}:${route_addr}")
        set +e
        if [[ -n "$key_path" && "$key_path" != "null" ]]; then
            ssh -i "$key_path" -o BatchMode=yes -o ConnectTimeout="${connect_timeout:-10}" \
                "${user}@${route_addr}" "${remote_cmd}"
        else
            ssh -o BatchMode=yes -o ConnectTimeout="${connect_timeout:-10}" \
                "${user}@${route_addr}" "${remote_cmd}"
        fi
        routed_rc=$?
        set -e

        if [[ "$routed_rc" -eq 0 ]]; then
            return 0
        fi

        # SSH transport failures should try the next declared authority route.
        # Remote cap failures are real results from the authority host and must
        # not be retried on a different route.
        case "$routed_rc" in
            255) ;;
            *) return "$routed_rc" ;;
        esac
    done

    echo "cap.sh: db_authority routing failed via all declared routes: ${attempted_routes[*]}" >&2

    return "$routed_rc"
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

    # Phase D.3a: DB authority routing (INERT BY DEFAULT). When db_authority.enabled
    # is true and the local host is not the authority and the cap is mutating, this
    # call SSH-routes the cap to the authority host and returns the routed exit
    # code. Otherwise returns 126 (sentinel) and we fall through to local execution.
    set +e
    _route_to_db_authority_if_needed "$name" "${args[@]}"
    local _route_rc=$?
    set -e
    if [[ "$_route_rc" != "126" ]]; then
        return "$_route_rc"
    fi

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
