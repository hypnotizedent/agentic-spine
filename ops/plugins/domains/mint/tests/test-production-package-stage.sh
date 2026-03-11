#!/usr/bin/env bash
# test-production-package-stage.sh - Validate governed production package staging for barudan and screenpro

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

PACKAGE_STAGE="$SPINE_ROOT/ops/plugins/domains/mint/bin/production-package-stage"
TMP_ROOT="$(mktemp -d)"
HANDOFFS_DIR="$TMP_ROOT/production-handoffs"
PACKAGES_DIR="$TMP_ROOT/production-packages"
PACKAGES_INDEX="$TMP_ROOT/production-packages-index.yaml"
STAGING_ROOT="$TMP_ROOT/production-packages/staged-bundles"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

run_stage() {
  MINT_PRODUCTION_HANDOFFS_DIR="$HANDOFFS_DIR" \
  MINT_PRODUCTION_PACKAGES_DIR="$PACKAGES_DIR" \
  MINT_PRODUCTION_PACKAGES_INDEX_FILE="$PACKAGES_INDEX" \
  MINT_PRODUCTION_PACKAGES_STAGING_ROOT="$STAGING_ROOT" \
  "$PACKAGE_STAGE" "$@"
}

section "Prepare test handoffs"
mkdir -p "$HANDOFFS_DIR"

# Handoff 1: Embroidery with .dst assets (barudan-ready)
cat >"$HANDOFFS_DIR/production_handoff_ORD-30001--REV-1.yaml" <<YAML
production_handoff_id: ORD-30001--REV-1
handoff_state: ready_for_staging
created_at: "2026-03-10T12:00:00Z"
order_id: ORD-30001
order_revision_id: REV-1
target_classes: [barudan, embroidery]
production_asset_refs:
  - artwork-intake/jobs/30001/production/embroidery/logo.dst
  - artwork-intake/jobs/30001/production/embroidery/back.dst
line_items:
  - order_line_id: LINE-1
    decoration_method: embroidery
    quantity: 50
    production_asset_refs:
      - artwork-intake/jobs/30001/production/embroidery/logo.dst
  - order_line_id: LINE-2
    decoration_method: embroidery
    quantity: 25
    production_asset_refs:
      - artwork-intake/jobs/30001/production/embroidery/back.dst
YAML

# Handoff 2: Screen print with .eps assets (screenpro-ready)
cat >"$HANDOFFS_DIR/production_handoff_ORD-30002--REV-1.yaml" <<YAML
production_handoff_id: ORD-30002--REV-1
handoff_state: ready_for_staging
created_at: "2026-03-10T12:05:00Z"
order_id: ORD-30002
order_revision_id: REV-1
target_classes: [screen_print_press, screenpro]
production_asset_refs:
  - artwork-intake/jobs/30002/production/screen/design.eps
line_items:
  - order_line_id: LINE-1
    decoration_method: screen_print
    quantity: 100
    production_asset_refs:
      - artwork-intake/jobs/30002/production/screen/design.eps
YAML

# Handoff 3: Embroidery with no .dst assets (blocked)
cat >"$HANDOFFS_DIR/production_handoff_ORD-30003--REV-1.yaml" <<YAML
production_handoff_id: ORD-30003--REV-1
handoff_state: ready_for_staging
created_at: "2026-03-10T12:10:00Z"
order_id: ORD-30003
order_revision_id: REV-1
target_classes: [barudan, embroidery]
production_asset_refs:
  - artwork-intake/jobs/30003/proofs/mockup.jpg
line_items:
  - order_line_id: LINE-1
    decoration_method: embroidery
    quantity: 12
    production_asset_refs:
      - artwork-intake/jobs/30003/proofs/mockup.jpg
YAML

