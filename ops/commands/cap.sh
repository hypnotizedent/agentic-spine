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

append_telemetry() {
    local name="$1"
    local safety="$2"
    local exit_code="$3"
    local telemetry_dir="$SPINE_STATE/telemetry"
    local session_boundary="${SPINE_SESSION_ID:-}"

    if [[ -z "$session_boundary" && "$safety" == "mutating" ]]; then
        session_boundary="${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ROLE:-${SPINE_TERMINAL_ID:-}}}"
    fi
    [[ -n "$session_boundary" ]] || session_boundary="nosession"

    mkdir -p "$telemetry_dir" 2>/dev/null || true
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$name" \
      "$safety" \
      "$exit_code" \
      "$session_boundary" \
      >> "$telemetry_dir/cap-usage.tsv" 2>/dev/null || true
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
        bash -lc "$command_string"
    )
}

run_cap() {
    local name="$1"
    shift || true

    local args=("$@")
    if [[ "${#args[@]}" -gt 0 && "${args[0]}" == "--" ]]; then
        args=("${args[@]:1}")
    fi

    ensure_runtime_dirs

    if ! yaml_query -e "$CAP_FILE" ".capabilities.\"$name\"" 2>/dev/null; then
        echo "ERROR: Unknown capability: $name"
        echo "Run 'ops cap list' to see available capabilities."
        exit 1
    fi

    local requires_list=()
    while IFS= read -r req; do
        [[ -z "${req:-}" || "${req:-}" == "null" ]] && continue
        requires_list+=("$req")
    done < <(yq e -r ".capabilities.\"$name\".requires[]?" "$CAP_FILE" 2>/dev/null || true)

    local cmd
    cmd="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".command")"
    local cwd
    cwd="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".cwd")"
    [[ -z "$cwd" || "$cwd" == "null" ]] && cwd="$HOME"
    cwd="$(eval echo "$cwd")"

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

    local ts rand run_key
    ts="$(date +%Y%m%d-%H%M%S)"
    rand="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 4 || echo "$$")"
    run_key="CAP-${ts}__${name}__R${rand}"

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
    command_string="$(build_command_string "$cmd" "${args[@]}")"

    echo "Executing..."
    echo "────────────────────────────────────────"
    set +e
    execute_command "$command_string" "$cwd" "$run_key"
    rc=$?
    set -e
    echo "────────────────────────────────────────"

    if [[ "$rc" -eq 0 && -n "${post_action:-}" && "$post_action" != "null" ]]; then
        echo ""
        echo "== POST-ACTION: ${post_action} =="
        echo "────────────────────────────────────────"
        set +e
        "$SPINE_CODE/bin/ops" cap run "$post_action"
        local post_rc=$?
        set -e
        if [[ "$post_rc" -eq 0 ]]; then
            echo "POST-ACTION OK: ${post_action}"
        else
            echo "POST-ACTION WARN: ${post_action} failed (non-blocking)"
        fi
        echo "────────────────────────────────────────"
    fi

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
            show_cap "$1"
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
