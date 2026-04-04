#!/usr/bin/env bash
set -euo pipefail

# Session Entry Enforcement Hook (UserPromptSubmit)
# Injects governance context on the first user prompt per session.
# Subsequent prompts pass through (marker file prevents re-injection).

# Read hook input from stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Marker: only inject once per session
MARKER="/tmp/claude-session-entry-${SESSION_ID}"
if [[ -f "$MARKER" ]]; then
  echo '{}'
  exit 0
fi

# Resolve spine root (relative to this script)
SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SPINE_ROOT/ops/lib/runtime-paths.sh" || { echo "FATAL: runtime-paths.sh not found" >&2; exit 1; }
spine_runtime_resolve_paths
source "$SPINE_ROOT/ops/lib/orchestration-remedy.sh" || { echo "FATAL: orchestration-remedy.sh not found" >&2; exit 1; }
BRANCH=$(git -C "$SPINE_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
TERMINAL_ROLE_CONTRACT="$SPINE_ROOT/ops/bindings/terminal.role.contract.yaml"
ROLE_RUNTIME_CONTRACT="$SPINE_ROOT/ops/bindings/role.runtime.control.contract.yaml"
GOVERNANCE_PROFILE_CONTRACT="${SPINE_GOVERNANCE_PROFILE_CONTRACT_PATH:-$SPINE_ROOT/ops/bindings/governance.profile.contract.yaml}"
GOVERNANCE_PROFILE_LANE="${SPINE_GOVERNANCE_PROFILE_LANE:-claude_code}"
SESSION_TERMINAL_ROLE="${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ROLE:-${SPINE_TERMINAL_NAME:-${SPINE_TERMINAL_ID:-}}}}"
SESSION_RUNTIME_ROLE="${SPINE_RUNTIME_ROLE:-}"

if [[ -z "$SESSION_RUNTIME_ROLE" && -n "$SESSION_TERMINAL_ROLE" ]] && command -v yq >/dev/null 2>&1 && [[ -f "$TERMINAL_ROLE_CONTRACT" ]]; then
  SESSION_RUNTIME_ROLE="$(yq e -r ".runtime_role_defaults.by_terminal_id.\"${SESSION_TERMINAL_ROLE}\" // \"\"" "$TERMINAL_ROLE_CONTRACT" 2>/dev/null || true)"
  if [[ -z "$SESSION_RUNTIME_ROLE" || "$SESSION_RUNTIME_ROLE" == "null" ]]; then
    SESSION_TERMINAL_TYPE="$(yq e -r ".roles[]? | select(.id == \"${SESSION_TERMINAL_ROLE}\") | .type" "$TERMINAL_ROLE_CONTRACT" 2>/dev/null | head -n1 || true)"
    if [[ -n "$SESSION_TERMINAL_TYPE" && "$SESSION_TERMINAL_TYPE" != "null" ]]; then
      SESSION_RUNTIME_ROLE="$(yq e -r ".runtime_role_defaults.by_terminal_type.\"${SESSION_TERMINAL_TYPE}\" // \"\"" "$TERMINAL_ROLE_CONTRACT" 2>/dev/null || true)"
    fi
  fi
fi

if [[ -z "$SESSION_RUNTIME_ROLE" ]] && command -v yq >/dev/null 2>&1 && [[ -f "$ROLE_RUNTIME_CONTRACT" ]]; then
  SESSION_RUNTIME_ROLE="$(yq e -r '.runtime_roles.default_role // ""' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || true)"
fi
[[ -n "$SESSION_RUNTIME_ROLE" && "$SESSION_RUNTIME_ROLE" != "null" ]] || SESSION_RUNTIME_ROLE="researcher"

CURRENT_GOVERNANCE_PROFILE="full_governance"
GOVERNANCE_PROFILE_DESCRIPTION="Live governed hook/attach context with dynamic runtime injection, role/write-scope enforcement, receipts required for mutations, and verification posture enforced."
GOVERNANCE_PROFILE_RESOLUTION="fallback to \`full_governance\` (contract not resolved yet)"

