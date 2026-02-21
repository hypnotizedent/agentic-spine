#!/usr/bin/env bash
# observability-smoke-test - Offline contract test for observability plugin scripts.
#
# Validates:
#   1) Expected observability scripts exist and are executable.
#   2) All observability scripts pass bash -n syntax check.
#   3) MANIFEST observability plugin script/capability counts match expected set.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
OBS_BIN="$SP/ops/plugins/observability/bin"
MANIFEST="$SP/ops/plugins/MANIFEST.yaml"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

EXPECTED_SCRIPTS=(
  "observability-stack-status"
  "prometheus-targets-status"
  "uptime-kuma-monitors-sync"
  "nas-health-status"
  "gitea-status"
  "immich-status"
  "immich-ingest-watch"
  "finance-stack-status"
  "finance-ronny-action-queue"
  "idrac-health-status"
  "switch-health-status"
  "stability-control-snapshot"
  "infra-core-slo-status"
  "stability-control-reconcile"
)

echo "observability-smoke-test"
echo "════════════════════════════════════════"

echo ""
echo "T1: Expected observability scripts exist and are executable"
(
  for script in "${EXPECTED_SCRIPTS[@]}"; do
    path="$OBS_BIN/$script"
    [[ -f "$path" ]] || { echo "  missing file: $path" >&2; exit 1; }
    [[ -x "$path" ]] || { echo "  not executable: $path" >&2; exit 1; }
  done
) && pass "all expected scripts present + executable" || fail "missing or non-executable observability script"

echo ""
echo "T2: All observability scripts pass interpreter-aware syntax checks"
(
  for script in "${EXPECTED_SCRIPTS[@]}"; do
    path="$OBS_BIN/$script"
    shebang="$(head -n 1 "$path" 2>/dev/null || true)"
    if [[ "$shebang" == *python* ]]; then
      command -v python3 >/dev/null 2>&1 || { echo "  python3 missing for $path" >&2; exit 1; }
      python3 - "$path" <<'PY'
import ast
import pathlib
import sys

target = pathlib.Path(sys.argv[1])
ast.parse(target.read_text())
PY
    else
      bash -n "$path"
    fi
  done
) && pass "syntax clean for all observability scripts" || fail "syntax check failed for one or more scripts"

echo ""
echo "T3: MANIFEST observability script/capability counts match expected set"
(
  command -v yq >/dev/null 2>&1 || { echo "  yq missing" >&2; exit 1; }

  manifest_script_count="$(yq -r '.plugins[] | select(.name == "observability") | .scripts | length' "$MANIFEST")"
  manifest_cap_count="$(yq -r '.plugins[] | select(.name == "observability") | .capabilities | length' "$MANIFEST")"
  mapfile -t manifest_scripts < <(yq -r '.plugins[] | select(.name == "observability") | .scripts[]' "$MANIFEST")
  expected_count="${#EXPECTED_SCRIPTS[@]}"

  [[ "$manifest_script_count" == "$expected_count" ]] || {
    echo "  script count mismatch: manifest=$manifest_script_count expected=$expected_count" >&2
    exit 1
  }
  [[ "$manifest_cap_count" == "$expected_count" ]] || {
    echo "  capability count mismatch: manifest=$manifest_cap_count expected=$expected_count" >&2
    exit 1
  }
  for script in "${EXPECTED_SCRIPTS[@]}"; do
    found=0
    for manifest_script in "${manifest_scripts[@]}"; do
      if [[ "$manifest_script" == "bin/${script}" ]]; then
        found=1
        break
      fi
    done
    [[ "$found" -eq 1 ]] || {
      echo "  missing in manifest: bin/${script}" >&2
      exit 1
    }
  done
) && pass "manifest counts + script mapping valid" || fail "manifest observability mapping mismatch"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
