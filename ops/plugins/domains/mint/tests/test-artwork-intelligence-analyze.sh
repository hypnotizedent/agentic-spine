#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"
ANALYZE="$REPO_ROOT/ops/plugins/domains/mint/bin/artwork-intelligence-analyze"
SNAPSHOT="$REPO_ROOT/ops/plugins/domains/mint/bin/artwork-intelligence-snapshot"
ARTIFACT_CAPTURE="$REPO_ROOT/ops/plugins/domains/mint/bin/artifact-record-capture"
ARTIFACT_SNAPSHOT="$REPO_ROOT/ops/plugins/domains/mint/bin/artifact-record-snapshot"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$ANALYZE" ]] || fail "missing artwork-intelligence-analyze executable"
[[ -x "$SNAPSHOT" ]] || fail "missing artwork-intelligence-snapshot executable"
[[ -x "$ARTIFACT_CAPTURE" ]] || fail "missing artifact-record-capture executable"
[[ -x "$ARTIFACT_SNAPSHOT" ]] || fail "missing artifact-record-snapshot executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

runtime_root="$tmp/mint-runtime"
test_spine_root="$tmp/spine"
state_root="$tmp/state"
artifacts_dir="$runtime_root/artifacts"
artifacts_index="$runtime_root/artifacts-index.yaml"
families_dir="$runtime_root/artwork-families"
families_index="$runtime_root/artwork-families-index.yaml"
analyses_dir="$runtime_root/artwork-intelligence"
analyses_index="$runtime_root/artwork-intelligence-index.yaml"
request_file="$tmp/cove-request.json"

mkdir -p "$test_spine_root/bin" "$state_root" "$artifacts_dir" "$families_dir" "$analyses_dir"

cat >"$request_file" <<'JSON'
{
  "case_label": "Cove Brewery artwork intelligence",
  "seed_id": "seed-cove-001",
  "customer_email": "marketing@covebrewery.com",
  "customer_name": "Cove Brewery",
  "thread_id": "CONV-COVE-20260313",
  "source_message_id": "MSG-COVE-ART",
  "line_items": [
    {
      "line_item_id": "cove-dolphin-tee",
      "description": "Dolphin Shirt",
      "product_type": "shirt",
      "style_code": "BC3001",
      "color": "Vintage White",
      "decoration_method": "screen_print",
      "requested_bindings": [
        {
          "location": "left chest",
          "family_hint": "Cove Brewery Logo",
          "variant_hint": "Cove Brewery Logo",
          "artifact_family_key": "cove-brewery-logo",
          "requested_size": {"width_in": 4, "height_in": 4},
          "current_color_truth": {
            "garment_color": "Vintage White",
            "ink_colors": ["Navy"],
            "pms_refs": ["PMS 295"]
          }
        },
        {
          "location": "full back",
          "family_hint": "Beer Pint Dolphins",
          "variant_hint": "Beer Pint Dolphins Back Graphic",
          "artifact_family_key": "beer-pint-dolphins-back",
          "requested_size": {"width_in": 11, "height_in": 12},
          "current_color_truth": {
            "garment_color": "Vintage White",
            "ink_colors": ["Blue", "Orange", "White"],
            "pms_refs": ["PMS 300", "PMS 151"]
          }
        }
      ]
    },
    {
      "line_item_id": "cove-hoodie",
      "description": "Cove Hoodie",
      "product_type": "hoodie",
      "style_code": "PC78",
      "color": "Charcoal",
      "decoration_method": "screen_print",
      "requested_bindings": [
        {
          "location": "left chest",
          "family_hint": "Cove Brewery Logo",
          "variant_hint": "Cove Brewery Logo",
          "artifact_family_key": "cove-brewery-logo",
          "requested_size": {"width_in": 4, "height_in": 4},
          "current_color_truth": {
            "garment_color": "Charcoal",
            "ink_colors": ["White"]
          }
        }
      ]
    },
    {
      "line_item_id": "cove-natural-tee",
      "description": "Cove Natural Tee",
      "product_type": "shirt",
      "style_code": "BC3001",
      "color": "Natural",
      "decoration_method": "screen_print",
      "requested_bindings": [
        {
          "location": "left chest",
          "family_hint": "Cove Brewery Logo",
          "variant_hint": "Cove Brewery Logo",
          "artifact_family_key": "cove-brewery-logo",
          "requested_size": {"width_in": 3.5, "height_in": 3.5},
          "current_color_truth": {
            "garment_color": "Natural"
          }
        }
      ]
    },
    {
      "line_item_id": "cove-reel-beer-ls",
      "description": "Reel Beer Long Sleeve",
      "product_type": "long sleeve",
      "style_code": "A4N3165",
      "color": "Pastel Mint",
      "decoration_method": "screen_print",
      "requested_bindings": [
        {
          "location": "full back",
          "family_hint": "Reel Beer",
          "variant_hint": "Reel Beer Deerfield Beach FL Back Graphic",
          "artifact_family_key": "reel-beer-back",
          "requested_size": {"width_in": 11, "height_in": 12},
          "current_color_truth": {
            "garment_color": "Pastel Mint",
            "mockup_color_note": "New mockup makes the blues look darker than prior production.",
            "mockup_implies_change": true
          }
        }
      ]
    },
    {
      "line_item_id": "cove-sleeve-variant",
      "description": "Cove Sleeve Variant",
      "product_type": "shirt",
      "style_code": "BC3001",
      "color": "Vintage White",
      "decoration_method": "screen_print",
      "requested_bindings": [
        {
          "location": "left sleeve",
          "family_hint": "Cove Brewery Logo",
          "variant_hint": "Cove Brewery Sleeve Logo Variant",
          "artifact_family_key": "cove-brewery-sleeve-variant",
          "requested_size": {"width_in": 2, "height_in": 2},
          "current_color_truth": {
            "garment_color": "Vintage White"
          }
        }
      ]
    },
    {
      "line_item_id": "cove-summerfest",
      "description": "Summerfest Graphic Tee",
      "product_type": "shirt",
      "style_code": "BC3001",
      "color": "Sand",
      "decoration_method": "screen_print",
      "requested_bindings": [
        {
          "location": "full front",
          "family_hint": "Summerfest Pelican Poster",
          "variant_hint": "Summerfest Pelican Poster",
          "artifact_family_key": "summerfest-pelican-poster",
          "requested_size": {"width_in": 11, "height_in": 14},
          "current_color_truth": {
            "garment_color": "Sand"
          }
        }
      ]
    },
    {
      "line_item_id": "cove-ambiguous",
      "description": "Mystery Placement",
      "product_type": "",
      "style_code": "",
      "color": "",
      "decoration_method": "screen_print",
      "requested_bindings": [
        {
          "location": "left chest",
          "family_hint": "",
          "variant_hint": "",
          "artifact_family_key": "",
          "current_color_truth": {}
        }
      ]
    }
  ]
}
JSON

