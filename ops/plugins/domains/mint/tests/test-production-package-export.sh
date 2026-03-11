#!/usr/bin/env bash
# test-production-package-export.sh - Validate governed production package export for barudan and screenpro

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

PACKAGE_EXPORT="$SPINE_ROOT/ops/plugins/domains/mint/bin/production-package-export"
PACKAGE_SHOW="$SPINE_ROOT/ops/plugins/domains/mint/bin/production-package-show"
TMP_ROOT="$(mktemp -d)"
PACKAGES_DIR="$TMP_ROOT/production-packages"
EXPORTS_DIR="$TMP_ROOT/production-package-exports"
EXPORTS_INDEX="$TMP_ROOT/production-package-exports-index.yaml"
EXPORT_BUNDLES_ROOT="$TMP_ROOT/production-package-exports/bundles"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

run_export() {
  MINT_PRODUCTION_PACKAGES_DIR="$PACKAGES_DIR" \
  MINT_PRODUCTION_EXPORTS_DIR="$EXPORTS_DIR" \
  MINT_PRODUCTION_EXPORTS_INDEX_FILE="$EXPORTS_INDEX" \
  MINT_PRODUCTION_EXPORTS_BUNDLES_ROOT="$EXPORT_BUNDLES_ROOT" \
  "$PACKAGE_EXPORT" "$@"
}

run_show() {
  MINT_PRODUCTION_PACKAGES_DIR="$PACKAGES_DIR" \
  MINT_PRODUCTION_EXPORTS_DIR="$EXPORTS_DIR" \
  "$PACKAGE_SHOW" "$@"
}

section "Prepare test staged packages"
mkdir -p "$PACKAGES_DIR"

# Staged package 1: Barudan (embroidery, ready for export)
cat >"$PACKAGES_DIR/production_package_ORD-30001--REV-1--barudan.yaml" <<YAML
production_package_id: ORD-30001--REV-1--barudan
production_handoff_id: ORD-30001--REV-1
order_id: ORD-30001
order_revision_id: REV-1
package_state: staged
target_class: embroidery
machine_target: barudan
source_asset_refs:
  - artwork-intake/jobs/30001/production/embroidery/logo.dst
  - artwork-intake/jobs/30001/production/embroidery/back.dst
staged_bundle_path: runtime/domain-state/mint/production-packages/staged-bundles/ORD-30001--REV-1--barudan
manifest_path: runtime/domain-state/mint/production-packages/staged-bundles/ORD-30001--REV-1--barudan/manifest.yaml
created_at: "2026-03-10T14:00:00Z"
created_by: mint.production.package.stage
receipt_notes: staged 2 assets for 2 line(s)
YAML

# Staged package 2: Screenpro (screen print, ready for export)
cat >"$PACKAGES_DIR/production_package_ORD-30002--REV-1--screenpro.yaml" <<YAML
production_package_id: ORD-30002--REV-1--screenpro
production_handoff_id: ORD-30002--REV-1
order_id: ORD-30002
order_revision_id: REV-1
package_state: staged
target_class: screen_print
machine_target: screenpro
source_asset_refs:
  - artwork-intake/jobs/30002/production/screen/design.eps
staged_bundle_path: runtime/domain-state/mint/production-packages/staged-bundles/ORD-30002--REV-1--screenpro
manifest_path: runtime/domain-state/mint/production-packages/staged-bundles/ORD-30002--REV-1--screenpro/manifest.yaml
created_at: "2026-03-10T14:05:00Z"
created_by: mint.production.package.stage
receipt_notes: staged 1 assets for 1 line(s)
YAML

# Blocked package 3: Barudan (blocked state, not exportable)
cat >"$PACKAGES_DIR/production_package_ORD-30003--REV-1--barudan.yaml" <<YAML
production_package_id: ORD-30003--REV-1--barudan
production_handoff_id: ORD-30003--REV-1
order_id: ORD-30003
order_revision_id: REV-1
package_state: blocked
target_class: embroidery
machine_target: barudan
source_asset_refs: []
staged_bundle_path: null
manifest_path: null
created_at: "2026-03-10T14:10:00Z"
created_by: mint.production.package.stage
receipt_notes: "line LINE-1 (method=embroidery) has no compatible assets"
blocking_reasons:
  - "line LINE-1 (method=embroidery) has no compatible assets (found: jpg; required: dst, u00)"
YAML

