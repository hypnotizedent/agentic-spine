#!/usr/bin/env bash
set -euo pipefail

OPERATOR_STORAGE_CONTROL_ROOT="${OPERATOR_STORAGE_CONTROL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SPINE_ROOT="${SPINE_ROOT:-$OPERATOR_STORAGE_CONTROL_ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
source "${OPERATOR_STORAGE_CONTROL_ROOT}/ops/lib/runtime-paths.sh"
TARGET_REPO="$(spine_resolve_target_repo)"
CURRENT_ROOT="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$CURRENT_ROOT" && -f "$CURRENT_ROOT/ops/capabilities.yaml" ]]; then
  OPERATOR_STORAGE_CONTROL_ROOT="$CURRENT_ROOT"
else
  OPERATOR_STORAGE_CONTROL_ROOT="$(spine_resolve_control_root "$TARGET_REPO")"
fi
spine_runtime_resolve_paths >/dev/null

OPERATOR_STORAGE_SURFACE_CONTRACT="${OPERATOR_STORAGE_SURFACE_CONTRACT:-$OPERATOR_STORAGE_CONTROL_ROOT/ops/bindings/operator.storage.surface.contract.yaml}"
OPERATOR_STORAGE_YQ_BIN="${OPERATOR_STORAGE_YQ_BIN:-yq}"
OPERATOR_STORAGE_JQ_BIN="${OPERATOR_STORAGE_JQ_BIN:-jq}"
OPERATOR_STORAGE_LAUNCHCTL_BIN="${OPERATOR_STORAGE_LAUNCHCTL_BIN:-launchctl}"
OPERATOR_STORAGE_UID="${OPERATOR_STORAGE_UID:-$(id -u)}"

operator_storage_fail() {
  echo "operator.storage.surface FAIL: $*" >&2
  exit 1
}

operator_storage_need_cmd() {
  command -v "$1" >/dev/null 2>&1 || operator_storage_fail "missing required tool: $1"
}

operator_storage_yq_clean_scalar() {
  local raw="${1:-}"
  printf '%s\n' "$raw" | sed '/^---$/d;/^[[:space:]]*$/d' | head -n 1
}

operator_storage_expand_path() {
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

operator_storage_contract_scalar() {
  local query="$1"
  local default_value="${2:-}"
  local out=""
  out="$("$OPERATOR_STORAGE_YQ_BIN" e -N -r "$query // \"\"" "$OPERATOR_STORAGE_SURFACE_CONTRACT" 2>/dev/null || true)"
  out="$(operator_storage_yq_clean_scalar "$out")"
  if [[ -n "$out" && "$out" != "null" ]]; then
    printf '%s\n' "$out"
    return 0
  fi
  printf '%s\n' "$default_value"
}

operator_storage_contract_json() {
  local query="$1"
  "$OPERATOR_STORAGE_YQ_BIN" e -o=json "$query" "$OPERATOR_STORAGE_SURFACE_CONTRACT" 2>/dev/null
}

operator_storage_load_contract() {
  [[ -f "$OPERATOR_STORAGE_SURFACE_CONTRACT" ]] || operator_storage_fail "missing contract: $OPERATOR_STORAGE_SURFACE_CONTRACT"
  operator_storage_need_cmd "$OPERATOR_STORAGE_YQ_BIN"
  operator_storage_need_cmd "$OPERATOR_STORAGE_JQ_BIN"
}

operator_storage_runtime_workbench_root() {
  operator_storage_expand_path "$(operator_storage_contract_scalar '.runtime_workbench_root' '')"
}

operator_storage_bootstrap_installer() {
  operator_storage_expand_path "$(operator_storage_contract_scalar '.bootstrap.installer_script_path' '')"
}

operator_storage_sync_label() {
  operator_storage_contract_scalar '.bootstrap.sync_launch_agent_label' 'com.ronny.operator-storage-surface-sync'
}

operator_storage_sync_template() {
  operator_storage_expand_path "$(operator_storage_contract_scalar '.bootstrap.sync_launchd_template' '')"
}

operator_storage_sync_root() {
  operator_storage_expand_path "$(operator_storage_contract_scalar '.bootstrap.sync_root' '~/Operator Sync')"
}

operator_storage_sync_conflicts_root() {
  operator_storage_expand_path "$(operator_storage_contract_scalar '.bootstrap.conflicts_root' '~/Operator Sync/.conflicts')"
}

operator_storage_launchagent_path() {
  local label="$1"
  printf '%s\n' "$HOME/Library/LaunchAgents/${label}.plist"
}

operator_storage_launchagent_state() {
  local label="$1"
  if ! [[ -f "$(operator_storage_launchagent_path "$label")" ]]; then
    printf 'missing\n'
    return 0
  fi
  if "$OPERATOR_STORAGE_LAUNCHCTL_BIN" print "gui/${OPERATOR_STORAGE_UID}/${label}" >/dev/null 2>&1; then
    printf 'loaded\n'
  else
    printf 'installed\n'
  fi
}

operator_storage_list_top_level_entries() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    return 0
  fi
  find "$root" -mindepth 1 -maxdepth 1 -print 2>/dev/null | sort | while IFS= read -r entry; do
    local name="${entry##*/}"
    case "$name" in
      .DS_Store|.localized|.gitkeep|.spine-*|.incoming|.conflicts) continue ;;
      *) printf '%s\n' "$entry" ;;
    esac
  done
}

operator_storage_count_entries() {
  local root="$1"
  operator_storage_list_top_level_entries "$root" | awk 'NF {count++} END {print count+0}'
}

operator_storage_relative_path() {
  local path="$1"
  local root="$2"
  python3 - "$path" "$root" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1]).resolve()
root = Path(sys.argv[2]).resolve()
print(path.relative_to(root))
PY
}

operator_storage_ensure_dir() {
  local path="$1"
  mkdir -p "$path"
}

operator_storage_unique_path() {
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

operator_storage_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

operator_storage_journal_id() {
  local prefix="${1:-OPERATOR-STORAGE}"
  date -u +"${prefix}-%Y%m%dT%H%M%SZ-$PPID-$RANDOM"
}
