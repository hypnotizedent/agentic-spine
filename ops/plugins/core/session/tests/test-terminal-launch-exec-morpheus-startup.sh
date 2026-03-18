#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SCRIPT="$ROOT/ops/plugins/core/session/bin/terminal-launch-exec"
CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.startup.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v grep >/dev/null 2>&1 || fail "grep required"
command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$SCRIPT" ]] || fail "terminal-launch-exec missing or not executable"
[[ -f "$CONTRACT" ]] || fail "missing startup contract"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_spine="$tmp/spine"
fake_workbench="$tmp/workbench"
fake_bin="$tmp/bin"
mkdir -p \
  "$fake_spine/ops/plugins/core/session/bin" \
  "$fake_spine/ops/plugins/core/orchestration/bin" \
  "$fake_spine/ops/plugins/domains/mint/morpheus-runtime" \
  "$fake_spine/ops/bindings" \
  "$fake_spine/bin" \
  "$fake_workbench" \
  "$fake_bin"

cp "$SCRIPT" "$fake_spine/ops/plugins/core/session/bin/terminal-launch-exec"
cp "$CONTRACT" "$fake_spine/ops/bindings/mint.customer.inbox.startup.contract.yaml"
chmod +x "$fake_spine/ops/plugins/core/session/bin/terminal-launch-exec"

session_env_file="$tmp/session.env.sh"
claude_log="$tmp/claude.log"
startup_record_dir="$tmp/startup-records"
mkdir -p "$startup_record_dir"

cat >"$fake_spine/ops/plugins/core/session/bin/session-start" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
env_file="${FAKE_SESSION_ENV_FILE:?}"
cat >"$env_file" <<'ENV'
export SPINE_SESSION_ID="SESSION-MORPHEUS-001"
ENV
printf '  source %s\n' "$env_file"
EOF
chmod +x "$fake_spine/ops/plugins/core/session/bin/session-start"

cat >"$fake_spine/ops/plugins/core/orchestration/bin/orchestration-launcher-plan" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "active_lock_count=0"
EOF
chmod +x "$fake_spine/ops/plugins/core/orchestration/bin/orchestration-launcher-plan"

cat >"$fake_spine/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "cap" && "${2:-}" == "run" && "${3:-}" == "mint.customer.inbox.startup" ]]; then
  shift 3
  [[ "${1:-}" == "--" ]] && shift
  cat <<JSON
{
  "mode": "canonical_inbox_work_items",
  "selection_order": "oldest_first",
  "scope_lock": "Mint Prints customer email inbox only",
  "first_action_command": "mintctl morpheus inbox first-email",
  "record_file": "${FAKE_STARTUP_RECORD:?}/MCIS-TEST.json",
  "work_items": {
    "backlog_count": 4,
    "first_subject": "Oldest customer ask",
    "hydration_mode": "preview_only"
  }
}
JSON
  exit 0
fi

echo "unexpected ops invocation: $*" >&2
exit 1
EOF
chmod +x "$fake_spine/bin/ops"

cat >"$fake_bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="${FAKE_CLAUDE_LOG:?}"
: >"$log_file"
for arg in "$@"; do
  printf 'arg=%s\n' "$arg" >>"$log_file"
done
printf 'cwd=%s\n' "$PWD" >>"$log_file"
printf 'startup_context_file=%s\n' "${SPINE_TERMINAL_STARTUP_CONTEXT_FILE:-}" >>"$log_file"
printf 'startup_mode=%s\n' "${SPINE_TERMINAL_STARTUP_MODE:-}" >>"$log_file"
printf 'startup_backlog_count=%s\n' "${SPINE_TERMINAL_STARTUP_BACKLOG_COUNT:-}" >>"$log_file"
printf 'startup_first_subject=%s\n' "${SPINE_TERMINAL_STARTUP_FIRST_SUBJECT:-}" >>"$log_file"
printf 'scope_lock=%s\n' "${SPINE_TERMINAL_SCOPE_LOCK:-}" >>"$log_file"
printf 'append_prompt=%s\n' "${SPINE_TERMINAL_STARTUP_APPEND_SYSTEM_PROMPT:-}" >>"$log_file"
exit 0
EOF
chmod +x "$fake_bin/claude"

touch "$startup_record_dir/MCIS-TEST.json"

env \
  PATH="$fake_bin:$PATH" \
  SPINE_ROOT="$fake_spine" \
  WORKBENCH_ROOT="$fake_workbench" \
  SPINE_INBOX="$tmp/runtime/inbox" \
  SPINE_OUTBOX="$tmp/runtime/outbox" \
  SPINE_STATE="$tmp/runtime/state" \
  SPINE_LOGS="$tmp/runtime/logs" \
  FAKE_SESSION_ENV_FILE="$session_env_file" \
  FAKE_CLAUDE_LOG="$claude_log" \
  FAKE_STARTUP_RECORD="$startup_record_dir" \
  "$fake_spine/ops/plugins/core/session/bin/terminal-launch-exec" \
    --role solo \
    --tool claude \
    --terminal MINT-MORPHEUS-01 >/dev/null

grep '^arg=--append-system-prompt$' "$claude_log" >/dev/null || fail "Morpheus launch should append startup context into Claude"
grep '^startup_context_file='"$startup_record_dir"'/MCIS-TEST.json$' "$claude_log" >/dev/null || fail "startup record file should be exported to Claude"
grep '^startup_mode=canonical_inbox_work_items$' "$claude_log" >/dev/null || fail "startup mode should be exported to Claude"
grep '^startup_backlog_count=4$' "$claude_log" >/dev/null || fail "startup backlog count should be exported to Claude"
grep '^startup_first_subject=Oldest customer ask$' "$claude_log" >/dev/null || fail "startup first subject should be exported to Claude"
grep '^scope_lock=Mint Prints customer email inbox only$' "$claude_log" >/dev/null || fail "scope lock should be exported to Claude"
grep 'Read the startup record at '"$startup_record_dir"'/MCIS-TEST.json before your first reply' "$claude_log" >/dev/null || fail "startup prompt should direct Claude to the governed startup record"
grep 'Do not ask what we are working on' "$claude_log" >/dev/null || fail "startup prompt should suppress generic scope questions"

pass "terminal-launch-exec injects governed Morpheus startup context into Claude"

echo "terminal launch exec Morpheus startup tests"
