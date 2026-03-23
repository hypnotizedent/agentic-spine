#!/usr/bin/env bash
# test-runtime-root-canonicalization.sh - Prove mint runtime surfaces honor canonical domain-state resolution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_SHOW="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-show"
QUOTE_RENDER="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-render"
PACKAGE_SHOW="$SPINE_ROOT/ops/plugins/domains/mint/bin/production-package-show"
PACKAGE_EXPORT="$SPINE_ROOT/ops/plugins/domains/mint/bin/production-package-export"
RENDER_FIXTURES="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-render"
TMP_ROOT="$(mktemp -d)"
DOMAIN_STATE="$TMP_ROOT/domain-state"
MINT_ROOT="$DOMAIN_STATE/mint"
PACKETS_DIR="$MINT_ROOT/quote-packets"
PACKAGES_DIR="$MINT_ROOT/production-packages"
EXPORTS_DIR="$MINT_ROOT/production-package-exports"
EXPORT_BUNDLES_ROOT="$EXPORTS_DIR/bundles"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR" "$PACKAGES_DIR"

section "Quote surfaces resolve from SPINE_DOMAIN_STATE"
packet_file="$PACKETS_DIR/quote_packet_runtime-root-ready.yaml"
cp "$RENDER_FIXTURES/ready-warning-shipping.packet.yaml" "$packet_file"
yq -i '.quote_packet_id = "runtime-root-ready"' "$packet_file"

show_output="$(
  SPINE_DOMAIN_STATE="$DOMAIN_STATE" \
  "$QUOTE_SHOW" runtime-root-ready
)"
grep -Fq "quote_packet:" <<<"$show_output" || fail "quote-show must read packets from canonical domain-state"
grep -Fq "runtime-root-ready" <<<"$show_output" || fail "quote-show must return the canonical packet id"

render_output="$(
  SPINE_DOMAIN_STATE="$DOMAIN_STATE" \
  "$QUOTE_RENDER" runtime-root-ready
)"
[[ "$(yq '.state' "$packet_file")" == "ready_for_review" ]] || fail "quote-render must mutate the canonical packet file"
grep -Fq "packet_file: $packet_file" <<<"$render_output" || fail "quote-render must report the canonical packet path"
pass "quote-show and quote-render resolve mint quote state from SPINE_DOMAIN_STATE"

section "Production package surfaces resolve from SPINE_DOMAIN_STATE"
package_id="ORD-40001--REV-1--barudan"
package_file="$PACKAGES_DIR/production_package_${package_id}.yaml"
cat >"$package_file" <<'YAML'
production_package_id: ORD-40001--REV-1--barudan
production_handoff_id: ORD-40001--REV-1
order_id: ORD-40001
order_revision_id: REV-1
package_state: staged
target_class: embroidery
machine_target: barudan
source_asset_refs:
  - artwork-intake/jobs/40001/production/embroidery/logo.dst
staged_bundle_path: runtime/domain-state/mint/production-packages/staged-bundles/ORD-40001--REV-1--barudan
manifest_path: runtime/domain-state/mint/production-packages/staged-bundles/ORD-40001--REV-1--barudan/manifest.yaml
created_at: "2026-03-23T12:30:00Z"
created_by: mint.production.package.stage
receipt_notes: staged 1 asset for canonical runtime-root proof
YAML

package_show_output="$(
  SPINE_DOMAIN_STATE="$DOMAIN_STATE" \
  "$PACKAGE_SHOW" "$package_id"
)"
[[ "$(yq '.production_package_id' <<<"$package_show_output")" == "$package_id" ]] || fail "package-show must read staged package from canonical domain-state"

package_export_output="$(
  SPINE_DOMAIN_STATE="$DOMAIN_STATE" \
  "$PACKAGE_EXPORT" "$package_id" --mode usb_bundle 2>/dev/null
)"
[[ "$(yq '.export_state' <<<"$package_export_output")" == "exported" ]] || fail "package-export must succeed from canonical domain-state"
export_file="$EXPORTS_DIR/production_export_${package_id}--usb_bundle.yaml"
bundle_path="$(yq '.export_bundle_path' <<<"$package_export_output")"
[[ -f "$export_file" ]] || fail "package-export must persist export record under canonical domain-state"
[[ "$bundle_path" == "$EXPORT_BUNDLES_ROOT/ORD-40001/barudan" ]] || fail "package-export bundle path must resolve under canonical domain-state"
[[ -f "$bundle_path/manifest.yaml" ]] || fail "package-export must write manifest into canonical export bundle path"
pass "package show/export resolve mint production state from SPINE_DOMAIN_STATE"

section "Summary"
echo "Mint runtime-root canonicalization checks passed"