section "Export barudan package to USB bundle"
barudan_output="$(run_export ORD-30001--REV-1--barudan --mode usb_bundle 2>/dev/null)"
[[ "$(yq '.export_state' <<<"$barudan_output")" == "exported" ]] || fail "barudan export must succeed"
[[ "$(yq '.machine_target' <<<"$barudan_output")" == "barudan" ]] || fail "barudan export must have correct target"
[[ "$(yq '.export_mode' <<<"$barudan_output")" == "usb_bundle" ]] || fail "barudan export must use usb_bundle mode"
barudan_export_id="$(yq '.production_export_id' <<<"$barudan_output")"
[[ "$barudan_export_id" == "ORD-30001--REV-1--barudan--usb_bundle" ]] || fail "barudan export ID must match package + mode"
barudan_bundle_path="$(yq '.export_bundle_path' <<<"$barudan_output")"
[[ -d "$barudan_bundle_path" ]] || fail "barudan export bundle must exist"
[[ -f "$barudan_bundle_path/manifest.yaml" ]] || fail "barudan export manifest must exist"
[[ -d "$barudan_bundle_path/files" ]] || fail "barudan export files dir must exist"
barudan_file_count="$(yq '.exported_files | length' "$barudan_bundle_path/manifest.yaml")"
[[ "$barudan_file_count" == "2" ]] || fail "barudan export manifest must reference 2 files (found $barudan_file_count)"
pass "barudan package exported successfully to USB bundle with 2 files"

section "Export screenpro package to USB bundle"
screenpro_output="$(run_export ORD-30002--REV-1--screenpro --mode usb_bundle 2>/dev/null)"
[[ "$(yq '.export_state' <<<"$screenpro_output")" == "exported" ]] || fail "screenpro export must succeed"
[[ "$(yq '.machine_target' <<<"$screenpro_output")" == "screenpro" ]] || fail "screenpro export must have correct target"
screenpro_export_id="$(yq '.production_export_id' <<<"$screenpro_output")"
[[ "$screenpro_export_id" == "ORD-30002--REV-1--screenpro--usb_bundle" ]] || fail "screenpro export ID must match package + mode"
screenpro_bundle_path="$(yq '.export_bundle_path' <<<"$screenpro_output")"
[[ -f "$screenpro_bundle_path/manifest.yaml" ]] || fail "screenpro export manifest must exist"
screenpro_file_count="$(yq '.exported_files | length' "$screenpro_bundle_path/manifest.yaml")"
[[ "$screenpro_file_count" == "1" ]] || fail "screenpro export manifest must reference 1 file (found $screenpro_file_count)"
pass "screenpro package exported successfully to USB bundle with 1 file"

section "Block export when package is not staged"
blocked_output="$(run_export ORD-30003--REV-1--barudan --mode usb_bundle 2>&1 || true)"
grep -Fq "package is not exportable" <<<"$blocked_output" || fail "blocked package must reject export with clear message"
pass "export blocked honestly when package state is not staged"

section "Rerun barudan export is idempotent"
rerun_output="$(run_export ORD-30001--REV-1--barudan --mode usb_bundle 2>&1)"
grep -Fq "export_state: existing_exported" <<<"$rerun_output" || fail "rerun must report existing_exported"
[[ "$(yq '.production_export_id' <<<"$rerun_output")" == "$barudan_export_id" ]] || fail "rerun must reuse same export ID"
pass "barudan package export is idempotent on rerun"

section "Show staged package metadata"
show_output="$(run_show ORD-30001--REV-1--barudan 2>/dev/null)"
[[ "$(yq '.production_package_id' <<<"$show_output")" == "ORD-30001--REV-1--barudan" ]] || fail "show must return correct package ID"
[[ "$(yq '.package_state' <<<"$show_output")" == "staged" ]] || fail "show must return package state"
[[ "$(yq '.source_asset_refs | length' <<<"$show_output")" == "2" ]] || fail "show must return source assets"
pass "package show returns correct metadata"

section "Show with export history"
show_exports_output="$(run_show ORD-30001--REV-1--barudan --exports 2>/dev/null)"
[[ "$(yq '.export_history | length' <<<"$show_exports_output")" -gt "0" ]] || fail "show --exports must include export history"
[[ "$(yq '.export_history[0].export_state' <<<"$show_exports_output")" == "exported" ]] || fail "export history must show exported state"
pass "package show with --exports includes export history"

section "Summary"
echo "Production package export checks passed"
