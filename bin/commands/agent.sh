#!/usr/bin/env bash
set -euo pipefail

SPINE="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
A="$SPINE/ops/runtime/inbox"

sub="${1:-help}"
shift || true

run() { local f="$1"; shift || true; exec "$A/$f" "$@"; }

case "$sub" in
  enqueue)   run "agent-enqueue.sh" "$@" ;;
  latest)    run "agent-latest.sh" "$@" ;;
  park)      run "agent-park-inbox.sh" "$@" ;;
  status)    run "agent-status.sh" "$@" ;;
  summary)   run "agent-summary.sh" "$@" ;;
  watchdog)  run "agent-watchdog.sh" "$@" ;;
  launch|start)  run "launch-agent.sh" "$@" ;;
  close|end)     run "close-session.sh" "$@" ;;
  help|-h|--help|"")
    cat <<EOF
ops agent <subcommand>

Core workflow:
  enqueue | latest | park | status | summary | watchdog | launch | close

Aliases:
  start -> launch
  end   -> close

Examples:
  ops agent enqueue "S123__slug__R001.md"
  ops agent status
EOF
    ;;
  *)
    echo "Unknown subcommand: $sub" >&2
    exec "$0" help
    ;;
esac
