#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SOURCE_DIR="$ROOT/ops/plugins/infra/host/launchd"
DEST_DIR="$HOME/Library/LaunchAgents"
UID_VAL="$(id -u)"
LABELS=(
  "com.ronny.backup-monitor-hourly"
  "com.ronny.infra-core-smoke"
  "com.ronny.launchd-health-check"
)

command -v launchctl >/dev/null 2>&1 || {
  echo "G15 FAIL: missing dependency: launchctl" >&2
  exit 2
}

failures=0
printf "%-34s %-8s %s\n" "label" "status" "detail"

for label in "${LABELS[@]}"; do
  src_plist="$SOURCE_DIR/$label.plist"
  dst_plist="$DEST_DIR/$label.plist"

  if [[ ! -f "$src_plist" ]]; then
    printf "%-34s %-8s %s\n" "$label" "FAIL" "missing source template"
    failures=$((failures + 1))
    continue
  fi
  if [[ ! -f "$dst_plist" ]]; then
    printf "%-34s %-8s %s\n" "$label" "FAIL" "missing installed plist"
    failures=$((failures + 1))
    continue
  fi
  if ! cmp -s "$src_plist" "$dst_plist"; then
    printf "%-34s %-8s %s\n" "$label" "FAIL" "installed plist drift"
    failures=$((failures + 1))
    continue
  fi
  if ! launchctl print "gui/${UID_VAL}/${label}" >/dev/null 2>&1; then
    printf "%-34s %-8s %s\n" "$label" "FAIL" "not loaded"
    failures=$((failures + 1))
    continue
  fi

  printf "%-34s %-8s %s\n" "$label" "PASS" "installed + loaded"
done

if [[ "$failures" -gt 0 ]]; then
  echo "G15 FAIL: launchagent health failures=$failures" >&2
  exit 1
fi

echo "G15 PASS: platform launchagents healthy"
