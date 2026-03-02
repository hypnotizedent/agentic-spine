#!/usr/bin/env bash
# TRIAGE: Enforce report-first mint-apps temp/upload write-surface governance and writable layer budget checks.
# D238: mint-apps-write-surface-lock
# Report/enforce ungoverned tmp/upload write surfaces for mint-apps.
set -euo pipefail

source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "mint-apps"

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"
GUARD_POLICY="$ROOT/ops/bindings/mint.storage.guard.policy.yaml"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d238-mint-apps-write-surface-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D238 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$SSH_BINDING" ]] || { echo "D238 FAIL: missing $SSH_BINDING" >&2; exit 1; }
[[ -f "$GUARD_POLICY" ]] || { echo "D238 FAIL: missing $GUARD_POLICY" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D238 FAIL: yq missing" >&2; exit 1; }

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$GUARD_POLICY" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D238 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

tmp_mb="$(yq -r '.thresholds.host_tmp_large_file_mb // 10' "$GUARD_POLICY" 2>/dev/null || echo 10)"
rootfs_warn_mb="$(yq -r '.thresholds.container_rootfs_warn_mb // 500' "$GUARD_POLICY" 2>/dev/null || echo 500)"

FINDINGS=0
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

to_mb() {
  local raw="$(echo "${1:-0}" | tr -d ' ' | tr '[:lower:]' '[:upper:]')"
  if [[ "$raw" =~ ^([0-9]+(\.[0-9]+)?)(B|KB|MB|GB|TB)$ ]]; then
    local num="${BASH_REMATCH[1]}"
    local unit="${BASH_REMATCH[3]}"
    case "$unit" in
      B) awk -v n="$num" 'BEGIN { printf "%.6f", n / 1024 / 1024 }' ;;
      KB) awk -v n="$num" 'BEGIN { printf "%.6f", n / 1024 }' ;;
      MB) awk -v n="$num" 'BEGIN { printf "%.6f", n }' ;;
      GB) awk -v n="$num" 'BEGIN { printf "%.6f", n * 1024 }' ;;
      TB) awk -v n="$num" 'BEGIN { printf "%.6f", n * 1024 * 1024 }' ;;
    esac
    return
  fi
  echo "0"
}

ge() {
  local a="$1" b="$2"
  awk -v a="$a" -v b="$b" 'BEGIN { exit !(a >= b) }'
}

ssh_host="$(yq -r '.ssh.targets[] | select(.id == "mint-apps") | .host // ""' "$SSH_BINDING" 2>/dev/null || true)"
ssh_user="$(yq -r '.ssh.targets[] | select(.id == "mint-apps") | .user // "ubuntu"' "$SSH_BINDING" 2>/dev/null || echo ubuntu)"
[[ -n "$ssh_host" ]] || { echo "D238 FAIL: mint-apps ssh target missing" >&2; exit 1; }

ref="$ssh_user@$ssh_host"
opts=(-n -o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
if ! ssh "${opts[@]}" "$ref" "true" >/dev/null 2>&1; then
  echo "D238 FAIL: ssh unreachable ($ref)" >&2
  exit 1
fi

large_tmp="$(ssh "${opts[@]}" "$ref" "find /tmp -maxdepth 2 -type f -size +${tmp_mb}M 2>/dev/null" || true)"
if [[ -n "$large_tmp" ]]; then
  first_path="$(echo "$large_tmp" | head -n1)"
  finding "MEDIUM" "STOR-006: host /tmp contains large file(s) > ${tmp_mb}MB (example: $first_path)"
fi

size_lines="$(ssh "${opts[@]}" "$ref" "docker ps --size --format '{{.Names}}|{{.Size}}'" 2>/dev/null || true)"
containers="$(ssh "${opts[@]}" "$ref" "docker ps --format '{{.Names}}'" 2>/dev/null || true)"

while IFS= read -r c; do
  [[ -z "$c" ]] && continue

  upload_dirs="$(ssh "${opts[@]}" "$ref" "docker exec '$c' sh -lc 'find /tmp -maxdepth 2 -type d 2>/dev/null | grep -Ei \"upload|uploads|scratch\" || true'" 2>/dev/null || true)"
  if [[ -n "$upload_dirs" ]]; then
    mount_dests="$(ssh "${opts[@]}" "$ref" "docker inspect --format '{{range .Mounts}}{{.Destination}}{{\"\\n\"}}{{end}}' '$c'" 2>/dev/null || true)"
    while IFS= read -r upload_dir; do
      [[ -z "$upload_dir" ]] && continue
      governed=0
      while IFS= read -r mount_dest; do
        [[ -z "$mount_dest" ]] && continue
        if [[ "$upload_dir" == "$mount_dest" || "$upload_dir" == "$mount_dest/"* ]]; then
          governed=1
          break
        fi
      done <<< "$mount_dests"
      if [[ "$governed" -ne 1 ]]; then
        finding "MEDIUM" "STOR-006: container '$c' upload path '$upload_dir' is not covered by a bind mount"
        break
      fi
    done <<< "$upload_dirs"
  fi

done <<< "$containers"

while IFS='|' read -r cname size_field; do
  [[ -n "$cname" ]] || continue
  writable_size="$(echo "$size_field" | awk '{print $1}')"
  writable_mb="$(to_mb "$writable_size")"
  if ge "$writable_mb" "$rootfs_warn_mb"; then
    finding "MEDIUM" "STOR-006: container '$cname' writable layer ${writable_mb}MB >= ${rootfs_warn_mb}MB"
  fi
done <<< "$size_lines"

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D238 FAIL: mint-apps write-surface findings=$FINDINGS"
    exit 1
  fi
  echo "D238 REPORT: mint-apps write-surface findings=$FINDINGS"
  exit 0
fi

echo "D238 PASS: mint-apps write-surface lock"
exit 0
