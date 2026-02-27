#!/usr/bin/env bash
# TRIAGE: D257 media-capacity-guard-lock — prevent unowned/stale high media pool capacity drift.
# Report/enforce guard for media pool capacity with ownership and staleness checks.
set -euo pipefail

ROOT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${SPINE_CODE:-$ROOT_DEFAULT}"
source "$ROOT/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

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
command -v yq >/dev/null 2>&1 || { echo "D257 FAIL: yq missing" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "D257 FAIL: python3 missing" >&2; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "D257 FAIL: ssh missing" >&2; exit 1; }

# Defaults (can be overridden by optional policy file)
DEFAULT_MODE="report"
WARN_PCT_DEFAULT="80"
FAIL_PCT_DEFAULT="85"
STALE_DAYS_DEFAULT="7"
STORAGE_HOST_ID_DEFAULT="pve"
POOL_NAME_DEFAULT="media"
OWNING_LOOP_PREFIX_DEFAULT="LOOP-INFRA-MEDIA-CAPACITY-GUARD-"
OWNING_TERMINAL_DEFAULT="SPINE-EXECUTION-01"
TREND_EVIDENCE_DEFAULT="docs/planning/W52_MEDIA_CAPACITY_TREND_EVIDENCE.md"

if [[ -f "$POLICY_FILE" ]]; then
  [[ -z "$MODE" ]] && MODE="$(yq -r '.mode.default_policy // "'"$DEFAULT_MODE"'"' "$POLICY_FILE" 2>/dev/null || echo "$DEFAULT_MODE")"
  WARN_PCT="$(yq -r '.thresholds.media_warn_pct // "'"$WARN_PCT_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$WARN_PCT_DEFAULT")"
  FAIL_PCT="$(yq -r '.thresholds.media_fail_pct // "'"$FAIL_PCT_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$FAIL_PCT_DEFAULT")"
  STALE_DAYS="$(yq -r '.thresholds.stale_days // "'"$STALE_DAYS_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$STALE_DAYS_DEFAULT")"
  STORAGE_HOST_ID="$(yq -r '.target.storage_host_id // "'"$STORAGE_HOST_ID_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$STORAGE_HOST_ID_DEFAULT")"
  POOL_NAME="$(yq -r '.target.pool_name // "'"$POOL_NAME_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$POOL_NAME_DEFAULT")"
  OWNING_LOOP_PREFIX="$(yq -r '.ownership.owning_loop_prefix // "'"$OWNING_LOOP_PREFIX_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$OWNING_LOOP_PREFIX_DEFAULT")"
  OWNING_TERMINAL="$(yq -r '.ownership.owning_terminal // "'"$OWNING_TERMINAL_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$OWNING_TERMINAL_DEFAULT")"
  TREND_EVIDENCE_FILE="$(yq -r '.evidence.trend_file // "'"$TREND_EVIDENCE_DEFAULT"'"' "$POLICY_FILE" 2>/dev/null || echo "$TREND_EVIDENCE_DEFAULT")"
else
  [[ -z "$MODE" ]] && MODE="$DEFAULT_MODE"
  WARN_PCT="$WARN_PCT_DEFAULT"
  FAIL_PCT="$FAIL_PCT_DEFAULT"
  STALE_DAYS="$STALE_DAYS_DEFAULT"
  STORAGE_HOST_ID="$STORAGE_HOST_ID_DEFAULT"
  POOL_NAME="$POOL_NAME_DEFAULT"
  OWNING_LOOP_PREFIX="$OWNING_LOOP_PREFIX_DEFAULT"
  OWNING_TERMINAL="$OWNING_TERMINAL_DEFAULT"
  TREND_EVIDENCE_FILE="$TREND_EVIDENCE_DEFAULT"
fi

[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D257 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

if [[ "$TREND_EVIDENCE_FILE" != /* ]]; then
  TREND_EVIDENCE_FILE="$ROOT/$TREND_EVIDENCE_FILE"
fi

FINDINGS=0
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

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
import re, sys
raw = (sys.argv[1] or "").strip()
m = re.search(r'(\d+(\.\d+)?)', raw)
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

# Find open owning gap candidate
gap_row="$(python3 - "$GAPS_BINDING" "$OWNING_LOOP_PREFIX" <<'PY'
import sys, yaml
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
import sys, datetime
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
import os, sys, datetime
p = sys.argv[1]
mtime = datetime.date.fromtimestamp(os.path.getmtime(p))
print((datetime.date.today() - mtime).days)
PY
)"
    if [[ "$trend_age_days" =~ ^[0-9]+$ ]] && (( trend_age_days <= STALE_DAYS )); then
      trend_ok=1
    fi
  fi
fi

echo "D257 CONTEXT: pool=$POOL_NAME usage=${media_pct}% mode=$MODE gap=${gap_id:-none} gap_age_days=${gap_age_days:-0} trend_ok=$trend_ok"

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
