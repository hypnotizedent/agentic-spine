#!/usr/bin/env bash
# TRIAGE: Post-stabilization terminal scope lock. Enforce canonical terminal IDs and collision-free active write scopes.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/stabilization.mode.yaml"
SCOPE_STATUS="$ROOT/ops/plugins/session/bin/terminal-scope-status"

fail() {
  echo "D135 FAIL: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing required file: $1"
}

iso_to_epoch() {
  local raw="${1:-}"
  python3 - "$raw" <<'PY'
from datetime import datetime, timezone
import sys

raw = (sys.argv[1] or "").strip()
if not raw:
    print(0)
    raise SystemExit(0)
try:
    dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
except Exception:
    print(0)
    raise SystemExit(0)
if dt.tzinfo is None:
    dt = dt.replace(tzinfo=timezone.utc)
print(int(dt.timestamp()))
PY
}

require_file "$CONTRACT"
[[ -x "$SCOPE_STATUS" ]] || fail "missing executable: $SCOPE_STATUS"
command -v yq >/dev/null 2>&1 || fail "missing required tool: yq"
command -v jq >/dev/null 2>&1 || fail "missing required tool: jq"

enabled="$(yq e -r '.enabled // false' "$CONTRACT")"
window_start="$(yq e -r '.window_start // ""' "$CONTRACT")"
window_end="$(yq e -r '.window_end // ""' "$CONTRACT")"
naming_pattern="$(yq e -r '.terminal_contract.naming_pattern // "^[A-Z]+-[A-Z0-9]+-[0-9]{2}$"' "$CONTRACT")"

if [[ "$enabled" == "true" ]]; then
  now_epoch="$(date +%s)"
  start_epoch="$(iso_to_epoch "$window_start")"
  end_epoch="$(iso_to_epoch "$window_end")"
  if [[ "$start_epoch" -eq 0 || "$end_epoch" -eq 0 || ( "$now_epoch" -ge "$start_epoch" && "$now_epoch" -le "$end_epoch" ) ]]; then
    echo "D135 PASS: stabilization window active; terminal scope lock deferred until ${window_end:-unset}"
    exit 0
  fi
fi

scope_json="$("$SCOPE_STATUS" --json || true)"
if ! printf '%s\n' "$scope_json" | jq -e '.' >/dev/null 2>&1; then
  fail "unable to parse terminal scope status json"
fi

collision_count="$(printf '%s\n' "$scope_json" | jq -r '.collision_count // 0')"
active_count="$(printf '%s\n' "$scope_json" | jq -r '.active_count // 0')"

if [[ "$collision_count" -gt 0 ]]; then
  details="$(printf '%s\n' "$scope_json" | jq -r '.collisions[]?')"
  fail "active terminal scope collision(s) detected ($collision_count): ${details//$'\n'/; }"
fi

invalid_ids=()
while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  if ! [[ "$id" =~ $naming_pattern ]]; then
    invalid_ids+=("$id")
  fi
done < <(printf '%s\n' "$scope_json" | jq -r '.active_terminal_ids[]?')

if [[ "${#invalid_ids[@]}" -gt 0 ]]; then
  fail "active terminal IDs violate naming pattern '$naming_pattern': ${invalid_ids[*]}"
fi

echo "D135 PASS: terminal scope lock enforced (active=$active_count, collisions=0)"
exit 0
