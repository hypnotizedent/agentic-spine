#!/usr/bin/env bash
# TRIAGE: Ensure launchd/cron entries use ~/code/agentic-spine paths, not legacy locations.
set -euo pipefail

# D29: Active Entrypoint Lock
# Fail if active launchd/cron entrypoints execute from ronny-ops,
# unless explicitly allowlisted with a non-expired exception.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXCEPTIONS="$ROOT/ops/bindings/legacy.entrypoint.exceptions.yaml"

fail() { echo "D29 FAIL: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool rg
require_tool awk
require_tool yq

RONNY_RE='(/Users/ronnyworks/ronny-ops|~/ronny-ops|\$HOME/ronny-ops|/ronny-ops/)'
FAIL_COUNT=0

[[ -f "$EXCEPTIONS" ]] || fail "exceptions binding missing: $EXCEPTIONS"
yq e '.' "$EXCEPTIONS" >/dev/null 2>&1 || fail "exceptions binding is not valid YAML"

parse_epoch() {
  local ts="$1"
  local epoch=""
  epoch="$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%s" 2>/dev/null || true)"
  if [[ -z "$epoch" ]]; then
    epoch="$(date -u -d "$ts" "+%s" 2>/dev/null || true)"
  fi
  [[ -n "$epoch" ]] || return 1
  printf '%s\n' "$epoch"
}

exception_valid_for_label() {
  local label="$1"
  local payload="$2"

  local expires
  expires="$(yq e ".exceptions[] | select(.label == \"$label\") | .expires_at" "$EXCEPTIONS" | head -n 1)"
  [[ -n "${expires:-}" && "${expires:-}" != "null" ]] || return 1

  local exp_epoch now_epoch
  exp_epoch="$(parse_epoch "$expires" 2>/dev/null || true)"
  [[ -n "${exp_epoch:-}" ]] || return 1
  now_epoch="$(date -u "+%s")"
  if (( exp_epoch <= now_epoch )); then
    return 1
  fi

  mapfile -t allowed_paths < <(yq e ".exceptions[] | select(.label == \"$label\") | .allowed_paths[]" "$EXCEPTIONS" 2>/dev/null || true)
  (( ${#allowed_paths[@]} > 0 )) || return 1

  local p
  for p in "${allowed_paths[@]}"; do
    [[ -n "${p:-}" && "${p:-}" != "null" ]] || continue
    if printf '%s' "$payload" | rg -q --fixed-strings "$p"; then
      return 0
    fi
  done

  return 1
}

# 1) Active launchd labels in ronny namespace must not execute from legacy paths.
if command -v launchctl >/dev/null 2>&1; then
  uid="$(id -u)"
  mapfile -t LABELS < <(
    launchctl print "gui/$uid" 2>/dev/null \
      | awk 'match($0, /(com\.ronny[A-Za-z0-9._-]*|works\.ronny[A-Za-z0-9._-]*)/) {print substr($0, RSTART, RLENGTH)}' \
      | sort -u
  )

  for label in "${LABELS[@]:-}"; do
    [[ -n "${label:-}" ]] || continue
    job_dump="$(launchctl print "gui/$uid/$label" 2>/dev/null || true)"
    [[ -n "$job_dump" ]] || continue

    if printf '%s' "$job_dump" | rg -q --pcre2 "$RONNY_RE"; then
      if exception_valid_for_label "$label" "$job_dump"; then
        continue
      fi
      echo "D29 FAIL HIT: active launchd job executes from ronny-ops without valid exception ($label)" >&2
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  done
fi

# 2) Active user crontab must not invoke ronny-ops unless explicitly allowlisted.
crontab_dump="$(crontab -l 2>/dev/null || true)"
if [[ -n "${crontab_dump:-}" ]] && printf '%s' "$crontab_dump" | rg -n --pcre2 "^(?!\\s*#).*$RONNY_RE" >/dev/null 2>&1; then
  if ! exception_valid_for_label "user-crontab" "$crontab_dump"; then
    echo "D29 FAIL HIT: active user crontab references ronny-ops without valid exception" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
fi

(( FAIL_COUNT == 0 )) || fail "active entrypoint lock violated (${FAIL_COUNT} hit(s))"

echo "D29 PASS: active entrypoint lock enforced"