resolve_governance_profile() {
  local resolved_profile=""
  local resolved_description=""
  local fallback_reason=""

  if ! command -v yq >/dev/null 2>&1; then
    fallback_reason="yq unavailable"
  elif [[ ! -r "$GOVERNANCE_PROFILE_CONTRACT" ]]; then
    fallback_reason="contract missing or unreadable at \`${GOVERNANCE_PROFILE_CONTRACT}\`"
  else
    resolved_profile="$(yq e -r ".lane_assignments.\"${GOVERNANCE_PROFILE_LANE}\" // \"\"" "$GOVERNANCE_PROFILE_CONTRACT" 2>/dev/null || true)"
    if [[ -z "$resolved_profile" || "$resolved_profile" == "null" ]]; then
      fallback_reason="lane \`${GOVERNANCE_PROFILE_LANE}\` missing from contract"
    else
      resolved_description="$(yq e -r ".profiles.\"${resolved_profile}\".description // \"\"" "$GOVERNANCE_PROFILE_CONTRACT" 2>/dev/null || true)"
      if [[ -z "$resolved_description" || "$resolved_description" == "null" ]]; then
        fallback_reason="profile \`${resolved_profile}\` missing description in contract"
      fi
    fi
  fi

  if [[ -n "$fallback_reason" ]]; then
    GOVERNANCE_PROFILE_RESOLUTION="fallback to \`full_governance\` (${fallback_reason})"
    return 1
  fi

  CURRENT_GOVERNANCE_PROFILE="$resolved_profile"
  GOVERNANCE_PROFILE_DESCRIPTION="$resolved_description"
  GOVERNANCE_PROFILE_RESOLUTION="resolved from \`ops/bindings/governance.profile.contract.yaml\` for lane \`${GOVERNANCE_PROFILE_LANE}\`"
  return 0
}

resolve_governance_profile || true

# --- Session admission resolution ---
source "$SPINE_ROOT/ops/lib/session-admission.sh" 2>/dev/null || true
spine_resolve_admission "$GOVERNANCE_PROFILE_LANE" 2>/dev/null || true

