#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_OPERATOR_CONTROL_ROOT="${ARCHIVE_OPERATOR_CONTROL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SPINE_ROOT="${SPINE_ROOT:-$ARCHIVE_OPERATOR_CONTROL_ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
source "${ARCHIVE_OPERATOR_CONTROL_ROOT}/ops/lib/runtime-paths.sh"
TARGET_REPO="$(spine_resolve_target_repo)"
CURRENT_ROOT="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$CURRENT_ROOT" && -f "$CURRENT_ROOT/ops/capabilities.runtime.yaml" ]]; then
  ARCHIVE_OPERATOR_CONTROL_ROOT="$CURRENT_ROOT"
else
  ARCHIVE_OPERATOR_CONTROL_ROOT="$(spine_resolve_control_root "$TARGET_REPO")"
fi
spine_runtime_resolve_paths >/dev/null

ARCHIVE_OPERATOR_STORAGE_CONTRACT="${ARCHIVE_OPERATOR_STORAGE_CONTRACT:-$ARCHIVE_OPERATOR_CONTROL_ROOT/ops/bindings/operator.storage.surface.contract.yaml}"
ARCHIVE_OPERATOR_RCLONE_BIN="${ARCHIVE_OPERATOR_RCLONE_BIN:-${RCLONE_BIN:-rclone}}"
ARCHIVE_OPERATOR_RSYNC_BIN="${ARCHIVE_OPERATOR_RSYNC_BIN:-rsync}"
ARCHIVE_OPERATOR_SSH_BIN="${ARCHIVE_OPERATOR_SSH_BIN:-ssh}"
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
    \$SPINE_STATE/*) printf '%s\n' "${SPINE_STATE}/${raw#\$SPINE_STATE/}" ;;
    \$SPINE_RUNTIME_ROOT/*) printf '%s\n' "${SPINE_RUNTIME_ROOT}/${raw#\$SPINE_RUNTIME_ROOT/}" ;;
    \$SPINE_TMP/*) printf '%s\n' "${SPINE_TMP}/${raw#\$SPINE_TMP/}" ;;
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
  ARCHIVE_OPERATOR_REHOME_MODE="$(archive_operator_contract_scalar '.surfaces.archives.rehome_surface.mode' 'governed_remote_source_rehome')"
  ARCHIVE_OPERATOR_REHOME_RECEIPT_ROOT="$(archive_operator_expand_path "$(archive_operator_contract_scalar '.surfaces.archives.rehome_surface.receipts_root' '$SPINE_EVIDENCE_ROOT/operator-storage/archive/operator-drop-assist/rehome')")"
  ARCHIVE_OPERATOR_REHOME_RELAY_STAGE_ROOT="$(archive_operator_expand_path "$(archive_operator_contract_scalar '.surfaces.archives.rehome_surface.relay_stage_root' '$SPINE_STATE/operator-storage/archive/rehome/staging')")"
  ARCHIVE_OPERATOR_REHOME_DEFAULT_VERIFY_MODE="$(archive_operator_contract_scalar '.surfaces.archives.rehome_surface.default_verify_mode' 'quick')"
  ARCHIVE_OPERATOR_SMB_HOST="$(archive_operator_contract_scalar '.surfaces.archives.remote_setup.smb_host' '100.x.x.x')"
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
    ARCHIVE_OPERATOR_REHOME_MODE \
    ARCHIVE_OPERATOR_REHOME_RECEIPT_ROOT \
    ARCHIVE_OPERATOR_REHOME_RELAY_STAGE_ROOT \
    ARCHIVE_OPERATOR_REHOME_DEFAULT_VERIFY_MODE \
    ARCHIVE_OPERATOR_SMB_HOST \
    ARCHIVE_OPERATOR_SMB_USER
}

archive_operator_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

archive_operator_require_rclone() {
  archive_operator_need_cmd "$ARCHIVE_OPERATOR_RCLONE_BIN"
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
  archive_operator_require_rclone
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
  archive_operator_require_rclone
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
  archive_operator_require_rclone
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

archive_operator_rehome_host_json() {
  local host_id="$1"
  HOST_ID="$host_id" "$ARCHIVE_OPERATOR_YQ_BIN" e -o=json '.surfaces.archives.rehome_surface.host_bindings[] | select(.id == strenv(HOST_ID))' "$ARCHIVE_OPERATOR_STORAGE_CONTRACT" 2>/dev/null || true
}

archive_operator_rehome_host_field() {
  local host_id="$1"
  local jq_query="$2"
  local host_json=""
  host_json="$(archive_operator_rehome_host_json "$host_id")"
  [[ -n "$host_json" ]] || return 1
  printf '%s' "$host_json" | "$ARCHIVE_OPERATOR_JQ_BIN" -r "$jq_query // \"\"" 2>/dev/null
}

archive_operator_rehome_host_allowed_roots() {
  local host_id="$1"
  HOST_ID="$host_id" "$ARCHIVE_OPERATOR_YQ_BIN" e -N -r '.surfaces.archives.rehome_surface.host_bindings[] | select(.id == strenv(HOST_ID)) | .allowed_source_roots[] // ""' "$ARCHIVE_OPERATOR_STORAGE_CONTRACT" 2>/dev/null | sed '/^---$/d;/^[[:space:]]*$/d'
}

archive_operator_rehome_host_transport() {
  archive_operator_rehome_host_field "$1" '.transport' 2>/dev/null || true
}

archive_operator_rehome_host_ssh_spec() {
  local host_id="$1"
  local ssh_target ssh_user
  ssh_target="$(archive_operator_rehome_host_field "$host_id" '.ssh_target')"
  ssh_user="$(archive_operator_rehome_host_field "$host_id" '.ssh_user' 2>/dev/null || true)"
  [[ -n "$ssh_target" ]] || archive_operator_fail "rehome host binding missing ssh_target: $host_id"
  if [[ -n "$ssh_user" ]]; then
    printf '%s@%s\n' "$ssh_user" "$ssh_target"
  else
    printf '%s\n' "$ssh_target"
  fi
}

archive_operator_rehome_host_fixture_root() {
  local host_id="$1"
  archive_operator_expand_path "$(archive_operator_rehome_host_field "$host_id" '.fixture_root')"
}

archive_operator_rehome_host_path() {
  local host_id="$1"
  local abs_path="$2"
  local transport
  transport="$(archive_operator_rehome_host_transport "$host_id")"
  case "$transport" in
    local_fixture)
      local fixture_root
      fixture_root="$(archive_operator_rehome_host_fixture_root "$host_id")"
      [[ -n "$fixture_root" ]] || archive_operator_fail "local_fixture host binding missing fixture_root: $host_id"
      printf '%s/%s\n' "${fixture_root%/}" "${abs_path#/}"
      ;;
    *)
      printf '%s\n' "$abs_path"
      ;;
  esac
}

archive_operator_rehome_source_root_allowed() {
  local host_id="$1"
  local source_path="$2"
  local raw allowed_root any=0
  while IFS= read -r raw; do
    [[ -n "$raw" ]] || continue
    any=1
    allowed_root="$(archive_operator_expand_path "$raw")"
    archive_operator_path_in_tree "$source_path" "$allowed_root" && return 0
  done < <(archive_operator_rehome_host_allowed_roots "$host_id")
  [[ "$any" -eq 0 ]] && return 1
  return 1
}

archive_operator_rehome_verify_basis() {
  local verify_mode="$1"
  archive_operator_contract_scalar ".surfaces.archives.rehome_surface.verify_modes.\"${verify_mode}\".manifest_basis" ""
}

archive_operator_rehome_verify_allows_delete() {
  local verify_mode="$1"
  archive_operator_truthy "$(archive_operator_contract_scalar ".surfaces.archives.rehome_surface.verify_modes.\"${verify_mode}\".delete_allowed" "false")"
}

archive_operator_rehome_receipt_id() {
  date -u +"ARCHIVE-REHOME-%Y%m%dT%H%M%SZ-$PPID-$RANDOM"
}

archive_operator_sha256_file() {
  local target="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$target" | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$target" | awk '{print $1}'
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$target" | awk '{print $NF}'
    return 0
  fi
  archive_operator_fail "missing checksum tool for strict verification (need sha256sum, shasum, or openssl)"
}

archive_operator_manifest_local() {
  local basis="$1"
  local root="$2"
  local output_path="$3"
  [[ -d "$root" ]] || archive_operator_fail "missing directory for manifest: $root"
  : > "$output_path"
  (
    cd "$root"
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      rel="${rel#./}"
      local size
      size="$(wc -c < "$rel" | tr -d ' ')"
      if [[ "$basis" == "size_count" ]]; then
        printf '%s\t%s\n' "$rel" "$size"
      else
        local hash
        hash="$(archive_operator_sha256_file "$rel")"
        printf '%s\t%s\t%s\n' "$rel" "$size" "$hash"
      fi
    done < <(find . -type f -print | LC_ALL=C sort)
  ) > "$output_path"
}

archive_operator_manifest_remote() {
  local ssh_spec="$1"
  local basis="$2"
  local root="$3"
  local output_path="$4"
  "$ARCHIVE_OPERATOR_SSH_BIN" "$ssh_spec" sh -s -- "$basis" "$root" > "$output_path" <<'EOF'
set -eu
basis="$1"
root="$2"
if [ ! -d "$root" ]; then
  echo "missing directory for manifest: $root" >&2
  exit 44
fi
checksum_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
    return 0
  fi
  echo "missing checksum tool for strict verification" >&2
  exit 45
}
cd "$root"
find . -type f -print | LC_ALL=C sort | while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  rel="${rel#./}"
  size="$(wc -c < "$rel" | tr -d ' ')"
  if [ "$basis" = "size_count" ]; then
    printf '%s\t%s\n' "$rel" "$size"
  else
    hash="$(checksum_file "$rel")"
    printf '%s\t%s\t%s\n' "$rel" "$size" "$hash"
  fi
done
EOF
}

archive_operator_binding_manifest() {
  local host_id="$1"
  local abs_path="$2"
  local basis="$3"
  local output_path="$4"
  local transport
  transport="$(archive_operator_rehome_host_transport "$host_id")"
  case "$transport" in
    local_fixture)
      archive_operator_manifest_local "$basis" "$(archive_operator_rehome_host_path "$host_id" "$abs_path")" "$output_path"
      ;;
    ssh|"")
      archive_operator_need_cmd "$ARCHIVE_OPERATOR_SSH_BIN"
      archive_operator_manifest_remote "$(archive_operator_rehome_host_ssh_spec "$host_id")" "$basis" "$abs_path" "$output_path"
      ;;
    *)
      archive_operator_fail "unsupported rehome host transport '$transport' for manifest: $host_id"
      ;;
  esac
}

archive_operator_binding_path_exists() {
  local host_id="$1"
  local abs_path="$2"
  local transport
  transport="$(archive_operator_rehome_host_transport "$host_id")"
  case "$transport" in
    local_fixture)
      [[ -e "$(archive_operator_rehome_host_path "$host_id" "$abs_path")" ]]
      ;;
    ssh|"")
      archive_operator_need_cmd "$ARCHIVE_OPERATOR_SSH_BIN"
      "$ARCHIVE_OPERATOR_SSH_BIN" "$(archive_operator_rehome_host_ssh_spec "$host_id")" sh -s -- "$abs_path" <<'EOF' >/dev/null 2>&1
set -eu
test -e "$1"
EOF
      ;;
    *)
      return 1
      ;;
  esac
}

archive_operator_binding_mkdir_p() {
  local host_id="$1"
  local abs_path="$2"
  local transport
  transport="$(archive_operator_rehome_host_transport "$host_id")"
  case "$transport" in
    local_fixture)
      mkdir -p "$(archive_operator_rehome_host_path "$host_id" "$abs_path")"
      ;;
    ssh|"")
      archive_operator_need_cmd "$ARCHIVE_OPERATOR_SSH_BIN"
      "$ARCHIVE_OPERATOR_SSH_BIN" "$(archive_operator_rehome_host_ssh_spec "$host_id")" sh -s -- "$abs_path" <<'EOF'
set -eu
mkdir -p "$1"
EOF
      ;;
    *)
      archive_operator_fail "unsupported rehome host transport '$transport' for mkdir: $host_id"
      ;;
  esac
}

archive_operator_copy_dir_local_to_local() {
  local source_dir="$1"
  local destination_dir="$2"
  mkdir -p "$destination_dir"
  cp -R "$source_dir"/. "$destination_dir"/
}

archive_operator_rehome_pull_to_stage() {
  local source_host_id="$1"
  local source_path="$2"
  local stage_dir="$3"
  local transport
  transport="$(archive_operator_rehome_host_transport "$source_host_id")"
  case "$transport" in
    local_fixture)
      archive_operator_copy_dir_local_to_local "$(archive_operator_rehome_host_path "$source_host_id" "$source_path")" "$stage_dir"
      ;;
    ssh|"")
      archive_operator_need_cmd "$ARCHIVE_OPERATOR_RSYNC_BIN"
      archive_operator_need_cmd "$ARCHIVE_OPERATOR_SSH_BIN"
      mkdir -p "$stage_dir"
      "$ARCHIVE_OPERATOR_RSYNC_BIN" -a --protect-args "$(archive_operator_rehome_host_ssh_spec "$source_host_id"):${source_path%/}/" "${stage_dir%/}/" >/dev/null
      ;;
    *)
      archive_operator_fail "unsupported rehome host transport '$transport' for relay pull: $source_host_id"
      ;;
  esac
}

archive_operator_rehome_push_stage_to_destination() {
  local stage_dir="$1"
  local destination_host_id="$2"
  local destination_path="$3"
  local transport
  transport="$(archive_operator_rehome_host_transport "$destination_host_id")"
  case "$transport" in
    local_fixture)
      archive_operator_copy_dir_local_to_local "$stage_dir" "$(archive_operator_rehome_host_path "$destination_host_id" "$destination_path")"
      ;;
    ssh|"")
      archive_operator_need_cmd "$ARCHIVE_OPERATOR_RSYNC_BIN"
      archive_operator_binding_mkdir_p "$destination_host_id" "$destination_path"
      "$ARCHIVE_OPERATOR_RSYNC_BIN" -a --protect-args "${stage_dir%/}/" "$(archive_operator_rehome_host_ssh_spec "$destination_host_id"):${destination_path%/}/" >/dev/null
      ;;
    *)
      archive_operator_fail "unsupported rehome host transport '$transport' for relay push: $destination_host_id"
      ;;
  esac
}

archive_operator_rehome_direct_possible() {
  local source_host_id="$1"
  local destination_host_id="$2"
  local destination_root="$3"
  archive_operator_truthy "$(archive_operator_rehome_host_field "$source_host_id" '.direct_remote_allowed' 2>/dev/null || echo false)" || return 1
  local source_transport destination_transport
  source_transport="$(archive_operator_rehome_host_transport "$source_host_id")"
  destination_transport="$(archive_operator_rehome_host_transport "$destination_host_id")"
  if [[ "$source_transport" == "local_fixture" && "$destination_transport" == "local_fixture" ]]; then
    [[ -d "$(archive_operator_rehome_host_path "$destination_host_id" "$destination_root")" ]]
    return
  fi
  if [[ "$source_transport" == "ssh" || -z "$source_transport" ]]; then
    archive_operator_need_cmd "$ARCHIVE_OPERATOR_SSH_BIN"
    "$ARCHIVE_OPERATOR_SSH_BIN" "$(archive_operator_rehome_host_ssh_spec "$source_host_id")" sh -s -- "$(archive_operator_rehome_host_ssh_spec "$destination_host_id")" "$destination_root" <<'EOF' >/dev/null 2>&1
set -eu
dest_spec="$1"
dest_root="$2"
command -v rsync >/dev/null 2>&1
command -v ssh >/dev/null 2>&1
ssh "$dest_spec" sh -s -- "$dest_root" <<'INNER'
set -eu
test -d "$1"
INNER
EOF
    return
  fi
  return 1
}

archive_operator_rehome_direct_copy() {
  local source_host_id="$1"
  local source_path="$2"
  local destination_host_id="$3"
  local destination_path="$4"
  local source_transport destination_transport
  source_transport="$(archive_operator_rehome_host_transport "$source_host_id")"
  destination_transport="$(archive_operator_rehome_host_transport "$destination_host_id")"
  if [[ "$source_transport" == "local_fixture" && "$destination_transport" == "local_fixture" ]]; then
    archive_operator_copy_dir_local_to_local "$(archive_operator_rehome_host_path "$source_host_id" "$source_path")" "$(archive_operator_rehome_host_path "$destination_host_id" "$destination_path")"
    return 0
  fi
  if [[ "$source_transport" == "ssh" || -z "$source_transport" ]]; then
    archive_operator_need_cmd "$ARCHIVE_OPERATOR_SSH_BIN"
    "$ARCHIVE_OPERATOR_SSH_BIN" "$(archive_operator_rehome_host_ssh_spec "$source_host_id")" sh -s -- "$source_path" "$(archive_operator_rehome_host_ssh_spec "$destination_host_id")" "$destination_path" <<'EOF'
set -eu
source_path="$1"
dest_spec="$2"
dest_path="$3"
if [ ! -d "$source_path" ]; then
  echo "missing source directory: $source_path" >&2
  exit 44
fi
command -v rsync >/dev/null 2>&1 || { echo "missing rsync on source host" >&2; exit 45; }
command -v ssh >/dev/null 2>&1 || { echo "missing ssh on source host" >&2; exit 46; }
ssh "$dest_spec" sh -s -- "$dest_path" <<'INNER'
set -eu
mkdir -p "$1"
INNER
rsync -a --protect-args "${source_path%/}/" "${dest_spec}:${dest_path%/}/" >/dev/null
EOF
    return 0
  fi
  archive_operator_fail "unsupported transport combination for direct rehome: ${source_transport:-ssh} -> ${destination_transport:-ssh}"
}

archive_operator_rehome_delete_source() {
  local source_host_id="$1"
  local source_path="$2"
  local transport
  transport="$(archive_operator_rehome_host_transport "$source_host_id")"
  case "$transport" in
    local_fixture)
      rm -rf -- "$(archive_operator_rehome_host_path "$source_host_id" "$source_path")"
      ;;
    ssh|"")
      archive_operator_need_cmd "$ARCHIVE_OPERATOR_SSH_BIN"
      "$ARCHIVE_OPERATOR_SSH_BIN" "$(archive_operator_rehome_host_ssh_spec "$source_host_id")" sh -s -- "$source_path" <<'EOF'
set -eu
[ -d "$1" ] || { echo "missing source directory for retirement: $1" >&2; exit 44; }
rm -rf -- "$1"
EOF
      ;;
    *)
      archive_operator_fail "unsupported rehome host transport '$transport' for source retirement: $source_host_id"
      ;;
  esac
}

archive_operator_manifest_line_count() {
  local manifest_path="$1"
  awk 'END {print NR+0}' "$manifest_path"
}

archive_operator_manifest_total_bytes() {
  local manifest_path="$1"
  awk -F '\t' '{sum += $2} END {print sum+0}' "$manifest_path"
}

archive_operator_manifest_compare() {
  local source_manifest="$1"
  local destination_manifest="$2"
  cmp -s "$source_manifest" "$destination_manifest"
}

archive_operator_manifest_diff_summary() {
  local source_manifest="$1"
  local destination_manifest="$2"
  local summary_path="$3"
  local source_only_count destination_only_count
  source_only_count="$(comm -23 "$source_manifest" "$destination_manifest" | awk 'END {print NR+0}')"
  destination_only_count="$(comm -13 "$source_manifest" "$destination_manifest" | awk 'END {print NR+0}')"
  cat > "$summary_path" <<EOF
metric	value
source_entries	$(archive_operator_manifest_line_count "$source_manifest")
destination_entries	$(archive_operator_manifest_line_count "$destination_manifest")
source_only	${source_only_count}
destination_only	${destination_only_count}
manifests_equal	$(archive_operator_manifest_compare "$source_manifest" "$destination_manifest" && echo true || echo false)
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
