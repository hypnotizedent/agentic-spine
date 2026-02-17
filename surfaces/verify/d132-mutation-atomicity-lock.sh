#!/usr/bin/env bash
# TRIAGE: Add `source "$ROOT/ops/lib/git-lock.sh"` and `acquire_git_lock` calls to mutating scripts listed in this gate.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

fail() {
  echo "D132 FAIL: $*" >&2
  exit 1
}

GOVERNED_SCRIPTS=(
  "ops/plugins/orchestration/bin/orchestration-loop-open"
  "ops/plugins/orchestration/bin/orchestration-handoff-validate"
  "ops/plugins/orchestration/bin/orchestration-ticket-issue"
  "ops/plugins/orchestration/bin/orchestration-terminal-entry"
  "ops/plugins/orchestration/bin/orchestration-integrate"
  "ops/plugins/orchestration/bin/orchestration-loop-close"
  "ops/plugins/infra/bin/infra-relocation-service-transition"
  "ops/plugins/infra/bin/infra-relocation-state-transition"
  "ops/plugins/proposals/bin/proposals-supersede"
)

errors=()

for script_rel in "${GOVERNED_SCRIPTS[@]}"; do
  script="$ROOT/$script_rel"
  if [[ ! -f "$script" ]]; then
    errors+=("$script_rel: file not found")
    continue
  fi

  if ! grep -q 'git-lock\.sh' "$script" 2>/dev/null; then
    errors+=("$script_rel: missing git-lock.sh source")
    continue
  fi

  if ! grep -q 'acquire_git_lock' "$script" 2>/dev/null; then
    errors+=("$script_rel: missing acquire_git_lock call")
  fi
done

if [[ "${#errors[@]}" -gt 0 ]]; then
  for err in "${errors[@]}"; do
    echo "  $err" >&2
  done
  fail "${#errors[@]} mutation atomicity violation(s)"
fi

echo "D132 PASS: mutation atomicity enforced (${#GOVERNED_SCRIPTS[@]} scripts validated)"
exit 0
