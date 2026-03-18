#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SCRIPT="$ROOT/ops/plugins/core/session/bin/terminal-launch-exec"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v grep >/dev/null 2>&1 || fail "grep required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$SCRIPT" ]] || fail "terminal-launch-exec missing or not executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_spine="$tmp/spine"
fake_workbench="$tmp/workbench"
mkdir -p "$fake_spine/ops/plugins/core/session/bin"
mkdir -p "$fake_spine/ops/plugins/core/orchestration/bin"
mkdir -p "$fake_spine/bin"
mkdir -p "$fake_spine/ops/bindings"
mkdir -p "$fake_workbench"

cp "$SCRIPT" "$fake_spine/ops/plugins/core/session/bin/terminal-launch-exec"
chmod +x "$fake_spine/ops/plugins/core/session/bin/terminal-launch-exec"

session_env_file="$tmp/session.env.sh"
accept_log="$tmp/handoff-accept.log"

cat >"$fake_spine/ops/plugins/core/session/bin/session-start" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
env_file="${FAKE_SESSION_ENV_FILE:?}"
cat >"$env_file" <<'ENV'
export SPINE_SESSION_ID="SESSION-TEST-001"
ENV
printf '  source %s\n' "$env_file"
SH
chmod +x "$fake_spine/ops/plugins/core/session/bin/session-start"

cat >"$fake_spine/ops/plugins/core/orchestration/bin/orchestration-launcher-plan" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "active_lock_count=0"
SH
chmod +x "$fake_spine/ops/plugins/core/orchestration/bin/orchestration-launcher-plan"

cat >"$fake_spine/bin/ops" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
log_file="${FAKE_ACCEPT_LOG:?}"
if [[ "${1:-}" == "cap" && "${2:-}" == "run" && "${3:-}" == "session.handoff.accept" ]]; then
  shift 3
  [[ "${1:-}" == "--" ]] && shift
  : >"$log_file"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id|--handoff-file|--terminal-id|--tool|--session-id|--agent-id|--worker-id)
        echo "${1#--}=${2:-}" >>"$log_file"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  echo "session.handoff.accept"
  echo "status: accepted"
  exit 0
fi
echo "unexpected ops invocation: $*" >&2
exit 1
SH
chmod +x "$fake_spine/bin/ops"

handoff_file="$tmp/runtime/state/handoffs/HO-TEST-001.yaml"
mkdir -p "$(dirname "$handoff_file")"

out="$(
  env \
    "SPINE_ROOT=$fake_spine" \
    "WORKBENCH_ROOT=$fake_workbench" \
    "SPINE_INBOX=$tmp/runtime/inbox" \
    "SPINE_OUTBOX=$tmp/runtime/outbox" \
    "SPINE_STATE=$tmp/runtime/state" \
    "SPINE_LOGS=$tmp/runtime/logs" \
    "FAKE_SESSION_ENV_FILE=$session_env_file" \
    "FAKE_ACCEPT_LOG=$accept_log" \
    "$fake_spine/ops/plugins/core/session/bin/terminal-launch-exec" \
      --role solo \
      --tool verify \
      --terminal TEST-TERM-01 \
      --handoff-id HO-TEST-001 \
      --handoff-file "$handoff_file" \
      --dry-run
)"

echo "$out" | grep 'dispatch_handoff_id=HO-TEST-001' >/dev/null || fail "launch plan should surface handoff id"
echo "$out" | grep "dispatch_handoff_file=$handoff_file" >/dev/null || fail "launch plan should surface handoff file"
grep '^id=HO-TEST-001$' "$accept_log" >/dev/null || fail "handoff accept should receive handoff id"
grep "^handoff-file=$handoff_file\$" "$accept_log" >/dev/null || fail "handoff accept should receive handoff file"
grep '^terminal-id=TEST-TERM-01$' "$accept_log" >/dev/null || fail "handoff accept should receive terminal id"
grep '^tool=verify$' "$accept_log" >/dev/null || fail "handoff accept should receive tool"
grep '^session-id=SESSION-TEST-001$' "$accept_log" >/dev/null || fail "handoff accept should receive session id"
pass "terminal-launch-exec accepts dispatched handoff context before tool launch"

echo "terminal launch exec handoff tests"
