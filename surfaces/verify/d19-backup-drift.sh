#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAP_SCRIPT="$ROOT/ops/plugins/backup/bin/backup-status"
BINDING_FILE="$ROOT/ops/bindings/backup.inventory.yaml"

fail(){ echo "D19 FAIL: $*" >&2; exit 1; }

# 1) Capability script must exist + be executable
[[ -f "$CAP_SCRIPT" ]] || fail "missing $CAP_SCRIPT"
[[ -x "$CAP_SCRIPT" ]] || fail "not executable: $CAP_SCRIPT"

# 2) Binding file must exist
[[ -f "$BINDING_FILE" ]] || fail "missing $BINDING_FILE"

# 3) No legacy/runtime smell coupling in backup plugin surface
if rg -n --hidden --no-ignore-vcs -S \
  '(ronny-ops|~/agent|/agent/|LaunchAgents|launchd|\.plist\b|cron\b|state/|/state/|receipts/|/receipts/)' \
  "$CAP_SCRIPT" >/dev/null; then
  fail "legacy/runtime smell markers found in backup-status"
fi

# 4) Forbid destructive/mutating commands (backup.status is inventory-only)
# Allow: ssh, ls, stat, find, test, cat, head, tail, awk, sed, grep, yq, date
if rg -n -S \
  '\b(rm|mv|cp|rsync|scp|restic|zfs|rclone|dd|mkfs|mount|umount|truncate)\b' \
  "$CAP_SCRIPT" >/dev/null; then
  fail "destructive/mutating command found in backup-status"
fi

# 5) HTTP method guard (should be none here, but keep consistent with other API gates)
if rg -n -S '\bcurl\b.*\s-X\s*(POST|PUT|PATCH|DELETE)\b' "$CAP_SCRIPT" >/dev/null; then
  fail "mutating HTTP method found"
fi

# 6) Token leak guardrail (never print secrets)
if rg -n -S '(echo|printf).*(TOKEN|SECRET|API_KEY|PASSWORD|INFISICAL_|CLOUDFLARE_)|set\s+-x' "$CAP_SCRIPT" >/dev/null; then
  fail "potential secret printing/debug tracing found"
fi

echo "D19 PASS: backup.status drift surface locked"
