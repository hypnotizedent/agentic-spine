#!/usr/bin/env bash
# Integration-style guardrails for proposals-apply admission controller.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/ops/plugins/proposals/bin/proposals-apply"
CONTRACT="$ROOT/ops/bindings/proposals.lifecycle.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

setup_fixture() {
  local d="$1"
  mkdir -p "$d/ops/plugins/proposals/bin"
  mkdir -p "$d/ops/plugins/verify/bin"
  mkdir -p "$d/ops/bindings"
  mkdir -p "$d/mailroom/state/loop-scopes"
  mkdir -p "$d/mailroom/outbox/proposals"
  mkdir -p "$d/code/workbench/scripts/root/aof"

  cp "$SCRIPT" "$d/ops/plugins/proposals/bin/proposals-apply"
  chmod +x "$d/ops/plugins/proposals/bin/proposals-apply"

  cat > "$d/ops/plugins/verify/bin/verify-topology" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
case "$cmd" in
  core)
    echo "verify.core.run"
    echo "summary: pass=8 fail=0"
    exit 0
    ;;
  recommend)
    domain="${VERIFY_RECOMMEND_DOMAIN:-core}"
    printf '{"recommended_domains":["%s"]}\n' "$domain"
    exit 0
    ;;
  domain)
    domain="${2:-core}"
    if [[ "${VERIFY_DOMAIN_FAIL:-0}" == "1" ]]; then
      echo "forced domain failure: $domain" >&2
      exit 1
    fi
    echo "verify.domain.run $domain"
    echo "summary: pass=1 fail=0"
    exit 0
    ;;
  *)
    echo "unknown verify command: $cmd" >&2
    exit 1
    ;;
esac
SH
  chmod +x "$d/ops/plugins/verify/bin/verify-topology"

  cat > "$d/code/workbench/scripts/root/aof/workbench-aof-check.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
mode="${WORKBENCH_AOF_MODE:-pass}"
case "$mode" in
  pass)
    echo "summary: P0=0 P1=0 P2=0"
    exit 0
    ;;
  p2)
    echo "summary: P0=0 P1=0 P2=1"
    exit 1
    ;;
  p1)
    echo "summary: P0=0 P1=1 P2=0"
    exit 1
    ;;
  p0)
    echo "summary: P0=1 P1=0 P2=0"
    exit 1
    ;;
  *)
    echo "checker failed without summary"
    exit 1
    ;;
esac
SH
  chmod +x "$d/code/workbench/scripts/root/aof/workbench-aof-check.sh"

  cat > "$d/ops/bindings/proposals.lifecycle.yaml" <<'YAML'
version: "1.2"
updated: "2026-02-17"
admission_controller:
  enabled: true
  bypass_allowed: false
  mutating_actions:
    canonical:
      - create
      - modify
      - delete
    aliases:
      created: create
      update: modify
      edit: modify
      api-write: modify
      remove: delete
  block_on_severity:
    - P0
    - P1
  warn_only_severity:
    - P2
YAML

  cat > "$d/ops/bindings/spine.schema.conventions.yaml" <<'YAML'
date_rules:
  iso_8601_regex: '^[0-9]{4}-[0-9]{2}-[0-9]{2}([T][0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$'
  canonical_fields:
    - updated
  accepted_legacy_fields:
    - discovered_at
legacy_alias_rules:
  touch_to_fix_required: true
  legacy_exceptions:
    - file: "ops/bindings/operational.gaps.yaml"
      allowed_keys:
        - notes
        - discovered_at
field_rules:
  disallowed_alias_keys:
    - notes
    - discovered_at
  discouraged_alias_keys:
    - updated
status_rules:
  allowed_values:
    - open
    - fixed
    - closed
  lifecycle_values:
    - active
    - pending
    - retired
policy:
  always_validate_files: []
reporting:
  audit_report_dir: docs/governance/_audits
  audit_report_prefix: SPINE_SCHEMA_CONVENTIONS_AUDIT
YAML

  cat > "$d/ops/bindings/operational.gaps.yaml" <<'YAML'
version: 1
updated: "2026-02-17"
gaps:
  - id: "GAP-OP-TEST"
    type: missing-entry
    doc: "ops/test"
    description: "fixture gap"
    severity: low
    status: open
    parent_loop: "LOOP-TEST-ADMISSION-20260217"
YAML

  cat > "$d/ops/bindings/d75-gap-mutation-policy.yaml" <<'YAML'
