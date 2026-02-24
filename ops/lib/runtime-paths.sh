#!/usr/bin/env bash
# Shared runtime path resolution for mailroom-bound surfaces.
#
# Authority split:
# - Repo-authoritative: receipts/sessions, mailroom/state/loop-scopes,
#   ops/bindings/operational.gaps.yaml.
# - Runtime-authoritative: ledger/handoffs/orchestration/proposals/audits
#   via SPINE_STATE/SPINE_OUTBOX when runtime contract is active.

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
      SPINE_CODE="${SPINE_REPO:-$HOME/code/agentic-spine}"
    fi
    SPINE_REPO="${SPINE_REPO:-$SPINE_CODE}"
  fi

  local contract_file="$SPINE_CODE/ops/bindings/mailroom.runtime.contract.yaml"
  local inbox_default="$SPINE_REPO/mailroom/inbox"
  local outbox_default="$SPINE_REPO/mailroom/outbox"
  local state_default="$SPINE_REPO/mailroom/state"
  local logs_default="$SPINE_REPO/mailroom/logs"

  local inbox="${SPINE_INBOX:-}"
  local outbox="${SPINE_OUTBOX:-}"
  local state="${SPINE_STATE:-}"
  local logs="${SPINE_LOGS:-}"

  local active runtime_root
  active="$(_spine_runtime_contract_value "$contract_file" '.active' 'false')"
  runtime_root="$(_spine_runtime_contract_value "$contract_file" '.runtime_root' '')"

  if [[ "$active" == "true" && -n "$runtime_root" ]]; then
    [[ -n "$inbox" ]] || inbox="$runtime_root/inbox"
    [[ -n "$outbox" ]] || outbox="$runtime_root/outbox"
    [[ -n "$state" ]] || state="$runtime_root/state"
    [[ -n "$logs" ]] || logs="$runtime_root/logs"
  fi

  [[ -n "$inbox" ]] || inbox="$inbox_default"
  [[ -n "$outbox" ]] || outbox="$outbox_default"
  [[ -n "$state" ]] || state="$state_default"
  [[ -n "$logs" ]] || logs="$logs_default"

  export SPINE_REPO SPINE_CODE SPINE_INBOX="$inbox" SPINE_OUTBOX="$outbox" SPINE_STATE="$state" SPINE_LOGS="$logs"
}

spine_resolve_mailroom_path() {
  local path="$1"
  local repo="${SPINE_REPO:-$HOME/code/agentic-spine}"
  local state="${SPINE_STATE:-$repo/mailroom/state}"
  local outbox="${SPINE_OUTBOX:-$repo/mailroom/outbox}"

  case "$path" in
    /*)
      printf '%s\n' "$path"
      ;;
    mailroom/state/*)
      printf '%s\n' "$state/${path#mailroom/state/}"
      ;;
    mailroom/outbox/*)
      printf '%s\n' "$outbox/${path#mailroom/outbox/}"
      ;;
    *)
      printf '%s\n' "$repo/$path"
      ;;
  esac
}
