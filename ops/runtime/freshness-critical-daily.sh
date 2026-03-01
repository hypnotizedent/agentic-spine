#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: refresh critical 24h freshness surfaces.
# Covers gates: D192, D193, D194, D205, D208 (+ D104 freshness support).
# LaunchAgent: com.ronny.freshness-critical-daily

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
EMAIL_INTENT_DIR="${SPINE_ROOT}/mailroom/outbox/alerts/email-intents"

enqueue_email_intent() {
  local severity="$1"
  local title="$2"
  local summary="$3"
  local intent_id created_at intent_file
  intent_id="email-intent-$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM}"
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  intent_file="${EMAIL_INTENT_DIR}/${intent_id}.yaml"
  mkdir -p "${EMAIL_INTENT_DIR}"
  cat >"${intent_file}" <<INTENT
intent_id: "${intent_id}"
created_at: "${created_at}"
domain_id: "freshness-critical"
severity: "${severity}"
title: "${title}"
summary: |-
$(printf '%s\n' "${summary}" | sed 's/^/  /')
suggested_recipient: "alerts@spine.ronny.works"
source_alert: "freshness-critical-daily"
flush_status: pending
INTENT
}

failures=0
declare -a failed_caps=()

run_cap() {
  local cap="$1"
  if "$CAP_RUNNER" cap run "$cap"; then
    return 0
  fi
  local rc=$?
  failures=$((failures + 1))
  failed_caps+=("${cap}(rc=${rc})")
  echo "[freshness-critical-daily] WARN ${cap} failed rc=${rc}" >&2
  return 0
}

echo "[freshness-critical-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

run_cap media-content-snapshot-refresh
run_cap ha-inventory-snapshot-build
run_cap network-inventory-snapshot-build
run_cap ha.z2m.devices.snapshot
run_cap network.home.dhcp.audit
run_cap calendar.external.ingest.refresh
run_cap calendar.ha.ingest.refresh
run_cap infra.storage.audit.snapshot
run_cap cloudflare.inventory.sync
run_cap verify.freshness.reconcile

if (( failures > 0 )); then
  enqueue_email_intent \
    "incident" \
    "freshness-critical-daily had refresh failures" \
    "failures=${failures}; failed_capabilities=${failed_caps[*]}"
  echo "[freshness-critical-daily] done with failures=$((${failures})) $(date -u +%Y-%m-%dT%H:%M:%SZ)" >&2
  exit 1
fi

echo "[freshness-critical-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
