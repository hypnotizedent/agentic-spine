#!/usr/bin/env bash
# TRIAGE: Check local-first watcher lane with explicit paid override controls.
# D74: Billing/provider lane lock
# Guardrails:
# - Background engine remains policy-governed and must support local provider path.
# - Watcher defaults to local and paid providers require explicit override.
# - Canonical launchd template uses lowercase /code path and local-first watcher lane.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-/Users/ronnyworks/code/workbench}"
if [[ ! -d "$WORKBENCH_ROOT" ]]; then
  WORKBENCH_ROOT="${HOME}/code/workbench"
fi

fail() {
  echo "D74 FAIL: $*" >&2
  exit 1
}

need_file() {
  local f="$1"
  [[ -f "$f" ]] || fail "missing file: $f"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

need_cmd rg
need_cmd python3

ENGINE_RUN="$ROOT/ops/engine/run.sh"
WATCHER="$ROOT/ops/runtime/inbox/hot-folder-watcher.sh"
PLIST_TEMPLATE="$WORKBENCH_ROOT/dotfiles/macbook/launchd/com.ronny.agent-inbox.plist"

need_file "$ENGINE_RUN"
need_file "$WATCHER"
need_file "$PLIST_TEMPLATE"

rg -q 'provider="\$\{SPINE_ENGINE_PROVIDER:-' "$ENGINE_RUN" \
  || fail "ops/engine/run.sh must resolve provider from SPINE_ENGINE_PROVIDER override"

rg -q 'local\)' "$ENGINE_RUN" \
  || fail "ops/engine/run.sh must support local provider lane"

if rg -q 'OpenAI provider failed; falling back to Anthropic' "$ENGINE_RUN"; then
  fail "ops/engine/run.sh must not silently fallback openai->anthropic"
fi

rg -q 'WATCHER_PROVIDER="\$\{SPINE_WATCHER_PROVIDER:-local\}"' "$WATCHER" \
  || fail "watcher must default SPINE_WATCHER_PROVIDER to local"

rg -q 'WATCHER_ALLOW_PAID_PROVIDER="\$\{SPINE_WATCHER_ALLOW_PAID_PROVIDER:-0\}"' "$WATCHER" \
  || fail "watcher must define SPINE_WATCHER_ALLOW_PAID_PROVIDER default 0"

rg -q "paid watcher provider '\\\$WATCHER_PROVIDER' requires SPINE_WATCHER_ALLOW_PAID_PROVIDER=1" "$WATCHER" \
  || fail "watcher must block paid providers unless explicit paid override is enabled"

rg -q 'WATCHER_ALLOW_ANTHROPIC="\$\{SPINE_WATCHER_ALLOW_ANTHROPIC:-0\}"' "$WATCHER" \
  || fail "watcher must define SPINE_WATCHER_ALLOW_ANTHROPIC default 0"

rg -q "provider=anthropic is blocked by default" "$WATCHER" \
  || fail "watcher must block anthropic unless explicit override flag is set"

if rg -q 'security find-generic-password -a "\$USER" -s "anthropic-api-key" -w' "$WATCHER"; then
  fail "watcher must not use implicit keychain fallback for ANTHROPIC_API_KEY"
fi

if rg -q '/Users/ronnyworks/[A-Z]' "$PLIST_TEMPLATE"; then
  fail "launchd template contains non-canonical uppercase path segment"
fi

python3 - "$PLIST_TEMPLATE" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as f:
    cfg = plistlib.load(f)

env = cfg.get("EnvironmentVariables", {})

def req(k, v):
    actual = env.get(k)
    if actual != v:
        raise SystemExit(f"missing/incorrect {k}: expected {v}, got {actual}")

req("SPINE_WATCHER_PROVIDER", "local")
req("SPINE_ENGINE_PROVIDER", "zai")
req("SPINE_REPO", "/Users/ronnyworks/code/agentic-spine")
req("SPINE_INBOX", "/Users/ronnyworks/code/agentic-spine/mailroom/inbox")
req("SPINE_OUTBOX", "/Users/ronnyworks/code/agentic-spine/mailroom/outbox")
req("SPINE_STATE", "/Users/ronnyworks/code/agentic-spine/mailroom/state")
req("SPINE_LOGS", "/Users/ronnyworks/code/agentic-spine/mailroom/logs")
req("ZAI_MODEL", "glm-5")
PY

echo "D74 PASS: billing/provider lanes locked (local-first watcher with explicit paid override)"
