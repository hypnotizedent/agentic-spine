#!/usr/bin/env bash
# TRIAGE: Keep briefing.config.yaml section->runner mappings executable and unique; add/update runner scripts when section IDs change.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/ops/bindings/briefing.config.yaml"

fail() {
  echo "D144 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONFIG" ]] || fail "missing briefing config: $CONFIG"
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"

errors=0
seen_ids=''

while IFS=$'\t' read -r section_id runner enabled; do
  [[ "$enabled" == "true" ]] || continue

  if [[ -z "$section_id" || "$section_id" == "null" ]]; then
    echo "  missing section id in briefing config" >&2
    errors=$((errors + 1))
    continue
  fi

  if grep -qx "$section_id" <<<"$seen_ids"; then
    echo "  duplicate section id: $section_id" >&2
    errors=$((errors + 1))
  else
    seen_ids="${seen_ids}${section_id}"$'\n'
  fi

  if [[ -z "$runner" || "$runner" == "null" ]]; then
    echo "  section '$section_id' missing runner path" >&2
    errors=$((errors + 1))
    continue
  fi

  if [[ ! -x "$ROOT/$runner" ]]; then
    echo "  runner missing/non-executable for section '$section_id': $runner" >&2
    errors=$((errors + 1))
  fi
done < <(yq -r '.sections[] | [.id, .runner, (.enabled|tostring)] | @tsv' "$CONFIG")

if (( errors > 0 )); then
  fail "briefing config parity violations: $errors"
fi

count="$(yq -r '[.sections[] | select(.enabled == true)] | length' "$CONFIG")"
echo "D144 PASS: briefing config parity valid (enabled_sections=$count)"
