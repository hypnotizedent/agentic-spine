#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_OPERATOR_CONTROL_ROOT="${ARCHIVE_OPERATOR_CONTROL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SPINE_ROOT="${SPINE_ROOT:-$ARCHIVE_OPERATOR_CONTROL_ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
source "${ARCHIVE_OPERATOR_CONTROL_ROOT}/ops/lib/runtime-paths.sh"
TARGET_REPO="$(spine_resolve_target_repo)"
CURRENT_ROOT="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$CURRENT_ROOT" && -f "$CURRENT_ROOT/ops/capabilities.yaml" ]]; then
  ARCHIVE_OPERATOR_CONTROL_ROOT="$CURRENT_ROOT"
else
  ARCHIVE_OPERATOR_CONTROL_ROOT="$(spine_resolve_control_root "$TARGET_REPO")"
fi
spine_runtime_resolve_paths >/dev/null

ARCHIVE_OPERATOR_STORAGE_CONTRACT="${ARCHIVE_OPERATOR_STORAGE_CONTRACT:-$ARCHIVE_OPERATOR_CONTROL_ROOT/ops/bindings/operator.storage.surface.contract.yaml}"
ARCHIVE_OPERATOR_RCLONE_BIN="${ARCHIVE_OPERATOR_RCLONE_BIN:-${RCLONE_BIN:-rclone}}"
ARCHIVE_OPERATOR_SECURITY_BIN="${ARCHIVE_OPERATOR_SECURITY_BIN:-security}"
ARCHIVE_OPERATOR_YQ_BIN="${ARCHIVE_OPERATOR_YQ_BIN:-yq}"
ARCHIVE_OPERATOR_JQ_BIN="${ARCHIVE_OPERATOR_JQ_BIN:-jq}"
ARCHIVE_OPERATOR_OSASCRIPT_BIN="${ARCHIVE_OPERATOR_OSASCRIPT_BIN:-osascript}"
ARCHIVE_OPERATOR_TRASH_STRATEGY="${ARCHIVE_OPERATOR_TRASH_STRATEGY:-finder_trash}"
ARCHIVE_OPERATOR_TRASH_ROOT="${ARCHIVE_OPERATOR_TRASH_ROOT:-$HOME/.Trash}"
ARCHIVE_OPERATOR_SKIP_REMOTE_SETUP="${ARCHIVE_OPERATOR_SKIP_REMOTE_SETUP:-0}"
ARCHIVE_OPERATOR_CONTIMEOUT="${ARCHIVE_OPERATOR_CONTIMEOUT:-3s}"
ARCHIVE_OPERATOR_TIMEOUT="${ARCHIVE_OPERATOR_TIMEOUT:-30s}"
ARCHIVE_OPERATOR_RETRIES="${ARCHIVE_OPERATOR_RETRIES:-1}"
ARCHIVE_OPERATOR_LOW_LEVEL_RETRIES="${ARCHIVE_OPERATOR_LOW_LEVEL_RETRIES:-1}"

archive_operator_fail() {
  echo "archive.operator.drop.assist FAIL: $*" >&2
  exit 1
}

archive_operator_need_cmd() {
  command -v "$1" >/dev/null 2>&1 || archive_operator_fail "missing required tool: $1"
}

archive_operator_yq_clean_scalar() {
  local raw="${1:-}"
  printf '%s\n' "$raw" | sed '/^---$/d;/^[[:space:]]*$/d' | head -n 1
}

