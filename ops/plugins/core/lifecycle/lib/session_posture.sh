# session_posture.sh — attach-time session posture resolution
#
# Resolves SPINE_SESSION_POSTURE (controller|membrane|worker|translator) and
# SPINE_NODE_TYPE at interactive attach time for the operator console path,
# then emits posture-derived policy env as `export` lines on stdout.
#
# IDENTITY UNIFICATION (2026-04-26):
# SPINE_EXECUTION_CLASS is the canonical execution identity. Legacy
# SPINE_RUNTIME_ROLE is a compatibility alias. Session posture is a DERIVED
# PROJECTION — it must not disagree with execution class. When a terminal has a
# by_terminal_id runtime role override, posture derives from that execution
# class, not from terminal type alone.
#
# This library is sourced (not executed). It must not set -euo pipefail at
# file top, must be idempotent, and must be macOS bash 3.2 compatible
# (no associative arrays). It performs no disk writes and keeps no state.
#
# Public functions:
#   session_posture_resolve TERMINAL_NAME REQUESTED_POSTURE [EXECUTION_CLASS]
#   session_posture_emit_env

__SP_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
__SP_CONTRACT_PATH="$__SP_ROOT/ops/bindings/terminal.role.contract.yaml"
__SP_SSH_TARGETS_PATH="$__SP_ROOT/ops/bindings/ssh.targets.yaml"
__SP_STORAGE_EVIDENCE_TARGET_ID="pve"
__SP_STORAGE_EVIDENCE_STATE_ROOT="/md1400/spine/state"

__sp_is_valid_posture() {
    case "$1" in
        controller|membrane|worker|translator) return 0 ;;
        *) return 1 ;;
    esac
}

__sp_resolve_terminal_type() {
    local terminal_name="$1"
    if [ -z "$terminal_name" ]; then
        printf ''
        return 0
    fi
    if ! command -v yq >/dev/null 2>&1; then
        printf ''
        return 0
    fi
    if [ ! -f "$__SP_CONTRACT_PATH" ]; then
        printf ''
        return 0
    fi
    local t
    t=$(yq -r ".roles[] | select(.id == \"$terminal_name\") | .type" "$__SP_CONTRACT_PATH" 2>/dev/null | head -n 1)
    if [ "$t" = "null" ]; then
        t=""
    fi
    printf '%s' "$t"
}

