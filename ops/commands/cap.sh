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
    local terminals_dir="$SPINE_STATE/terminals"
    local session_boundary="${SPINE_SESSION_ID:-}"
    local terminal_id="${TERMINAL_ID:-${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ROLE:-${SPINE_TERMINAL_ID:-}}}}"

    if [[ -z "$session_boundary" && "$safety" == "mutating" ]]; then
        session_boundary="${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ROLE:-${SPINE_TERMINAL_ID:-}}}"
    fi
    [[ -n "$session_boundary" ]] || session_boundary="nosession"

    if [[ -z "$terminal_id" ]]; then
        local host_part pid_part
        host_part="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"
        host_part="$(printf '%s' "$host_part" | tr '[:space:]/' '__')"
        pid_part="$$"
        terminal_id="attach-${OPS_TERMINAL_ROLE:-unset}-${host_part}-${pid_part}"
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
    local args=("$@")

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
    local runtime_role="${SPINE_RUNTIME_ROLE:-worker}"
    local terminal_id="${TERMINAL_ID:-${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ROLE:-${SPINE_TERMINAL_ID:-unknown-terminal}}}}"
    local lane_id="${SPINE_LANE:-execution}"
    local args_display="none"
    local source_refs_csv="none"
    local governance_version="SPINE.md@unknown"
    local governance_last_verified=""
    local execution_host=""
    local execution_mode="${SPINE_EXECUTION_MODE:-capability}"

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
| Blocker Reason | none |
| Runtime Role | ${runtime_role:-unknown} |
| Role Policy Enforced | false |
| Role Policy Override Used | false |
| Role Policy Override Ref | none |
| Role Policy Override Reason | none |
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
    CAP_RUNTIME_ROLE="$runtime_role" \
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

loop_id = os.environ.get("CAP_LOOP_ID", "").strip()
if loop_id:
    exec_payload["loop_id"] = loop_id
wave_id = os.environ.get("CAP_WAVE_ID", "").strip()
if wave_id:
    exec_payload["wave_id"] = wave_id

exec_receipt_path.write_text(json.dumps(exec_payload, indent=2) + "\n", encoding="utf-8")

attestation_payload = {
    "schema_version": "1.0",
    "request_id": os.environ["CAP_RUN_KEY"],
    "capability": os.environ["CAP_TASK_ID"],
    "generated_at_utc": os.environ["CAP_TIMESTAMP_UTC"],
    "loop_id": loop_id,
    "entry_packet_path": os.environ.get("CAP_ENTRY_PACKET_PATH", ""),
    "entry_packet_hash": os.environ.get("CAP_ENTRY_PACKET_HASH", "none"),
    "governance_version": os.environ.get("CAP_GOVERNANCE_VERSION", "SPINE.md@unknown"),
    "execution_host": os.environ.get("CAP_EXECUTION_HOST", "unknown-host"),
    "execution_mode": os.environ.get("CAP_EXECUTION_MODE", "capability"),
    "runtime_role": os.environ.get("CAP_RUNTIME_ROLE", "worker"),
    "completion_level": "",
    "checks_passed": checks_passed,
    "checks_failed": [],
    "receipts": {
        "markdown": {"path": str(receipt_path), "sha256": sha256(receipt_path)},
        "exec": {"path": str(exec_receipt_path), "sha256": sha256(exec_receipt_path)},
        "output": {"path": str(output_path), "sha256": sha256(output_path)},
    },
    "evidence_refs": exec_payload["evidence_refs"],
    "prompt_lineage": exec_payload["prompt_lineage"],
    "verdict": status,
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
    write_cap_receipt "$name" "$safety" "$cmd" "$cwd" "$run_key" "$start_time" "$end_time" "$rc" "$output_file" "${args[@]}"
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
