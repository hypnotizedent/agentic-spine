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

mint_operator_expand_path() {
  local raw="${1:-}"
  case "$raw" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${raw#"~/"}" ;;
    \$SPINE_EVIDENCE_ROOT/*|\$SPINE_VERIFY_ROOT/*|evidence/*|receipts/*) spine_resolve_mailroom_path "$raw" ;;
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
    yq e -N -r "$query // [] | .[]" "$MINT_OPERATOR_STORAGE_CONTRACT" 2>/dev/null | sed '/^---$/d;/^[[:space:]]*$/d'
  fi
}

mint_operator_storage_load_contract() {
  MINT_OPERATOR_MODE="$(mint_operator_contract_scalar '.critical_path.mode' 'direct_remote_operator_drop')"
  MINT_OPERATOR_CANONICAL_DROP_ROOT="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.canonical_operator_drop.path' '~/MinIO/artwork-intake/operator-drop')")"
  MINT_OPERATOR_CANONICAL_DROP_BROWSE_ROOT="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.canonical_operator_drop.browse_mount_path' "$MINT_OPERATOR_CANONICAL_DROP_ROOT")")"
  MINT_OPERATOR_BUCKET="$(mint_operator_contract_scalar '.canonical_operator_drop.bucket' 'artwork-intake')"
  MINT_OPERATOR_PREFIX="$(mint_operator_contract_scalar '.canonical_operator_drop.prefix' 'operator-drop')"
  MINT_OPERATOR_CANONICAL_DROP_REMOTE="$(mint_operator_contract_scalar '.canonical_operator_drop.remote' "${MINT_OPERATOR_REMOTE:-mintfiles}:${MINT_OPERATOR_BUCKET}/${MINT_OPERATOR_PREFIX}")"
  MINT_OPERATOR_INGEST_COMMAND="$(mint_operator_contract_scalar '.canonical_operator_drop.ingest_command' './bin/mintctl morpheus intake')"
  MINT_OPERATOR_LEGACY_DESKTOP_PATH="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.legacy_desktop_inbox.path' '~/Desktop/Operator Drop')")"
  MINT_OPERATOR_REMOTE="$(mint_operator_contract_scalar '.remote_target.rclone_remote' 'mintfiles')"
  MINT_OPERATOR_HEALTH_PROBE_PATH="$(mint_operator_contract_scalar '.remote_target.health_probe_path' "${MINT_OPERATOR_BUCKET}")"
  MINT_OPERATOR_CONTIMEOUT="$(mint_operator_contract_scalar '.remote_target.contimeout' '2s')"
  MINT_OPERATOR_TIMEOUT="$(mint_operator_contract_scalar '.remote_target.timeout' '10s')"
  MINT_OPERATOR_RETRIES="$(mint_operator_contract_scalar '.remote_target.retries' '1')"
  MINT_OPERATOR_LOW_LEVEL_RETRIES="$(mint_operator_contract_scalar '.remote_target.low_level_retries' '1')"
  MINT_OPERATOR_MOUNT_LABEL="$(mint_operator_contract_scalar '.mount_surface.launch_agent_label' 'com.ronnyworks.mintfiles.mount')"
  MINT_OPERATOR_MOUNT_TEMPLATE="$(mint_operator_contract_scalar '.mount_surface.launchd_template' 'ops/plugins/infra/host/launchd/com.ronnyworks.mintfiles.mount.plist')"
  MINT_OPERATOR_MOUNT_SCRIPT="${MINT_OPERATOR_MOUNT_SCRIPT:-$(mint_operator_expand_path "$(mint_operator_contract_scalar '.mount_surface.mount_script_path' '~/code/workbench/scripts/root/mounts/mintfiles-mount.sh')")}"
  MINT_OPERATOR_MOUNTPOINT="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.mount_surface.mountpoint' '~/MinIO')")"
  MINT_OPERATOR_MOUNT_OPERATOR_DROP="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.mount_surface.operator_drop_path' '~/MinIO/artwork-intake/operator-drop')")"
  MINT_OPERATOR_LAUNCHD_HEALTH_INTERVAL_SECONDS="$(mint_operator_contract_scalar '.mount_surface.launchd_health_interval_seconds' '15')"
  MINT_OPERATOR_MOUNT_ROLE="$(mint_operator_contract_scalar '.mount_surface.role' 'optional_browse_surface')"
  MINT_OPERATOR_MOUNT_BROWSE_ONLY="$(mint_operator_contract_scalar '.mount_surface.browse_only' 'true')"
  MINT_OPERATOR_ASSIST_MODE="$(mint_operator_contract_scalar '.assisted_move_surface.mode' 'governed_mountless_remote_move')"
  MINT_OPERATOR_ASSIST_DESTINATION_ROOT="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.assisted_move_surface.destination_root' "$MINT_OPERATOR_CANONICAL_DROP_BROWSE_ROOT")")"
  MINT_OPERATOR_ASSIST_REMOTE_DESTINATION="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.assisted_move_surface.remote_destination' "$MINT_OPERATOR_CANONICAL_DROP_REMOTE")")"
  MINT_OPERATOR_ASSIST_REMOTE_STAGING_PREFIX="$(mint_operator_contract_scalar '.assisted_move_surface.staging_prefix' "${MINT_OPERATOR_BUCKET}/${MINT_OPERATOR_PREFIX}/.incoming")"
  MINT_OPERATOR_ASSIST_VERIFICATION_METHOD="$(mint_operator_contract_scalar '.assisted_move_surface.verification_method' 'rclone_check_size_one_way')"
  MINT_OPERATOR_ASSIST_CLEANUP_POLICY="$(mint_operator_contract_scalar '.assisted_move_surface.cleanup_policy' 'trash_after_verified_arrival')"
  MINT_OPERATOR_ASSIST_CONFLICT_POLICY="$(mint_operator_contract_scalar '.assisted_move_surface.conflict_policy' 'fail_if_destination_exists')"
  MINT_OPERATOR_ASSIST_RECEIPT_ROOT="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.assisted_move_surface.receipts_root' '.evidence/spine/mint/operator-drop-assist')")"
  MINT_OPERATOR_ASSIST_HELPER_BIN="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.assisted_move_surface.helper_bin_path' '~/.local/bin/mint-operator-drop-assist')")"
  MINT_OPERATOR_ASSIST_FINDER_APP="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.assisted_move_surface.finder_app_path' '~/Applications/Mint Operator Drop.app')")"
  MINT_OPERATOR_ASSIST_CONTROL_PLANE_ROOT="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.assisted_move_surface.control_plane_root' '~/.wt/agentic-spine/control-plane')")"
  MINT_OPERATOR_ASSIST_INSTALLER_SCRIPT="$(mint_operator_expand_path "$(mint_operator_contract_scalar '.assisted_move_surface.installer_script_path' '~/code/workbench/scripts/root/operator/install-mint-operator-drop-surface.sh')")"
  MINT_OPERATOR_ASSIST_REQUIRES_ENTRY_SURFACE="$(mint_operator_contract_scalar '.assisted_move_surface.boring_state_requires_entry_surface' 'true')"

  export \
    MINT_OPERATOR_MODE \
    MINT_OPERATOR_CANONICAL_DROP_ROOT \
    MINT_OPERATOR_CANONICAL_DROP_BROWSE_ROOT \
    MINT_OPERATOR_BUCKET \
    MINT_OPERATOR_PREFIX \
    MINT_OPERATOR_CANONICAL_DROP_REMOTE \
    MINT_OPERATOR_INGEST_COMMAND \
    MINT_OPERATOR_LEGACY_DESKTOP_PATH \
    MINT_OPERATOR_REMOTE \
    MINT_OPERATOR_HEALTH_PROBE_PATH \
    MINT_OPERATOR_CONTIMEOUT \
    MINT_OPERATOR_TIMEOUT \
    MINT_OPERATOR_RETRIES \
    MINT_OPERATOR_LOW_LEVEL_RETRIES \
    MINT_OPERATOR_MOUNT_LABEL \
    MINT_OPERATOR_MOUNT_TEMPLATE \
    MINT_OPERATOR_MOUNT_SCRIPT \
    MINT_OPERATOR_MOUNTPOINT \
    MINT_OPERATOR_MOUNT_OPERATOR_DROP \
    MINT_OPERATOR_LAUNCHD_HEALTH_INTERVAL_SECONDS \
    MINT_OPERATOR_MOUNT_ROLE \
    MINT_OPERATOR_MOUNT_BROWSE_ONLY \
    MINT_OPERATOR_ASSIST_MODE \
    MINT_OPERATOR_ASSIST_DESTINATION_ROOT \
    MINT_OPERATOR_ASSIST_REMOTE_DESTINATION \
    MINT_OPERATOR_ASSIST_REMOTE_STAGING_PREFIX \
    MINT_OPERATOR_ASSIST_VERIFICATION_METHOD \
    MINT_OPERATOR_ASSIST_CLEANUP_POLICY \
    MINT_OPERATOR_ASSIST_CONFLICT_POLICY \
    MINT_OPERATOR_ASSIST_RECEIPT_ROOT \
    MINT_OPERATOR_ASSIST_HELPER_BIN \
    MINT_OPERATOR_ASSIST_FINDER_APP \
    MINT_OPERATOR_ASSIST_CONTROL_PLANE_ROOT \
    MINT_OPERATOR_ASSIST_INSTALLER_SCRIPT \
    MINT_OPERATOR_ASSIST_REQUIRES_ENTRY_SURFACE
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

mint_operator_storage_count_lines() {
  local content="${1:-}"
  if [[ -z "$content" ]]; then
    printf '0\n'
  else
    printf '%s\n' "$content" | sed '/^$/d' | wc -l | tr -d ' '
  fi
}

mint_operator_storage_list_required_paths() {
  mint_operator_contract_list '.mount_surface.required_visible_paths'
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

mint_operator_storage_mount_probe_output() {
  [[ -x "$MINT_OPERATOR_MOUNT_SCRIPT" ]] || return 2
  "$MINT_OPERATOR_MOUNT_SCRIPT" status
}

mint_operator_storage_probe_field() {
  local payload="$1"
  local label="$2"
  printf '%s\n' "$payload" | sed -n "s/^${label}: //p" | tail -n 1
}

mint_operator_storage_mount_status() {
  local payload
  if ! payload="$(mint_operator_storage_mount_probe_output 2>/dev/null || true)"; then
    printf 'UNKNOWN|no|no|no|unknown\n'
    return 0
  fi

  local state attached accessible process rc_reachable
  state="$(printf '%s\n' "$payload" | sed -n 's/^Mount: \([A-Z]*\) (.*/\1/p' | tail -n 1)"
  attached="$(mint_operator_storage_probe_field "$payload" 'Mount attached')"
  accessible="$(mint_operator_storage_probe_field "$payload" 'Mount accessible')"
  process="$(mint_operator_storage_probe_field "$payload" 'rclone process')"
  rc_reachable="$(mint_operator_storage_probe_field "$payload" 'RC reachable')"

  [[ -n "$state" ]] || state="UNKNOWN"
  [[ -n "$attached" ]] || attached="no"
  [[ -n "$accessible" ]] || accessible="no"
  [[ -n "$process" ]] || process="no"
  [[ -n "$rc_reachable" ]] || rc_reachable="unknown"
  printf '%s|%s|%s|%s|%s\n' "$state" "$attached" "$accessible" "$process" "$rc_reachable"
}

mint_operator_storage_operator_drop_ready() {
  if [[ "$MINT_OPERATOR_MODE" == "direct_remote_operator_drop" ]]; then
    mint_operator_storage_remote_ok
    return $?
  fi
  [[ -d "$MINT_OPERATOR_MOUNT_OPERATOR_DROP" ]] || return 1
  ls -1 "$MINT_OPERATOR_MOUNT_OPERATOR_DROP" >/dev/null 2>&1
}

mint_operator_storage_required_paths_ready() {
  local path raw
  while IFS= read -r raw; do
    [[ -n "$raw" ]] || continue
    path="$(mint_operator_expand_path "$raw")"
    [[ -d "$path" ]] || return 1
    ls -1 "$path" >/dev/null 2>&1 || return 1
  done < <(mint_operator_storage_list_required_paths)
}

mint_operator_storage_list_mount_fallback_entries() {
  local mount_state="${1:-}"
  [[ "$mount_state" == "ACTIVE" ]] && return 0
  [[ -d "$MINT_OPERATOR_MOUNTPOINT" ]] || return 0

  find "$MINT_OPERATOR_MOUNTPOINT" -mindepth 1 -maxdepth 1 -print 2>/dev/null | sort | while IFS= read -r entry; do
    local name="${entry##*/}"
    mint_operator_storage_ignore_name "$name" && continue
    printf '%s\n' "$entry"
  done
}

mint_operator_storage_legacy_desktop_entries() {
  [[ -d "$MINT_OPERATOR_LEGACY_DESKTOP_PATH" ]] || return 0
  find "$MINT_OPERATOR_LEGACY_DESKTOP_PATH" -mindepth 1 -maxdepth 1 -print 2>/dev/null | sort | while IFS= read -r entry; do
    local name="${entry##*/}"
    mint_operator_storage_ignore_name "$name" && continue
    printf '%s\n' "$entry"
  done
}

mint_operator_storage_legacy_desktop_state() {
  if [[ ! -e "$MINT_OPERATOR_LEGACY_DESKTOP_PATH" ]]; then
    printf 'absent\n'
    return 0
  fi

  local entries
  entries="$(mint_operator_storage_legacy_desktop_entries || true)"
  if [[ -z "$entries" ]]; then
    printf 'empty\n'
  else
    printf 'dirty\n'
  fi
}

mint_operator_storage_assist_helper_state() {
  if [[ -x "$MINT_OPERATOR_ASSIST_HELPER_BIN" ]]; then
    printf 'installed\n'
  else
    printf 'missing\n'
  fi
}

mint_operator_storage_assist_app_state() {
  if [[ -d "$MINT_OPERATOR_ASSIST_FINDER_APP" || -f "$MINT_OPERATOR_ASSIST_FINDER_APP" ]]; then
    printf 'installed\n'
  else
    printf 'missing\n'
  fi
}

mint_operator_storage_assist_surface_state() {
  local helper_state app_state
  helper_state="$(mint_operator_storage_assist_helper_state)"
  app_state="$(mint_operator_storage_assist_app_state)"

  if [[ "$helper_state" == "installed" && "$app_state" == "installed" ]]; then
    printf 'ready\n'
  elif [[ "$helper_state" == "missing" && "$app_state" == "missing" ]]; then
    printf 'missing\n'
  else
    printf 'partial\n'
  fi
}
