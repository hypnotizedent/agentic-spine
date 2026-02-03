#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAP_SCRIPT="$ROOT/ops/plugins/docker/bin/docker-compose-status"

fail(){ echo "D18 FAIL: $*" >&2; exit 1; }

# 1) Capability script must exist + be executable
[[ -f "$CAP_SCRIPT" ]] || fail "missing $CAP_SCRIPT"
[[ -x "$CAP_SCRIPT" ]] || fail "not executable: $CAP_SCRIPT"

# 2) No legacy/runtime smell coupling in docker plugin surface
# (keep this conservative; we only scan the plugin script)
if rg -n --hidden --no-ignore-vcs -S \
  '(ronny-ops|~/agent|/agent/|LaunchAgents|launchd|\.plist\b|cron\b|state/|/state/|receipts/|/receipts/)' \
  "$CAP_SCRIPT" >/dev/null; then
  fail "legacy/runtime smell markers found in docker-compose-status"
fi

# 3) Read-only enforcement: forbid mutating docker/compose operations
# Allow: ps, ls, inspect, config, version
if rg -n -S \
  '\bdocker(\s+-[^\n]+)?\s+(compose|stack)\s+(up|down|restart|rm|stop|start|kill|pull|build|create|run|exec)\b' \
  "$CAP_SCRIPT" >/dev/null; then
  fail "mutating docker compose/stack command found"
fi

# Also forbid destructive docker commands
if rg -n -S '\bdocker\s+(system\s+prune|volume\s+rm|network\s+rm|image\s+rm|container\s+rm)\b' \
  "$CAP_SCRIPT" >/dev/null; then
  fail "destructive docker command found"
fi

# 4) HTTP method guard (should be none here, but keep consistent with other API gates)
if rg -n -S '\bcurl\b.*\s-X\s*(POST|PUT|PATCH|DELETE)\b' "$CAP_SCRIPT" >/dev/null; then
  fail "mutating HTTP method found"
fi

# 5) Token leak guardrail (never print secrets)
if rg -n -S '(echo|printf).*(TOKEN|SECRET|API_KEY|PASSWORD)|set\s+-x' "$CAP_SCRIPT" >/dev/null; then
  fail "potential secret printing/debug tracing found"
fi

echo "D18 PASS: docker.compose.status drift surface locked"