cat >"$test_spine_root/bin/ops" <<EOF
#!/usr/bin/env bash
set -euo pipefail

capability="\${3:-}"
shift 3 || true
if [[ "\${1:-}" == "--" ]]; then
  shift
fi

echo "Receipt: /tmp/\${capability}.receipt.md"

case "\$capability" in
  mint.customer.record.snapshot)
    cat <<'JSON'
{"fresh_slate":{"customer":{"record_id":"cust-cove","name":"Cove Brewery","email":"marketing@covebrewery.com","company":"Cove Brewery"}},"legacy_hold":{"latest_order":{"invoice_number":"13716","nickname":"Cove Brewery Winter Merch","created_at":"2026-01-07T23:05:25Z"},"latest_order_imprints":[{"imprint_id":"1","location":"Left Chest","width":"4","height":"4","decoration_type":"screen_print","description":"Cove Brewery Logo","colors_count":1},{"imprint_id":"2","location":"Full Back","width":"11","height":"12","decoration_type":"screen_print","description":"Beer Pint Dolphins Back Graphic","colors_count":3},{"imprint_id":"3","location":"Full Back","width":"11","height":"12","decoration_type":"screen_print","description":"Reel Beer Deerfield Beach FL Back Graphic","colors_count":2}]}}
JSON
    ;;
  mint.artifact.record.snapshot)
    MINT_RUNTIME_ROOT="$runtime_root" \
    MINT_ARTIFACT_DIR="$artifacts_dir" \
    MINT_ARTIFACT_INDEX_FILE="$artifacts_index" \
    "$ARTIFACT_SNAPSHOT" "\$@"
    ;;
  *)
    echo "unsupported capability: \$capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$test_spine_root/bin/ops"

