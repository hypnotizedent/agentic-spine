#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops run - Enqueue work into mailroom and optionally wait for result
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ops run --file <path> [--timeout <sec>] [--async]
#   ops run --fixture <name> [--timeout <sec>] [--async]
#   ops run --inline "prompt text" [--timeout <sec>] [--async]
#
# Examples:
#   ops run --fixture S20260201-180000__email_received__R0001.md
#   ops run --file /tmp/my_prompt.md --timeout 180
#   ops run --file /tmp/my_prompt.md --async
#   ops run --inline "What is 2+2?" --async
#
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

usage() {
  cat <<'EOF'
ops run - Enqueue work into mailroom

Usage:
  ops run --file <path>      Enqueue a file
  ops run --fixture <name>   Enqueue a fixture from fixtures/events/v1/
  ops run --inline "text"    Enqueue inline prompt text

Options:
  --timeout <sec>   Wait timeout in seconds (default: 120)
  --async           Enqueue and exit immediately (don't wait)

Examples:
  ops run --fixture S20260201-180000__email_received__R0001.md
  ops run --file ~/prompts/task.md --timeout 180
  ops run --inline "Summarize the system status" --async
EOF
}

# Defaults
TIMEOUT=120
ASYNC=0
FILE=""
FIXTURE=""
INLINE=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) TIMEOUT="${2:-120}"; shift 2;;
    --async) ASYNC=1; shift;;
    --file) FILE="${2:-}"; shift 2;;
    --fixture) FIXTURE="${2:-}"; shift 2;;
    --inline) INLINE="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

# Resolve SPINE_REPO
SPINE_REPO="${SPINE_REPO:-$HOME/Code/agentic-spine}"

INBOX="${SPINE_INBOX:-$SPINE_REPO/mailroom/inbox}"
OUTBOX="${SPINE_OUTBOX:-$SPINE_REPO/mailroom/outbox}"
RECEIPTS="$SPINE_REPO/receipts/sessions"

QUEUED="$INBOX/queued"
mkdir -p "$QUEUED" "$OUTBOX" "$RECEIPTS"

# Determine source
src=""
run_key=""

if [[ -n "$FIXTURE" ]]; then
  src="$SPINE_REPO/fixtures/events/v1/$FIXTURE"
  if [[ ! -f "$src" ]]; then
    echo "Fixture not found: $src"
    echo "Available fixtures:"
    ls -1 "$SPINE_REPO/fixtures/events/v1/"
    exit 2
  fi
  run_key="${FIXTURE%.md}"

elif [[ -n "$FILE" ]]; then
  src="$FILE"
  if [[ ! -f "$src" ]]; then
    echo "File not found: $src"
    exit 2
  fi
  base="$(basename "$src")"
  run_key="${base%.md}"

elif [[ -n "$INLINE" ]]; then
  # Generate run_key for inline prompts
  ts="$(date +%Y%m%d-%H%M%S)"
  rand="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 4 || echo "$$")"
  run_key="S${ts}__inline__R${rand}"

  # Create temp file with standard headers
  src="$(mktemp)"
  cat > "$src" <<PROMPT
AUDIENCE: SUPERVISOR
MODE: TALK
SESSION TYPE: SPINE
PIPELINE STAGE: VERIFY
HORIZON: NOW
OUTCOME: "CLI inline prompt"

$INLINE
PROMPT

else
  echo "Must provide --file, --fixture, or --inline"
  usage
  exit 2
fi

dest="$QUEUED/${run_key}.md"

# Enqueue (copy to preserve source)
cp "$src" "$dest"

# Clean up temp file if inline
[[ -n "$INLINE" ]] && rm -f "$src"

echo "ENQUEUED: $dest"
echo "RUN_KEY:  $run_key"

if [[ "$ASYNC" -eq 1 ]]; then
  echo "MODE:     async"
  echo ""
  echo "Check result later:"
  echo "  outbox:  $OUTBOX/${run_key}__RESULT.md"
  echo "  receipt: $RECEIPTS/R${run_key}/receipt.md"
  exit 0
fi

# Sync mode: wait for result
out="$OUTBOX/${run_key}__RESULT.md"
rec="$RECEIPTS/R${run_key}/receipt.md"

echo "MODE:     sync"
echo "TIMEOUT:  ${TIMEOUT}s"
echo ""
echo "Waiting for result..."

start="$(date +%s)"
while true; do
  if [[ -f "$out" ]] && [[ -f "$rec" ]]; then
    break
  fi
  now="$(date +%s)"
  if (( now - start >= TIMEOUT )); then
    echo ""
    echo "TIMEOUT waiting for result after ${TIMEOUT}s"
    echo "Check manually:"
    echo "  outbox:  $out"
    echo "  receipt: $rec"
    exit 124
  fi
  sleep 0.5
done

# Extract status from receipt
status="$(grep -m 1 '| Status |' "$rec" 2>/dev/null | sed 's/.*| Status | *//' | sed 's/ *|.*//' || echo "unknown")"

echo ""
echo "════════════════════════════════════════"
echo "DONE"
echo "════════════════════════════════════════"
echo "RUN_KEY:  $run_key"
echo "STATUS:   $status"
echo "OUTBOX:   $out"
echo "RECEIPT:  $rec"
echo ""

# Exit based on status
case "$status" in
  done|DONE|ok|OK|pass|PASS|success|SUCCESS) exit 0;;
  *) exit 1;;
esac