session_posture_resolve() {
    local terminal_name="${1:-}"
    local requested_posture="${2:-}"
    local execution_class="${3:-}"

    # 1. Node type
    if [ -n "${SPINE_LOCAL_ROLE:-}" ]; then
        __SP_NODE_TYPE="$SPINE_LOCAL_ROLE"
    else
        __SP_NODE_TYPE="operator_console"
    fi

    # 2. Terminal type
    local terminal_type
    terminal_type="$(__sp_resolve_terminal_type "$terminal_name")"

    # 3. Default posture — execution class is canonical, terminal type is fallback.
    #    When execution_class is provided (from terminal.sh after contract
    #    resolution), posture derives from it to prevent split identity.
    local default_posture default_source
    if [ -n "$execution_class" ]; then
        # Execution class is canonical — derive posture from it
        case "$execution_class" in
            worker)          default_posture="worker" ;;
            qc)              default_posture="membrane" ;;
            close|librarian) default_posture="controller" ;;
            researcher)
                # Researcher posture still depends on terminal type for
                # controller vs membrane distinction
                case "$terminal_type" in
                    control-plane) default_posture="controller" ;;
                    *)             default_posture="membrane" ;;
                esac
                ;;
            *)               default_posture="membrane" ;;
        esac
        default_source="derived:execution-class:${execution_class}"
    else
        # Legacy/fallback: terminal type only (no execution class provided)
        case "$terminal_type" in
            control-plane)   default_posture="controller" ;;
            observation)     default_posture="membrane" ;;
            domain-runtime)  default_posture="membrane" ;;
            "")              default_posture="membrane" ;;
            *)               default_posture="membrane" ;;
        esac
        if [ -n "$terminal_type" ]; then
            default_source="default:terminal-type:${terminal_type}"
        elif [ -z "$terminal_name" ]; then
            default_source="default:ad-hoc"
        else
            default_source="default:ad-hoc"
        fi
    fi

    # 4. Explicit request override
    if [ -n "$requested_posture" ]; then
        if ! __sp_is_valid_posture "$requested_posture"; then
            printf "session_posture: invalid posture '%s' (expected: controller|membrane|worker|translator)\n" \
                "$requested_posture" >&2
            return 2
        fi
        # Operator-console guard: forbid worker/translator unless contract-driven
        case "$__SP_NODE_TYPE" in
            operator_console)
                case "$requested_posture" in
                    worker)
                        # Allow if execution_class=worker (contract-driven).
                        # execution_class is the canonical identity passed by
                        # terminal.sh; runtime_role is only a legacy alias and
                        # may be unset under `set -u`.
                        if [ "$execution_class" != "worker" ]; then
                            printf "session_posture: posture '%s' is forbidden for node type '%s' without contract worker role\n" \
                                "$requested_posture" "$__SP_NODE_TYPE" >&2
                            printf "session_posture:   allowed for operator_console: controller membrane (or worker with contract role)\n" >&2
                            return 3
                        fi
                        ;;
                    translator)
                        printf "session_posture: posture '%s' is forbidden for node type '%s'\n" \
                            "$requested_posture" "$__SP_NODE_TYPE" >&2
                        printf "session_posture:   allowed for operator_console: controller membrane\n" >&2
                        return 3
                        ;;
                esac
                ;;
        esac
        __SP_POSTURE="$requested_posture"
        __SP_SOURCE="explicit:cli"
    else
        __SP_POSTURE="$default_posture"
        __SP_SOURCE="$default_source"
    fi

    return 0
}

# ── Recovery posture resolution ──────────────────────────────────────
# Detects operator_site from local network interfaces and derives
# recovery_posture + recovery_ready. Called after session_posture_resolve.
# Sets: __SP_OPERATOR_SITE, __SP_RECOVERY_POSTURE, __SP_RECOVERY_READY,
#        __SP_SITE_DETECTION_BASIS
#
# RECOVERY_READY (formerly SAFE_TO_MUTATE, renamed 2026-05-03):
# Pure recovery-readiness telemetry — signals whether the execution host's
# canonical state is reachable from this terminal so a mutation could be
# rolled back. NOT a mutation permission gate. Mutation enforcement lives in
# role.runtime.control.contract.yaml (bound terminal identity +
# mutating_capability_allowlist_by_role). This variable has no downstream
# enforcement consumer; it is informational telemetry only.
#
# Site CIDRs from topology.sites.yaml:
#   shop: 192.168.1.0/24
#   home: 10.0.0.0/24
# Tailscale CGNAT: 100.64.0.0/10

