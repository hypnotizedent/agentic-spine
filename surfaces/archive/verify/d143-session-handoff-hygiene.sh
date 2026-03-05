#!/usr/bin/env bash
# TRIAGE: Keep handoff config valid and expire/close stale active handoffs so none exceed 2x configured TTL.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPINE_REPO="${SPINE_REPO:-$ROOT}"
SPINE_CODE="${SPINE_CODE:-$ROOT}"
source "$ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

CONFIG="$ROOT/ops/bindings/handoff.config.yaml"

fail() {
  echo "D143 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONFIG" ]] || fail "missing handoff config: $CONFIG"
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
command -v python3 >/dev/null 2>&1 || fail "required tool missing: python3"

ttl_hours="$(yq -r '.defaults.ttl_hours // 72' "$CONFIG")"
[[ "$ttl_hours" =~ ^[0-9]+$ ]] || fail "invalid ttl_hours in config"

handoff_dir_rel="$(yq -r '.storage.directory // "mailroom/state/handoffs"' "$CONFIG")"
handoff_dir="$(spine_resolve_mailroom_path "$handoff_dir_rel")"
mkdir -p "$handoff_dir"

stale=0
required_missing=0

while IFS= read -r file; do
  [[ -f "$file" ]] || continue

  while IFS= read -r field; do
    [[ -z "$field" || "$field" == "null" ]] && continue
    value="$(yq -r ".$field // \"\"" "$file" 2>/dev/null || true)"
    if [[ -z "$value" || "$value" == "null" ]]; then
      echo "  missing required field '$field' in $(basename "$file")" >&2
      required_missing=$((required_missing + 1))
    fi
  done < <(yq -r '.required_fields[]?' "$CONFIG")

  state="$(yq -r '.state // ""' "$file")"
  [[ "$state" == "active" ]] || continue

  created="$(yq -r '.created_at_utc // ""' "$file")"
  age_hours="$(python3 - "$created" <<'PY'
import datetime as dt
import sys
raw = sys.argv[1]
try:
    t = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
except Exception:
    print(-1)
    raise SystemExit(0)
now = dt.datetime.now(dt.timezone.utc)
print(int((now - t).total_seconds() // 3600))
PY
)"

  if [[ "$age_hours" =~ ^-?[0-9]+$ ]] && (( age_hours >= ttl_hours * 2 )); then
    echo "  stale active handoff $(basename "$file") age=${age_hours}h ttl=${ttl_hours}h" >&2
    stale=$((stale + 1))
  fi
done < <(find "$handoff_dir" -maxdepth 1 -type f -name 'HO-*.yaml' | sort)

if (( required_missing > 0 || stale > 0 )); then
  fail "handoff hygiene violations (missing_fields=$required_missing stale_active=$stale)"
fi

count="$(find "$handoff_dir" -maxdepth 1 -type f -name 'HO-*.yaml' | wc -l | tr -d ' ')"
echo "D143 PASS: handoff hygiene valid (files=$count ttl_hours=$ttl_hours)"