export SPINE_ROOT="$test_spine_root"
export SPINE_STATE="$state_root"
export MINT_RUNTIME_ROOT="$runtime_root"
export MINT_ARTIFACT_DIR="$artifacts_dir"
export MINT_ARTIFACT_INDEX_FILE="$artifacts_index"
export MINT_ARTWORK_FAMILIES_DIR="$families_dir"
export MINT_ARTWORK_FAMILIES_INDEX_FILE="$families_index"
export MINT_ARTWORK_INTELLIGENCE_DIR="$analyses_dir"
export MINT_ARTWORK_INTELLIGENCE_INDEX_FILE="$analyses_index"

cat >"$tmp/cove-logo.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="4in" height="4in" viewBox="0 0 400 400">
  <path d="M40 200 L200 40 L360 200 L200 360 Z" fill="#123456"/>
</svg>
SVG
printf 'back' >"$tmp/beer-pint.ai"
printf 'reel' >"$tmp/reel-beer.ai"

"$ARTIFACT_CAPTURE" \
  --seed-id seed-cove-001 \
  --customer-email marketing@covebrewery.com \
  --customer-name "Cove Brewery" \
  --original-filename "cove-brewery-logo.svg" \
  --artifact-role print_ready \
  --canonical-object-key "mint/cove/print-ready/cove-brewery-logo.svg" \
  --canonical-object-path "$tmp/cove-logo.svg" \
  "$tmp/cove-logo.svg" \
  --json >/dev/null

"$ARTIFACT_CAPTURE" \
  --seed-id seed-cove-001 \
  --customer-email marketing@covebrewery.com \
  --customer-name "Cove Brewery" \
  --original-filename "beer-pint-dolphins-back.ai" \
  --artifact-role print_ready \
  --canonical-object-key "mint/cove/print-ready/beer-pint-dolphins-back.ai" \
  --canonical-object-path "$tmp/beer-pint.ai" \
  "$tmp/beer-pint.ai" \
  --json >/dev/null

"$ARTIFACT_CAPTURE" \
  --seed-id seed-cove-001 \
  --customer-email marketing@covebrewery.com \
  --customer-name "Cove Brewery" \
  --original-filename "reel-beer-back.ai" \
  --artifact-role print_ready \
  --canonical-object-key "mint/cove/print-ready/reel-beer-back.ai" \
  --canonical-object-path "$tmp/reel-beer.ai" \
  "$tmp/reel-beer.ai" \
  --json >/dev/null

python3 - "$families_dir" <<'PY'
import json
import sys
from pathlib import Path

import yaml

repo_root = Path("/Users/ronnyworks/code/agentic-spine")
sys.path.insert(0, str(repo_root / "ops/plugins/domains/mint/lib"))
from artwork_intelligence_common import artwork_family_id  # noqa: E402

families_dir = Path(sys.argv[1])
families_dir.mkdir(parents=True, exist_ok=True)
customer = {
    "customer_id": "cust-cove",
    "customer_email": "marketing@covebrewery.com",
    "customer_name": "Cove Brewery",
}