session_recovery_posture_resolve() {
    local iface_output=""
    iface_output="$(ifconfig 2>/dev/null || ip -4 addr show 2>/dev/null || true)"

    local has_shop_lan=0
    local has_home_lan=0
    local has_tailscale=0

    if printf '%s' "$iface_output" | grep -q 'inet 192\.168\.1\.'; then
        has_shop_lan=1
    fi
    if printf '%s' "$iface_output" | grep -q 'inet 10\.0\.0\.'; then
        has_home_lan=1
    fi
    if printf '%s' "$iface_output" | grep -q 'inet 100\.'; then
        has_tailscale=1
    fi

    # Site detection
    if [ "$has_shop_lan" -eq 1 ] && [ "$has_home_lan" -eq 0 ]; then
        __SP_OPERATOR_SITE="shop"
        __SP_SITE_DETECTION_BASIS="interface:shop_lan"
    elif [ "$has_home_lan" -eq 1 ] && [ "$has_shop_lan" -eq 0 ]; then
        __SP_OPERATOR_SITE="home"
        __SP_SITE_DETECTION_BASIS="interface:home_lan"
    elif [ "$has_shop_lan" -eq 1 ] && [ "$has_home_lan" -eq 1 ]; then
        __SP_OPERATOR_SITE="unknown"
        __SP_SITE_DETECTION_BASIS="interface:ambiguous"
    elif [ "$has_tailscale" -eq 1 ]; then
        __SP_OPERATOR_SITE="mobile"
        __SP_SITE_DETECTION_BASIS="interface:tailscale_only"
    else
        __SP_OPERATOR_SITE="unknown"
        __SP_SITE_DETECTION_BASIS="interface:no_match"
    fi

    # Recovery posture derivation
    case "$__SP_OPERATOR_SITE" in
        shop)   __SP_RECOVERY_POSTURE="full" ;;
        home)   __SP_RECOVERY_POSTURE="partial" ;;
        mobile) __SP_RECOVERY_POSTURE="remote" ;;
        *)      __SP_RECOVERY_POSTURE="unknown" ;;
    esac

    # recovery_ready derivation (telemetry only; not a mutation gate).
    # Post-D.3b v4, canonical state readiness is storage_evidence_node
    # reachability, not execution-host local state. execution_host local state is
    # projection/cache and must not make this banner look canonical.
    local storage_evidence_state_status=""
    storage_evidence_state_status="$(__sp_probe_storage_evidence_state)"
    case "$storage_evidence_state_status" in
        ready)
            __SP_RECOVERY_READY="true"
            __SP_SITE_DETECTION_BASIS="${__SP_SITE_DETECTION_BASIS}+storage_evidence_node_state:ready"
            ;;
        *)
            case "$__SP_RECOVERY_POSTURE" in
                full)    __SP_RECOVERY_READY="true" ;;
                partial) __SP_RECOVERY_READY="site_local_only" ;;
                remote)  __SP_RECOVERY_READY="tailscale_reachable_only" ;;
                *)       __SP_RECOVERY_READY="false" ;;
            esac
            if [ -n "$storage_evidence_state_status" ]; then
                __SP_SITE_DETECTION_BASIS="${__SP_SITE_DETECTION_BASIS}+storage_evidence_node_state:${storage_evidence_state_status}"
            fi
            ;;
    esac

    return 0
}

__sp_probe_storage_evidence_state() {
    if ! command -v ssh >/dev/null 2>&1; then
        printf 'ssh_unavailable'
        return 0
    fi
    if ! command -v yq >/dev/null 2>&1; then
        printf 'binding_unreadable'
        return 0
    fi
    if [ ! -f "$__SP_SSH_TARGETS_PATH" ]; then
        printf 'binding_missing'
        return 0
    fi

    # Source resolver lazily (not at file top) to avoid init-time overhead
    local _sp_resolver="$__SP_ROOT/ops/lib/ssh-resolve.sh"
    if [ -f "$_sp_resolver" ]; then
        # shellcheck source=ops/lib/ssh-resolve.sh
        . "$_sp_resolver"
    else
        printf 'resolver_missing'
        return 0
    fi

    local host tailscale_ip user probe_host identity_opts
    host="$(ssh_resolve_host "$__SP_STORAGE_EVIDENCE_TARGET_ID")"
    tailscale_ip="$(ssh_resolve_tailscale_ip "$__SP_STORAGE_EVIDENCE_TARGET_ID")"
    user="$(ssh_resolve_user "$__SP_STORAGE_EVIDENCE_TARGET_ID" "root")"
    identity_opts="$(ssh_resolve_machine_identity_opts "$__SP_STORAGE_EVIDENCE_TARGET_ID" 2>/dev/null)" || true

    case "$__SP_OPERATOR_SITE" in
        shop)
            probe_host="$host"
            ;;
        home|mobile|unknown)
            probe_host="${tailscale_ip:-$host}"
            ;;
        *)
            probe_host="${tailscale_ip:-$host}"
            ;;
    esac

    if [ -z "$probe_host" ]; then
        printf 'target_missing'
        return 0
    fi

    # shellcheck disable=SC2086
    if ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $identity_opts \
        "${user}@${probe_host}" \
        "test -r '$__SP_STORAGE_EVIDENCE_STATE_ROOT/shared_authority.db' && test -d '$__SP_STORAGE_EVIDENCE_STATE_ROOT/loop-scopes'" \
        >/dev/null 2>&1; then
        printf 'ready'
    else
        printf 'unreachable'
    fi
}