archive_operator_expand_path() {
  local raw="${1:-}"
  case "$raw" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${raw#"~/"}" ;;
    \$SPINE_EVIDENCE_ROOT/*|\$SPINE_VERIFY_ROOT/*|evidence/*|receipts/*) spine_resolve_mailroom_path "$raw" ;;
    .runtime/*|.evidence/*|.data/*|.backups/*) printf '%s\n' "${ARCHIVE_OPERATOR_CONTROL_ROOT}/${raw}" ;;
    /*) printf '%s\n' "$raw" ;;
    *) printf '%s\n' "$raw" ;;
  esac
}

archive_operator_contract_scalar() {
  local query="$1"
  local default_value="${2:-}"
  local out=""
  out="$("$ARCHIVE_OPERATOR_YQ_BIN" e -N -r "$query // \"\"" "$ARCHIVE_OPERATOR_STORAGE_CONTRACT" 2>/dev/null || true)"
  out="$(archive_operator_yq_clean_scalar "$out")"
  if [[ -n "$out" && "$out" != "null" ]]; then
    printf '%s\n' "$out"
    return 0
  fi
  printf '%s\n' "$default_value"
}

archive_operator_contract_list() {
  local query="$1"
  "$ARCHIVE_OPERATOR_YQ_BIN" e -N -r "$query // [] | .[]" "$ARCHIVE_OPERATOR_STORAGE_CONTRACT" 2>/dev/null | sed '/^---$/d;/^[[:space:]]*$/d'
}

archive_operator_route_json() {
  local route_id="$1"
  ROUTE_ID="$route_id" "$ARCHIVE_OPERATOR_YQ_BIN" e -o=json '.surfaces.archives.assisted_move_surface.routes[] | select(.id == strenv(ROUTE_ID))' "$ARCHIVE_OPERATOR_STORAGE_CONTRACT" 2>/dev/null || true
}

archive_operator_route_field() {
  local route_id="$1"
  local jq_query="$2"
  local route_json=""
  route_json="$(archive_operator_route_json "$route_id")"
  [[ -n "$route_json" ]] || return 1
  printf '%s' "$route_json" | "$ARCHIVE_OPERATOR_JQ_BIN" -r "$jq_query // \"\"" 2>/dev/null
}

archive_operator_route_ids() {
  "$ARCHIVE_OPERATOR_YQ_BIN" e -N -r '.surfaces.archives.assisted_move_surface.routes[].id // ""' "$ARCHIVE_OPERATOR_STORAGE_CONTRACT" 2>/dev/null | sed '/^---$/d;/^[[:space:]]*$/d'
}

archive_operator_load_contract() {
  [[ -f "$ARCHIVE_OPERATOR_STORAGE_CONTRACT" ]] || archive_operator_fail "missing contract: $ARCHIVE_OPERATOR_STORAGE_CONTRACT"
  archive_operator_need_cmd "$ARCHIVE_OPERATOR_YQ_BIN"
  archive_operator_need_cmd "$ARCHIVE_OPERATOR_JQ_BIN"
  archive_operator_need_cmd "$ARCHIVE_OPERATOR_RCLONE_BIN"

  ARCHIVE_OPERATOR_MOUNT_ROOT="$(archive_operator_expand_path "$(archive_operator_contract_scalar '.surfaces.archives.mount_root' '~/Archives')")"
  ARCHIVE_OPERATOR_MOUNT_SCRIPT="$(archive_operator_expand_path "$(archive_operator_contract_scalar '.surfaces.archives.mount_script_path' '')")"
  ARCHIVE_OPERATOR_ASSIST_MODE="$(archive_operator_contract_scalar '.surfaces.archives.assisted_move_surface.mode' 'governed_mountless_remote_move')"
  ARCHIVE_OPERATOR_ASSIST_HELPER_BIN="$(archive_operator_expand_path "$(archive_operator_contract_scalar '.surfaces.archives.assisted_move_surface.helper_bin_path' '~/.local/bin/archive-operator-drop-assist')")"
  ARCHIVE_OPERATOR_ASSIST_FINDER_APP="$(archive_operator_expand_path "$(archive_operator_contract_scalar '.surfaces.archives.assisted_move_surface.finder_app_path' '~/Applications/Archive Operator Drop.app')")"
  ARCHIVE_OPERATOR_ASSIST_INSTALLER_SCRIPT="$(archive_operator_expand_path "$(archive_operator_contract_scalar '.surfaces.archives.assisted_move_surface.installer_script_path' '')")"
  ARCHIVE_OPERATOR_ASSIST_RECEIPT_ROOT="$(archive_operator_expand_path "$(archive_operator_contract_scalar '.surfaces.archives.assisted_move_surface.receipts_root' '.evidence/spine/archive/operator-drop-assist')")"
  ARCHIVE_OPERATOR_ASSIST_DEFAULT_ROUTE="$(archive_operator_contract_scalar '.surfaces.archives.assisted_move_surface.default_route' 'Legacy')"
  ARCHIVE_OPERATOR_ASSIST_SELECTOR_REQUIRED="$(archive_operator_contract_scalar '.surfaces.archives.assisted_move_surface.route_selector_required' 'true')"
  ARCHIVE_OPERATOR_ASSIST_SELECTOR_LABEL="$(archive_operator_contract_scalar '.surfaces.archives.assisted_move_surface.selector_label' 'family')"
  ARCHIVE_OPERATOR_ASSIST_VERIFICATION_METHOD="$(archive_operator_contract_scalar '.surfaces.archives.assisted_move_surface.verification_method' 'rclone_check_size_one_way')"
  ARCHIVE_OPERATOR_ASSIST_CLEANUP_POLICY="$(archive_operator_contract_scalar '.surfaces.archives.assisted_move_surface.cleanup_policy' 'trash_after_verified_arrival')"
  ARCHIVE_OPERATOR_SMB_HOST="$(archive_operator_contract_scalar '.surfaces.archives.remote_setup.smb_host' '100.96.211.33')"
  ARCHIVE_OPERATOR_SMB_USER="$(archive_operator_contract_scalar '.surfaces.archives.remote_setup.smb_user' 'archive')"

  export \
    ARCHIVE_OPERATOR_MOUNT_ROOT \
    ARCHIVE_OPERATOR_MOUNT_SCRIPT \
    ARCHIVE_OPERATOR_ASSIST_MODE \
    ARCHIVE_OPERATOR_ASSIST_HELPER_BIN \
    ARCHIVE_OPERATOR_ASSIST_FINDER_APP \
    ARCHIVE_OPERATOR_ASSIST_INSTALLER_SCRIPT \
    ARCHIVE_OPERATOR_ASSIST_RECEIPT_ROOT \
    ARCHIVE_OPERATOR_ASSIST_DEFAULT_ROUTE \
    ARCHIVE_OPERATOR_ASSIST_SELECTOR_REQUIRED \
    ARCHIVE_OPERATOR_ASSIST_SELECTOR_LABEL \
    ARCHIVE_OPERATOR_ASSIST_VERIFICATION_METHOD \
    ARCHIVE_OPERATOR_ASSIST_CLEANUP_POLICY \
    ARCHIVE_OPERATOR_SMB_HOST \
    ARCHIVE_OPERATOR_SMB_USER
}

archive_operator_mount_status() {
  [[ -x "$ARCHIVE_OPERATOR_MOUNT_SCRIPT" ]] || { printf 'UNKNOWN\n'; return 0; }
  local payload=""
  payload="$("$ARCHIVE_OPERATOR_MOUNT_SCRIPT" status 2>/dev/null || true)"
  printf '%s\n' "$payload" | sed -n 's/^Mount: \([A-Z]*\) (.*/\1/p' | tail -n 1
}

archive_operator_assist_helper_state() {
  if [[ -x "$ARCHIVE_OPERATOR_ASSIST_HELPER_BIN" ]]; then
    printf 'installed\n'
  else
    printf 'missing\n'
  fi
}

archive_operator_assist_app_state() {
  if [[ -d "$ARCHIVE_OPERATOR_ASSIST_FINDER_APP" || -f "$ARCHIVE_OPERATOR_ASSIST_FINDER_APP" ]]; then
    printf 'installed\n'
  else
    printf 'missing\n'
  fi
}

archive_operator_assist_surface_state() {
  local helper_state app_state
  helper_state="$(archive_operator_assist_helper_state)"
  app_state="$(archive_operator_assist_app_state)"
  if [[ "$helper_state" == "installed" && "$app_state" == "installed" ]]; then
    printf 'ready\n'
  else
    printf 'missing\n'
  fi
}

archive_operator_get_password() {
  archive_operator_need_cmd "$ARCHIVE_OPERATOR_SECURITY_BIN"
  "$ARCHIVE_OPERATOR_SECURITY_BIN" find-internet-password -w -a "$ARCHIVE_OPERATOR_SMB_USER" -s "$ARCHIVE_OPERATOR_SMB_HOST"
}

archive_operator_remote_defined() {
  local remote_name="$1"
  "$ARCHIVE_OPERATOR_RCLONE_BIN" config show "$remote_name" >/dev/null 2>&1
}

archive_operator_ensure_rclone_remotes() {
  [[ "$ARCHIVE_OPERATOR_SKIP_REMOTE_SETUP" == "1" ]] && return 0
  local archive_pass
  archive_pass="$(archive_operator_get_password)"
  while IFS= read -r share_json; do
    [[ -n "$share_json" ]] || continue
    local remote_name share_name
    remote_name="$(printf '%s' "$share_json" | "$ARCHIVE_OPERATOR_JQ_BIN" -r '.remote_name // ""')"
    share_name="$(printf '%s' "$share_json" | "$ARCHIVE_OPERATOR_JQ_BIN" -r '.share // ""')"
    [[ -n "$remote_name" && -n "$share_name" ]] || archive_operator_fail "archive remote setup row missing remote_name/share"
    archive_operator_remote_defined "$remote_name" && continue
    "$ARCHIVE_OPERATOR_RCLONE_BIN" config create "$remote_name" smb \
      host "$ARCHIVE_OPERATOR_SMB_HOST" \
      user "$ARCHIVE_OPERATOR_SMB_USER" \
      pass "$archive_pass" \
      share "$share_name" \
      --obscure >/dev/null
  done < <("$ARCHIVE_OPERATOR_YQ_BIN" e -I=0 -o=json '.surfaces.archives.remote_setup.shares[]' "$ARCHIVE_OPERATOR_STORAGE_CONTRACT" 2>/dev/null)
}

archive_operator_assist_remote_ok() {
  local probe_remote="$1"
  "$ARCHIVE_OPERATOR_RCLONE_BIN" lsf "$probe_remote" \
    --max-depth 1 \
    --contimeout "$ARCHIVE_OPERATOR_CONTIMEOUT" \
    --timeout "$ARCHIVE_OPERATOR_TIMEOUT" \
    --retries "$ARCHIVE_OPERATOR_RETRIES" \
    --low-level-retries "$ARCHIVE_OPERATOR_LOW_LEVEL_RETRIES" >/dev/null 2>&1
}

archive_operator_rclone_base_args() {
  printf '%s\0' \
    --contimeout "$ARCHIVE_OPERATOR_CONTIMEOUT" \
    --timeout "$ARCHIVE_OPERATOR_TIMEOUT" \
    --retries "$ARCHIVE_OPERATOR_RETRIES" \
    --low-level-retries "$ARCHIVE_OPERATOR_LOW_LEVEL_RETRIES"
}

archive_operator_rclone_run() {
  local -a base_args
  mapfile -d '' -t base_args < <(archive_operator_rclone_base_args)
  "$ARCHIVE_OPERATOR_RCLONE_BIN" "$@" "${base_args[@]}"
}

archive_operator_receipt_id() {
  date -u +"ARCHIVE-DROP-%Y%m%dT%H%M%SZ-$PPID-$RANDOM"
}

archive_operator_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

archive_operator_absolute_path() {
  local raw="$1"
  (cd "$(dirname "$raw")" && printf '%s/%s\n' "$(pwd)" "$(basename "$raw")")
}

archive_operator_path_in_tree() {
  local path_a="$1"
  local path_b="$2"
  [[ "$path_a" == "$path_b" || "$path_a" == "$path_b/"* ]]
}

archive_operator_unique_path() {
  local target="$1"
  if [[ ! -e "$target" ]]; then
    printf '%s\n' "$target"
    return 0
  fi
  local dir base name ext candidate idx
  dir="$(dirname "$target")"
  base="$(basename "$target")"
  name="$base"
  ext=""
  if [[ "$base" == *.* && "$base" != .* ]]; then
    name="${base%.*}"
    ext=".${base##*.}"
  fi
  idx=1
  while :; do
    candidate="${dir}/${name}-${idx}${ext}"
    [[ ! -e "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
    idx=$((idx + 1))
  done
}

archive_operator_collect_metrics() {
  local root="$1"
  local count=0
  local bytes=0
  while IFS= read -r -d '' file; do
    count=$((count + 1))
    bytes=$((bytes + $(stat -f '%z' "$file")))
  done < <(find "$root" -type f -print0)
  printf '%s|%s\n' "$count" "$bytes"
}

archive_operator_source_root_allowed() {
  local source_path="$1"
  local raw allowed_root any=0
  while IFS= read -r raw; do
    [[ -n "$raw" ]] || continue
    any=1
    allowed_root="$(archive_operator_expand_path "$raw")"
    archive_operator_path_in_tree "$source_path" "$allowed_root" && return 0
  done < <(archive_operator_contract_list '.surfaces.archives.assisted_move_surface.allowed_source_roots')
  [[ "$any" -eq 0 ]] && return 0
  return 1
}

archive_operator_normalize_relative_path() {
  local raw="${1:-}"
  raw="${raw#/}"
  raw="${raw%/}"
  if [[ -z "$raw" ]]; then
    printf '%s\n' ""
    return 0
  fi
  [[ "$raw" != *".."* ]] || archive_operator_fail "relative destination path must not contain '..': $raw"
  [[ "$raw" != "." && "$raw" != .*"/.."* ]] || archive_operator_fail "relative destination path must be under the selected route: $raw"
  printf '%s\n' "$raw"
}

archive_operator_join_remote_path() {
  local base="$1"
  local suffix="${2:-}"
  suffix="$(archive_operator_normalize_relative_path "$suffix")"
  if [[ -z "$suffix" ]]; then
    printf '%s\n' "${base%/}"
  else
    printf '%s/%s\n' "${base%/}" "$suffix"
  fi
}

archive_operator_join_browse_path() {
  local base="$1"
  local suffix="${2:-}"
  suffix="$(archive_operator_normalize_relative_path "$suffix")"
  if [[ -z "$suffix" ]]; then
    printf '%s\n' "${base%/}"
  else
    printf '%s/%s\n' "${base%/}" "$suffix"
  fi
}

archive_operator_remote_path_exists() {
  local remote_path="$1"
  archive_operator_rclone_run lsf "$remote_path" --max-depth 1 >/dev/null 2>&1
}

archive_operator_remote_purge() {
  local remote_path="$1"
  archive_operator_rclone_run purge "$remote_path" >/dev/null 2>&1 || true
}

archive_operator_verify_remote_parity() {
  local source_dir="$1"
  local remote_dir="$2"
  archive_operator_rclone_run check "$source_dir" "$remote_dir" --one-way --size-only >/dev/null 2>&1
}

archive_operator_write_receipt() {
  local receipt_id="$1"
  local status="$2"
  local route_id="$3"
  local source_path="$4"
  local destination_remote="$5"
  local destination_browse="$6"
  local cleanup_action="$7"
  local preview="$8"
  local file_count="$9"
  local total_bytes="${10}"
  local into_path="${11}"

  local receipt_dir="${ARCHIVE_OPERATOR_ASSIST_RECEIPT_ROOT}/${receipt_id}"
  mkdir -p "$receipt_dir"
  cat > "${receipt_dir}/receipt.yaml" <<EOF
receipt_id: ${receipt_id}
status: ${status}
generated_at: $(archive_operator_timestamp)
surface: archives
route: ${route_id}
source_path: ${source_path}
destination_remote: ${destination_remote}
destination_browse_path: ${destination_browse}
relative_destination_path: ${into_path}
cleanup_action: ${cleanup_action}
preview: ${preview}
file_count: ${file_count}
total_bytes: ${total_bytes}
verification_method: ${ARCHIVE_OPERATOR_ASSIST_VERIFICATION_METHOD}
EOF
}

archive_operator_trash_source() {
  local source_path="$1"
  case "$ARCHIVE_OPERATOR_TRASH_STRATEGY" in
    keep) return 0 ;;
    trash_dir)
      mkdir -p "$ARCHIVE_OPERATOR_TRASH_ROOT"
      local trash_target
      trash_target="$(archive_operator_unique_path "${ARCHIVE_OPERATOR_TRASH_ROOT}/$(basename "$source_path")")"
      mv "$source_path" "$trash_target"
      return 0
      ;;
    finder_trash)
      if command -v "$ARCHIVE_OPERATOR_OSASCRIPT_BIN" >/dev/null 2>&1; then
        if "$ARCHIVE_OPERATOR_OSASCRIPT_BIN" - "$source_path" >/dev/null 2>&1 <<'EOF'
on run argv
  tell application "Finder"
    delete POSIX file (item 1 of argv)
  end tell
end run
EOF
        then
          return 0
        fi
      fi
      ;;
  esac
  mkdir -p "$ARCHIVE_OPERATOR_TRASH_ROOT"
  local fallback_target
  fallback_target="$(archive_operator_unique_path "${ARCHIVE_OPERATOR_TRASH_ROOT}/$(basename "$source_path")")"
  mv "$source_path" "$fallback_target"
}
