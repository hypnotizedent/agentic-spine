#!/usr/bin/env bash
# ops lane <builder|runner|clerk> - show lane context
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LANE="${1:-}"

usage() {
  cat <<USAGE
Usage: ops lane <builder|runner|clerk>
  builder (1) - Issue workspace / editing lane
  runner  (2) - Logs, health checks, runtime verification
  clerk   (3) - Background governance watcher
USAGE
  exit 1
}

if [[ -z "$LANE" ]]; then
  usage
fi

case "$LANE" in
  builder|1)
    # Builder lane must be "safe to start": remote parity + worktree hygiene checks.
    # We source preflight so it can export GOV_* context into the current process.
    source "$SCRIPT_DIR/commands/preflight.sh"
    cat <<BUILDER
═══════════════════════════════════════════════════════════
  LANE 1: BUILDER
  Issue: ${CURRENT_ISSUE:-none}
  Worktree: ${CURRENT_WORKTREE:-main}
═══════════════════════════════════════════════════════════
BUILDER
    ;;
  runner|2)
    cat <<RUNNER
═══════════════════════════════════════════════════════════
  LANE 2: RUNNER
  Purpose: Prove it works (logs, curls, migrations)
═══════════════════════════════════════════════════════════
RUNNER
    ;;
  clerk|3)
    cat <<CLERK
═══════════════════════════════════════════════════════════
  LANE 3: CLERK
  Purpose: Drift detection + docs vigilance
═══════════════════════════════════════════════════════════
CLERK
    ;;
  *)
    usage
    ;;
esac