version: 1
gate_id: D75
description: "fixture D75 policy without status/lifecycle keys"
file: ops/bindings/operational.gaps.yaml
window: 50
enforcement_after_sha: "46b736b"
required_trailers:
  - Gap-Mutation
  - Gap-Capability
  - Gap-Run-Key
strict: true
YAML

  cat > "$d/mailroom/state/loop-scopes/LOOP-TEST-ADMISSION-20260217.scope.md" <<'MD'
---
status: active
---
MD
}

write_manifest_and_files() {
  local d="$1"
  local cp="$2"
  local action="$3"
  local path="$4"
  mkdir -p "$d/mailroom/outbox/proposals/$cp/files/$(dirname "$path")"
  cat > "$d/mailroom/outbox/proposals/$cp/manifest.yaml" <<YAML
proposal: $cp
agent: "test@fixture"
created: 2026-02-17T00:00:00Z
loop_id: LOOP-TEST-ADMISSION-20260217
changes:
  - action: $action
    path: $path
    reason: "fixture"
YAML
  cat > "$d/mailroom/outbox/proposals/$cp/receipt.md" <<'MD'
# fixture receipt
MD
}

init_fixture_repo() {
  local d="$1"
  git -C "$d" init -q
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Fixture Tester"
  git -C "$d" add -A
  git -C "$d" commit -qm "fixture baseline"
}

run_with_env() {
  local d="$1"
  local cp="$2"
  local out="$3"
  shift 3
  (
    export HOME="$d"
    export SPINE_CODE="$d"
    export WORKBENCH_ROOT="$d/code/workbench"
    # Invoke directly so test coverage matches shebang runtime (/bin/bash on macOS).
    "$@" "$d/ops/plugins/proposals/bin/proposals-apply" --dry-run "$cp"
  ) >"$out" 2>&1
}

require_cmd yq
require_cmd jq
require_cmd git
require_cmd mktemp

[[ -f "$SCRIPT" ]] || fail "missing script under test: $SCRIPT"
[[ -f "$CONTRACT" ]] || fail "missing lifecycle contract: $CONTRACT"

# Static policy checks.
enabled="$(yq e -r '.admission_controller.enabled // ""' "$CONTRACT")"
[[ "$enabled" == "true" ]] || fail "admission_controller.enabled must be true"
pass "admission_controller.enabled=true"

bypass="$(yq e -r '.admission_controller.bypass_allowed | tostring' "$CONTRACT")"
[[ "$bypass" == "false" ]] || fail "admission_controller.bypass_allowed must be false"
pass "admission_controller.bypass_allowed=false"

block_list="$(yq e -r '.admission_controller.block_on_severity[]?' "$CONTRACT" | paste -sd ',' -)"
[[ "$block_list" == *"P0"* && "$block_list" == *"P1"* ]] || fail "block_on_severity must include P0 and P1"
pass "block_on_severity includes P0,P1"

warn_list="$(yq e -r '.admission_controller.warn_only_severity[]?' "$CONTRACT" | paste -sd ',' -)"
[[ "$warn_list" == *"P2"* ]] || fail "warn_only_severity must include P2"
pass "warn_only_severity includes P2"

grep -q '^run_admission_controller()' "$SCRIPT" || fail "run_admission_controller function missing"
grep -q '^run_admission_controller$' "$SCRIPT" || fail "run_admission_controller call missing"
if grep -q -- '--skip-admission' "$SCRIPT"; then
  fail "unexpected admission bypass flag (--skip-admission) detected"
fi
pass "admission path is hardwired and no bypass flag exists"

# Test 1: clean dry-run passes and does not crash on unset arrays.
tmp1="$(mktemp -d)"
setup_fixture "$tmp1"
write_manifest_and_files "$tmp1" CP-SMOKE create docs/hello.md
echo "hello" > "$tmp1/mailroom/outbox/proposals/CP-SMOKE/files/docs/hello.md"
init_fixture_repo "$tmp1"
out1="$(mktemp)"
if ! run_with_env "$tmp1" CP-SMOKE "$out1" env; then
  cat "$out1" >&2
  fail "CP-SMOKE should pass admission"
fi
grep -q 'Admission summary: P0=0 P1=0 P2=0' "$out1" || fail "CP-SMOKE missing zero-findings summary"
pass "CP-SMOKE admission passes"