records = [
    {
        "family_key": "covebrewerylogo",
        "family_label": "Cove Brewery Logo",
        "variants": [
            {
                "variant_key": "covebrewerylogo",
                "variant_label": "Cove Brewery Logo",
                "variant_status": "active",
                "artifact_ids": [],
                "artifact_refs": [],
                "provenance": ["print_ready", "active"],
            }
        ],
        "historical_imprint_truth": [
            {
                "family_key": "covebrewerylogo",
                "variant_key": "covebrewerylogo",
                "location": "left_chest",
                "decoration_method": "screen_print",
                "blank_style_code": "BC3001",
                "garment_family": "t_shirt",
                "garment_color": "Vintage White",
                "size": {"width_in": 4, "height_in": 4},
                "color_truth": {
                    "ink_colors": ["Navy"],
                    "thread_colors": [],
                    "pms_refs": ["PMS 295"],
                    "thread_refs": [],
                    "garment_color": "Vintage White",
                    "source_kind": "historical_production"
                },
                "order_ref": "13716",
                "source_kind": "historical_production",
                "confidence": "high"
            }
        ]
    },
    {
        "family_key": "beerpintdolphins",
        "family_label": "Beer Pint Dolphins",
        "variants": [
            {
                "variant_key": "beerpintdolphinsbackgraphic",
                "variant_label": "Beer Pint Dolphins Back Graphic",
                "variant_status": "active",
                "artifact_ids": [],
                "artifact_refs": [],
                "provenance": ["print_ready", "active"],
            }
        ],
        "historical_imprint_truth": [
            {
                "family_key": "beerpintdolphins",
                "variant_key": "beerpintdolphinsbackgraphic",
                "location": "full_back",
                "decoration_method": "screen_print",
                "blank_style_code": "BC3001",
                "garment_family": "t_shirt",
                "garment_color": "Vintage White",
                "size": {"width_in": 11, "height_in": 12},
                "color_truth": {
                    "ink_colors": ["Blue", "Orange", "White"],
                    "thread_colors": [],
                    "pms_refs": ["PMS 300", "PMS 151"],
                    "thread_refs": [],
                    "garment_color": "Vintage White",
                    "source_kind": "historical_production"
                },
                "order_ref": "13716",
                "source_kind": "historical_production",
                "confidence": "high"
            }
        ]
    },
    {
        "family_key": "reelbeer",
        "family_label": "Reel Beer",
        "variants": [
            {
                "variant_key": "reelbeerdeerfieldbeachflbackgraphic",
                "variant_label": "Reel Beer Deerfield Beach FL Back Graphic",
                "variant_status": "active",
                "artifact_ids": [],
                "artifact_refs": [],
                "provenance": ["print_ready", "active"],
            }
        ],
        "historical_imprint_truth": [
            {
                "family_key": "reelbeer",
                "variant_key": "reelbeerdeerfieldbeachflbackgraphic",
                "location": "full_back",
                "decoration_method": "screen_print",
                "blank_style_code": "A4N3165",
                "garment_family": "long_sleeve",
                "garment_color": "Seafoam",
                "size": {"width_in": 11, "height_in": 12},
                "color_truth": {
                    "ink_colors": ["Navy", "White"],
                    "thread_colors": [],
                    "pms_refs": ["PMS 295"],
                    "thread_refs": [],
                    "garment_color": "Seafoam",
                    "source_kind": "historical_production"
                },
                "order_ref": "13716",
                "source_kind": "historical_production",
                "confidence": "high"
            }
        ]
    }
]

for payload in records:
    family_id = artwork_family_id(customer, payload["family_key"])
    record = {
        "family_id": family_id,
        "schema_version": "1.0",
        "customer_binding": customer,
        "family_key": payload["family_key"],
        "family_label": payload["family_label"],
        "family_status": "active",
        "seed_refs": ["seed-cove-001"],
        "job_refs": [],
        "order_refs": ["13716"],
        "variants": payload["variants"],
        "historical_imprint_truth": payload["historical_imprint_truth"],
        "analysis_refs": [],
        "receipts": {},
        "evidence_refs": {},
        "created_at": "2026-03-12T10:00:00Z",
        "updated_at": "2026-03-12T10:00:00Z",
    }
    path = families_dir / f"artwork_family_{family_id}.yaml"
    with path.open("w", encoding="utf-8") as fh:
        yaml.safe_dump(record, fh, sort_keys=False)
PY

cat >"$families_index" <<'YAML'
artwork_families: []
YAML

analysis_json="$("$ANALYZE" --request-file "$request_file" --json)"

analysis_id="$(echo "$analysis_json" | jq -r '.analysis_id')"
[[ -n "$analysis_id" && "$analysis_id" != "null" ]] || fail "analysis id should be present"
[[ -f "$analyses_dir/artwork_intelligence_${analysis_id}.yaml" ]] || fail "analysis record should be written"

relationship_state() {
  local line_id="$1"
  echo "$analysis_json" | jq -r --arg line_id "$line_id" '.data.line_items[] | select(.line_item_id==$line_id) | .requested_bindings[0].relationship_classification'
}

color_state() {
  local line_id="$1"
  echo "$analysis_json" | jq -r --arg line_id "$line_id" '.data.line_items[] | select(.line_item_id==$line_id) | .requested_bindings[0].color_continuity_state'
}

