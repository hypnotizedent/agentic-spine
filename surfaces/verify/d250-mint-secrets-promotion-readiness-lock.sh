#!/usr/bin/env bash
# TRIAGE: Guard report->enforce promotion for W45 secrets gates with explicit 3-run evidence.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/mint.secrets.promotion.contract.yaml"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d250-mint-secrets-promotion-readiness-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D250 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

fail() { echo "D250 FAIL: $*" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
command -v rg >/dev/null 2>&1 || fail "required tool missing: rg"
[[ -f "$CONTRACT" ]] || fail "missing contract: ops/bindings/mint.secrets.promotion.contract.yaml"

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$CONTRACT" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || fail "invalid policy mode '$MODE'"

CERT_REL="$(yq -r '.mode.report_cert_file // ""' "$CONTRACT")"
[[ -n "$CERT_REL" && "$CERT_REL" != "null" ]] || fail "mode.report_cert_file missing from contract"
CERT_FILE="$ROOT/$CERT_REL"

FINDINGS=0
finding() {
  echo "  HIGH: $*"
  FINDINGS=$((FINDINGS + 1))
}

if [[ ! -f "$CERT_FILE" ]]; then
  finding "missing promotion cert file: $CERT_REL"
else
  for field in report_run_1 report_run_2 report_run_3 findings_total promotion_decision; do
    rg -q "^\\- ${field}:" "$CERT_FILE" || finding "cert file missing field '${field}'"
  done
fi

if [[ "$MODE" == "enforce" ]]; then
  rg -q '^\- report_run_1:\s+PASS$' "$CERT_FILE" || finding "report_run_1 must be PASS for enforce"
  rg -q '^\- report_run_2:\s+PASS$' "$CERT_FILE" || finding "report_run_2 must be PASS for enforce"
  rg -q '^\- report_run_3:\s+PASS$' "$CERT_FILE" || finding "report_run_3 must be PASS for enforce"
  rg -q '^\- findings_total:\s+0$' "$CERT_FILE" || finding "findings_total must be 0 for enforce"
  rg -q '^\- promotion_decision:\s+ENFORCE_APPROVED$' "$CERT_FILE" || finding "promotion_decision must be ENFORCE_APPROVED for enforce"

  for gate_script in \
    "$ROOT/surfaces/verify/d245-mint-secrets-inventory-lock.sh" \
    "$ROOT/surfaces/verify/d246-mint-secrets-alias-drift-lock.sh" \
    "$ROOT/surfaces/verify/d247-mint-shipping-secrets-contract-lock.sh" \
    "$ROOT/surfaces/verify/d248-mint-payment-secrets-contract-lock.sh" \
    "$ROOT/surfaces/verify/d249-mint-notifications-secrets-contract-lock.sh"; do
    if [[ ! -x "$gate_script" ]]; then
      finding "missing executable prerequisite script: ${gate_script#$ROOT/}"
      continue
    fi
    if ! "$gate_script" --policy enforce >/dev/null; then
      finding "prerequisite gate failed in enforce mode: ${gate_script#$ROOT/}"
    fi
  done
fi

if (( FINDINGS > 0 )); then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D250 FAIL: promotion readiness findings=$FINDINGS"
    exit 1
  fi
  echo "D250 REPORT: promotion readiness findings=$FINDINGS"
  exit 0
fi

if [[ "$MODE" == "enforce" ]]; then
  echo "D250 PASS: report->enforce promotion evidence validated"
else
  echo "D250 PASS: report-mode promotion guard contract present"
fi
