#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
AUDIT="$ROOT/ops/plugins/core/verify/bin/workbench-impl-audit"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (expected: $needle)"
  fi
}

echo "workbench implementation audit tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT
SPINE_FIXTURE="$TMPDIR_BASE/spine"
WORKBENCH_FIXTURE="$TMPDIR_BASE/workbench"
mkdir -p \
  "$SPINE_FIXTURE/ops/bindings" \
  "$SPINE_FIXTURE/ops" \
  "$SPINE_FIXTURE/ops/plugins/domains/mint/lib" \
  "$SPINE_FIXTURE/ops/plugins/domains/media/bin" \
  "$SPINE_FIXTURE/docs/not-allowed" \
  "$WORKBENCH_FIXTURE/agents/microsoft/tools"

printf '#!/usr/bin/env python3\n' > "$SPINE_FIXTURE/ops/plugins/domains/mint/lib/customer_voice.py"
printf '#!/usr/bin/env bash\n' > "$SPINE_FIXTURE/ops/plugins/domains/media/bin/media-backup-create"
printf 'stub\n' > "$WORKBENCH_FIXTURE/agents/microsoft/tools/microsoft_tools.py"
printf 'nope\n' > "$SPINE_FIXTURE/docs/not-allowed/invalid-tool"

cat > "$SPINE_FIXTURE/ops/bindings/fabric.boundary.contract.yaml" <<YAML
version: 1
spine:
  canonical_repo: "$SPINE_FIXTURE"
workbench:
  canonical_repo: "$WORKBENCH_FIXTURE"
capability_boundary:
  domain_external_prefixes: []
domain_external_implementation_boundary:
  default_allowed_location:
    id: default:workbench-domain-external
    repo: workbench
    allowed_roots:
      - agents/
      - docs/infrastructure/domains/
      - infra/compose/
    rationale: Default workbench location.
  allowed_location_overrides:
    - id: mint-spine-customer-runtime
      match:
        capability_prefixes:
          - mint.customer.voice.
          - mint.customer.frontdesk.
      repo: spine
      allowed_roots:
        - ops/plugins/domains/mint/
      rationale: Mint customer runtime remains spine-local.
    - id: media-spine-backup-runtime
      match:
        capability_ids:
          - media.backup.create
      repo: spine
      allowed_roots:
        - ops/plugins/domains/media/bin/
      rationale: Media backup runtime remains spine-local.
YAML

cat > "$SPINE_FIXTURE/ops/capabilities.yaml" <<YAML
capabilities:
  microsoft.mail.search:
    plane: domain_external
    domain: microsoft
    implementation_repo: "$WORKBENCH_FIXTURE"
    implementation_path: agents/microsoft/tools/microsoft_tools.py
  mint.customer.voice.intake.capture:
    plane: domain_external
    domain: mint
    implementation_repo: "$SPINE_FIXTURE"
    implementation_path: ops/plugins/domains/mint/lib/customer_voice.py
  media.backup.create:
    plane: domain_external
    domain: media
    implementation_repo: "$SPINE_FIXTURE"
    implementation_path: ops/plugins/domains/media/bin/media-backup-create
  invalid.repo:
    plane: domain_external
    domain: media
    implementation_repo: "$SPINE_FIXTURE"
    implementation_path: docs/not-allowed/invalid-tool
  invalid.metadata:
    plane: domain_external
    domain: mint
YAML

set +e
list_out="$(python3 "$AUDIT" --root "$SPINE_FIXTURE" --list 2>&1)"
list_rc=$?
set -e
if [[ "$list_rc" -eq 0 ]]; then
  pass "list mode succeeds when not strict"
else
  fail "list mode succeeds when not strict"
  echo "$list_out" >&2
fi

assert_contains "$list_out" "default:workbench-domain-external" "default workbench authority is reported"
assert_contains "$list_out" "mint-spine-customer-runtime" "mint spine override authority is reported"
assert_contains "$list_out" "media-spine-backup-runtime" "media spine override authority is reported"
assert_contains "$list_out" "metadata_errors: 1" "metadata violation count is reported"
assert_contains "$list_out" "repo_errors: 1" "repo scope violation count is reported"
assert_contains "$list_out" "media.backup.create | media | ok | media-spine-backup-runtime" "media backup resolves through explicit spine authority"
assert_contains "$list_out" "mint.customer.voice.intake.capture | mint | ok | mint-spine-customer-runtime" "mint voice resolves through explicit spine authority"

set +e
strict_out="$(python3 "$AUDIT" --root "$SPINE_FIXTURE" --strict 2>&1)"
strict_rc=$?
set -e
if [[ "$strict_rc" -ne 0 ]]; then
  pass "strict mode fails on metadata or repo violations"
else
  fail "strict mode fails on metadata or repo violations"
  echo "$strict_out" >&2
fi
assert_contains "$strict_out" "repo_scope_violations:" "strict output includes repo scope violations"
assert_contains "$strict_out" "metadata_violations:" "strict output includes metadata violations"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
