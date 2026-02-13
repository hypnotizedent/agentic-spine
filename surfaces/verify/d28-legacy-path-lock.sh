#!/usr/bin/env bash
# TRIAGE: Replace legacy absolute paths with ~/code/ relative paths. Check archive queue.
set -euo pipefail

# D28: Archive Runway Lock
# 1) Forbid active absolute ronny-ops path references in spine runtime/governance surfaces.
# 2) Enforce extraction queue contract: each item has exactly three required fields.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QUEUE="$ROOT/ops/bindings/extraction.queue.yaml"

fail() { echo "D28 FAIL: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool rg
require_tool yq

LEGACY_PATH='/Users/ronnyworks/ronny''-ops'
legacy_a="docs"
legacy_b="legacy"

# Active scan surface (strict): runtime/governance docs + entrypoint code.
# Explicit quarantine/archive exclusions are allowed historical zones.
HITS="$(
  rg -n --fixed-strings "$LEGACY_PATH" \
    "$ROOT/bin" \
    "$ROOT/ops" \
    "$ROOT/surfaces" \
    "$ROOT/docs/core" \
    "$ROOT/docs/governance" \
    "$ROOT/.github" \
    --glob '!**/.git/**' \
    --glob '!**/.archive/**' \
    --glob "!**/${legacy_a}/${legacy_b}/**" \
    --glob '!**/docs/governance/_audits/**' \
    --glob '!**/docs/governance/_receipts_meta/**' \
    --glob '!**/receipts/**' \
    --glob '!**/mailroom/**' \
    --glob '!**/d28-legacy-path-lock.sh' \
    --glob '!**/d29-active-entrypoint-lock.sh' \
    --glob '!**/d30-active-config-lock.sh' \
    --glob '!**/ops/bindings/legacy.entrypoint.exceptions.yaml' \
    --glob '!**/ops/bindings/host.audit.allowlist.yaml' \
    --glob '!**/ops/plugins/host/bin/host-drift-audit' \
    --glob '!**/ops/plugins/docs/bin/docs-lint' \
    --glob '!**/ops/tools/legacy-freeze.sh' \
    --glob '!**/ops/tools/legacy-thaw.sh' \
    --glob '!**/docs/governance/HOST_DRIFT_POLICY.md' 2>/dev/null || true
)"

[[ -z "$HITS" ]] || fail "active ronny-ops absolute path reference found"

[[ -f "$QUEUE" ]] || fail "extraction queue binding missing: ops/bindings/extraction.queue.yaml"
yq e '.' "$QUEUE" >/dev/null 2>&1 || fail "extraction queue binding is not valid YAML"

# Queue contract: every extraction item must contain exactly these keys.
mapfile -t ITEM_INDEXES < <(yq e '.items | keys | .[]' "$QUEUE" 2>/dev/null || true)
for idx in "${ITEM_INDEXES[@]:-}"; do
  [[ -n "${idx:-}" && "${idx:-}" != "null" ]] || continue

  mapfile -t KEYS < <(yq e ".items[$idx] | keys | .[]" "$QUEUE")
  (( ${#KEYS[@]} == 3 )) || fail "items[$idx] must contain exactly 3 fields"

  need_canon=0
  need_parity=0
  need_rollback=0
  for k in "${KEYS[@]}"; do
    case "$k" in
      canonical_target_path) need_canon=1 ;;
      parity_check_command) need_parity=1 ;;
      rollback_command) need_rollback=1 ;;
      *) fail "items[$idx] has unsupported field: $k" ;;
    esac
  done

  (( need_canon == 1 && need_parity == 1 && need_rollback == 1 )) \
    || fail "items[$idx] missing one or more required fields"

done

echo "D28 PASS: legacy absolute path lock + extraction queue contract enforced"
