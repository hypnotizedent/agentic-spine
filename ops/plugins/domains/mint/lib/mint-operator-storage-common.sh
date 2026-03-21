#!/usr/bin/env bash
set -euo pipefail

MINT_OPERATOR_STORAGE_CONTROL_ROOT="${MINT_OPERATOR_STORAGE_CONTROL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SPINE_ROOT="${SPINE_ROOT:-$MINT_OPERATOR_STORAGE_CONTROL_ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
source "${MINT_OPERATOR_STORAGE_CONTROL_ROOT}/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

MINT_OPERATOR_STORAGE_CONTRACT="${MINT_OPERATOR_STORAGE_CONTRACT:-$MINT_OPERATOR_STORAGE_CONTROL_ROOT/ops/bindings/mint.operator.storage.contract.yaml}"
MINT_OPERATOR_RCLONE_BIN="${MINT_OPERATOR_RCLONE_BIN:-${RCLONE_BIN:-rclone}}"
MINT_OPERATOR_JQ_BIN="${MINT_OPERATOR_JQ_BIN:-jq}"

mint_operator_storage_fail() {
  echo "mint.operator.storage FAIL: $*" >&2
  exit 1
}

mint_operator_yq_clean_scalar() {
  local raw="${1:-}"
  printf '%s\n' "$raw" | sed '/^---$/d;/^[[:space:]]*$/d' | head -n 1
}

mint_operator_yq_clean_list() {
  local raw="${1:-}"
  printf '%s\n' "$raw" | sed '/^---$/d;/^[[:space:]]*$/d'
}

mint_operator_expand_path() {
  local raw="${1:-}"
  case "$raw" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${raw#"~/"}" ;;
    .runtime/*|.evidence/*|.data/*|.backups/*) printf '%s\n' "${SPINE_WORKSPACE_ROOT}/${raw}" ;;
    /*) printf '%s\n' "$raw" ;;
    *) printf '%s\n' "$raw" ;;
  esac
}

mint_operator_contract_scalar() {
  local query="$1"
  local default_value="${2:-}"
  if [[ -f "$MINT_OPERATOR_STORAGE_CONTRACT" ]] && command -v yq >/dev/null 2>&1; then
    local out=""
    out="$(yq e -N -r "$query // \"\"" "$MINT_OPERATOR_STORAGE_CONTRACT" 2>/dev/null || true)"
    out="$(mint_operator_yq_clean_scalar "$out")"
    if [[ -n "$out" && "$out" != "null" ]]; then
      printf '%s\n' "$out"
      return 0
    fi
  fi
  printf '%s\n' "$default_value"
}

mint_operator_contract_list() {
  local query="$1"
  if [[ -f "$MINT_OPERATOR_STORAGE_CONTRACT" ]] && command -v yq >/dev/null 2>&1; then
    local out=""
    out="$(yq e -N -r "$query // [] | .[]" "$MINT_OPERATOR_STORAGE_CONTRACT" 2>/dev/null || true)"
    mint_operator_yq_clean_list "$out"
  fi
}

mint_operator_storage_load_contract() {
  MINT_OPERATOR_LOCAL_INBOX="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.local_inbox.path' '~/Desktop/Operator Drop')")"
  MINT_OPERATOR_LOCAL_IGNORE="${MINT_OPERATOR_LOCAL_IGNORE:-.DS_Store,.localized}"
  MINT_OPERATOR_REMOTE="$(mint_operator_contract_scalar '.remote_target.rclone_remote' 'mintfiles')"
  MINT_OPERATOR_BUCKET="$(mint_operator_contract_scalar '.remote_target.bucket' 'artwork-intake')"
  MINT_OPERATOR_PREFIX="$(mint_operator_contract_scalar '.remote_target.prefix' 'operator-drop')"
  MINT_OPERATOR_HEALTH_PROBE_PATH="$(mint_operator_contract_scalar '.remote_target.health_probe_path' "${MINT_OPERATOR_BUCKET}")"
  MINT_OPERATOR_CONTIMEOUT="$(mint_operator_contract_scalar '.remote_target.contimeout' '2s')"
  MINT_OPERATOR_TIMEOUT="$(mint_operator_contract_scalar '.remote_target.timeout' '10s')"
  MINT_OPERATOR_RETRIES="$(mint_operator_contract_scalar '.remote_target.retries' '1')"
  MINT_OPERATOR_LOW_LEVEL_RETRIES="$(mint_operator_contract_scalar '.remote_target.low_level_retries' '1')"
  MINT_OPERATOR_CREATE_EMPTY_SRC_DIRS="$(mint_operator_contract_scalar '.remote_target.create_empty_src_dirs' 'true')"
  MINT_OPERATOR_MINT_REPO_ROOT="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.ingest.mint_repo_root' '~/code/mint-modules')")"
  MINT_OPERATOR_MINTCTL_COMMAND="$(mint_operator_contract_scalar '.ingest.mintctl_command' './bin/mintctl morpheus intake')"
  MINT_OPERATOR_FOLDER_FLAG="$(mint_operator_contract_scalar '.ingest.folder_flag' '--folder')"
  MINT_OPERATOR_SOURCE_FLAG="$(mint_operator_contract_scalar '.ingest.source_flag' '--source')"
  MINT_OPERATOR_MOUNT_LABEL="$(mint_operator_contract_scalar '.convenience_mount.launch_agent_label' 'com.ronnyworks.mintfiles.mount')"
  MINT_OPERATOR_MOUNTPOINT="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.convenience_mount.mountpoint' '~/MinIO')")"
  MINT_OPERATOR_SYNC_LABEL="$(mint_operator_contract_scalar '.automation.sync_launchd_label' 'com.ronny.mint-operator-drop-sync')"
  MINT_OPERATOR_CADENCE_SECONDS="$(mint_operator_contract_scalar '.automation.cadence_seconds' '60')"
  MINT_OPERATOR_STATE_ROOT="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.runtime_state.state_root' '.runtime/spine/state/mint/operator-drop')")"
  MINT_OPERATOR_HISTORY_FILE="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.runtime_state.sync_history_file' '.runtime/spine/state/mint/operator-drop/sync-history.tsv')")"

  export \
    MINT_OPERATOR_LOCAL_INBOX \
    MINT_OPERATOR_REMOTE \
    MINT_OPERATOR_BUCKET \
    MINT_OPERATOR_PREFIX \
    MINT_OPERATOR_HEALTH_PROBE_PATH \
    MINT_OPERATOR_CONTIMEOUT \
    MINT_OPERATOR_TIMEOUT \
    MINT_OPERATOR_RETRIES \
    MINT_OPERATOR_LOW_LEVEL_RETRIES \
    MINT_OPERATOR_CREATE_EMPTY_SRC_DIRS \
    MINT_OPERATOR_MINT_REPO_ROOT \
    MINT_OPERATOR_MINTCTL_COMMAND \
    MINT_OPERATOR_FOLDER_FLAG \
    MINT_OPERATOR_SOURCE_FLAG \
    MINT_OPERATOR_MOUNT_LABEL \
    MINT_OPERATOR_MOUNTPOINT \
    MINT_OPERATOR_SYNC_LABEL \
    MINT_OPERATOR_CADENCE_SECONDS \
    MINT_OPERATOR_STATE_ROOT \
    MINT_OPERATOR_HISTORY_FILE
}

mint_operator_storage_require_contract() {
  [[ -f "$MINT_OPERATOR_STORAGE_CONTRACT" ]] || mint_operator_storage_fail "missing contract: $MINT_OPERATOR_STORAGE_CONTRACT"
  command -v yq >/dev/null 2>&1 || mint_operator_storage_fail "missing required tool: yq"
}

mint_operator_storage_ignore_name() {
  local name="$1"
  case "$name" in
    .DS_Store|.localized|._*|.gitkeep) return 0 ;;
    *) return 1 ;;
  esac
}

mint_operator_storage_ensure_local_roots() {
  mkdir -p "$MINT_OPERATOR_LOCAL_INBOX"
  mkdir -p "$(dirname "$MINT_OPERATOR_HISTORY_FILE")"
}

mint_operator_storage_is_mount_attached() {
  mount | grep -Fq " on ${MINT_OPERATOR_MOUNTPOINT} ("
}

mint_operator_storage_mount_accessible() {
  [[ -d "$MINT_OPERATOR_MOUNTPOINT" ]] || return 1
  ls -1 "$MINT_OPERATOR_MOUNTPOINT" >/dev/null 2>&1
}

mint_operator_storage_mount_process_running() {
  pgrep -af rclone 2>/dev/null | grep -F " mount " | grep -Fq -- "$MINT_OPERATOR_MOUNTPOINT"
}

mint_operator_storage_mount_status() {
  local mounted="no"
  local accessible="no"
  local process="no"

  mint_operator_storage_is_mount_attached && mounted="yes"
  mint_operator_storage_mount_accessible && accessible="yes"
  mint_operator_storage_mount_process_running && process="yes"

  if [[ "$mounted" == "yes" && "$accessible" == "yes" && "$process" == "yes" ]]; then
    printf 'ACTIVE|%s|%s|%s\n' "$mounted" "$accessible" "$process"
  elif [[ "$mounted" == "yes" || "$process" == "yes" ]]; then
    printf 'STALE|%s|%s|%s\n' "$mounted" "$accessible" "$process"
  else
    printf 'INACTIVE|%s|%s|%s\n' "$mounted" "$accessible" "$process"
  fi
}

mint_operator_storage_list_mount_fallback_entries() {
  [[ -d "$MINT_OPERATOR_MOUNTPOINT" ]] || return 0
  find "$MINT_OPERATOR_MOUNTPOINT" -mindepth 1 -maxdepth 1 -print 2>/dev/null | sort | while IFS= read -r entry; do
    local name="${entry##*/}"
    mint_operator_storage_ignore_name "$name" && continue
    printf '%s\n' "$entry"
  done
}

mint_operator_storage_list_inbox_dirs() {
  [[ -d "$MINT_OPERATOR_LOCAL_INBOX" ]] || return 0
  find "$MINT_OPERATOR_LOCAL_INBOX" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort | while IFS= read -r entry; do
    local name="${entry##*/}"
    mint_operator_storage_ignore_name "$name" && continue
    printf '%s\n' "$entry"
  done
}

mint_operator_storage_list_inbox_loose_entries() {
  [[ -d "$MINT_OPERATOR_LOCAL_INBOX" ]] || return 0
  find "$MINT_OPERATOR_LOCAL_INBOX" -mindepth 1 -maxdepth 1 ! -type d -print 2>/dev/null | sort | while IFS= read -r entry; do
    local name="${entry##*/}"
    mint_operator_storage_ignore_name "$name" && continue
    printf '%s\n' "$entry"
  done
}

mint_operator_storage_count_lines() {
  local content="${1:-}"
  if [[ -z "$content" ]]; then
    printf '0\n'
  else
    printf '%s\n' "$content" | sed '/^$/d' | wc -l | tr -d ' '
  fi
}

mint_operator_storage_remote_ok() {
  command -v "$MINT_OPERATOR_RCLONE_BIN" >/dev/null 2>&1 || return 2
  "$MINT_OPERATOR_RCLONE_BIN" lsf "${MINT_OPERATOR_REMOTE}:${MINT_OPERATOR_HEALTH_PROBE_PATH}" \
    --max-depth 1 \
    --contimeout "$MINT_OPERATOR_CONTIMEOUT" \
    --timeout "$MINT_OPERATOR_TIMEOUT" \
    --retries "$MINT_OPERATOR_RETRIES" \
    --low-level-retries "$MINT_OPERATOR_LOW_LEVEL_RETRIES" >/dev/null 2>&1
}

mint_operator_storage_history_append() {
  local status="$1"
  local folder="$2"
  local message="${3:-}"
  mkdir -p "$(dirname "$MINT_OPERATOR_HISTORY_FILE")"
  printf '%s\t%s\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$status" \
    "$folder" \
    "$message" >> "$MINT_OPERATOR_HISTORY_FILE"
}

mint_operator_storage_last_history_line() {
  [[ -f "$MINT_OPERATOR_HISTORY_FILE" ]] || return 0
  tail -n 1 "$MINT_OPERATOR_HISTORY_FILE" 2>/dev/null || true
}