section "Stage barudan package from embroidery handoff"
barudan_output="$(run_stage ORD-30001--REV-1 --target barudan)"
[[ "$(yq '.package_state' <<<"$barudan_output")" == "staged" ]] || fail "barudan package must be staged"
[[ "$(yq '.machine_target' <<<"$barudan_output")" == "barudan" ]] || fail "barudan package must have correct target"
[[ "$(yq '.source_asset_count' <<<"$barudan_output")" == "2" ]] || fail "barudan package must have 2 assets"
barudan_package_id="$(yq '.production_package_id' <<<"$barudan_output")"
[[ "$barudan_package_id" == "ORD-30001--REV-1--barudan" ]] || fail "barudan package ID must match handoff + target"
barudan_manifest="$STAGING_ROOT/$barudan_package_id/manifest.yaml"
[[ -f "$barudan_manifest" ]] || fail "barudan manifest must exist"
barudan_file_count="$(yq '.source_asset_refs | length' "$barudan_manifest")"
[[ "$barudan_file_count" == "2" ]] || fail "barudan manifest must reference 2 files (found $barudan_file_count)"
pass "barudan package staged successfully with 2 .dst assets"

section "Stage screenpro package from screen-print handoff"
screenpro_output="$(run_stage ORD-30002--REV-1 --target screenpro)"
[[ "$(yq '.package_state' <<<"$screenpro_output")" == "staged" ]] || fail "screenpro package must be staged"
[[ "$(yq '.machine_target' <<<"$screenpro_output")" == "screenpro" ]] || fail "screenpro package must have correct target"
[[ "$(yq '.source_asset_count' <<<"$screenpro_output")" == "1" ]] || fail "screenpro package must have 1 asset"
screenpro_package_id="$(yq '.production_package_id' <<<"$screenpro_output")"
[[ "$screenpro_package_id" == "ORD-30002--REV-1--screenpro" ]] || fail "screenpro package ID must match handoff + target"
screenpro_manifest="$STAGING_ROOT/$screenpro_package_id/manifest.yaml"
[[ -f "$screenpro_manifest" ]] || fail "screenpro manifest must exist"
screenpro_file_count="$(yq '.source_asset_refs | length' "$screenpro_manifest")"
[[ "$screenpro_file_count" == "1" ]] || fail "screenpro manifest must reference 1 file (found $screenpro_file_count)"
pass "screenpro package staged successfully with 1 .eps asset"

section "Block barudan package when handoff has no .dst assets"
blocked_output="$(run_stage ORD-30003--REV-1 --target barudan 2>/dev/null || true)"
[[ "$(yq '.package_state' <<<"$blocked_output")" == "blocked" ]] || fail "barudan package must be blocked (output: $blocked_output)"
[[ "$(yq '.blocking_reasons | length' <<<"$blocked_output")" -gt "0" ]] || fail "blocked package must have blocking reasons"
[[ "$(yq '.source_asset_count' <<<"$blocked_output")" == "0" ]] || fail "blocked package must have 0 assets"
blocked_package_file="$PACKAGES_DIR/production_package_ORD-30003--REV-1--barudan.yaml"
[[ -f "$blocked_package_file" ]] || fail "blocked package record must exist"
[[ "$(yq '.package_state' "$blocked_package_file")" == "blocked" ]] || fail "blocked package record must show blocked state"
pass "barudan package blocked honestly when handoff has no .dst assets"

section "Rerun barudan staging is idempotent"
rerun_output="$(run_stage ORD-30001--REV-1 --target barudan 2>&1)"
grep -Fq "package_state: existing_staged" <<<"$rerun_output" || fail "rerun must report existing_staged"
[[ "$(yq '.production_package_id' <<<"$rerun_output")" == "$barudan_package_id" ]] || fail "rerun must reuse same package ID"
pass "barudan package staging is idempotent on rerun"

section "Auto-infer barudan target from embroidery handoff"
inferred_output="$(run_stage ORD-30001--REV-1 2>&1)"
grep -Fq "package_state: existing_staged" <<<"$inferred_output" || fail "inferred target must reuse existing staged package"
[[ "$(yq '.machine_target' <<<"$inferred_output")" == "barudan" ]] || fail "inferred target must be barudan"
pass "target inference works for embroidery handoffs"

section "Summary"
echo "Production package staging checks passed"
