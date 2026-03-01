#!/usr/bin/env bash
# TRIAGE: Ensure recovery engine bindings/state/audit are healthy and no stale exhausted lockouts are left untracked.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BINDING_FILE="$ROOT/ops/bindings/recovery.actions.yaml"
STATE_ROOT="$ROOT/ops/plugins/recovery/state"
COOLDOWN_DIR="$STATE_ROOT/cooldown"
ATTEMPTS_DIR="$STATE_ROOT/attempts"
AUDIT_LOG="$ROOT/mailroom/logs/recovery-dispatch.ndjson"
GAPS_FILE="$ROOT/ops/bindings/operational.gaps.yaml"

fail() {
  echo "D296 FAIL: $*" >&2
  exit 1
}

file_mtime_epoch() {
  local f="$1"
  if stat -f %m "$f" >/dev/null 2>&1; then
    stat -f %m "$f"
  else
    stat -c %Y "$f"
  fi
}

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"

[[ -f "$BINDING_FILE" ]] || fail "missing recovery actions binding: $BINDING_FILE"
[[ -f "$GAPS_FILE" ]] || fail "missing gaps file: $GAPS_FILE"

yq e '.' "$BINDING_FILE" >/dev/null 2>&1 || fail "invalid YAML: $BINDING_FILE"

mkdir -p "$COOLDOWN_DIR" "$ATTEMPTS_DIR" "$(dirname "$AUDIT_LOG")"
touch "$AUDIT_LOG"
if ! : >"$COOLDOWN_DIR/.d296-write-test" 2>/dev/null; then
  fail "cooldown dir not writable: $COOLDOWN_DIR"
fi
rm -f "$COOLDOWN_DIR/.d296-write-test"

if ! : >"$ATTEMPTS_DIR/.d296-write-test" 2>/dev/null; then
  fail "attempts dir not writable: $ATTEMPTS_DIR"
fi
rm -f "$ATTEMPTS_DIR/.d296-write-test"

if ! : >"$AUDIT_LOG" 2>/dev/null; then
  fail "audit log not writable: $AUDIT_LOG"
fi

action_count="$(yq e '.actions | length' "$BINDING_FILE" 2>/dev/null || echo 0)"
[[ "$action_count" =~ ^[0-9]+$ ]] || action_count=0
(( action_count > 0 )) || fail "recovery binding has zero actions"

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

now_epoch="$(date +%s)"
for ((i=0; i<action_count; i++)); do
  action_id="$(yq e -r ".actions[$i].id // \"\"" "$BINDING_FILE")"
  [[ -n "$action_id" ]] || { err "action[$i] missing id"; continue; }

  max_attempts="$(yq e -r ".actions[$i].safety.max_attempts // .actions[$i].recovery.max_attempts // .defaults.max_attempts // 2" "$BINDING_FILE")"
  [[ "$max_attempts" =~ ^[0-9]+$ ]] || max_attempts=2

  safe_id="$(printf '%s' "$action_id" | tr -cs 'A-Za-z0-9._-' '_')"
  attempts_file="$ATTEMPTS_DIR/$safe_id"
  cooldown_file="$COOLDOWN_DIR/$safe_id"

  attempts=0
  if [[ -f "$attempts_file" ]]; then
    attempts="$(cat "$attempts_file" 2>/dev/null || echo 0)"
    [[ "$attempts" =~ ^[0-9]+$ ]] || attempts=0
  fi

  if (( attempts >= max_attempts )); then
    [[ -f "$cooldown_file" ]] || continue
    mtime="$(file_mtime_epoch "$cooldown_file" 2>/dev/null || echo 0)"
    [[ "$mtime" =~ ^[0-9]+$ ]] || mtime=0
    age_sec=$((now_epoch - mtime))

    if (( age_sec > 172800 )); then
      mapfile -t gate_ids < <(yq e -r ".actions[$i].trigger.gate_ids[]?" "$BINDING_FILE" 2>/dev/null || true)
      if [[ "${#gate_ids[@]}" -eq 0 ]]; then
        continue
      fi

      has_open_gap=0
      for gid in "${gate_ids[@]}"; do
        [[ -n "$gid" ]] || continue
        open_count="$(GID="$gid" yq e '[.gaps[] | select(.status == "open" and (.recovery_gate_id // "") == strenv(GID))] | length' "$GAPS_FILE" 2>/dev/null || echo 0)"
        [[ "$open_count" =~ ^[0-9]+$ ]] || open_count=0
        if (( open_count > 0 )); then
          has_open_gap=1
          break
        fi
      done

      if (( has_open_gap == 0 )); then
        err "stale exhausted action '$action_id' (>48h) has no linked open recovery gap"
      fi
    fi
  fi
done

if (( errors > 0 )); then
  fail "$errors violation(s)"
fi

echo "D300 PASS: recovery engine health checks passed (actions=$action_count)"
