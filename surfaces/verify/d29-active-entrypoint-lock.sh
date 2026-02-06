#!/usr/bin/env bash
set -euo pipefail

# D29: Active Entrypoint Lock
# Fail if active launchd/cron entrypoints sourced from /Code still execute from ronny-ops.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODE_ROOT="${CODE_ROOT:-$HOME/Code}"

fail() { echo "D29 FAIL: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool rg
require_tool awk

RONNY_RE='(/Users/ronnyworks/ronny-ops|~/ronny-ops|\$HOME/ronny-ops|/ronny-ops/)'
FAIL_COUNT=0

# 1) Active user launchd jobs whose source plist exists under /Code
if command -v launchctl >/dev/null 2>&1; then
  uid="$(id -u)"

  mapfile -t LABELS < <(
    launchctl print "gui/$uid" 2>/dev/null \
      | awk 'match($0, /com\.ronny[A-Za-z0-9._-]*/) {print substr($0, RSTART, RLENGTH)}' \
      | sort -u
  )

  for label in "${LABELS[@]:-}"; do
    [[ -n "${label:-}" ]] || continue
    job_dump="$(launchctl print "gui/$uid/$label" 2>/dev/null || true)"
    [[ -n "$job_dump" ]] || continue

    plist_path="$(echo "$job_dump" | awk -F' = ' '/^[[:space:]]*path = /{print $2; exit}')"
    [[ -n "${plist_path:-}" ]] || continue

    plist_base="$(basename "$plist_path")"
    mapfile -t SOURCE_PLISTS < <(
      find "$CODE_ROOT" -type f -name "$plist_base" \
        -not -path '*/.git/*' \
        -not -path '*/.archive/*' \
        -not -path '*/docs/legacy/*' 2>/dev/null
    )

    # Only enforce /Code-managed launchd entrypoints.
    (( ${#SOURCE_PLISTS[@]} > 0 )) || continue

    if echo "$job_dump" | rg -q --pcre2 "$RONNY_RE"; then
      echo "D29 FAIL HIT: active launchd job executes from ronny-ops ($label)" >&2
      FAIL_COUNT=$((FAIL_COUNT + 1))
      continue
    fi

    # Also ensure the /Code plist source does not carry ronny-ops execution paths.
    for src in "${SOURCE_PLISTS[@]}"; do
      if rg -n --pcre2 "^(?!\\s*#).*$RONNY_RE" "$src" >/dev/null 2>&1; then
        echo "D29 FAIL HIT: /Code launchd source references ronny-ops ($src)" >&2
        FAIL_COUNT=$((FAIL_COUNT + 1))
      fi
    done
  done
fi

# 2) Active user crontab must not invoke ronny-ops
if crontab_dump="$(crontab -l 2>/dev/null || true)"; then
  if [[ -n "${crontab_dump:-}" ]] && echo "$crontab_dump" | rg -n --pcre2 "^(?!\\s*#).*$RONNY_RE" >/dev/null 2>&1; then
    echo "D29 FAIL HIT: active user crontab references ronny-ops" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
fi

(( FAIL_COUNT == 0 )) || fail "active entrypoint lock violated (${FAIL_COUNT} hit(s))"

echo "D29 PASS: active /Code entrypoints are not executing from ronny-ops"