session_posture_emit_env() {
    printf 'export SPINE_NODE_TYPE=%q\n' "${__SP_NODE_TYPE:-}"
    printf 'export SPINE_SESSION_POSTURE=%q\n' "${__SP_POSTURE:-}"
    printf 'export SPINE_SESSION_POSTURE_SOURCE=%q\n' "${__SP_SOURCE:-}"

    case "${__SP_POSTURE:-}" in
        controller)
            printf 'export SPINE_POSTURE_SUBAGENTS=default\n'
            printf 'export SPINE_POSTURE_TELEMETRY=required\n'
            printf 'export SPINE_POSTURE_FRICTION=required\n'
            printf 'export SPINE_POSTURE_RECEIPTS=required\n'
            printf 'export SPINE_POSTURE_BROKER_ACCESS=governed_read\n'
            ;;
        membrane)
            printf 'export SPINE_POSTURE_SUBAGENTS=forbidden\n'
            printf 'export SPINE_POSTURE_TELEMETRY=default\n'
            printf 'export SPINE_POSTURE_FRICTION=optional\n'
            printf 'export SPINE_POSTURE_RECEIPTS=required\n'
            printf 'export SPINE_POSTURE_BROKER_ACCESS=read_only\n'
            ;;
        worker)
            printf 'export SPINE_POSTURE_SUBAGENTS=optional\n'
            printf 'export SPINE_POSTURE_TELEMETRY=required\n'
            printf 'export SPINE_POSTURE_FRICTION=required_on_blocker\n'
            printf 'export SPINE_POSTURE_RECEIPTS=required\n'
            printf 'export SPINE_POSTURE_BROKER_ACCESS=governed_write\n'
            ;;
        translator)
            printf 'export SPINE_POSTURE_SUBAGENTS=forbidden\n'
            printf 'export SPINE_POSTURE_TELEMETRY=required\n'
            printf 'export SPINE_POSTURE_FRICTION=required_on_isolation_break\n'
            printf 'export SPINE_POSTURE_RECEIPTS=required\n'
            printf 'export SPINE_POSTURE_BROKER_ACCESS=isolated\n'
            ;;
    esac

    printf 'export SPINE_OPERATOR_SITE=%q\n' "${__SP_OPERATOR_SITE:-unknown}"
    printf 'export SPINE_RECOVERY_POSTURE=%q\n' "${__SP_RECOVERY_POSTURE:-unknown}"
    printf 'export SPINE_RECOVERY_READY=%q\n' "${__SP_RECOVERY_READY:-false}"
    printf 'export SPINE_SITE_DETECTION_BASIS=%q\n' "${__SP_SITE_DETECTION_BASIS:-unavailable}"

    printf 'export SPINE_DEFAULT_VERIFY_CMD=%q\n' "./bin/ops verify --foundation"
    printf 'export SPINE_DEFAULT_CONTROL_LOOP_CMD=%q\n' "./bin/ops status --control-loop"

    if [ -n "${SPINE_STATE:-}" ]; then
        printf 'export SPINE_FRICTION_INTAKE_PATH=%q\n' "${SPINE_STATE}/friction-queue.ndjson"
    fi
}
