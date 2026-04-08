#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BACKUP_STATUS="$ROOT/ops/plugins/infra/backup/bin/backup-status"

[[ -x "$BACKUP_STATUS" ]] || {
  echo "G6 FAIL: missing backup status capability: $BACKUP_STATUS" >&2
  exit 2
}

set +e
output="$("$BACKUP_STATUS" 2>&1)"
rc=$?
set -e

printf '%s\n' "$output"

if [[ "$rc" -ne 0 ]]; then
  echo "G6 FAIL: backup status probe failed" >&2
  exit 1
fi

summary_line="$(printf '%s\n' "$output" | grep '^summary:' | tail -n1 || true)"
if [[ -z "$summary_line" ]]; then
  echo "G6 FAIL: backup status missing summary line" >&2
  exit 1
fi

read -r degraded blocked <<EOF
$(SUMMARY_LINE="$summary_line" python3 - <<'PY'
import os, re
line = os.environ.get("SUMMARY_LINE", "")
m = re.search(r'\|\s*(\d+)\s+degraded\s+\|\s*(\d+)\s+context_blocked', line)
if not m:
    print("999 999")
else:
    print(m.group(1), m.group(2))
PY
)
EOF

if [[ ! "$degraded" =~ ^[0-9]+$ || ! "$blocked" =~ ^[0-9]+$ ]]; then
  echo "G6 FAIL: unable to parse backup summary" >&2
  exit 1
fi

if [[ "$degraded" -gt 0 || "$blocked" -gt 0 ]]; then
  echo "G6 FAIL: backup currency degraded=$degraded context_blocked=$blocked" >&2
  exit 1
fi

echo "G6 PASS: backup currency current"
