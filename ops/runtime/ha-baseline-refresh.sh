#!/usr/bin/env bash
set -euo pipefail

# ha-baseline-refresh.sh — Automated weekly refresh of all HA SSOT bindings
# Runs all HA snapshot capabilities sequentially, then rebuilds unified baseline.
# Designed to be invoked by launchd (com.ronny.ha-baseline-refresh.plist).
#
# Exit 0 on success, non-zero on critical failure (baseline build fails).
# Individual snapshot failures are logged but do not abort the run.

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="$SPINE_ROOT/bin/ops"
LOG_PREFIX="[ha-baseline-refresh]"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "$LOG_PREFIX Starting HA baseline refresh at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo

# ─────────────────────────────────────────────────────────────────────────────
# PRECONDITIONS
# ─────────────────────────────────────────────────────────────────────────────

if [[ ! -x "$CAP_RUNNER" ]]; then
  echo "$LOG_PREFIX FATAL: cap runner not found at $CAP_RUNNER"
  exit 2
fi

# ─────────────────────────────────────────────────────────────────────────────
# SNAPSHOT CAPABILITIES (order: independent snapshots first, then baseline)
# ─────────────────────────────────────────────────────────────────────────────

SNAPSHOT_CAPS=(
  "ha.addons.snapshot"
  "ha.automations.snapshot"
  "ha.dashboard.snapshot"
  "ha.helpers.snapshot"
  "ha.integrations.snapshot"
  "ha.scenes.snapshot"
  "ha.scripts.snapshot"
  "ha.hacs.snapshot"
  "ha.entity.state.baseline"
  "ha.device.map.build"
  "ha.z2m.devices.snapshot"
  "ha.zwave.devices.snapshot"
)

PASS=0
FAIL=0

for cap in "${SNAPSHOT_CAPS[@]}"; do
  echo "$LOG_PREFIX Running: $cap"
  if spine_job_run \
    "ha-baseline-refresh:${cap}" \
    "$CAP_RUNNER" cap run "$cap" 2>&1; then
    PASS=$((PASS + 1))
    echo "$LOG_PREFIX OK: $cap"
  else
    FAIL=$((FAIL + 1))
    echo "$LOG_PREFIX WARN: $cap failed (continuing)"
  fi
  echo
done

echo "$LOG_PREFIX Snapshots complete: $PASS passed, $FAIL failed"
echo

# ─────────────────────────────────────────────────────────────────────────────
# BASELINE BUILD (critical — exit non-zero on failure)
# ─────────────────────────────────────────────────────────────────────────────

echo "$LOG_PREFIX Running: ha.ssot.baseline.build"
if spine_job_run \
  "ha-baseline-refresh:ha.ssot.baseline.build" \
  "$CAP_RUNNER" cap run ha.ssot.baseline.build 2>&1; then
  echo "$LOG_PREFIX OK: baseline built successfully"
else
  echo "$LOG_PREFIX FATAL: ha.ssot.baseline.build failed"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# RUNBOOK SYNC (non-critical — log and continue on failure)
# ─────────────────────────────────────────────────────────────────────────────

echo "$LOG_PREFIX Running: ha.ssot.apply (runbook drift sync)"
if echo "yes" | spine_job_run \
  "ha-baseline-refresh:ha.ssot.apply" \
  "$CAP_RUNNER" cap run ha.ssot.apply 2>&1; then
  echo "$LOG_PREFIX OK: runbook synced"
else
  echo "$LOG_PREFIX WARN: ha.ssot.apply failed (runbook may be stale)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# GIT SYNC (commit + push if bindings changed)
# ─────────────────────────────────────────────────────────────────────────────

cd "$SPINE_ROOT"

CHANGED_FILES=$(git diff --name-only ops/bindings/ha.*.yaml ops/bindings/z2m.*.yaml ops/bindings/zwave.*.yaml 2>/dev/null || true)

if [[ -n "$CHANGED_FILES" ]]; then
  echo
  echo "$LOG_PREFIX Binding changes detected, committing..."

  COMMIT_TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  COMMIT_MSG="sync(ha): weekly baseline refresh [$COMMIT_TS]

Snapshots: $PASS/$((PASS + FAIL)) passed
Files changed:
$CHANGED_FILES"

  git add ops/bindings/ha.*.yaml ops/bindings/z2m.*.yaml ops/bindings/zwave.*.yaml 2>/dev/null || true
  git commit -m "$COMMIT_MSG"
  echo "$LOG_PREFIX Committed binding changes"

  if git remote | grep -q origin; then
    echo "$LOG_PREFIX Pushing to origin..."
    if git push origin main 2>&1; then
      echo "$LOG_PREFIX Pushed successfully"
    else
      echo "$LOG_PREFIX WARN: Push failed (may need manual intervention)"
      spine_enqueue_email_intent \
        "ha-baseline-refresh" \
        "warn" \
        "ha-baseline-refresh push failed" \
        "Binding changes were committed but push to origin failed. Manual intervention may be required."
    fi
  fi
else
  echo "$LOG_PREFIX No binding changes to commit"
fi

echo
echo "$LOG_PREFIX Finished at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "$LOG_PREFIX Summary: $PASS/$((PASS + FAIL)) snapshots passed, baseline built"
exit 0
