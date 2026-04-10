# session_posture.sh — attach-time session posture resolution
#
# Resolves SPINE_SESSION_POSTURE (controller|membrane|worker|translator) and
# SPINE_NODE_TYPE at interactive attach time for the operator console path,
# then emits posture-derived policy env as `export` lines on stdout.
#
# IMPORTANT: SPINE_SESSION_POSTURE is NEW runtime truth introduced for the
# node-posture contract (LOOP-SPINE-NODE-POSTURE-CONTRACT-20260410). It is
# a SEPARATE contract from SPINE_EXECUTION_POSTURE and MUST NOT be aliased,
# mirrored, or conflated with it here. Execution posture lives elsewhere
# and is owned by the execution plane.
#
# This library is sourced (not executed). It must not set -euo pipefail at
# file top, must be idempotent, and must be macOS bash 3.2 compatible
# (no associative arrays). It performs no disk writes and keeps no state.
#
# Public functions:
#   session_posture_resolve TERMINAL_NAME REQUESTED_POSTURE
#   session_posture_emit_env

__SP_CONTRACT_PATH="/Users/ronnyworks/code/agentic-spine/ops/bindings/terminal.role.contract.yaml"

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

    # 1. Node type
    if [ -n "${SPINE_LOCAL_ROLE:-}" ]; then
        __SP_NODE_TYPE="$SPINE_LOCAL_ROLE"
    else
        __SP_NODE_TYPE="operator_console"
    fi

    # 2. Terminal type
    local terminal_type
    terminal_type="$(__sp_resolve_terminal_type "$terminal_name")"

    # 3. Default posture by terminal type
    local default_posture default_source
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

    # 4. Explicit request override
    if [ -n "$requested_posture" ]; then
        if ! __sp_is_valid_posture "$requested_posture"; then
            printf "session_posture: invalid posture '%s' (expected: controller|membrane|worker|translator)\n" \
                "$requested_posture" >&2
            return 2
        fi
        case "$__SP_NODE_TYPE" in
            operator_console)
                case "$requested_posture" in
                    worker|translator)
                        printf "session_posture: posture '%s' is forbidden for node type '%s'\n" \
                            "$requested_posture" "$__SP_NODE_TYPE" >&2
                        printf "session_posture:   allowed for operator_console: controller membrane\n" >&2
                        printf "session_posture:   see LOOP-SPINE-NODE-POSTURE-CONTRACT-20260410\n" >&2
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

    printf 'export SPINE_DEFAULT_VERIFY_CMD=%q\n' "./bin/ops verify --spine-lite"
    printf 'export SPINE_DEFAULT_CONTROL_LOOP_CMD=%q\n' "./bin/ops status --control-loop"

    if [ -n "${SPINE_STATE:-}" ]; then
        printf 'export SPINE_FRICTION_INTAKE_PATH=%q\n' "${SPINE_STATE}/friction-queue.ndjson"
    fi
}
