#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
REVIEW="$ROOT/ops/plugins/domains/mint/bin/artie-revision-review"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$REVIEW" ]] || fail "missing artie-revision-review executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINIO_MOUNT_ROOT="$tmp/minio"
export MINT_DATA_ROOT="$tmp/mint-runtime"
export MINT_ARTIE_REVISION_REVIEW_CONTRACT="$ROOT/ops/bindings/mint.artie.revision.review.contract.yaml"
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE" "$MINIO_MOUNT_ROOT"

cat >"$SPINE_ROOT/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

echo "Receipt: /tmp/${capability}.receipt.md"

case "$capability" in
  mint.artwork.place)
    source_file=""
    artifact_role="proof"
    context=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --context) context="$2"; shift 2 ;;
        --artifact-role) artifact_role="$2"; shift 2 ;;
        --json) shift ;;
        *)
          if [[ -z "$source_file" ]]; then
            source_file="$1"
          fi
          shift
        ;;
      esac
    done
    [[ -n "$source_file" ]] || exit 1
    target_dir="$MINIO_MOUNT_ROOT/artwork-intake/operator-drop/13823 PapaPalooza/2. Proofs"
    mkdir -p "$target_dir"
    target_file="$target_dir/$(basename "$source_file")"
    cp "$source_file" "$target_file"
    cat <<JSON
{"capability":"mint.artwork.place","status":"ok","data":{"placement_id":"MAP-TEST-1","placement_state":"placed","resolved_target_key":"operator-drop/13823 PapaPalooza","resolved_target_path":"$target_dir","resolved_file_path":"$target_file","canonical_object_key":"artwork-intake/operator-drop/13823 PapaPalooza/2. Proofs/$(basename "$source_file")","artifact_role":"$artifact_role","context":"$context","record_file":"/tmp/artwork-place-record.json","index_file":"/tmp/artwork-place-index.ndjson"}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

upstream_file="$tmp/upstream.json"
cat >"$upstream_file" <<'JSON'
{
  "customer_identity": "Papa's Raw Bar",
  "job_identity": "13823",
  "selected_artwork_ref": {
    "resolved_file_path": "/tmp/original/papapalooza.pdf",
    "resolved_target_key": "operator-drop/13823 PapaPalooza",
    "original_filename": "papapalooza.pdf"
  },
  "selected_artwork_preflight": {
    "owner": "Artie",
    "record_file": "/tmp/artwork-preflight-upstream.yaml",
    "summary": "Original production art was already preflighted by Artie."
  }
}
JSON

fail_file="$tmp/papapalooza-1.pdf"
cat >"$fail_file" <<'EOF2'
Serving our community since 1976
EOF2

json_fail="$("$REVIEW" "$fail_file" \
  --customer "Papa's Raw Bar" \
  --job "13823" \
  --context "Troy Ganter Papa's Raw Bar papapalooza" \
  --requested-change "Serving our community since 1976, Lighthouse Point, FL" \
  --upstream-handoff-file "$upstream_file" \
  --json)"

fail_record="$(echo "$json_fail" | jq -r '.record_file')"
sheik_file="$(echo "$json_fail" | jq -r '.sheik_handoff.record_file')"
review_text_file="$(echo "$json_fail" | jq -r '.extraction.text_file')"
review_preflight_record="$(echo "$json_fail" | jq -r '.artwork_preflight.record_file')"

[[ "$(echo "$json_fail" | jq -r '.review_outcome')" == "fail" ]] || fail "review should fail when the location clause is missing"
[[ "$(echo "$json_fail" | jq -r '.exact_miss')" == "Lighthouse Point, FL" ]] || fail "review should surface the exact missing location clause"
[[ "$(echo "$json_fail" | jq -r '.proof_readiness.state')" == "revision_required" ]] || fail "failed review should require another revision"
[[ "$(echo "$json_fail" | jq -r '.morpheus_consumption.should_reason_visually')" == "false" ]] || fail "Morpheus should not own visual reasoning"
[[ "$(echo "$json_fail" | jq -r '.artwork_preflight.owner')" == "Artie" ]] || fail "review should surface Artie-owned preflight truth for the reviewed proof"
[[ "$(echo "$json_fail" | jq -r '.upstream_selected_artwork_preflight.record_file')" == "/tmp/artwork-preflight-upstream.yaml" ]] || fail "review should carry forward the upstream selected artwork preflight record"
[[ -f "$fail_record" ]] || fail "review record should exist"
[[ -f "$sheik_file" ]] || fail "failed review should create a Sheik handoff"
[[ -f "$review_text_file" ]] || fail "review text extraction file should exist"
[[ -f "$review_preflight_record" ]] || fail "reviewed proof preflight record should exist"
[[ "$(jq -r '.handoff_state' "$sheik_file")" == "ready_for_sheik_revision" ]] || fail "Sheik handoff state should be ready_for_sheik_revision"
[[ "$(jq -r '.next_revision_instruction' "$sheik_file")" == *'Lighthouse Point, FL'* ]] || fail "Sheik handoff should carry the exact missing clause"
[[ "$(jq -r '.artwork_preflight.owner' "$sheik_file")" == "Artie" ]] || fail "Sheik handoff should carry the reviewed proof preflight truth"
pass "artie-revision-review fails missing-location proofs into a governed Sheik handoff"

pass_file="$tmp/papapalooza-pass.pdf"
cat >"$pass_file" <<'EOF3'
Serving our community since 1976, Lighthouse Point, FL
EOF3

json_pass="$("$REVIEW" "$pass_file" \
  --customer "Papa's Raw Bar" \
  --job "13823" \
  --context "Troy Ganter Papa's Raw Bar papapalooza" \
  --requested-change "Serving our community since 1976, Lighthouse Point, FL" \
  --json)"

[[ "$(echo "$json_pass" | jq -r '.review_outcome')" == "pass" ]] || fail "review should pass when the full requested text is present"
[[ "$(echo "$json_pass" | jq -r '.proof_readiness.state')" == "ready_for_mockup_prep" ]] || fail "passed review should become proof-ready"
[[ "$(echo "$json_pass" | jq -r '.sheik_handoff')" == "null" ]] || fail "passed review should not create a Sheik handoff"
[[ "$(echo "$json_pass" | jq -r '.artwork_preflight.owner')" == "Artie" ]] || fail "passed review should still surface the governed proof preflight truth"
pass "artie-revision-review marks complete proofs ready for downstream proof prep"
