#!/usr/bin/env bash
# TRIAGE: D311 communications-runbook-authority-lock
# Enforces: canonical communications runbook has no stale docker-host mail-archiver refs
# and all authority doc references resolve to existing files.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WORKBENCH="${WORKBENCH_ROOT:-$HOME/code/workbench}"
RUNBOOK="$WORKBENCH/docs/infrastructure/domains/communications/COMMUNICATIONS_RUNBOOK.md"
CONTRACT="$ROOT/ops/bindings/mail.archiver.account.linkage.contract.yaml"

fail=0

# Guard: required files exist
if [[ ! -f "$RUNBOOK" ]]; then
  echo "D311 FAIL: canonical runbook missing: $RUNBOOK" >&2
  exit 1
fi
if [[ ! -f "$CONTRACT" ]]; then
  echo "D311 FAIL: linkage contract missing: $CONTRACT" >&2
  exit 1
fi

# Check 1: no docker-host refs in mail-archiver operations
if grep -n 'ssh docker-host' "$RUNBOOK" | grep -qi 'mail'; then
  echo "D311 FAIL: runbook contains stale docker-host SSH commands for mail-archiver" >&2
  fail=1
fi

# Check 2: authority contract references in runbook resolve to existing files
while IFS= read -r ref; do
  # Strip leading "- " and backticks
  ref=$(echo "$ref" | sed 's/^- `//;s/`.*//;s/^ *//')
  # Only check spine-relative paths (ops/ or docs/)
  case "$ref" in
    ops/*|docs/*)
      if [[ ! -f "$ROOT/$ref" ]]; then
        echo "D311 FAIL: runbook references non-existent authority file: $ref" >&2
        fail=1
      fi
      ;;
  esac
done < <(grep -E '^\s*- `(ops/|docs/)' "$RUNBOOK")

# Check 3: linkage contract has onboarding section
if ! grep -q '^onboarding:' "$CONTRACT"; then
  echo "D311 FAIL: linkage contract missing onboarding section" >&2
  fail=1
fi

# Check 4: legacy guide is tombstoned
LEGACY="$WORKBENCH/docs/legacy/infrastructure/reference/guides/MAIL_ARCHIVER.md"
if [[ -f "$LEGACY" ]]; then
  if ! grep -q 'status: tombstoned' "$LEGACY"; then
    echo "D311 FAIL: legacy MAIL_ARCHIVER.md exists but is not tombstoned" >&2
    fail=1
  fi
fi

exit $fail