[[ "$(relationship_state cove-dolphin-tee)" == "exact_reuse" ]] || fail "dolphin tee should exact-reuse historical truth"
[[ "$(echo "$analysis_json" | jq -r '.data.line_items[] | select(.line_item_id=="cove-dolphin-tee") | .requested_bindings[] | select(.location=="full_back") | .relationship_classification')" == "exact_reuse" ]] || fail "dolphin tee back should exact-reuse historical truth"
[[ "$(relationship_state cove-hoodie)" == "prior_art_reuse_with_blank_change" ]] || fail "hoodie logo should classify as blank-change reuse"
[[ "$(relationship_state cove-natural-tee)" == "prior_art_reuse_with_size_change" ]] || fail "natural tee logo should classify as size-change reuse"
[[ "$(relationship_state cove-reel-beer-ls)" == "exact_reuse" ]] || fail "reel beer long sleeve should stay exact-reuse for artwork identity"
[[ "$(relationship_state cove-sleeve-variant)" == "prior_art_variant_existing_asset" ]] || fail "sleeve logo should classify as prior_art_variant_existing_asset"
[[ "$(relationship_state cove-summerfest)" == "new_graphic" ]] || fail "summerfest should classify as new graphic"
[[ "$(relationship_state cove-ambiguous)" == "ambiguous_needs_operator_review" ]] || fail "ambiguous case should remain operator review"

[[ "$(color_state cove-dolphin-tee)" == "exact_match" ]] || fail "dolphin tee should keep exact color continuity"
[[ "$(color_state cove-hoodie)" == "changed_from_prior" ]] || fail "hoodie should detect changed imprint color"
[[ "$(color_state cove-natural-tee)" == "likely_match_needs_confirmation" ]] || fail "natural tee should require confirmation on changed garment"
[[ "$(color_state cove-reel-beer-ls)" == "ambiguous_mockup_only" ]] || fail "reel beer should detect ambiguous mockup-only color change"
[[ "$(color_state cove-summerfest)" == "unknown" ]] || fail "new graphic should have unknown color truth"
[[ "$(echo "$analysis_json" | jq -r '.data.line_items[] | select(.line_item_id=="cove-dolphin-tee") | .requested_bindings[] | select(.location=="left_chest") | .artwork_preflight.owner')" == "Artie" ]] || fail "artwork intelligence should surface Artie-owned preflight truth on matched bindings"
[[ "$(echo "$analysis_json" | jq -r '.data.line_items[] | select(.line_item_id=="cove-dolphin-tee") | .requested_bindings[] | select(.location=="left_chest") | .artwork_preflight.recommended_print_method')" == "screen_print" ]] || fail "clean vector artwork should recommend screen print in artwork intelligence"
[[ "$(echo "$analysis_json" | jq -r '.data.line_items[] | select(.line_item_id=="cove-dolphin-tee") | .requested_bindings[] | select(.location=="left_chest") | .prepress_review_required')" == "false" ]] || fail "clean vector artwork should not force prepress review on exact reuse"
[[ "$(echo "$analysis_json" | jq -r '.data.receipts.artwork_preflight_record_files | length')" -ge 1 ]] || fail "analysis should persist governed artwork preflight records for matched artifacts"

[[ "$(echo "$analysis_json" | jq -r '.data.summary.relationship_counts.exact_reuse')" == "3" ]] || fail "summary should count three exact reuse bindings"
[[ "$(echo "$analysis_json" | jq -r '.data.summary.relationship_counts.prior_art_reuse_with_blank_change')" == "1" ]] || fail "summary should count one blank-change binding"
[[ "$(echo "$analysis_json" | jq -r '.data.summary.relationship_counts.prior_art_reuse_with_size_change')" == "1" ]] || fail "summary should count one size-change binding"
[[ "$(echo "$analysis_json" | jq -r '.data.summary.relationship_counts.prior_art_variant_existing_asset')" == "1" ]] || fail "summary should count one variant binding"
[[ "$(echo "$analysis_json" | jq -r '.data.summary.relationship_counts.new_graphic')" == "1" ]] || fail "summary should count one new graphic binding"
[[ "$(echo "$analysis_json" | jq -r '.data.summary.relationship_counts.ambiguous_needs_operator_review')" == "1" ]] || fail "summary should count one ambiguous binding"

snapshot_json="$("$SNAPSHOT" --email marketing@covebrewery.com --json)"
[[ "$(echo "$snapshot_json" | jq -r '.state')" == "analysis_present_review_required" ]] || fail "snapshot should report review-required state"
[[ "$(echo "$snapshot_json" | jq -r '.latest.analysis_id')" == "$analysis_id" ]] || fail "snapshot should surface latest analysis id"
[[ "$(echo "$snapshot_json" | jq -r '.latest.relationship_counts.exact_reuse')" == "3" ]] || fail "snapshot should carry summary counts"

pass "artwork-intelligence-analyze classifies Cove reuse, sizing, and color continuity from governed family truth"
