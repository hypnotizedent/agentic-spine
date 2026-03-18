#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
PREFLIGHT="$ROOT/ops/plugins/domains/mint/bin/artwork-preflight"
ARTIFACT_CAPTURE="$ROOT/ops/plugins/domains/mint/bin/artifact-record-capture"
CONTRACT="$ROOT/ops/bindings/mint.artwork.preflight.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$PREFLIGHT" ]] || fail "missing artwork-preflight executable"
[[ -x "$ARTIFACT_CAPTURE" ]] || fail "missing artifact-record-capture executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$ROOT"
export SPINE_STATE="$tmp/state"
export MINT_DATA_ROOT="$tmp/mint-runtime"
export MINT_RUNTIME_ROOT="$tmp/mint-runtime"
export MINT_ARTWORK_PREFLIGHT_CONTRACT="$CONTRACT"

mkdir -p "$SPINE_STATE" "$MINT_DATA_ROOT"

raster_file="$tmp/full-color-gradient.png"
python3 - "$raster_file" <<'PY'
from PIL import Image
import sys

path = sys.argv[1]
img = Image.new("RGB", (1200, 1200))
pixels = img.load()
for y in range(img.height):
    for x in range(img.width):
        pixels[x, y] = ((x * 255) // img.width, (y * 255) // img.height, ((x + y) * 255) // (img.width + img.height))
img.save(path, format="PNG")
PY

json_raster="$("$PREFLIGHT" "$raster_file" --attachment-name "full-color-gradient.png" --piece-quantity 300 --json)"
raster_record="$(echo "$json_raster" | jq -r '.record_file')"
[[ -f "$raster_record" ]] || fail "raster preflight should persist a governed record"
[[ "$(echo "$json_raster" | jq -r '.data.analysis.file_kind')" == "raster" ]] || fail "raster file should classify as raster"
[[ "$(echo "$json_raster" | jq -r '.data.analysis.recommended_print_method')" == "dtg" ]] || fail "full-color gradient raster should recommend dtg"
[[ "$(echo "$json_raster" | jq -r '.data.analysis.has_gradients')" == "true" ]] || fail "raster preflight should detect gradients"

vector_file="$tmp/clean-vector.svg"
cat >"$vector_file" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="12in" height="12in" viewBox="0 0 1200 1200">
  <rect width="1200" height="1200" fill="#ffffff"/>
  <path d="M120 300 L600 120 L1080 300 L960 960 L240 960 Z" fill="#002d72"/>
  <path d="M350 450 L850 450 L600 840 Z" fill="#f58220"/>
</svg>
EOF

json_artifact="$("$ARTIFACT_CAPTURE" "$vector_file" \
  --seed-id seed-vector-001 \
  --customer-email vector@example.com \
  --customer-name "Vector Test" \
  --canonical-object-key "mint/vector/clean-vector.svg" \
  --canonical-object-path "$vector_file" \
  --original-filename "clean-vector.svg" \
  --artifact-role print_ready \
  --json)"
artifact_id="$(echo "$json_artifact" | jq -r '.artifact_id')"

json_vector="$("$PREFLIGHT" --artifact-id "$artifact_id" --piece-quantity 144 --json)"
vector_record="$(echo "$json_vector" | jq -r '.record_file')"
[[ -f "$vector_record" ]] || fail "artifact-backed vector preflight should persist a governed record"
[[ "$(echo "$json_vector" | jq -r '.data.source_ref.artifact_id')" == "$artifact_id" ]] || fail "artifact-backed preflight should preserve artifact identity"
[[ "$(echo "$json_vector" | jq -r '.data.analysis.file_kind')" == "vector" ]] || fail "svg should classify as vector"
[[ "$(echo "$json_vector" | jq -r '.data.analysis.recommended_print_method')" == "screen_print" ]] || fail "clean vector art at quantity should recommend screen_print"
[[ "$(echo "$json_vector" | jq -r '.data.analysis.review_required')" == "false" ]] || fail "clean vector art should not force review"
[[ "$(echo "$json_vector" | jq -r '.data.analysis.print_ready_candidate')" == "true" ]] || fail "clean vector art should be print-ready candidate"

eps_file="$tmp/review-needed.eps"
cat >"$eps_file" <<'EOF'
%!PS-Adobe-3.0 EPSF-3.0
%%BoundingBox: 0 0 720 144
%%DocumentCustomColors: (PANTONE 295 C)
%%CMYKCustomColor: 1 0.57 0 0.4 (PANTONE 295 C)
/Helvetica findfont 24 scalefont setfont
10 30 moveto (Sample Text) show
newpath
10 10 moveto
710 10 lineto
710 134 lineto
10 134 lineto
closepath
fill
EOF

json_eps="$("$PREFLIGHT" "$eps_file" --piece-quantity 72 --json)"
[[ "$(echo "$json_eps" | jq -r '.data.analysis.file_kind')" == "vector" ]] || fail "eps should classify as vector"
[[ "$(echo "$json_eps" | jq -r '.data.analysis.prepress_signals.spot_color_refs[0]')" == *"PANTONE 295 C"* ]] || fail "eps preflight should detect spot-color refs"
[[ "$(echo "$json_eps" | jq -r '.data.analysis.review_required')" == "true" ]] || fail "live text in eps should force review"
[[ "$(echo "$json_eps" | jq -r '.data.analysis.readiness_state')" == "vector_review_required" ]] || fail "eps with live text should stay review_required"

pass "artwork-preflight records raster recommendations, clean vector screen-print truth, and review-required vector prepress blockers"