# --- Terminal write scope resolution ---
TERMINAL_WRITE_SCOPE=""
TERMINAL_TYPE=""
if [[ -n "$SESSION_TERMINAL_ROLE" ]] && command -v yq >/dev/null 2>&1 && [[ -f "$TERMINAL_ROLE_CONTRACT" ]]; then
  TERMINAL_TYPE="$(yq e -r ".roles[]? | select(.id == \"${SESSION_TERMINAL_ROLE}\") | .type" "$TERMINAL_ROLE_CONTRACT" 2>/dev/null | head -n1 || true)"
  [[ -n "$TERMINAL_TYPE" && "$TERMINAL_TYPE" != "null" ]] || TERMINAL_TYPE=""
  TERMINAL_WRITE_SCOPE="$(yq e -r ".roles[]? | select(.id == \"${SESSION_TERMINAL_ROLE}\") | .write_scope[]?" "$TERMINAL_ROLE_CONTRACT" 2>/dev/null | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g' || true)"
  [[ -n "$TERMINAL_WRITE_SCOPE" && "$TERMINAL_WRITE_SCOPE" != "null" ]] || TERMINAL_WRITE_SCOPE=""
fi

parse_epoch_utc() {
  local ts="${1:-}"
  [[ -n "$ts" ]] || { echo 0; return; }

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$ts" <<'PY'
import sys
from datetime import datetime, timezone

ts = (sys.argv[1] or "").strip()
if not ts:
    print(0)
    raise SystemExit(0)

if ts.endswith("Z"):
    ts = ts[:-1] + "+00:00"

try:
    dt = datetime.fromisoformat(ts)
except Exception:
    print(0)
    raise SystemExit(0)

if dt.tzinfo is None:
    dt = dt.replace(tzinfo=timezone.utc)

print(int(dt.timestamp()))
PY
    return
  fi

  if date --version >/dev/null 2>&1; then
    date -d "$ts" "+%s" 2>/dev/null || echo 0
    return
  fi

  local clean_ts="${ts%%Z*}"
  clean_ts="${clean_ts%%+*}"
  date -j -f "%Y-%m-%dT%H:%M:%S" "$clean_ts" "+%s" 2>/dev/null || echo 0
}

# --- Non-main session isolation guard (GAP-OP-656) ---
WORKTREE_ISO_CONTRACT="$SPINE_ROOT/ops/bindings/worktree.session.isolation.yaml"
WSI_ENABLED=true
WSI_MAIN_BRANCH="main"
WSI_MANAGED_PREFIX="${HOME}/code/.runtime/spine/tmp/worktrees/agentic-spine/"
WSI_REQUIRE_NON_MAIN_IN_MANAGED=true
WSI_REQUIRE_IDENTITY=true
WSI_IDENTITY_ENV_VAR="OPS_WORKTREE_IDENTITY"
WSI_BYPASS_ENV_VAR="OPS_WORKTREE_ISOLATION_BYPASS"
WSI_BYPASS_REF_ENV_VAR="OPS_WORKTREE_ISOLATION_BYPASS_REF"
WSI_BYPASS_FRICTION_REF_ENV_VAR="OPS_WORKTREE_ISOLATION_BYPASS_FRICTION_REF"
WSI_BYPASS_REASON_ENV_VAR="OPS_WORKTREE_ISOLATION_BYPASS_REASON"
WSI_BYPASS_ALLOWED="1"
WSI_ALLOW_DETACHED=false
WSI_REMEDIATION="Run ./bin/ops start loop <LOOP_ID> and export OPS_WORKTREE_IDENTITY=<LOOP_ID>."
WSI_BYPASS_WARNING="Emergency bypass only: export OPS_WORKTREE_ISOLATION_BYPASS=1"
WSI_IDENTITY_PATTERNS=()

if [[ -f "$WORKTREE_ISO_CONTRACT" ]] && command -v yq >/dev/null 2>&1; then
  WSI_ENABLED="$(yq e -r '.policy.enabled // true' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo true)"
  WSI_MAIN_BRANCH="$(yq e -r '.policy.main_branch // "main"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo main)"
  WSI_MANAGED_PREFIX="$(yq e -r '.policy.managed_worktree_prefix // ""' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo "${HOME}/code/.runtime/spine/tmp/worktrees/agentic-spine/")"
  [[ -n "$WSI_MANAGED_PREFIX" && "$WSI_MANAGED_PREFIX" != "null" ]] || WSI_MANAGED_PREFIX="${HOME}/code/.runtime/spine/tmp/worktrees/agentic-spine/"
  WSI_REQUIRE_NON_MAIN_IN_MANAGED="$(yq e -r '.policy.require_non_main_in_managed_worktree // true' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo true)"
  WSI_REQUIRE_IDENTITY="$(yq e -r '.policy.require_explicit_identity_on_non_main // true' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo true)"
  WSI_IDENTITY_ENV_VAR="$(yq e -r '.policy.identity_env_var // "OPS_WORKTREE_IDENTITY"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo OPS_WORKTREE_IDENTITY)"
  WSI_BYPASS_ENV_VAR="$(yq e -r '.policy.bypass_env_var // "OPS_WORKTREE_ISOLATION_BYPASS"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo OPS_WORKTREE_ISOLATION_BYPASS)"
  WSI_BYPASS_REF_ENV_VAR="$(yq e -r '.policy.bypass_ref_env_var // "OPS_WORKTREE_ISOLATION_BYPASS_REF"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo OPS_WORKTREE_ISOLATION_BYPASS_REF)"
  WSI_BYPASS_FRICTION_REF_ENV_VAR="$(yq e -r '.policy.bypass_friction_ref_env_var // "OPS_WORKTREE_ISOLATION_BYPASS_FRICTION_REF"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo OPS_WORKTREE_ISOLATION_BYPASS_FRICTION_REF)"
  WSI_BYPASS_REASON_ENV_VAR="$(yq e -r '.policy.bypass_reason_env_var // "OPS_WORKTREE_ISOLATION_BYPASS_REASON"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo OPS_WORKTREE_ISOLATION_BYPASS_REASON)"
  WSI_BYPASS_ALLOWED="$(yq e -r '.policy.bypass_allowed_value // "1"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo 1)"
  WSI_ALLOW_DETACHED="$(yq e -r '.policy.allow_detached_head // false' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo false)"
  WSI_REMEDIATION="$(yq e -r '.messages.remediation // "Run ./bin/ops start loop <LOOP_ID> and export OPS_WORKTREE_IDENTITY=<LOOP_ID>."' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo "$WSI_REMEDIATION")"
  WSI_BYPASS_WARNING="$(yq e -r '.messages.bypass_warning // "Emergency bypass only: export OPS_WORKTREE_ISOLATION_BYPASS=1"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo "$WSI_BYPASS_WARNING")"
  while IFS= read -r pat; do
    [[ -n "$pat" && "$pat" != "null" ]] && WSI_IDENTITY_PATTERNS+=("$pat")
  done < <(yq e -r '.policy.identity_patterns[]?' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || true)
fi

if [[ "$WSI_MANAGED_PREFIX" == "~/"* ]]; then
  WSI_MANAGED_PREFIX="$HOME/${WSI_MANAGED_PREFIX#~/}"
fi

if [[ "$WSI_ENABLED" == "true" ]]; then
  WSI_ISSUES=()
  WSI_ROOT="$(git -C "$SPINE_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$SPINE_ROOT")"
  WSI_IDENTITY_VALUE="${!WSI_IDENTITY_ENV_VAR-}"
  WSI_BYPASS_VALUE="${!WSI_BYPASS_ENV_VAR-}"
  WSI_BYPASS_REF_VALUE="${!WSI_BYPASS_REF_ENV_VAR-}"
  WSI_BYPASS_FRICTION_REF_VALUE="${!WSI_BYPASS_FRICTION_REF_ENV_VAR-}"
  WSI_BYPASS_REASON_VALUE="${!WSI_BYPASS_REASON_ENV_VAR-}"

  if [[ "$BRANCH" == "HEAD" && "$WSI_ALLOW_DETACHED" != "true" ]]; then
    WSI_ISSUES+=("Detached HEAD is not allowed by isolation policy.")
  fi

  if [[ "$BRANCH" != "$WSI_MAIN_BRANCH" && "$BRANCH" != "unknown" ]]; then
    if [[ "$WSI_BYPASS_VALUE" == "$WSI_BYPASS_ALLOWED" ]]; then
      if [[ -z "$WSI_BYPASS_REF_VALUE" ]]; then
        WSI_ISSUES+=("Bypass '$WSI_BYPASS_ENV_VAR=$WSI_BYPASS_VALUE' missing '$WSI_BYPASS_REF_ENV_VAR'.")
      fi
      if [[ -z "$WSI_BYPASS_FRICTION_REF_VALUE" ]]; then
        WSI_ISSUES+=("Bypass '$WSI_BYPASS_ENV_VAR=$WSI_BYPASS_VALUE' missing '$WSI_BYPASS_FRICTION_REF_ENV_VAR'.")
      fi
      if [[ -z "$WSI_BYPASS_REASON_VALUE" ]]; then
        WSI_ISSUES+=("Bypass '$WSI_BYPASS_ENV_VAR=$WSI_BYPASS_VALUE' missing '$WSI_BYPASS_REASON_ENV_VAR'.")
      fi
    else
      if [[ "$WSI_REQUIRE_NON_MAIN_IN_MANAGED" == "true" ]]; then
        case "$WSI_ROOT/" in
          "$WSI_MANAGED_PREFIX"*) ;;
          *) WSI_ISSUES+=("Non-main branch '$BRANCH' is outside managed worktree prefix '$WSI_MANAGED_PREFIX'.") ;;
        esac
      fi

      if [[ "$WSI_REQUIRE_IDENTITY" == "true" ]]; then
        if [[ -z "$WSI_IDENTITY_VALUE" ]]; then
          WSI_ISSUES+=("Non-main branch '$BRANCH' requires explicit identity env '$WSI_IDENTITY_ENV_VAR'.")
        elif [[ "${#WSI_IDENTITY_PATTERNS[@]}" -gt 0 ]]; then
          WSI_ID_OK=false
          for pat in "${WSI_IDENTITY_PATTERNS[@]}"; do
            if [[ "$WSI_IDENTITY_VALUE" =~ $pat ]]; then
              WSI_ID_OK=true
              break
            fi
          done
          if [[ "$WSI_ID_OK" != "true" ]]; then
            WSI_ISSUES+=("$WSI_IDENTITY_ENV_VAR='$WSI_IDENTITY_VALUE' does not match allowed identity patterns.")
          fi
        fi
      fi
    fi
  fi

  if [[ "${#WSI_ISSUES[@]}" -gt 0 ]]; then
    WSI_LINES=""
    for issue in "${WSI_ISSUES[@]}"; do
      WSI_LINES="${WSI_LINES}"$'\n'"- ${issue}"
    done
    BLOCK_MSG=$(cat <<EOF
## SESSION ENTRY BLOCKED (D140 Worktree Session Isolation)

Branch: \`${BRANCH}\`
Worktree: \`${WSI_ROOT}\`

Violations:${WSI_LINES}

Remediation: ${WSI_REMEDIATION}
${WSI_BYPASS_WARNING}
EOF
)
    jq -n --arg msg "$BLOCK_MSG" '{"systemMessage": $msg}'
    exit 0
  fi
fi

# Marker is written only after isolation checks pass.
touch "$MARKER"

# --- Dynamic context gathering (via spine.context capability) ---

# Use spine.context for governance brief delivery (Move 3: dynamic context)
CONTEXT_SCRIPT="$SPINE_ROOT/ops/plugins/core/context/bin/spine-context"

# Spine status (loops + gaps + inbox + proposals)
LOOPS="(none)"
if [[ -x "$SPINE_ROOT/bin/ops" ]]; then
  LOOPS=$(timeout 10 "$SPINE_ROOT/bin/ops" status --brief 2>/dev/null || echo "(unavailable)")
fi

# --- Orchestration state and joined telemetry (parity with session-v3-attach) ---
LOOP_ID_RESOLVED="${SPINE_LOOP_ID:-${LOOP_ID:-}}"
LOOP_EXECUTION_MODE="unknown"
ORCHESTRATION_STATE="unknown"
ORCHESTRATION_LANE_ROLE=""
ORCHESTRATION_REMEDY=""
ORCHESTRATION_BLOCK=""

if [[ -n "$LOOP_ID_RESOLVED" ]]; then
  LOOP_SCOPE_PATH="${SPINE_STATE}/loop-scopes/${LOOP_ID_RESOLVED}.scope.md"
  if [[ -f "$LOOP_SCOPE_PATH" ]] && command -v yq >/dev/null 2>&1; then
    # Extract execution_mode from frontmatter
    LOOP_EXECUTION_MODE=$(awk '
      BEGIN { in_fm = 0; mode = "single_worker" }
      /^---$/ { in_fm = !in_fm; next }
      in_fm && /^execution_mode:/ { gsub(/^execution_mode: */, ""); gsub(/"/, ""); mode = $0 }
      END { print mode }
    ' "$LOOP_SCOPE_PATH" 2>/dev/null || echo "single_worker")
  fi

  # Derive orchestration_state
  if [[ "$LOOP_EXECUTION_MODE" == "orchestrator_subagents" ]]; then
    if [[ -n "${SPINE_ORCHESTRATION_CONTEXT:-}" ]]; then
      ORCHESTRATION_STATE="active"
      ORCHESTRATION_LANE_ROLE="${SPINE_LANE_ROLE:-unknown}"
    else
      ORCHESTRATION_STATE="available_not_entered"
      ORCHESTRATION_REMEDY="$(orchestration_remedy_worker_lane_entry "$LOOP_ID_RESOLVED" "claude")"
    fi
  elif [[ "$LOOP_EXECUTION_MODE" == "single_worker" ]]; then
    ORCHESTRATION_STATE="not_applicable"
  fi
fi

# Build orchestration block
if [[ -n "$LOOP_ID_RESOLVED" ]]; then
  ORCHESTRATION_BLOCK="### Active Loop And Orchestration State
**Loop ID:** ${LOOP_ID_RESOLVED}
**Execution mode:** ${LOOP_EXECUTION_MODE}
**Orchestration state:** ${ORCHESTRATION_STATE}"

  if [[ -n "$ORCHESTRATION_LANE_ROLE" ]]; then
    ORCHESTRATION_BLOCK="${ORCHESTRATION_BLOCK}
**Orchestration lane role:** ${ORCHESTRATION_LANE_ROLE}"
  fi

  if [[ -n "$ORCHESTRATION_REMEDY" ]]; then
    ORCHESTRATION_BLOCK="${ORCHESTRATION_BLOCK}
**Orchestration remedy:** ${ORCHESTRATION_REMEDY}

⚠️  This loop uses orchestrator_subagents mode but terminal is not in orchestration lane.
   Open worker terminal: ${ORCHESTRATION_REMEDY}"
  fi

  ORCHESTRATION_BLOCK="${ORCHESTRATION_BLOCK}
"
fi

# Joined engine telemetry (parity with session-v3-attach)
JOINED_TELEMETRY_BLOCK=""
JOINED_STATE_FILE="${SPINE_STATE}/domain-state/spine/SPINE_ENGINE_JOINED_STATE.yaml"
if [[ -f "$JOINED_STATE_FILE" ]] && command -v yq >/dev/null 2>&1; then
  OPEN_LOOPS=$(yq e -r '.summary.open_loops // "?"' "$JOINED_STATE_FILE" 2>/dev/null || echo "?")
  OPEN_GAPS=$(yq e -r '.summary.open_gaps // "?"' "$JOINED_STATE_FILE" 2>/dev/null || echo "?")
  BLOCKED_WORKTREES=$(yq e -r '.summary.blocked_worktrees // "?"' "$JOINED_STATE_FILE" 2>/dev/null || echo "?")
  ACTIVE_WAVES=$(yq e -r '.summary.active_waves // "?"' "$JOINED_STATE_FILE" 2>/dev/null || echo "?")
  RECENT_FORCE_CLOSES=$(yq e -r '.summary.recent_force_closes // 0' "$JOINED_STATE_FILE" 2>/dev/null || echo "0")
  RECENT_DOD_OVERRIDES=$(yq e -r '.summary.recent_dod_overrides // 0' "$JOINED_STATE_FILE" 2>/dev/null || echo "0")
  ENGINE_COHERENCE_ATTENTION=$(yq e -r '.summary.engine_coherence_needs_attention // false' "$JOINED_STATE_FILE" 2>/dev/null || echo "false")

  JOINED_TELEMETRY_BLOCK="### Joined Engine Telemetry
**Open loops:** ${OPEN_LOOPS}
**Open gaps:** ${OPEN_GAPS}
**Blocked worktrees:** ${BLOCKED_WORKTREES}
**Active waves:** ${ACTIVE_WAVES}
**Recent force-closes:** ${RECENT_FORCE_CLOSES} (7d window)
**Recent DoD overrides:** ${RECENT_DOD_OVERRIDES} (7d window)
**Engine coherence needs attention:** ${ENGINE_COHERENCE_ATTENTION}"

  if [[ "$ENGINE_COHERENCE_ATTENTION" == "true" ]]; then
    JOINED_TELEMETRY_BLOCK="${JOINED_TELEMETRY_BLOCK}

⚠️  Engine coherence needs attention - run 'ops cap run lifecycle.health' for details"
  fi

  JOINED_TELEMETRY_BLOCK="${JOINED_TELEMETRY_BLOCK}
"
fi

# Proposal queue health (lightweight: count pending proposals)
PROPOSALS_HEALTH=""
PROPOSALS_DIR="$SPINE_ROOT/mailroom/outbox/proposals"
if [[ -d "$PROPOSALS_DIR" ]]; then
  pending=0
  held=0
  for cpdir in "$PROPOSALS_DIR"/CP-*/; do
    [[ -d "$cpdir" ]] || continue
    [[ -f "$cpdir/.applied" ]] && continue
    manifest="$cpdir/manifest.yaml"
    [[ -f "$manifest" ]] || continue
    st=$(grep -m1 '^status:' "$manifest" 2>/dev/null | sed 's/^status: *//' | tr -d '"' || echo "pending")
    case "$st" in
      draft_hold) held=$((held + 1)) ;;
      pending|draft|"") pending=$((pending + 1)) ;;
    esac
  done
  if [[ "$pending" -gt 5 ]]; then
    PROPOSALS_HEALTH="
> **Proposal queue: ${pending} pending** (threshold: 5). Run \`proposals.status\` and triage."
  fi
fi

# Active worktree count (max allowed: 2)
WT_COUNT=$(git -C "$SPINE_ROOT" worktree list --porcelain 2>/dev/null | grep -c '^worktree' || echo 0)

# Dirty working tree warning (multi-terminal safety)
DIRTY_STATUS="$(git -C "$SPINE_ROOT" status --porcelain 2>/dev/null || true)"
DIRTY_COUNT="$(printf '%s\n' "$DIRTY_STATUS" | sed '/^$/d' | wc -l | tr -d ' ')"

DIRTY_WARNING=""
if [[ "${DIRTY_COUNT:-0}" != "0" ]]; then
  DIRTY_WARNING="
> **WORKTREE IS DIRTY (${DIRTY_COUNT} change(s)).**
> If you didn't make these changes, STOP. Another agent/terminal is in-flight.
> Default policy for multi-agent work: treat repo as read-only and submit a change proposal instead.
>
> Quick fix (operator only): commit/stash/clean before running verify or applying proposals.
"
fi

# ─── Multi-agent session detection ──────────────────────────
SESSIONS_DIR="${SPINE_STATE:?SPINE_STATE must be set}/sessions"
SESSION_TTL=${SPINE_SESSION_TTL:-14400}  # 4 hours
ACTIVE_SESSIONS=0
NOW=$(date +%s)

if [[ -d "$SESSIONS_DIR" ]]; then
  for sdir in "$SESSIONS_DIR"/SES-*/; do
    [[ -d "$sdir" ]] || continue
    manifest="$sdir/session.yaml"
    [[ -f "$manifest" ]] || continue

    created=$(grep '^created:' "$manifest" 2>/dev/null | sed 's/^created: *//' | tr -d '"' || echo "")
    pid=$(grep '^pid:' "$manifest" 2>/dev/null | sed 's/^pid: *//' | tr -d '"' || echo "")

    pid_alive=false
    if [[ -n "$pid" && "$pid" != "null" ]]; then
      if kill -0 "$pid" 2>/dev/null; then
        pid_alive=true
      fi
    fi

    epoch=$(parse_epoch_utc "$created")
    age=$((NOW - epoch))
    if [[ "$pid_alive" == "true" && $age -lt $SESSION_TTL ]]; then
      ACTIVE_SESSIONS=$((ACTIVE_SESSIONS + 1))
    fi
  done
fi

MULTI_AGENT_WARNING=""
if [[ "$ACTIVE_SESSIONS" -gt 1 ]]; then
  MULTI_AGENT_WARNING="
> **MULTI-AGENT MODE ACTIVE ($ACTIVE_SESSIONS sessions detected).**
> Proposal flow required — avoid direct commit.
> Use: \`./bin/ops cap run proposals.submit \"desc\"\` to submit changes.
> Apply-owner applies: \`./bin/ops cap run proposals.apply CP-...\`
> Direct commits are blocked by pre-commit hook unless apply-owner lock is held.
"
fi

# --- Dynamic gate metadata (from gate.registry.yaml summary block) ---
GATE_REGISTRY="$SPINE_ROOT/ops/bindings/gate.registry.yaml"
GATE_LINE=""
if [[ -f "$GATE_REGISTRY" ]]; then
  GATE_TOTAL="$(awk '/^  total:/{print $2; exit}' "$GATE_REGISTRY" 2>/dev/null)"
  GATE_ACTIVE="$(awk '/^  active:/{print $2; exit}' "$GATE_REGISTRY" 2>/dev/null)"
  GATE_RETIRED="$(awk '/^  retired:/{print $2; exit}' "$GATE_REGISTRY" 2>/dev/null)"
  GATE_LINE="**Gates:** ${GATE_TOTAL:-0} total, ${GATE_ACTIVE:-0} active, ${GATE_RETIRED:-0} retired"
fi

# --- Friction queue depth ---
FRICTION_QUEUE="${SPINE_STATE:?SPINE_STATE must be set}/friction-queue.ndjson"
FRICTION_LINE=""
if [[ -f "$FRICTION_QUEUE" ]]; then
  FRICTION_DEPTH=$(wc -l < "$FRICTION_QUEUE" 2>/dev/null | tr -d ' ')
  [[ "${FRICTION_DEPTH:-0}" != "0" ]] && FRICTION_LINE="**Friction queue:** ${FRICTION_DEPTH} items"
fi

# --- Docker context ---
DOCKER_CTX="(none)"
if command -v docker >/dev/null 2>&1; then
  DOCKER_CTX="$(timeout 2 docker context show 2>/dev/null || echo "unavailable")"
fi

# Read governance brief — prefer spine.context dynamic delivery, fallback to surviving authority docs
BRIEF_FILES=(
  "$SPINE_ROOT/docs/governance/SPINE.md"
  "$SPINE_ROOT/docs/governance/SESSION_PROTOCOL.md"
)
BRIEF_MODE="${SESSION_ENTRY_BRIEF_MODE:-summary}"  # summary|full
if [[ -x "$CONTEXT_SCRIPT" ]]; then
  BRIEF_FULL=$("$CONTEXT_SCRIPT" --section brief 2>/dev/null || true)
else
  BRIEF_FULL=""
fi

if [[ -z "$BRIEF_FULL" ]]; then
  BRIEF_FULL="$(
    {
      emitted=0
      for brief_file in "${BRIEF_FILES[@]}"; do
        [[ -f "$brief_file" ]] || continue
        if (( emitted > 0 )); then
          echo ""
          echo "---"
          echo ""
        fi
        cat "$brief_file"
        emitted=$((emitted + 1))
      done
      if (( emitted == 0 )); then
        echo "(governance brief unavailable — expected docs/governance/SPINE.md and docs/governance/SESSION_PROTOCOL.md)"
      fi
    }
  )"
fi

summarize_brief() {
  local text="$1"
  printf '%s\n' "$text" | awk '
    BEGIN {
      capture = 0
      lines = 0
      emitted = 0
    }
    /^## / {
      if ($0 ~ /^## (Commit & Branch Rules|Multi-Agent Write Policy \(Mailroom-Gated Writes\)|Verify & Receipts|Quick Commands)$/) {
        capture = 1
        lines = 0
        print
        emitted = 1
        next
      }
      capture = 0
    }
    capture == 1 {
      if (lines < 12) {
        print
        lines++
      }
    }
    END {
      if (emitted == 0) {
        # Fallback: keep context bounded to first lines if headings change.
        # shellcheck disable=SC2317
        print ""
      }
    }
  '
}

if [[ "$BRIEF_MODE" == "full" ]]; then
  BRIEF_RENDERED="$BRIEF_FULL"
else
  BRIEF_SUMMARY="$(summarize_brief "$BRIEF_FULL" | sed '/^[[:space:]]*$/N;/^\n$/D')"
  if [[ -z "$BRIEF_SUMMARY" ]]; then
    BRIEF_SUMMARY="$(printf '%s\n' "$BRIEF_FULL" | sed -n '1,80p')"
  fi
  BRIEF_RENDERED="$BRIEF_SUMMARY

> Full authority: \`docs/governance/SPINE.md\` + \`docs/governance/SESSION_PROTOCOL.md\` (set \`SESSION_ENTRY_BRIEF_MODE=full\` to inject full text)."
fi

# --- Terminal authority block ---
if [[ -n "$SESSION_TERMINAL_ROLE" && -n "$TERMINAL_WRITE_SCOPE" ]]; then
  TERMINAL_AUTHORITY="### Terminal Authority
**ID:** \`${SESSION_TERMINAL_ROLE}\` | **Type:** ${TERMINAL_TYPE:-unknown} | **Role:** \`${SESSION_RUNTIME_ROLE}\`
**Write scope:** ${TERMINAL_WRITE_SCOPE}
**Boundary:** Do not edit files outside this write scope. If work exceeds scope, stop and state which terminal owns it."
else
  TERMINAL_AUTHORITY="### Terminal Authority
**Posture:** unscoped/default | **Role:** \`${SESSION_RUNTIME_ROLE}\`
**Boundary:** No terminal-scoped write authority. Do not claim scoped write access."
fi

IDENTITY_BLOCK="### Platform Identity
The spine is a production-grade agentic execution system and governance-first control plane for repeatable, unattended, recoverable work across models, tools, terminals, and nodes.
**Not:** a homelab/domain workload manager; infrastructure, media, Home Assistant, finance, and similar systems are workloads the platform runs, not the platform identity."

ADMISSION_BLOCK="### Session Admission
**Lane:** \`${GOVERNANCE_PROFILE_LANE}\` | **Profile:** \`${CURRENT_GOVERNANCE_PROFILE}\` | **Parity:** \`${SA_PARITY_STATUS:-degraded}\`
**Admission:** \`${SA_ADMISSION_DELIVERY:-none}\` | **Mutation:** \`${SA_MUTATION_POSTURE:-no_governed_mutation}\`
**Resolution:** ${GOVERNANCE_PROFILE_RESOLUTION}
Cowork remains out-of-scope for governed mutation until a governed adapter exists."

# Build the system message: dynamic state + canonical brief
MSG="## SESSION ENTRY PROTOCOL (governance hook)

**Branch:** \`${BRANCH}\` | **Worktrees:** ${WT_COUNT}/2 | **Sessions:** ${ACTIVE_SESSIONS} | **Docker:** \`${DOCKER_CTX}\`
**Terminal:** \`${SESSION_TERMINAL_ROLE:-unset}\` → \`${SESSION_RUNTIME_ROLE}\`
${GATE_LINE:+${GATE_LINE}
}${FRICTION_LINE:+${FRICTION_LINE}
}${DIRTY_WARNING}${MULTI_AGENT_WARNING}${PROPOSALS_HEALTH}
${IDENTITY_BLOCK}

${ADMISSION_BLOCK}

${TERMINAL_AUTHORITY}

${ORCHESTRATION_BLOCK:+${ORCHESTRATION_BLOCK}}### Spine Status
\`\`\`
${LOOPS}
\`\`\`

${JOINED_TELEMETRY_BLOCK:+${JOINED_TELEMETRY_BLOCK}}${BRIEF_RENDERED}"

# Output JSON with systemMessage
jq -n --arg msg "$MSG" '{"systemMessage": $msg}'
