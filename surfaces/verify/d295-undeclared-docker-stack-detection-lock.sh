#!/usr/bin/env bash
# TRIAGE: Detect runtime docker compose projects not declared in compose target authority.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/inventory.enforcement.contract.yaml"
TARGETS="$ROOT/ops/bindings/docker.compose.targets.yaml"

[[ -f "$CONTRACT" ]] || { echo "D295 FAIL: missing contract $CONTRACT" >&2; exit 1; }
[[ -f "$TARGETS" ]] || { echo "D295 FAIL: missing targets file $TARGETS" >&2; exit 1; }

MODE="$(yq e '.docker_stack_parity.mode // "report_only"' "$CONTRACT")"

mapfile -t DECLARED < <(yq e -r '.targets[]?.stacks[]? | select((.legacy_only // false) == false) | .name' "$TARGETS" | sed '/^null$/d;/^$/d' | sort -u)
if [[ "${#DECLARED[@]}" -eq 0 ]]; then
  echo "D295 FAIL: no declared compose stack names in docker.compose.targets" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  if [[ "$MODE" == "report_only" ]]; then
    echo "D295 REPORT: runtime observation unavailable (docker command missing); declared_stack_count=${#DECLARED[@]}"
    exit 0
  fi
  echo "D295 FAIL: runtime observation unavailable (docker command missing)" >&2
  exit 1
fi

RAW="$(timeout 12s docker compose ls --format json 2>/dev/null || true)"
if [[ -z "$RAW" || "$RAW" == "[]" ]]; then
  if [[ "$MODE" == "report_only" ]]; then
    echo "D295 REPORT: docker compose runtime list unavailable/empty; declared_stack_count=${#DECLARED[@]}"
    exit 0
  fi
  echo "D295 FAIL: docker compose runtime list unavailable/empty" >&2
  exit 1
fi

mapfile -t OBSERVED < <(printf '%s\n' "$RAW" | jq -r '.[]?.Name // empty' 2>/dev/null | sed '/^$/d' | sort -u)
if [[ "${#OBSERVED[@]}" -eq 0 ]]; then
  if [[ "$MODE" == "report_only" ]]; then
    echo "D295 REPORT: docker compose runtime parse produced zero project names; declared_stack_count=${#DECLARED[@]}"
    exit 0
  fi
  echo "D295 FAIL: docker compose runtime parse produced zero project names" >&2
  exit 1
fi

declare -A DECL_SET=()
for name in "${DECLARED[@]}"; do DECL_SET["$name"]=1; done

ROGUE=()
for name in "${OBSERVED[@]}"; do
  if [[ -z "${DECL_SET[$name]:-}" ]]; then
    ROGUE+=("$name")
  fi
done

if [[ "${#ROGUE[@]}" -gt 0 ]]; then
  if [[ "$MODE" == "report_only" ]]; then
    echo "D295 REPORT: undeclared docker compose projects observed: ${ROGUE[*]}"
    exit 0
  fi
  echo "D295 FAIL: undeclared docker compose projects observed: ${ROGUE[*]}" >&2
  exit 1
fi

echo "D295 PASS: docker compose project registry parity holds (declared=${#DECLARED[@]} observed=${#OBSERVED[@]})"
