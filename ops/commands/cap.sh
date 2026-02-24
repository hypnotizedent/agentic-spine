#!/usr/bin/env bash
set -euo pipefail

SCRIPT_CODE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTIVE_CODE_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -n "$ACTIVE_CODE_ROOT" && -f "$ACTIVE_CODE_ROOT/ops/capabilities.yaml" ]]; then
    SPINE_CODE="$ACTIVE_CODE_ROOT"
    # Prefer active checkout/worktree for runtime artifacts (receipts/mailroom state).
    SPINE_REPO="$ACTIVE_CODE_ROOT"
else
    SPINE_CODE="${SPINE_CODE:-$SCRIPT_CODE_ROOT}"
    SPINE_REPO="${SPINE_REPO:-$SPINE_CODE}"
fi

_SP_LIB_DIR="${BASH_SOURCE%/*}"
[[ "$_SP_LIB_DIR" == "${BASH_SOURCE}" ]] && _SP_LIB_DIR="$(pwd)"
source "$_SP_LIB_DIR/../lib/yaml.sh"
source "$_SP_LIB_DIR/../lib/runtime-paths.sh"
spine_runtime_resolve_paths
export SPINE_INBOX SPINE_OUTBOX SPINE_STATE SPINE_LOGS

STATE_DIR="$SPINE_STATE"
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