# Test 2: domain failure blocks apply.
tmp2="$(mktemp -d)"
setup_fixture "$tmp2"
write_manifest_and_files "$tmp2" CP-DOMAIN create docs/domain.md
echo "domain" > "$tmp2/mailroom/outbox/proposals/CP-DOMAIN/files/docs/domain.md"
init_fixture_repo "$tmp2"
out2="$(mktemp)"
if run_with_env "$tmp2" CP-DOMAIN "$out2" env VERIFY_RECOMMEND_DOMAIN=loop_gap VERIFY_DOMAIN_FAIL=1; then
  cat "$out2" >&2
  fail "CP-DOMAIN should be blocked when domain verify fails"
fi
grep -q 'Admission controller blocked' "$out2" || fail "CP-DOMAIN missing block message"
pass "domain verify failure blocks"

# Test 3: workbench P2 findings are warn-only.
tmp3="$(mktemp -d)"
setup_fixture "$tmp3"
write_manifest_and_files "$tmp3" CP-WB create workbench/docs/marker.md
echo "marker" > "$tmp3/mailroom/outbox/proposals/CP-WB/files/workbench/docs/marker.md"
mkdir -p "$tmp3/code/workbench/docs"
init_fixture_repo "$tmp3"
out3="$(mktemp)"
if ! run_with_env "$tmp3" CP-WB "$out3" env WORKBENCH_AOF_MODE=p2; then
  cat "$out3" >&2
  fail "CP-WB should pass on P2-only workbench findings"
fi
grep -q 'workbench checker reported P2 findings: 1' "$out3" || fail "CP-WB missing P2 warning evidence"
pass "workbench P2 findings are warn-only"

# Test 4: schema touch-and-fix violation blocks.
tmp4="$(mktemp -d)"
setup_fixture "$tmp4"
write_manifest_and_files "$tmp4" CP-SCHEMA modify ops/bindings/operational.gaps.yaml
cat > "$tmp4/mailroom/outbox/proposals/CP-SCHEMA/files/ops/bindings/operational.gaps.yaml" <<'YAML'
version: 1
updated: "2026-02-17"
gaps:
  - id: "GAP-OP-TEST-2"
    discovered_at: "2026-02-17"
    notes: "legacy-excepted key in touched file"
    type: missing-entry
    doc: "ops/test"
    description: "fixture schema check"
    severity: low
    status: open
    parent_loop: "LOOP-TEST-ADMISSION-20260217"
YAML
init_fixture_repo "$tmp4"
out4="$(mktemp)"
if run_with_env "$tmp4" CP-SCHEMA "$out4" env; then
  cat "$out4" >&2
  fail "CP-SCHEMA should be blocked by touch_and_fix enforcement"
fi
grep -q 'schema_conventions' "$out4" || fail "CP-SCHEMA missing schema finding"
grep -q 'touch_and_fix enforced' "$out4" || fail "CP-SCHEMA missing touch_and_fix message"
pass "schema touch_and_fix violation blocks"

# Test 5: binding without status/lifecycle must not produce empty-value P1 failures.
tmp5="$(mktemp -d)"
setup_fixture "$tmp5"
write_manifest_and_files "$tmp5" CP-BINDING modify ops/bindings/d75-gap-mutation-policy.yaml
cat > "$tmp5/mailroom/outbox/proposals/CP-BINDING/files/ops/bindings/d75-gap-mutation-policy.yaml" <<'YAML'
version: 1
gate_id: D75
description: "updated fixture d75 policy without status/lifecycle keys"
file: ops/bindings/operational.gaps.yaml
window: 50
enforcement_after_sha: "f094469"
required_trailers:
  - Gap-Mutation
  - Gap-Capability
  - Gap-Run-Key
strict: true
YAML
init_fixture_repo "$tmp5"
out5="$(mktemp)"
if ! run_with_env "$tmp5" CP-BINDING "$out5" env; then
  cat "$out5" >&2
  fail "CP-BINDING should pass without false status/lifecycle P1 findings"
fi
if grep -q "non-canonical status value ''" "$out5"; then
  cat "$out5" >&2
  fail "CP-BINDING produced false empty status finding"
fi
if grep -q "non-canonical lifecycle value ''" "$out5"; then
  cat "$out5" >&2
  fail "CP-BINDING produced false empty lifecycle finding"
fi
pass "binding without status/lifecycle avoids false P1 findings"

echo "All admission tests passed"
