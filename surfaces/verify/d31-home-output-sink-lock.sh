#!/usr/bin/env bash
# TRIAGE: Move log/out/err files from ~/ to project paths. No home-root output sinks.
set -euo pipefail

# D31: Home Output Sink Lock
# Blocks active runtime log sinks and home-root log artifacts that are
# outside declared sink allowlists.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$ROOT/ops/bindings/home.output.sinks.yaml"

fail() { echo "D31 FAIL: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool yq
require_tool awk

[[ -f "$BINDING" ]] || fail "binding missing: $BINDING"
yq e '.' "$BINDING" >/dev/null 2>&1 || fail "binding is not valid YAML"

HOME_ROOT="$(yq e '.host_root' "$BINDING")"
[[ -n "${HOME_ROOT:-}" && "${HOME_ROOT:-}" != "null" ]] || fail "host_root missing in binding"

path_allowed() {
  local path="$1"
  local prefix
  while IFS= read -r prefix; do
    [[ -n "${prefix:-}" && "${prefix:-}" != "null" ]] || continue
    if [[ "$path" == "$prefix"* ]]; then
      return 0
    fi
  done < <(yq e '.allowed_prefixes[]' "$BINDING")

  local file
  while IFS= read -r file; do
    [[ -n "${file:-}" && "${file:-}" != "null" ]] || continue
    if [[ "$path" == "$file" ]]; then
      return 0
    fi
  done < <(yq e '.allowed_files[]' "$BINDING")

  return 1
}

FAIL_COUNT=0

if command -v launchctl >/dev/null 2>&1; then
  uid="$(id -u)"
  mapfile -t LABELS < <(
    launchctl print "gui/$uid" 2>/dev/null \
      | awk 'match($0, /(com\.ronny[A-Za-z0-9._-]*|works\.ronny[A-Za-z0-9._-]*)/) {print substr($0, RSTART, RLENGTH)}' \
      | sort -u
  )

  for label in "${LABELS[@]:-}"; do
    [[ -n "${label:-}" ]] || continue
    dump="$(launchctl print "gui/$uid/$label" 2>/dev/null || true)"
    [[ -n "$dump" ]] || continue

    for key in "stdout path" "stderr path"; do
      sink="$(echo "$dump" | awk -F' = ' -v k="$key" '$0 ~ k" = " {print $2; exit}')"
      [[ -n "${sink:-}" ]] || continue
      [[ "$sink" == "$HOME_ROOT/"* ]] || continue
      if ! path_allowed "$sink"; then
        echo "D31 HIT: launchd sink not allowlisted ($label -> $sink)" >&2
        FAIL_COUNT=$((FAIL_COUNT + 1))
      fi
    done
  done
fi

# Home-root log artifacts are forbidden unless allowlisted.
while IFS= read -r f; do
  [[ -n "${f:-}" ]] || continue
  if ! path_allowed "$f"; then
    echo "D31 HIT: home-root log artifact not allowlisted ($f)" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done < <(
  find "$HOME_ROOT" -maxdepth 1 -type f \
    \( -name "*.log" -o -name "*.out" -o -name "*.err" \
       -o -name ".*.log" -o -name ".*.out" -o -name ".*.err" \) \
    2>/dev/null
)

(( FAIL_COUNT == 0 )) || fail "home output sink lock violated (${FAIL_COUNT} hit(s))"
echo "D31 PASS: home output sink lock enforced"
