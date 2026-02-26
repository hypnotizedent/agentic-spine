#!/usr/bin/env bash
# TRIAGE: Validate storage audit snapshot wrapper emits full STOR-001..STOR-008 linkage payload with governance mapping.
# D239: storage-audit-snapshot-lock
# Report/enforce capability wrapper integrity for storage snapshot + STOR finding linkage output.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
GUARD_POLICY="$ROOT/ops/bindings/mint.storage.guard.policy.yaml"
SNAPSHOT_CMD="$ROOT/ops/plugins/infra/bin/infra-storage-audit-snapshot"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d239-storage-audit-snapshot-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D239 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -x "$SNAPSHOT_CMD" ]] || { echo "D239 FAIL: snapshot command not executable: $SNAPSHOT_CMD" >&2; exit 1; }
[[ -f "$GUARD_POLICY" ]] || { echo "D239 FAIL: missing $GUARD_POLICY" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D239 FAIL: yq missing" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "D239 FAIL: python3 missing" >&2; exit 1; }

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$GUARD_POLICY" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D239 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

json_out="$($SNAPSHOT_CMD --format json 2>/dev/null || true)"
if [[ -z "$json_out" ]]; then
  echo "D239 FAIL: storage snapshot capability produced empty output" >&2
  exit 1
fi

missing=0
for stor_id in STOR-001 STOR-002 STOR-003 STOR-004 STOR-005 STOR-006 STOR-007 STOR-008; do
  if ! printf '%s' "$json_out" | python3 -c 'import json,sys; data=json.load(sys.stdin); ids={x.get("id") for x in data.get("stor_findings",[])}; sid=sys.argv[1]; raise SystemExit(0 if sid in ids else 1)' "$stor_id" >/dev/null 2>&1; then
    echo "  HIGH: missing $stor_id in snapshot output"
    missing=$((missing + 1))
  fi
done

if ! printf '%s' "$json_out" | python3 -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if data.get("governance_linkage") else 1)' >/dev/null 2>&1; then
  echo "  HIGH: snapshot output missing governance_linkage section"
  missing=$((missing + 1))
fi

if [[ "$missing" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D239 FAIL: storage audit snapshot linkage findings=$missing"
    exit 1
  fi
  echo "D239 REPORT: storage audit snapshot linkage findings=$missing"
  exit 0
fi

echo "D239 PASS: storage audit snapshot lock"
exit 0
