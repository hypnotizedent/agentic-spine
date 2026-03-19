#!/usr/bin/env bash
# Shared runtime/evidence/data path resolution for spine surfaces.
#
# Canonical boring split:
# - agentic-spine: authored control plane only
# - .runtime/spine: live execution + mutable operational state
# - .evidence/spine: receipts, verification output, cap-run evidence
# - .data: business/domain truth
# - .backups: preserved archives and backups

_spine_expand_home_token() {
  local raw="${1:-}"
  case "$raw" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${raw#"~/"}" ;;
    *) printf '%s\n' "$raw" ;;
  esac
}

_spine_guess_workspace_root() {
  local code_root="${1:-}"
  code_root="$(_spine_expand_home_token "$code_root")"

  case "$code_root" in
    */code/.wt/*)
      printf '%s\n' "${code_root%%/.wt/*}"
      return 0
      ;;
    */code/.runtime/spine/tmp/worktrees/*)
      printf '%s\n' "${code_root%%/.runtime/spine/tmp/worktrees/*}"
      return 0
      ;;
  esac

  local parent
  parent="$(dirname "$code_root")"
  if [[ "$(basename "$parent")" == "code" ]]; then
    printf '%s\n' "$parent"
    return 0
  fi

  printf '%s\n' "$HOME/code"
}

_spine_runtime_contract_value() {
  local contract_file="$1"
  local expr="$2"
  local default_value="$3"

  if [[ -f "$contract_file" ]]; then
    if command -v yaml_query >/dev/null 2>&1; then
      local out
      out="$(yaml_query "$contract_file" "$expr" 2>/dev/null || true)"
      if [[ -n "$out" && "$out" != "null" ]]; then
        printf '%s\n' "$out"
        return 0
      fi
    elif command -v yq >/dev/null 2>&1; then
      local out
      out="$(yq e -r "$expr // \"\"" "$contract_file" 2>/dev/null || true)"
      if [[ -n "$out" && "$out" != "null" ]]; then
        printf '%s\n' "$out"
        return 0
      fi
    fi
  fi

  printf '%s\n' "$default_value"
}

spine_runtime_resolve_paths() {
  local detected_root=""
  detected_root="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$detected_root" && -f "$detected_root/ops/capabilities.yaml" ]]; then
    SPINE_CODE="$detected_root"
    SPINE_REPO="$detected_root"
  else
    if [[ -z "${SPINE_CODE:-}" ]]; then
      SPINE_CODE="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    fi
    SPINE_REPO="${SPINE_REPO:-$SPINE_CODE}"
  fi

  local contract_file="$SPINE_CODE/ops/bindings/mailroom.runtime.contract.yaml"
  local workspace_root="${SPINE_WORKSPACE_ROOT:-}"
  local runtime_root="${SPINE_RUNTIME_ROOT:-}"
  local mailroom_root="${SPINE_MAILROOM_ROOT:-}"
  local inbox="${SPINE_INBOX:-}"
  local outbox="${SPINE_OUTBOX:-}"
  local state="${SPINE_STATE:-}"
  local locks="${SPINE_LOCKS:-}"
  local logs="${SPINE_LOGS:-}"
  local tmp="${SPINE_TMP:-}"
  local evidence_root="${SPINE_EVIDENCE_ROOT:-}"
  local receipts="${SPINE_RECEIPTS:-}"
  local verify_root="${SPINE_VERIFY_ROOT:-}"
  local verify_reports_root="${SPINE_VERIFY_REPORTS_ROOT:-}"
  local verify_indexes_dir="${SPINE_VERIFY_INDEXES_DIR:-}"
  local receipt_index_file="${SPINE_RECEIPT_INDEX_FILE:-}"
  local verify_history_dir="${SPINE_VERIFY_HISTORY_DIR:-}"
  local verify_failure_history_file="${SPINE_VERIFY_FAILURE_HISTORY_FILE:-}"
  local verify_state_root="${SPINE_VERIFY_STATE_ROOT:-}"
  local verify_pass_streak_file="${SPINE_VERIFY_PASS_STREAK_FILE:-}"
  local loop_closeouts_root="${SPINE_LOOP_CLOSEOUTS_ROOT:-}"
  local census_root="${SPINE_CENSUS_ROOT:-}"
  local cap_runs="${SPINE_CAP_RUNS_ROOT:-}"
  local data_root="${SPINE_DATA_ROOT:-}"
  local backups_root="${SPINE_BACKUPS_ROOT:-}"
  local domain_state="${SPINE_DOMAIN_STATE:-}"
  local foundation_root="${SPINE_FOUNDATION_ROOT:-}"
  local agent_context_root="${SPINE_AGENT_CONTEXT_ROOT:-}"
  local agent_context_file="${SPINE_AGENT_CONTEXT_FILE:-}"

  if [[ -z "$workspace_root" ]]; then
    workspace_root="$(_spine_runtime_contract_value "$contract_file" '.workspace_root' '')"
  fi
  [[ -n "$workspace_root" ]] || workspace_root="$(_spine_guess_workspace_root "$SPINE_CODE")"
  workspace_root="$(_spine_expand_home_token "$workspace_root")"

  if [[ -z "$runtime_root" ]]; then
    runtime_root="$(_spine_runtime_contract_value "$contract_file" '.runtime_root' '')"
  fi
  [[ -n "$runtime_root" ]] || runtime_root="$workspace_root/.runtime/spine"
  runtime_root="$(_spine_expand_home_token "$runtime_root")"

  if [[ -z "$mailroom_root" ]]; then
    mailroom_root="$(_spine_runtime_contract_value "$contract_file" '.mailroom_root' '')"
  fi
  [[ -n "$mailroom_root" ]] || mailroom_root="$runtime_root/mailroom"
  mailroom_root="$(_spine_expand_home_token "$mailroom_root")"

  if [[ -z "$state" ]]; then
    state="$(_spine_runtime_contract_value "$contract_file" '.state_root' '')"
  fi
  [[ -n "$state" ]] || state="$runtime_root/state"
  state="$(_spine_expand_home_token "$state")"

  if [[ -z "$locks" ]]; then
    locks="$(_spine_runtime_contract_value "$contract_file" '.locks_root' '')"
  fi
  [[ -n "$locks" ]] || locks="$runtime_root/locks"
  locks="$(_spine_expand_home_token "$locks")"

  if [[ -z "$logs" ]]; then
    logs="$(_spine_runtime_contract_value "$contract_file" '.logs_root' '')"
  fi
  [[ -n "$logs" ]] || logs="$runtime_root/logs"
  logs="$(_spine_expand_home_token "$logs")"

  if [[ -z "$tmp" ]]; then
    tmp="$(_spine_runtime_contract_value "$contract_file" '.tmp_root' '')"
  fi
  [[ -n "$tmp" ]] || tmp="$runtime_root/tmp"
  tmp="$(_spine_expand_home_token "$tmp")"

  if [[ -z "$inbox" ]]; then
    inbox="$(_spine_runtime_contract_value "$contract_file" '.inbox_root' '')"
  fi
  [[ -n "$inbox" ]] || inbox="$mailroom_root/inbox"
  inbox="$(_spine_expand_home_token "$inbox")"

  if [[ -z "$outbox" ]]; then
    outbox="$(_spine_runtime_contract_value "$contract_file" '.outbox_root' '')"
  fi
  [[ -n "$outbox" ]] || outbox="$mailroom_root/outbox"
  outbox="$(_spine_expand_home_token "$outbox")"

  if [[ -z "$evidence_root" ]]; then
    evidence_root="$(_spine_runtime_contract_value "$contract_file" '.evidence_root' '')"
  fi
  [[ -n "$evidence_root" ]] || evidence_root="$workspace_root/.evidence/spine"
  evidence_root="$(_spine_expand_home_token "$evidence_root")"

  if [[ -z "$receipts" ]]; then
    receipts="$(_spine_runtime_contract_value "$contract_file" '.receipts_root' '')"
  fi
  [[ -n "$receipts" ]] || receipts="$evidence_root/sessions"
  receipts="$(_spine_expand_home_token "$receipts")"

  if [[ -z "$verify_root" ]]; then
    verify_root="$(_spine_runtime_contract_value "$contract_file" '.verify_root' '')"
  fi
  [[ -n "$verify_root" ]] || verify_root="$evidence_root/verify"
  verify_root="$(_spine_expand_home_token "$verify_root")"

  if [[ -z "$verify_reports_root" ]]; then
    verify_reports_root="$(_spine_runtime_contract_value "$contract_file" '.verify_reports_root' '')"
  fi
  [[ -n "$verify_reports_root" ]] || verify_reports_root="$evidence_root/reports/verify"
  verify_reports_root="$(_spine_expand_home_token "$verify_reports_root")"

  [[ -n "$verify_indexes_dir" ]] || verify_indexes_dir="$verify_root/indexes"
  verify_indexes_dir="$(_spine_expand_home_token "$verify_indexes_dir")"

  [[ -n "$receipt_index_file" ]] || receipt_index_file="$verify_indexes_dir/receipt-index.yaml"
  receipt_index_file="$(_spine_expand_home_token "$receipt_index_file")"

  [[ -n "$verify_history_dir" ]] || verify_history_dir="$verify_root/history"
  verify_history_dir="$(_spine_expand_home_token "$verify_history_dir")"

  [[ -n "$verify_failure_history_file" ]] || verify_failure_history_file="$verify_history_dir/verify-failure-class-history.ndjson"
  verify_failure_history_file="$(_spine_expand_home_token "$verify_failure_history_file")"

  [[ -n "$verify_state_root" ]] || verify_state_root="$state/verify"
  verify_state_root="$(_spine_expand_home_token "$verify_state_root")"

  [[ -n "$verify_pass_streak_file" ]] || verify_pass_streak_file="$verify_state_root/gate-pass-streak.json"
  verify_pass_streak_file="$(_spine_expand_home_token "$verify_pass_streak_file")"

  if [[ -z "$loop_closeouts_root" ]]; then
    loop_closeouts_root="$(_spine_runtime_contract_value "$contract_file" '.loop_closeouts_root' '')"
  fi
  [[ -n "$loop_closeouts_root" ]] || loop_closeouts_root="$evidence_root/loop-closeouts"
  loop_closeouts_root="$(_spine_expand_home_token "$loop_closeouts_root")"

  if [[ -z "$census_root" ]]; then
    census_root="$(_spine_runtime_contract_value "$contract_file" '.census_root' '')"
  fi
  [[ -n "$census_root" ]] || census_root="$evidence_root/census"
  census_root="$(_spine_expand_home_token "$census_root")"

  if [[ -z "$cap_runs" ]]; then
    cap_runs="$(_spine_runtime_contract_value "$contract_file" '.cap_runs_root' '')"
  fi
  [[ -n "$cap_runs" ]] || cap_runs="$evidence_root/cap-runs"
  cap_runs="$(_spine_expand_home_token "$cap_runs")"

  if [[ -z "$data_root" ]]; then
    data_root="$(_spine_runtime_contract_value "$contract_file" '.data_root' '')"
  fi
  [[ -n "$data_root" ]] || data_root="$workspace_root/.data"
  data_root="$(_spine_expand_home_token "$data_root")"

  if [[ -z "$backups_root" ]]; then
    backups_root="$(_spine_runtime_contract_value "$contract_file" '.backups_root' '')"
  fi
  [[ -n "$backups_root" ]] || backups_root="$workspace_root/.backups"
  backups_root="$(_spine_expand_home_token "$backups_root")"

  [[ -n "$foundation_root" ]] || foundation_root="$workspace_root/agentic-foundation"
  foundation_root="$(_spine_expand_home_token "$foundation_root")"

  if [[ -z "$domain_state" ]]; then
    domain_state="$(_spine_runtime_contract_value "$contract_file" '.domain_state_root' '')"
  fi
  [[ -n "$domain_state" ]] || domain_state="$data_root"
  domain_state="$(_spine_expand_home_token "$domain_state")"

  [[ -n "$agent_context_root" ]] || agent_context_root="$runtime_root/context"
  agent_context_root="$(_spine_expand_home_token "$agent_context_root")"

  [[ -n "$agent_context_file" ]] || agent_context_file="$agent_context_root/agent-context.md"
  agent_context_file="$(_spine_expand_home_token "$agent_context_file")"

  export \
    SPINE_REPO \
    SPINE_CODE \
    SPINE_WORKSPACE_ROOT="$workspace_root" \
    SPINE_RUNTIME_ROOT="$runtime_root" \
    SPINE_MAILROOM_ROOT="$mailroom_root" \
    SPINE_INBOX="$inbox" \
    SPINE_OUTBOX="$outbox" \
    SPINE_STATE="$state" \
    SPINE_LOCKS="$locks" \
    SPINE_LOGS="$logs" \
    SPINE_TMP="$tmp" \
    SPINE_EVIDENCE_ROOT="$evidence_root" \
    SPINE_RECEIPTS="$receipts" \
    SPINE_VERIFY_ROOT="$verify_root" \
    SPINE_VERIFY_REPORTS_ROOT="$verify_reports_root" \
    SPINE_VERIFY_INDEXES_DIR="$verify_indexes_dir" \
    SPINE_RECEIPT_INDEX_FILE="$receipt_index_file" \
    SPINE_VERIFY_HISTORY_DIR="$verify_history_dir" \
    SPINE_VERIFY_FAILURE_HISTORY_FILE="$verify_failure_history_file" \
    SPINE_VERIFY_STATE_ROOT="$verify_state_root" \
    SPINE_VERIFY_PASS_STREAK_FILE="$verify_pass_streak_file" \
    SPINE_LOOP_CLOSEOUTS_ROOT="$loop_closeouts_root" \
    SPINE_CENSUS_ROOT="$census_root" \
    SPINE_CAP_RUNS_ROOT="$cap_runs" \
    SPINE_DATA_ROOT="$data_root" \
    SPINE_BACKUPS_ROOT="$backups_root" \
    SPINE_FOUNDATION_ROOT="$foundation_root" \
    SPINE_DOMAIN_STATE="$domain_state" \
    SPINE_AGENT_CONTEXT_ROOT="$agent_context_root" \
    SPINE_AGENT_CONTEXT_FILE="$agent_context_file"
}

spine_resolve_mailroom_path() {
  local path="$1"
  local repo="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  local inbox="${SPINE_INBOX:-$HOME/code/.runtime/spine/mailroom/inbox}"
  local outbox="${SPINE_OUTBOX:-$HOME/code/.runtime/spine/mailroom/outbox}"
  local state="${SPINE_STATE:-$HOME/code/.runtime/spine/state}"
  local logs="${SPINE_LOGS:-$HOME/code/.runtime/spine/logs}"
  local evidence_root="${SPINE_EVIDENCE_ROOT:-$HOME/code/.evidence/spine}"
  local receipts="${SPINE_RECEIPTS:-$HOME/code/.evidence/spine/sessions}"
  local verify_root="${SPINE_VERIFY_ROOT:-$HOME/code/.evidence/spine/verify}"
  local verify_reports_root="${SPINE_VERIFY_REPORTS_ROOT:-$HOME/code/.evidence/spine/reports/verify}"
  local verify_state_root="${SPINE_VERIFY_STATE_ROOT:-$HOME/code/.runtime/spine/state/verify}"
  local loop_closeouts_root="${SPINE_LOOP_CLOSEOUTS_ROOT:-$HOME/code/.evidence/spine/loop-closeouts}"
  local census_root="${SPINE_CENSUS_ROOT:-$HOME/code/.evidence/spine/census}"
  local agent_context_root="${SPINE_AGENT_CONTEXT_ROOT:-$HOME/code/.runtime/spine/context}"
  local domain_state="${SPINE_DOMAIN_STATE:-$HOME/code/.data}"

  path="${path//\$SPINE_REPO/$repo}"
  path="${path//\$SPINE_INBOX/$inbox}"
  path="${path//\$SPINE_OUTBOX/$outbox}"
  path="${path//\$SPINE_STATE/$state}"
  path="${path//\$SPINE_LOGS/$logs}"
  path="${path//\$SPINE_EVIDENCE_ROOT/$evidence_root}"
  path="${path//\$SPINE_RECEIPTS/$receipts}"
  path="${path//\$SPINE_VERIFY_ROOT/$verify_root}"
  path="${path//\$SPINE_VERIFY_REPORTS_ROOT/$verify_reports_root}"
  path="${path//\$SPINE_AGENT_CONTEXT_ROOT/$agent_context_root}"
  path="${path//\$SPINE_DOMAIN_STATE/$domain_state}"

  case "$path" in
    /*)
      printf '%s\n' "$path"
      ;;
    mailroom/inbox)
      printf '%s\n' "$inbox"
      ;;
    mailroom/inbox/*)
      printf '%s\n' "$inbox/${path#mailroom/inbox/}"
      ;;
    mailroom/state)
      printf '%s\n' "$state"
      ;;
    mailroom/state/*)
      printf '%s\n' "$state/${path#mailroom/state/}"
      ;;
    mailroom/outbox)
      printf '%s\n' "$outbox"
      ;;
    mailroom/outbox/*)
      printf '%s\n' "$outbox/${path#mailroom/outbox/}"
      ;;
    mailroom/logs)
      printf '%s\n' "$logs"
      ;;
    mailroom/logs/*)
      printf '%s\n' "$logs/${path#mailroom/logs/}"
      ;;
    receipts/sessions)
      printf '%s\n' "$receipts"
      ;;
    receipts/sessions/*)
      printf '%s\n' "$receipts/${path#receipts/sessions/}"
      ;;
    evidence/sessions)
      printf '%s\n' "$receipts"
      ;;
    evidence/sessions/*)
      printf '%s\n' "$receipts/${path#evidence/sessions/}"
      ;;
    receipts/audits)
      printf '%s\n' "$verify_root"
      ;;
    receipts/audits/*)
      printf '%s\n' "$verify_root/${path#receipts/audits/}"
      ;;
    evidence/verify)
      printf '%s\n' "$verify_root"
      ;;
    evidence/verify/*)
      printf '%s\n' "$verify_root/${path#evidence/verify/}"
      ;;
    evidence/reports)
      printf '%s\n' "$verify_reports_root"
      ;;
    evidence/reports/*)
      printf '%s\n' "$verify_reports_root/${path#evidence/reports/}"
      ;;
    evidence/loop-closeouts)
      printf '%s\n' "$loop_closeouts_root"
      ;;
    evidence/loop-closeouts/*)
      printf '%s\n' "$loop_closeouts_root/${path#evidence/loop-closeouts/}"
      ;;
    evidence/census)
      printf '%s\n' "$census_root"
      ;;
    evidence/census/*)
      printf '%s\n' "$census_root/${path#evidence/census/}"
      ;;
    runtime/verify)
      printf '%s\n' "$verify_state_root"
      ;;
    runtime/verify/*)
      printf '%s\n' "$verify_state_root/${path#runtime/verify/}"
      ;;
    runtime/context)
      printf '%s\n' "$agent_context_root"
      ;;
    runtime/context/*)
      printf '%s\n' "$agent_context_root/${path#runtime/context/}"
      ;;
    runtime/domain-state)
      printf '%s\n' "$domain_state"
      ;;
    runtime/domain-state/*)
      printf '%s\n' "$domain_state/${path#runtime/domain-state/}"
      ;;
    *)
      printf '%s\n' "$repo/$path"
      ;;
  esac
}

spine_contract_ack_dir() {
  local state="${SPINE_STATE:-$HOME/code/.runtime/spine/state}"
  printf '%s\n' "$state/bootstrap/contract-read"
}

spine_contract_ack_file() {
  local ack_dir
  ack_dir="$(spine_contract_ack_dir)"
  printf '%s\n' "$ack_dir/$(date +%Y%m%d).ack"
}

spine_resolve_domain_state() {
  local subpath="${1:-}"
  local domain_state="${SPINE_DOMAIN_STATE:-$HOME/code/.data}"
  local full_path="$domain_state"
  [[ -z "$subpath" ]] || full_path="$domain_state/$subpath"
  mkdir -p "$(dirname "$full_path")" 2>/dev/null || true
  printf '%s\n' "$full_path"
}

spine_resolve_evidence_path() {
  local path="${1:-}"
  if [[ -z "$path" ]]; then
    printf '%s\n' "${SPINE_EVIDENCE_ROOT:-$HOME/code/.evidence/spine}"
    return 0
  fi
  spine_resolve_mailroom_path "$path"
}
