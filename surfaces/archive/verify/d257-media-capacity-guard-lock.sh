#!/usr/bin/env bash
# TRIAGE: D257 media-capacity-guard-lock - prevent unowned/stale high media pool capacity drift.
# Report/enforce guard for media pool capacity with ownership, runway policy, projection freshness,
# and authority/projection parity checks.
set -euo pipefail

ROOT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${SPINE_CODE:-$ROOT_DEFAULT}"
source "$ROOT/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "pve"

SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"
GAPS_BINDING="$ROOT/ops/bindings/operational.gaps.yaml"
POLICY_FILE="$ROOT/ops/bindings/infra.capacity.guard.policy.yaml"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d257-media-capacity-guard-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D257 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$SSH_BINDING" ]] || { echo "D257 FAIL: missing $SSH_BINDING" >&2; exit 1; }
[[ -f "$GAPS_BINDING" ]] || { echo "D257 FAIL: missing $GAPS_BINDING" >&2; exit 1; }
[[ -f "$POLICY_FILE" ]] || { echo "D257 FAIL: missing $POLICY_FILE" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D257 FAIL: yq missing" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "D257 FAIL: python3 missing" >&2; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "D257 FAIL: ssh missing" >&2; exit 1; }

# Defaults (policy override supported)
DEFAULT_MODE="report"
WARN_PCT_DEFAULT="80"
FAIL_PCT_DEFAULT="85"
STALE_DAYS_DEFAULT="7"
STORAGE_HOST_ID_DEFAULT="pve"
POOL_NAME_DEFAULT="media"
OWNING_LOOP_PREFIX_DEFAULT="LOOP-INFRA-MEDIA-CAPACITY-GUARD-"
OWNING_TERMINAL_DEFAULT="SPINE-EXECUTION-01"
TREND_EVIDENCE_DEFAULT="docs/planning/W52_MEDIA_CAPACITY_TREND_EVIDENCE.md"
RUNWAY_MIN_DAYS_DEFAULT="30"
SNAPSHOT_PATH_DEFAULT="ops/bindings/media.capacity.snapshot.yaml"
SNAPSHOT_TTL_HOURS_DEFAULT="30"

[[ -z "$MODE" ]] && MODE="$(yq -r '.mode.default_policy // "'"$DEFAULT_MODE"'"' "$POLICY_FILE" 2>/dev/null || echo "$DEFAULT_MODE")"
WARN_PCT="$(yq -r '.thresholds.media_warn_pct // "'"$WARN_PCT_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$WARN_PCT_DEFAULT")"
FAIL_PCT="$(yq -r '.thresholds.media_fail_pct // "'"$FAIL_PCT_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$FAIL_PCT_DEFAULT")"
STALE_DAYS="$(yq -r '.thresholds.stale_days // "'"$STALE_DAYS_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$STALE_DAYS_DEFAULT")"
STORAGE_HOST_ID="$(yq -r '.target.storage_host_id // "'"$STORAGE_HOST_ID_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$STORAGE_HOST_ID_DEFAULT")"
POOL_NAME="$(yq -r '.target.pool_name // "'"$POOL_NAME_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$POOL_NAME_DEFAULT")"
OWNING_LOOP_PREFIX="$(yq -r '.ownership.owning_loop_prefix // "'"$OWNING_LOOP_PREFIX_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$OWNING_LOOP_PREFIX_DEFAULT")"
OWNING_TERMINAL="$(yq -r '.ownership.owning_terminal // "'"$OWNING_TERMINAL_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$OWNING_TERMINAL_DEFAULT")"
TREND_EVIDENCE_FILE="$(yq -r '.evidence.trend_file // "'"$TREND_EVIDENCE_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$TREND_EVIDENCE_DEFAULT")"
RUNWAY_MIN_DAYS="$(yq -r '.runway.runway_min_days // "'"$RUNWAY_MIN_DAYS_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$RUNWAY_MIN_DAYS_DEFAULT")"
SNAPSHOT_PATH="$(yq -r '.runway.snapshot_path // "'"$SNAPSHOT_PATH_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$SNAPSHOT_PATH_DEFAULT")"
SNAPSHOT_TTL_HOURS="$(yq -r '.runway.projection_freshness_ttl_hours // "'"$SNAPSHOT_TTL_HOURS_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$SNAPSHOT_TTL_HOURS_DEFAULT")"

[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D257 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

[[ "$TREND_EVIDENCE_FILE" = /* ]] || TREND_EVIDENCE_FILE="$ROOT/$TREND_EVIDENCE_FILE"
[[ "$SNAPSHOT_PATH" = /* ]] || SNAPSHOT_PATH="$ROOT/$SNAPSHOT_PATH"

FINDINGS=0
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

# Integrity checks on threshold/runway contract itself.
if ! [[ "$WARN_PCT" =~ ^[0-9]+$ && "$FAIL_PCT" =~ ^[0-9]+$ ]]; then
  finding "HIGH" "threshold_integrity: warn/fail thresholds must be integers (warn='$WARN_PCT' fail='$FAIL_PCT')"
else
  if (( WARN_PCT < 1 || WARN_PCT > 99 || FAIL_PCT < 1 || FAIL_PCT > 100 || WARN_PCT >= FAIL_PCT )); then
    finding "HIGH" "threshold_integrity: invalid threshold ordering/range warn=${WARN_PCT}% fail=${FAIL_PCT}%"
  fi
fi
if ! [[ "$RUNWAY_MIN_DAYS" =~ ^[0-9]+$ ]] || (( RUNWAY_MIN_DAYS < 1 )); then
  finding "HIGH" "runway_integrity: runway_min_days must be a positive integer (got '$RUNWAY_MIN_DAYS')"
fi
if ! [[ "$SNAPSHOT_TTL_HOURS" =~ ^[0-9]+$ ]] || (( SNAPSHOT_TTL_HOURS < 1 )); then
  finding "HIGH" "freshness_integrity: projection_freshness_ttl_hours must be positive integer (got '$SNAPSHOT_TTL_HOURS')"
fi

ssh_host="$(yq -r ".ssh.targets[] | select(.id == \"$STORAGE_HOST_ID\") | .host // \"\"" "$SSH_BINDING" 2>/dev/null || true)"
ssh_user="$(yq -r ".ssh.targets[] | select(.id == \"$STORAGE_HOST_ID\") | .user // \"ubuntu\"" "$SSH_BINDING" 2>/dev/null || echo ubuntu)"
[[ -n "$ssh_host" ]] || { echo "D257 FAIL: missing ssh target id='$STORAGE_HOST_ID' in $SSH_BINDING" >&2; exit 1; }

ref="$ssh_user@$ssh_host"
opts=(-o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

if ! ssh "${opts[@]}" "$ref" "true" >/dev/null 2>&1; then
  echo "D257 FAIL: ssh unreachable ($ref)" >&2
  exit 1
fi

raw_cap="$(ssh "${opts[@]}" "$ref" "zpool list -Hp -o capacity '$POOL_NAME' 2>/dev/null | head -1" 2>/dev/null || true)"
if [[ -z "$raw_cap" ]]; then
  raw_cap="$(ssh "${opts[@]}" "$ref" "zpool list '$POOL_NAME' -H 2>/dev/null | awk '{print \$5}' | head -1" 2>/dev/null || true)"
fi

media_pct="$(python3 - "$raw_cap" <<'PY'
import re
import sys
raw = (sys.argv[1] or "").strip()
m = re.search(r"(\d+(\.\d+)?)", raw)
if not m:
    print("")
    raise SystemExit(0)
print(int(float(m.group(1))))
PY
)"

if [[ -z "$media_pct" ]]; then
  echo "D257 FAIL: unable to parse pool capacity for '$POOL_NAME' (raw='$raw_cap')" >&2
  exit 1
fi

# Find open owning gap candidate.
gap_row="$(python3 - "$GAPS_BINDING" "$OWNING_LOOP_PREFIX" <<'PY'
import sys
import yaml
path, prefix = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    doc = yaml.safe_load(f) or {}
rows = []
for g in doc.get("gaps", []):
    if g.get("status") != "open":
        continue
    gid = (g.get("id") or "").strip()
    parent = (g.get("parent_loop") or "").strip()
    discovered = (g.get("discovered_at") or "").strip()
    desc = (g.get("description") or "").lower()
    if parent.startswith(prefix) or ("media" in desc and ("capacity" in desc or "cap " in desc)):
        rows.append((discovered, gid, parent))
rows.sort()
if rows:
    d, gid, parent = rows[0]
    print(f"{gid}|{d}|{parent}")
PY
)"

gap_id=""
gap_discovered=""
gap_parent_loop=""
if [[ -n "$gap_row" ]]; then
  IFS='|' read -r gap_id gap_discovered gap_parent_loop <<< "$gap_row"
fi

gap_age_days=0
if [[ -n "$gap_discovered" ]]; then
  gap_age_days="$(python3 - "$gap_discovered" <<'PY'
import datetime
import sys
s = (sys.argv[1] or "").strip()
try:
    d = datetime.date.fromisoformat(s[:10])
    print((datetime.date.today() - d).days)
except Exception:
    print(0)
PY
)"
fi

terminal_ok=0
if [[ -n "$gap_parent_loop" ]]; then
  scope_file="$ROOT/mailroom/state/loop-scopes/${gap_parent_loop}.scope.md"
  if [[ -f "$scope_file" ]]; then
    active_terminal="$(awk -F': ' '/^active_terminal:/ {print $2; exit}' "$scope_file" | tr -d '"' | xargs || true)"
    if [[ "$active_terminal" == "$OWNING_TERMINAL" ]]; then
      terminal_ok=1
    fi
  fi
fi

trend_ok=0
if [[ -f "$TREND_EVIDENCE_FILE" ]]; then
  if rg -n "downward_trend:[[:space:]]*true" "$TREND_EVIDENCE_FILE" >/dev/null 2>&1; then
    trend_age_days="$(python3 - "$TREND_EVIDENCE_FILE" <<'PY'
import datetime
import os
import sys
mtime = datetime.date.fromtimestamp(os.path.getmtime(sys.argv[1]))
print((datetime.date.today() - mtime).days)
PY
)"
    if [[ "$trend_age_days" =~ ^[0-9]+$ ]] && (( trend_age_days <= STALE_DAYS )); then
      trend_ok=1
    fi
  fi
fi

snapshot_exists=0
snapshot_parse_error=0
snapshot_fresh=0
snapshot_age_hours=-1
snapshot_warn=""
snapshot_fail=""
snapshot_runway_min=""
snapshot_policy_path=""
snapshot_policy_compliant=0
snapshot_runway_status="unknown"
snapshot_days_to_fail=""
snapshot_days_to_warn=""
snapshot_usage_pct=""
snapshot_policy_path_parity=0
snapshot_threshold_parity=0
snapshot_runway_parity=0
snapshot_usage_delta=""

snapshot_eval_tmp="$(mktemp)"
trap 'rm -f "$snapshot_eval_tmp"' EXIT
python3 - "$SNAPSHOT_PATH" "$WARN_PCT" "$FAIL_PCT" "$RUNWAY_MIN_DAYS" "$SNAPSHOT_TTL_HOURS" "$media_pct" "$POLICY_FILE" > "$snapshot_eval_tmp" <<'PY'
import datetime
import math
import pathlib
import sys

import yaml

snapshot_path = pathlib.Path(sys.argv[1])
warn_expected = str(sys.argv[2])
fail_expected = str(sys.argv[3])
runway_expected = str(sys.argv[4])
ttl_hours = int(float(sys.argv[5]))
live_usage = float(sys.argv[6])
policy_path = pathlib.Path(sys.argv[7]).resolve()

print("exists=1" if snapshot_path.exists() else "exists=0")
if not snapshot_path.exists():
    raise SystemExit(0)

try:
    obj = yaml.safe_load(snapshot_path.read_text(encoding="utf-8")) or {}
except Exception:
    print("parse_error=1")
    raise SystemExit(0)

if not isinstance(obj, dict):
    print("parse_error=1")
    raise SystemExit(0)

print("parse_error=0")

generated = str(obj.get("generated_at_utc", "") or "").strip()
age_h = -1.0
if generated:
    ts = generated
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    try:
        dt_obj = datetime.datetime.fromisoformat(ts)
        if dt_obj.tzinfo is None:
            dt_obj = dt_obj.replace(tzinfo=datetime.timezone.utc)
        age_h = (datetime.datetime.now(datetime.timezone.utc) - dt_obj.astimezone(datetime.timezone.utc)).total_seconds() / 3600.0
    except Exception:
        age_h = -1.0

print(f"age_hours={round(age_h, 2) if age_h >= 0 else -1}")
print("fresh=1" if age_h >= 0 and age_h <= ttl_hours else "fresh=0")

pool = obj.get("pool", {}) if isinstance(obj.get("pool"), dict) else {}
projection = obj.get("projection", {}) if isinstance(obj.get("projection"), dict) else {}
policy_eval = obj.get("policy_evaluation", {}) if isinstance(obj.get("policy_evaluation"), dict) else {}
policy_ref = obj.get("policy_reference", {}) if isinstance(obj.get("policy_reference"), dict) else {}

snap_warn = str(pool.get("warn_pct", ""))
snap_fail = str(pool.get("fail_pct", ""))
snap_runway_min = str(policy_eval.get("runway_min", policy_ref.get("runway_min_days", "")))
snap_policy_path = str(policy_ref.get("path", ""))
snap_policy_compliant = policy_eval.get("compliant", False)
snap_runway_status = str(obj.get("runway_status", "unknown"))
snap_days_to_warn = projection.get("days_to_warn")
snap_days_to_fail = projection.get("days_to_fail")
snap_usage = pool.get("usage_pct")

print(f"warn_pct={snap_warn}")
print(f"fail_pct={snap_fail}")
print(f"runway_min_days={snap_runway_min}")
print(f"policy_path={snap_policy_path}")
print(f"policy_compliant={1 if bool(snap_policy_compliant) else 0}")
print(f"runway_status={snap_runway_status}")
print(f"days_to_warn={'' if snap_days_to_warn is None else snap_days_to_warn}")
print(f"days_to_fail={'' if snap_days_to_fail is None else snap_days_to_fail}")
print(f"usage_pct={'' if snap_usage is None else snap_usage}")

try:
    policy_rel = str(policy_path.relative_to(pathlib.Path.cwd().resolve()))
except Exception:
    policy_rel = str(policy_path)

threshold_parity = 1 if snap_warn == warn_expected and snap_fail == fail_expected else 0
runway_parity = 1 if snap_runway_min == runway_expected else 0
path_parity = 1 if snap_policy_path in {policy_rel, str(policy_path)} else 0
print(f"threshold_parity={threshold_parity}")
print(f"runway_parity={runway_parity}")
print(f"policy_path_parity={path_parity}")

usage_delta = ""
try:
    if snap_usage is not None and snap_usage != "":
        usage_delta = abs(float(snap_usage) - live_usage)
except Exception:
    usage_delta = ""
print(f"usage_delta={usage_delta}")
PY

while IFS='=' read -r key value; do
  case "$key" in
    exists) snapshot_exists="$value" ;;
    parse_error) snapshot_parse_error="$value" ;;
    fresh) snapshot_fresh="$value" ;;
    age_hours) snapshot_age_hours="$value" ;;
    warn_pct) snapshot_warn="$value" ;;
    fail_pct) snapshot_fail="$value" ;;
    runway_min_days) snapshot_runway_min="$value" ;;
    policy_path) snapshot_policy_path="$value" ;;
    policy_compliant) snapshot_policy_compliant="$value" ;;
    runway_status) snapshot_runway_status="$value" ;;
    days_to_warn) snapshot_days_to_warn="$value" ;;
    days_to_fail) snapshot_days_to_fail="$value" ;;
    usage_pct) snapshot_usage_pct="$value" ;;
    threshold_parity) snapshot_threshold_parity="$value" ;;
    runway_parity) snapshot_runway_parity="$value" ;;
    policy_path_parity) snapshot_policy_path_parity="$value" ;;
    usage_delta) snapshot_usage_delta="$value" ;;
  esac
done < "$snapshot_eval_tmp"

if [[ "$snapshot_exists" != "1" ]]; then
  finding "HIGH" "projection_missing: snapshot not found at ${SNAPSHOT_PATH#$ROOT/}"
else
  if [[ "$snapshot_parse_error" == "1" ]]; then
    finding "HIGH" "projection_parse_error: unable to parse snapshot at ${SNAPSHOT_PATH#$ROOT/}"
  else
    if [[ "$snapshot_fresh" != "1" ]]; then
      finding "HIGH" "projection_stale: snapshot age=${snapshot_age_hours}h exceeds ttl=${SNAPSHOT_TTL_HOURS}h"
    fi
    if [[ "$snapshot_threshold_parity" != "1" ]]; then
      finding "HIGH" "projection_parity_threshold: snapshot warn/fail (${snapshot_warn}/${snapshot_fail}) != policy (${WARN_PCT}/${FAIL_PCT})"
    fi
    if [[ "$snapshot_runway_parity" != "1" ]]; then
      finding "HIGH" "projection_parity_runway: snapshot runway_min_days='${snapshot_runway_min}' != policy '${RUNWAY_MIN_DAYS}'"
    fi
    if [[ "$snapshot_policy_path_parity" != "1" ]]; then
      finding "MEDIUM" "projection_parity_policy_path: snapshot policy_reference.path='${snapshot_policy_path:-missing}' does not match policy file"
    fi
    if [[ -n "$snapshot_usage_delta" ]]; then
      usage_delta_int="$(python3 - "$snapshot_usage_delta" <<'PY'
import sys
try:
    print(int(float(sys.argv[1])))
except Exception:
    print(0)
PY
)"
      if (( usage_delta_int > 2 )); then
        finding "MEDIUM" "projection_parity_usage_delta: live usage=${media_pct}% snapshot=${snapshot_usage_pct}% delta>${usage_delta_int}%"
      fi
    fi
    if [[ "$snapshot_policy_compliant" != "1" ]]; then
      finding "HIGH" "runway_noncompliant: runway_status=${snapshot_runway_status} days_to_warn=${snapshot_days_to_warn:-none} days_to_fail=${snapshot_days_to_fail:-none} min_days=${RUNWAY_MIN_DAYS}"
    fi
  fi
fi

echo "D257 CONTEXT: pool=$POOL_NAME usage=${media_pct}% mode=$MODE gap=${gap_id:-none} gap_age_days=${gap_age_days:-0} trend_ok=$trend_ok snapshot_fresh=$snapshot_fresh runway_status=${snapshot_runway_status} days_to_fail=${snapshot_days_to_fail:-none}"

if (( media_pct >= FAIL_PCT )); then
  finding "HIGH" "critical_breach: $POOL_NAME ${media_pct}% >= fail ${FAIL_PCT}%"
fi

if (( media_pct >= WARN_PCT )); then
  if [[ -z "$gap_id" ]]; then
    finding "HIGH" "stale_unowned: $POOL_NAME ${media_pct}% >= warn ${WARN_PCT}% with no open owning gap"
  fi
  if [[ -n "$gap_id" && "$terminal_ok" -ne 1 ]]; then
    finding "MEDIUM" "ownership_mismatch: gap=$gap_id loop_terminal!=${OWNING_TERMINAL}"
  fi
  if (( gap_age_days > STALE_DAYS )) && [[ "$trend_ok" -ne 1 ]]; then
    finding "HIGH" "stale_no_trend: $POOL_NAME >= ${WARN_PCT}% for ${gap_age_days}d (> ${STALE_DAYS}d) without downward trend evidence"
  fi
fi

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D257 FAIL: media capacity guard findings=$FINDINGS"
    exit 1
  fi
  echo "D257 REPORT: media capacity guard findings=$FINDINGS"
  exit 0
fi

echo "D257 PASS: media capacity guard lock"
exit 0
