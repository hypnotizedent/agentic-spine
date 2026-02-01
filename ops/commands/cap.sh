#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops cap - Execute governed capabilities with receipts
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ops cap list                    List available capabilities
#   ops cap run <name> [args...]    Execute a capability
#   ops cap show <name>             Show capability details
#
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/Code/agentic-spine}"
STATE_DIR="$SPINE_REPO/mailroom/state"
CAP_FILE="$SPINE_REPO/ops/capabilities.yaml"
RECEIPTS="$SPINE_REPO/receipts/sessions"
LEDGER="$STATE_DIR/ledger.csv"

# Ensure state directory exists before any writes
ensure_state_dir() {
    mkdir -p "$STATE_DIR"
}

usage() {
    cat <<'EOF'
ops cap - Execute governed capabilities

Usage:
  ops cap list                    List available capabilities
  ops cap run <name> [args...]    Execute a capability with receipt
  ops cap show <name>             Show capability details

Examples:
  ops cap list
  ops cap run spine.verify
  ops cap run monolith.search "TODO" agentic-spine
  ops cap show infra.docker_ps
EOF
}

# Check yq is available (for YAML parsing)
check_deps() {
    if ! command -v yq >/dev/null 2>&1; then
        echo "ERROR: yq required for YAML parsing"
        echo "Install: brew install yq"
        exit 1
    fi
}

list_caps() {
    echo "=== AVAILABLE CAPABILITIES ==="
    echo ""
    yq e '.capabilities | keys | .[]' "$CAP_FILE" | while read -r cap; do
        desc="$(yq e ".capabilities.\"$cap\".description" "$CAP_FILE")"
        safety="$(yq e ".capabilities.\"$cap\".safety" "$CAP_FILE")"
        printf "  %-25s [%s] %s\n" "$cap" "$safety" "$desc"
    done
    echo ""
    echo "Run: ops cap run <name> [args...]"
}

show_cap() {
    local name="$1"

    if ! yq e ".capabilities.\"$name\"" "$CAP_FILE" | grep -q "description"; then
        echo "ERROR: Unknown capability: $name"
        echo "Run 'ops cap list' to see available capabilities."
        exit 1
    fi

    echo "=== CAPABILITY: $name ==="
    yq e ".capabilities.\"$name\"" "$CAP_FILE"
}

run_cap() {
    local name="$1"
    shift
    local args=("$@")

    # Validate capability exists
    if ! yq e ".capabilities.\"$name\"" "$CAP_FILE" | grep -q "description"; then
        echo "ERROR: Unknown capability: $name"
        echo "Run 'ops cap list' to see available capabilities."
        exit 1
    fi

    # Extract capability config
    local cmd
    cmd="$(yq e ".capabilities.\"$name\".command" "$CAP_FILE")"
    local cwd
    cwd="$(yq e ".capabilities.\"$name\".cwd // \"$HOME\"" "$CAP_FILE")"
    local safety
    safety="$(yq e ".capabilities.\"$name\".safety" "$CAP_FILE")"
    local approval
    approval="$(yq e ".capabilities.\"$name\".approval" "$CAP_FILE")"
    local desc
    desc="$(yq e ".capabilities.\"$name\".description" "$CAP_FILE")"

    # Expand env vars in cwd
    cwd="$(eval echo "$cwd")"

    # Generate run key
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local rand
    rand="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 4 || echo "$$")"
    local run_key="CAP-${ts}__${name}__R${rand}"

    echo "════════════════════════════════════════"
    echo "CAPABILITY: $name"
    echo "════════════════════════════════════════"
    echo "Description: $desc"
    echo "Safety:      $safety"
    echo "Approval:    $approval"
    echo "Run Key:     $run_key"
    echo "Command:     $cmd ${args[*]:-}"
    echo "CWD:         $cwd"
    echo ""

    # Check approval for mutating/destructive
    if [[ "$approval" == "manual" ]]; then
        echo "⚠️  This capability requires manual approval."
        read -r -p "Type 'yes' to proceed: " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "ABORTED"
            exit 1
        fi
    fi

    echo "Executing..."
    echo "────────────────────────────────────────"

    # Execute and capture output
    local start_time
    start_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local output_file="/tmp/cap_${run_key}_output.txt"
    local exit_code=0

    if (cd "$cwd" && $cmd "${args[@]}" 2>&1 | tee "$output_file"); then
        exit_code=0
    else
        exit_code=$?
    fi

    local end_time
    end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    echo "────────────────────────────────────────"

    # Write receipt
    local receipt_dir="$RECEIPTS/R${run_key}"
    mkdir -p "$receipt_dir"

    local output_hash
    output_hash="$(shasum -a 256 "$output_file" 2>/dev/null | cut -d' ' -f1 || echo "n/a")"

    cat > "$receipt_dir/receipt.md" <<EOF
# Receipt: $run_key

| Field | Value |
|-------|-------|
| Run ID | \`$run_key\` |
| Capability | \`$name\` |
| Status | $([ $exit_code -eq 0 ] && echo "done" || echo "failed") |
| Exit Code | $exit_code |
| Generated | $end_time |
| Model | local (capability) |
| Context | $safety |

## Inputs

| Field | Value |
|-------|-------|
| Command | \`$cmd ${args[*]:-}\` |
| CWD | \`$cwd\` |
| Args | \`${args[*]:-none}\` |

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

    # Copy output to receipt dir
    cp "$output_file" "$receipt_dir/output.txt"
    rm -f "$output_file"

    # Append to ledger (ensure state dir exists)
    ensure_state_dir
    echo "$run_key,$end_time,$start_time,$end_time,$([ $exit_code -eq 0 ] && echo "done" || echo "failed"),$name,receipt.md,,capability" >> "$LEDGER"

    echo ""
    echo "════════════════════════════════════════"
    echo "DONE"
    echo "════════════════════════════════════════"
    echo "Run Key:  $run_key"
    echo "Status:   $([ $exit_code -eq 0 ] && echo "done" || echo "failed")"
    echo "Receipt:  $receipt_dir/receipt.md"
    echo "Output:   $receipt_dir/output.txt"

    exit $exit_code
}

# Main
check_deps

case "${1:-}" in
    list)
        list_caps
        ;;
    show)
        [[ -z "${2:-}" ]] && { echo "Usage: ops cap show <name>"; exit 1; }
        show_cap "$2"
        ;;
    run)
        [[ -z "${2:-}" ]] && { echo "Usage: ops cap run <name> [args...]"; exit 1; }
        shift  # remove 'run'
        run_cap "$@"
        ;;
    -h|--help|"")
        usage
        ;;
    *)
        echo "Unknown subcommand: $1"
        usage
        exit 1
        ;;
esac