# Bootstrap runtime directories/files that may be absent in fresh worktrees.
ensure_runtime_scaffold() {
    local proposals_dir="$SPINE_CODE/mailroom/outbox/proposals"
    local loop_scopes_dir="$SPINE_CODE/mailroom/state/loop-scopes"
    local calendar_dir="$SPINE_CODE/mailroom/outbox/calendar"
    local calendar_external_dir="$calendar_dir/external"
    local evidence_state_dir="$SPINE_CODE/ops/plugins/evidence/state"
    local receipt_index="$evidence_state_dir/receipt-index.yaml"

    mkdir -p \
        "$RECEIPTS" \
        "$proposals_dir" \
        "$loop_scopes_dir" \
        "$calendar_dir" \
        "$calendar_external_dir" \
        "$evidence_state_dir"

    if [[ ! -f "$receipt_index" ]]; then
        cat > "$receipt_index" <<EOF
updated_at_utc: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
source_root: "$RECEIPTS"
entries: []
EOF
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

check_deps() {
    if ! command -v yq >/dev/null 2>&1; then
        echo "ERROR: yq required for YAML parsing"
        echo "Install: brew install yq"
        exit 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq required for JSON processing"
        echo "Install: brew install jq"
        exit 1
    fi
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
    ensure_runtime_scaffold

    # ── Resolve active policy preset ──
    source "$SPINE_CODE/ops/lib/resolve-policy.sh"
    resolve_policy_knobs

    # ── Config extraction & validation ──
    if ! yaml_query -e "$CAP_FILE" ".capabilities.\"$name\"" 2>/dev/null; then
        echo "ERROR: Unknown capability: $name"
        echo "Run 'ops cap list' to see available capabilities."
        exit 1
    fi

    # ── Load capability configuration from YAML ──
    local requires_list=()
    while IFS= read -r req; do
        [[ -z "${req:-}" || "${req:-}" == "null" ]] && continue
        requires_list+=("$req")
    done < <(yq e ".capabilities.\"$name\".requires[]?" "$CAP_FILE" 2>/dev/null || true)

    local cmd
    cmd="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".command")"
    local cwd
    cwd="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".cwd")"
    [[ -z "$cwd" || "$cwd" == "null" ]] && cwd="$HOME"
    local safety
    safety="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".safety")"
    local approval
    approval="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".approval")"
    local desc
    desc="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".description")"
    local post_action
    post_action="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".post_action")"
    local effective_multi_agent_writes="${RESOLVED_MULTI_AGENT_WRITES:-direct}"
    local active_session_count=0

    count_active_sessions() {
      local sessions_dir="$SPINE_STATE/sessions"
      local repo_sessions_dir="$SPINE_REPO/mailroom/state/sessions"
      local count=0
      local scanned=()

      for dir in "$sessions_dir" "$repo_sessions_dir"; do
        [[ -n "$dir" ]] || continue
        [[ -d "$dir" ]] || continue

        local seen=0
        for existing in "${scanned[@]:-}"; do
          if [[ "$existing" == "$dir" ]]; then
            seen=1
            break
          fi
        done
        [[ "$seen" -eq 1 ]] && continue
        scanned+=("$dir")

        for session_dir in "$dir"/SES-*; do
          [[ -d "$session_dir" ]] || continue
          local manifest="$session_dir/session.yaml"
          [[ -f "$manifest" ]] || continue
          local pid
          pid="$(sed -n 's/^pid:[[:space:]]*//p' "$manifest" | head -1)"
          [[ -n "${pid:-}" ]] || continue
          if kill -0 "$pid" 2>/dev/null; then
            count=$((count + 1))
          fi
        done
      done

      echo "$count"
    }

    # ── Apply approval_default from policy preset ──
    # Top-level cap runs: strict preset forces manual approval
    # Precondition runs (OPS_CAP_STACK non-empty): per-capability setting respected
    if [[ -z "${OPS_CAP_STACK:-}" ]] && [[ "$RESOLVED_APPROVAL_DEFAULT" == "manual" ]]; then
      approval="manual"
    fi

    # ── Multi-session write posture ──
    # Balanced mode keeps direct writes for single-session work, but forces
    # proposal-only writes while multiple active sessions exist.
    active_session_count="$(count_active_sessions)"
    if [[ "${active_session_count:-0}" -gt 1 ]]; then
      effective_multi_agent_writes="${RESOLVED_MULTI_AGENT_WRITES_WHEN_MULTI_SESSION:-proposal-only}"
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
    echo "Policy:      $RESOLVED_POLICY_PRESET (approval_default=$RESOLVED_APPROVAL_DEFAULT, multi_agent_writes=$effective_multi_agent_writes, active_sessions=$active_session_count)"
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
      if [[ "$effective_multi_agent_writes" == "proposal-only" ]]; then
        echo "BLOCKED: multi_agent_writes=proposal-only (policy: $RESOLVED_POLICY_PRESET, active_sessions=$active_session_count)"
        echo "Direct mutating capability '$name' blocked. Use proposal flow."
        echo ""
        echo "Remediation:"
        echo "  ./bin/ops cap run proposals.submit \"$name: $desc\""
        exit 1
      fi
    fi

    # ── Proactive mutation guard (critical domains, snapshot-driven) ──
    if [[ -z "${OPS_CAP_STACK:-}" && ( "$safety" == "mutating" || "$safety" == "destructive" ) ]]; then
      local guard_policy="$SPINE_CODE/ops/bindings/proactive.guard.policy.yaml"
      if [[ -f "$guard_policy" ]]; then
        local guard_enabled
        guard_enabled="$(yaml_query "$guard_policy" '.enabled' 2>/dev/null || echo false)"
        if [[ "$guard_enabled" == "true" ]]; then
          local cap_domain
          cap_domain="$(yaml_query "$CAP_FILE" ".capabilities.\"$name\".domain" 2>/dev/null || echo none)"
          [[ "$cap_domain" == "null" ]] && cap_domain="none"

          # Fallback domain resolution from topology capability prefixes.
          if [[ -z "$cap_domain" || "$cap_domain" == "none" ]]; then
            cap_domain="$(yq e -r "
              .domain_metadata[]
              | select((.capability_prefixes // []) | any(. as \$p | \"$name\" | startswith(\$p)))
              | .domain_id
            " "$SPINE_CODE/ops/bindings/gate.execution.topology.yaml" 2>/dev/null | head -n1 || true)"
          fi

          if [[ -n "${cap_domain:-}" && "$cap_domain" != "none" && "$cap_domain" != "null" ]]; then
            local critical_domains_only critical_domain
            critical_domains_only="$(yaml_query "$guard_policy" '.critical_domains_only' 2>/dev/null || echo true)"
            critical_domain="$(yaml_query "$guard_policy" ".domain_to_critical_domain.\"$cap_domain\"" 2>/dev/null || true)"

            if [[ -z "$critical_domain" && "$critical_domains_only" != "true" ]]; then
              critical_domain="$cap_domain"
            fi

            if [[ -n "$critical_domain" ]]; then
              local allowlisted=0
              while IFS= read -r allowed_cap; do
                [[ -z "$allowed_cap" || "$allowed_cap" == "null" ]] && continue
                if [[ "$allowed_cap" == "$name" ]]; then
                  allowlisted=1
                  break
                fi
              done < <(yq e -r ".recovery_allowlist_by_domain.\"$critical_domain\"[]?" "$guard_policy" 2>/dev/null || true)

              if [[ "$allowlisted" -eq 0 ]]; then
                local snapshot_capability snapshot_ttl trigger_statuses
                snapshot_capability="$(yaml_query "$guard_policy" '.snapshot_capability' 2>/dev/null || echo "stability.control.snapshot")"
                snapshot_ttl="$(yaml_query "$guard_policy" '.snapshot_ttl_minutes' 2>/dev/null || echo 15)"
                trigger_statuses="$(yq e -r '.trigger_statuses[]?' "$guard_policy" 2>/dev/null | tr '\n' ' ' || true)"

                local snapshot_dir="" snapshot_run_key="" snapshot_generated="" snapshot_age_min=999999
                local candidate latest_mtime
                latest_mtime=0
                while IFS= read -r -d '' candidate; do
                  [[ -f "$candidate/receipt.md" ]] || continue
                  if ! grep -Fq "| Capability | \`$snapshot_capability\` |" "$candidate/receipt.md"; then
                    continue
                  fi
                  local mtime
                  mtime="$(stat -f '%m' "$candidate" 2>/dev/null || echo 0)"
                  if [[ "$mtime" -gt "$latest_mtime" ]]; then
                    latest_mtime="$mtime"
                    snapshot_dir="$candidate"
                  fi
                done < <(find "$RECEIPTS" -maxdepth 1 -type d -name 'R*' -print0 2>/dev/null)

                if [[ -n "$snapshot_dir" ]]; then
                  snapshot_run_key="$(sed -nE 's/^[|] Run ID [|] `([^`]+)` [|]/\1/p' "$snapshot_dir/receipt.md" | head -n1 || true)"
                  snapshot_generated="$(sed -nE 's/^[|] Generated [|] ([^|]+) [|]/\1/p' "$snapshot_dir/receipt.md" | head -n1 || true)"
                  if [[ -n "$snapshot_generated" ]]; then
                    snapshot_age_min="$(
                      python3 - "$snapshot_generated" <<'PY'
from datetime import datetime, timezone
import sys
raw = sys.argv[1].strip()
try:
    dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
except Exception:
    print(999999)
    raise SystemExit(0)
now = datetime.now(timezone.utc)
delta = now - dt.astimezone(timezone.utc)
print(max(0, int(delta.total_seconds() // 60)))
PY
                    )"
                  fi
                fi

                local reconcile_tmpl reconcile_cmd
                reconcile_tmpl="$(yaml_query "$guard_policy" '.required_reconcile_command_template' 2>/dev/null || echo "./bin/ops cap run stability.control.reconcile --domain {{critical_domain}}")"
                reconcile_cmd="${reconcile_tmpl//\{\{critical_domain\}\}/$critical_domain}"

                if [[ -z "$snapshot_dir" || "$snapshot_age_min" -gt "$snapshot_ttl" ]]; then
                  echo "BLOCKED: proactive mutation guard"
                  echo "Capability: $name"
                  echo "Blocking domain: $critical_domain (mapped from capability domain: $cap_domain)"
                  if [[ -n "$snapshot_run_key" ]]; then
                    echo "Latest snapshot run key: $snapshot_run_key (stale: ${snapshot_age_min}m > ttl ${snapshot_ttl}m)"
                  else
                    echo "Latest snapshot run key: none"
                  fi
                  echo "Required reconcile command: $reconcile_cmd"
                  echo "Unblock criteria: run fresh snapshot and clear warn/incident for target domain."
                  blocked_reason="proactive_guard_snapshot_missing_or_stale:$critical_domain"
                  exit_code=3
                else
                  local snapshot_output domain_status
                  snapshot_output="$snapshot_dir/output.txt"
                  domain_status=""
                  if [[ -f "$snapshot_output" ]]; then
                    # Prefer JSON payload when available in output.
                    local json_payload
                    json_payload="$(sed -n '/^{/,$p' "$snapshot_output" 2>/dev/null || true)"
                    if [[ -n "$json_payload" ]] && printf '%s\n' "$json_payload" | jq -e '.' >/dev/null 2>&1; then
                      domain_status="$(printf '%s\n' "$json_payload" | jq -r --arg d "$critical_domain" '.domains[]? | select(.id == $d) | .status' | head -n1 || true)"
                    fi
                    if [[ -z "$domain_status" || "$domain_status" == "null" ]]; then
                      domain_status="$(awk -v d="$critical_domain" '$1==d {print tolower($2); exit}' "$snapshot_output" 2>/dev/null || true)"
                    fi
                  fi

                  domain_status="$(echo "${domain_status:-unknown}" | tr '[:upper:]' '[:lower:]' | xargs)"
                  local should_block=0
                  local t
                  for t in $trigger_statuses; do
                    t="$(echo "$t" | tr '[:upper:]' '[:lower:]')"
                    if [[ "$domain_status" == "$t" ]]; then
                      should_block=1
                      break
                    fi
                  done

                  if [[ "$should_block" -eq 1 ]]; then
                    echo "BLOCKED: proactive mutation guard"
                    echo "Capability: $name"
                    echo "Blocking domain: $critical_domain (mapped from capability domain: $cap_domain)"
                    echo "Triggering snapshot run key: ${snapshot_run_key:-unknown}"
                    echo "Snapshot domain status: $domain_status"
                    echo "Required reconcile command: $reconcile_cmd"
                    echo "Unblock criteria: snapshot for target domain must be outside trigger statuses [$trigger_statuses]."
                    blocked_reason="proactive_guard_domain_blocked:$critical_domain:$domain_status:${snapshot_run_key:-none}"
                    exit_code=3
                  fi
                fi
              fi
            fi
          fi
        fi
      fi
    fi

    # ── AOF contract acknowledgment (v0.2) ──
    # When .environment.yaml exists, enforce daily contract read acknowledgment
    # before allowing mutating/destructive capabilities.
    if [[ -z "$blocked_reason" && ( "$safety" == "mutating" || "$safety" == "destructive" ) ]] && [[ "$name" != "aof.contract.acknowledge" ]]; then
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
        if (( ${#args[@]} > 0 )); then
            if (cd "$cwd" && SPINE_REPO="$SPINE_REPO" SPINE_CODE="$SPINE_CODE" SPINE_ROOT="$SPINE_CODE" SPINE_CAP_RUN_KEY="$run_key" $cmd "${args[@]}" 2>&1 | tee "$output_file"); then
                exit_code=0
            else
                exit_code=$?
            fi
        else
            if (cd "$cwd" && SPINE_REPO="$SPINE_REPO" SPINE_CODE="$SPINE_CODE" SPINE_ROOT="$SPINE_CODE" SPINE_CAP_RUN_KEY="$run_key" $cmd 2>&1 | tee "$output_file"); then
                exit_code=0
            else
                exit_code=$?
            fi
        fi
        echo "────────────────────────────────────────"
    fi

    # ── Execute post_action if defined and main cap succeeded ──
    if [[ "$exit_code" -eq 0 && -n "${post_action:-}" && "$post_action" != "null" ]]; then
        echo ""
        echo "== POST-ACTION: ${post_action} =="
        echo "────────────────────────────────────────"
        if SPINE_REPO="$SPINE_REPO" SPINE_CODE="$SPINE_CODE" SPINE_ROOT="$SPINE_CODE" "$SPINE_CODE/bin/ops" cap run "${post_action}" 2>&1 | tee -a "$output_file"; then
            echo "POST-ACTION OK: ${post_action}"
        else
            echo "POST-ACTION WARN: ${post_action} failed (non-blocking)"
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
