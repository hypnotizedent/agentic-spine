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

# Runtime root (mailroom/, receipts/, state/) is fixed by contract.
SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"

# Code root is derived from where this command is executed from (worktree-safe).
SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

STATE_DIR="$SPINE_REPO/mailroom/state"
CAP_FILE="$SPINE_CODE/ops/capabilities.yaml"
RECEIPTS="$SPINE_REPO/receipts/sessions"
LEDGER="$STATE_DIR/ledger.csv"
LEDGER_HEADER="run_id,created_at,started_at,finished_at,status,prompt_file,result_file,error,context_used"

# Ensure state directory exists before any writes
ensure_state_dir() {
    mkdir -p "$STATE_DIR"

    # Initialize ledger header for fresh clones / new worktrees.
    # ledger.csv is append-only runtime state; it must be parseable by loops tooling.
    if [[ ! -f "$LEDGER" || ! -s "$LEDGER" ]]; then
        echo "$LEDGER_HEADER" > "$LEDGER"
        return
    fi

    if ! head -n 1 "$LEDGER" | grep -q '^run_id,'; then
        local tmp
        tmp="$(mktemp "/tmp/spine-ledger.XXXXXX")"
        {
            echo "$LEDGER_HEADER"
            cat "$LEDGER"
        } > "$tmp"
        mv "$tmp" "$LEDGER"
    fi
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

    # ── Temp file cleanup trap ──
    _cap_tmp=""
    cleanup_cap() { [[ -n "$_cap_tmp" ]] && rm -f "$_cap_tmp" 2>/dev/null || true; }
    trap cleanup_cap EXIT INT TERM

    # Ensure runtime state is bootstrapped before executing anything.
    ensure_state_dir

    # ── Resolve active policy preset ──
    source "$SPINE_CODE/ops/lib/resolve-policy.sh"
    resolve_policy_knobs

    # ── Config extraction & validation ──
    if ! yq e ".capabilities.\"$name\"" "$CAP_FILE" | grep -q "description"; then
        echo "ERROR: Unknown capability: $name"
        echo "Run 'ops cap list' to see available capabilities."
        exit 1
    fi

    # ── Load capability configuration from YAML ──
    # Optional preconditions: .requires[] (capabilities to run first)
    # - Used to enforce secrets preflight for API-touching capabilities.
    local requires_list=()
    while IFS= read -r req; do
        [[ -z "${req:-}" || "${req:-}" == "null" ]] && continue
        requires_list+=("$req")
    done < <(yq e ".capabilities.\"$name\".requires[]?" "$CAP_FILE" 2>/dev/null || true)

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

    # ── Apply approval_default from policy preset ──
    # Top-level cap runs: strict preset forces manual approval
    # Precondition runs (OPS_CAP_STACK non-empty): per-capability setting respected
    if [[ -z "${OPS_CAP_STACK:-}" ]] && [[ "$RESOLVED_APPROVAL_DEFAULT" == "manual" ]]; then
      approval="manual"
    fi

    # ── Expand environment variables ──
    cwd="$(eval echo "$cwd")"

    # ── Generate collision-proof run key ──
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local rand
    rand="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 4 || echo "$$")"
    local run_key="CAP-${ts}__${name}__R${rand}"

    # ── Display execution banner ──
    echo "════════════════════════════════════════"
    echo "CAPABILITY: $name"
    echo "════════════════════════════════════════"
    echo "Description: $desc"
    echo "Safety:      $safety"
    echo "Approval:    $approval"
    echo "Run Key:     $run_key"
    echo "Policy:      $RESOLVED_POLICY_PRESET (approval_default=$RESOLVED_APPROVAL_DEFAULT)"
    echo "Command:     $cmd ${args[*]:-}"
    echo "CWD:         $cwd"
    echo ""

    # ── Approval gate (manual safety level) ──
    if [[ "$approval" == "manual" ]]; then
        echo "⚠️  This capability requires manual approval."
        read -r -p "Type 'yes' to proceed: " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "ABORTED"
            exit 1
        fi
    fi

    # ── Prepare capture (receipt should exist even if preconditions fail) ──
    local start_time
    start_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local output_file="/tmp/cap_${run_key}_output.txt"
    _cap_tmp="$output_file"
    local exit_code=0
    local blocked_reason=""

    # ── Policy enforcement: proposal_required + multi_agent_writes ──
    # Skip enforcement for precondition runs, read-only caps, and governance caps
    if [[ -z "${OPS_CAP_STACK:-}" && "$safety" == "mutating" ]]; then
      # proposal_required: strict preset forces proposal flow for mutating caps
      if [[ "${RESOLVED_PROPOSAL_REQUIRED:-false}" == "true" ]]; then
        echo "BLOCKED: proposal_required=true (policy: $RESOLVED_POLICY_PRESET)"
        echo "Mutating capability '$name' requires proposal flow under current policy."
        echo ""
        echo "Remediation:"
        echo "  ./bin/ops cap run proposals.submit \"$name: $desc\""
        exit 1
      fi
      # multi_agent_writes: proposal-only blocks direct mutating caps
      if [[ "${RESOLVED_MULTI_AGENT_WRITES:-direct}" == "proposal-only" ]]; then
        echo "BLOCKED: multi_agent_writes=proposal-only (policy: $RESOLVED_POLICY_PRESET)"
        echo "Direct mutating capability '$name' blocked. Use proposal flow."
        echo ""
        echo "Remediation:"
        echo "  ./bin/ops cap run proposals.submit \"$name: $desc\""
        exit 1
      fi
    fi

    # ── AOF contract acknowledgment (v0.2) ──
    # When .environment.yaml exists, enforce daily contract read acknowledgment
    # before allowing mutating/destructive capabilities.
    if [[ "$safety" == "mutating" || "$safety" == "destructive" ]] && [[ "$name" != "aof.contract.acknowledge" ]]; then
      local env_contract="${cwd}/.environment.yaml"
      if [[ -f "$env_contract" ]]; then
        local ack_check
        set +e
        ack_check="$(CONTRACT_FILE="$env_contract" bash "$SPINE_CODE/ops/plugins/aof/bin/contract-read-check.sh" 2>&1)"
        local ack_rc=$?
        set -e
        if [[ "$ack_rc" -eq 2 ]]; then
          echo "BLOCKED: AOF contract acknowledgment required"
          echo "Environment contract exists at: $env_contract"
          echo ""
          echo "Remediation:"
          echo "  ./bin/ops cap run aof.contract.status    # view current state"
          echo "  ./bin/ops cap run aof.contract.acknowledge"
          blocked_reason="aof_contract_ack_required"
          exit_code=2
        fi
      fi
    fi

    # ── Execute preconditions (dependency chain, cycle guard) ──
    local precond_failed=0
    local precond_rc=0
    local precond_name=""
    if [[ -n "$blocked_reason" ]]; then
        echo "$blocked_reason" > "$output_file"
    elif (( ${#requires_list[@]} > 0 )); then
        local stack="${OPS_CAP_STACK:-}"
        stack=",$stack,$name,"
        export OPS_CAP_STACK="${stack}"
        for req in "${requires_list[@]}"; do
            if [[ "${stack}" == *",${req},"* ]]; then
                echo "ERROR: requires cycle detected: ${name} -> ${req}"
                precond_failed=1
                precond_rc=1
                precond_name="$req"
                break
            fi
            echo ""
            echo "== PRECONDITION: ${req} =="
            set +e
            SPINE_REPO="$SPINE_REPO" SPINE_CODE="$SPINE_CODE" "$SPINE_CODE/bin/ops" cap run "${req}"
            rc=$?
            set -e
            if [[ "$rc" -ne 0 ]]; then
                precond_failed=1
                precond_rc="$rc"
                precond_name="$req"
                break
            fi
        done
        if [[ "$precond_failed" -eq 0 ]]; then
            echo ""
            echo "== PRECONDITIONS OK =="
            echo ""
        fi
    fi

    if [[ -n "$blocked_reason" ]]; then
        : # already blocked — skip execution
    elif [[ "$precond_failed" -eq 1 ]]; then
        echo "STOP: precondition failed: ${precond_name} (exit=$precond_rc)" | tee "$output_file" >/dev/null
        exit_code="$precond_rc"
    else
        echo "Executing..."
        echo "────────────────────────────────────────"

        # ── Execute capability command, capture output ──
        # Force code root for scripts that rely on SPINE_ROOT, while keeping runtime root stable.
        if (cd "$cwd" && SPINE_REPO="$SPINE_REPO" SPINE_CODE="$SPINE_CODE" SPINE_ROOT="$SPINE_CODE" SPINE_CAP_RUN_KEY="$run_key" $cmd "${args[@]}" 2>&1 | tee "$output_file"); then
            exit_code=0
        else
            exit_code=$?
        fi
        echo "────────────────────────────────────────"
    fi

    local end_time
    end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # ── Write receipt (markdown + SHA256) ──
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

    # Copy output to receipt dir, then clean temp
    cp "$output_file" "$receipt_dir/output.txt"
    rm -f "$output_file"
    _cap_tmp=""

    # ── Append ledger entry (CSV) ──
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
