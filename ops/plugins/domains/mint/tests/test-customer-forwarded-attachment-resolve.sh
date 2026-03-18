#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
RESOLVE="$ROOT/ops/plugins/domains/mint/bin/customer-forwarded-attachment-resolve"
ARTIFACT_CAPTURE_BIN="$ROOT/ops/plugins/domains/mint/bin/artifact-record-capture"
ARTIFACT_SNAPSHOT_BIN="$ROOT/ops/plugins/domains/mint/bin/artifact-record-snapshot"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$RESOLVE" ]] || fail "missing customer-forwarded-attachment-resolve executable"
[[ -x "$ARTIFACT_CAPTURE_BIN" ]] || fail "missing artifact-record-capture executable"
[[ -x "$ARTIFACT_SNAPSHOT_BIN" ]] || fail "missing artifact-record-snapshot executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINIO_MOUNT_ROOT="$tmp/minio"
export MINT_RUNTIME_ROOT="$tmp/runtime/domain-state/mint"
export ARTIFACT_CAPTURE_BIN
export ARTIFACT_SNAPSHOT_BIN
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE" "$MINIO_MOUNT_ROOT/artwork-intake/operator-drop/13823 PapaPalooza"

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
  microsoft.mail.get)
    cat <<'JSON'
{"id":"MSG-SOURCE","subject":"FW: Troy / Papa's Raw Bar / papapalooza","receivedDateTime":"2026-03-12T13:20:00Z","bodyPreview":"Use the attached papapalooza.pdf for Troy. Earlier bad versions should be ignored.","body":{"contentType":"Text","content":"Use the attached papapalooza.pdf for Troy. Earlier bad versions should be ignored."},"from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}}}
JSON
    ;;
  microsoft.mail.search)
    cat <<'JSON'
{"value":[{"id":"MSG-OLD","subject":"Sheik older papapalooza proof","receivedDateTime":"2026-03-10T15:00:00Z","from":{"emailAddress":{"address":"sheik@vendor.example","name":"Sheik"}}},{"id":"MSG-BAD","subject":"Sheik bad papapalooza proof","receivedDateTime":"2026-03-11T16:00:00Z","from":{"emailAddress":{"address":"sheik@vendor.example","name":"Sheik"}}}]}
JSON
    ;;
  microsoft.mail.attachments.list)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --top) shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    [[ -n "$message_id" ]] || {
      echo "missing list args" >&2
      exit 1
    }
    case "$message_id" in
      MSG-SOURCE)
        cat <<'JSON'
{"value":[{"id":"ATT-SOURCE","name":"papapalooza.pdf","contentType":"application/pdf","size":11,"lastModifiedDateTime":"2026-03-12T13:10:00Z","isInline":false}]}
JSON
        ;;
      MSG-OLD)
        cat <<'JSON'
{"value":[{"id":"ATT-OLD","name":"papapalooza_old.pdf","contentType":"application/pdf","size":7,"lastModifiedDateTime":"2026-03-10T15:00:00Z","isInline":false}]}
JSON
        ;;
      MSG-BAD)
        cat <<'JSON'
{"value":[{"id":"ATT-BAD","name":"papapalooza_bad.pdf","contentType":"application/pdf","size":7,"lastModifiedDateTime":"2026-03-11T16:00:00Z","isInline":false}]}
JSON
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.attachment.download)
    output_dir=""
    attachment_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --output-dir) output_dir="$2"; shift 2 ;;
        --attachment-id) attachment_id="$2"; shift 2 ;;
        --message-id) shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    [[ -n "$output_dir" && -n "$attachment_id" ]] || {
      echo "missing download args" >&2
      exit 1
    }
    mkdir -p "$output_dir"
    case "$attachment_id" in
      ATT-SOURCE)
        printf 'PDFREVISION' >"$output_dir/papapalooza.pdf"
        cat <<JSON
{"id":"ATT-SOURCE","name":"papapalooza.pdf","contentType":"application/pdf","size":11,"sha256":"$(printf 'PDFREVISION' | shasum -a 256 | awk '{print $1}')","filePath":"$output_dir/papapalooza.pdf","messageId":"MSG-SOURCE"}
JSON
        ;;
      ATT-OLD)
        printf 'OLDPAPA' >"$output_dir/papapalooza_old.pdf"
        cat <<JSON
{"id":"ATT-OLD","name":"papapalooza_old.pdf","contentType":"application/pdf","size":7,"sha256":"$(printf 'OLDPAPA' | shasum -a 256 | awk '{print $1}')","filePath":"$output_dir/papapalooza_old.pdf","messageId":"MSG-OLD"}
JSON
        ;;
      ATT-BAD)
        printf 'BADPAPA' >"$output_dir/papapalooza_bad.pdf"
        cat <<JSON
{"id":"ATT-BAD","name":"papapalooza_bad.pdf","contentType":"application/pdf","size":7,"sha256":"$(printf 'BADPAPA' | shasum -a 256 | awk '{print $1}')","filePath":"$output_dir/papapalooza_bad.pdf","messageId":"MSG-BAD"}
JSON
        ;;
      *)
        echo "unexpected attachment id: $attachment_id" >&2
        exit 1
        ;;
    esac
    ;;
  mint.customer.seed.ensure)
    cat <<'JSON'
{"seed":{"id":"seed-papa-1","source":"email","status":"new","has_line_item":false},"customer_email":"troy@papasrawbar.com","customer_display_name":"Troy","record_file":"/tmp/seed-ensure-record.json"}
JSON
    ;;
  mint.artifact.record.snapshot)
    MINT_RUNTIME_ROOT="$MINT_RUNTIME_ROOT" \
    MINIO_MOUNT_ROOT="$MINIO_MOUNT_ROOT" \
    "$ARTIFACT_SNAPSHOT_BIN" "$@"
    ;;
  mint.artifact.record.capture)
    MINT_RUNTIME_ROOT="$MINT_RUNTIME_ROOT" \
    MINIO_MOUNT_ROOT="$MINIO_MOUNT_ROOT" \
    "$ARTIFACT_CAPTURE_BIN" "$@"
    ;;
  mint.artwork.place)
    file=""
    context=""
    artifact_role="original"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --context) context="$2"; shift 2 ;;
        --artifact-role) artifact_role="$2"; shift 2 ;;
        --json) shift ;;
        *)
          if [[ -z "$file" ]]; then
            file="$1"
          fi
          shift
        ;;
      esac
    done
    [[ -n "$file" ]] || {
      echo "missing placement file" >&2
      exit 1
    }
    case "$artifact_role" in
      proof) role_folder="2. Proofs" ;;
      reference_mockup) role_folder="2. Reference Mockups" ;;
      print_ready) role_folder="3. Print Ready" ;;
      production_asset) role_folder="4. Production Assets" ;;
      superseded) role_folder="_superseded" ;;
      *) role_folder="1. Originals" ;;
    esac
    mkdir -p "$MINIO_MOUNT_ROOT/artwork-intake/operator-drop/13823 PapaPalooza/$role_folder"
    target="$MINIO_MOUNT_ROOT/artwork-intake/operator-drop/13823 PapaPalooza/$role_folder/$(basename "$file")"
    cp "$file" "$target"
    cat <<JSON
{"capability":"mint.artwork.place","data":{"placement_state":"placed","resolved_target_key":"artwork-intake/operator-drop/13823 PapaPalooza","resolved_file_path":"$target","canonical_object_key":"artwork-intake/operator-drop/13823 PapaPalooza/$role_folder/$(basename "$file")","artifact_role":"$artifact_role","context":"$context"}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$RESOLVE" MSG-SOURCE --mailbox team@mintprints.com --context "Troy Papa's Raw Bar papapalooza" --json)"
record_file="$(echo "$json_out" | jq -r '.record_file')"
index_file="$(echo "$json_out" | jq -r '.index_file')"
artifact_id="$(echo "$json_out" | jq -r '.artifact.artifact_id')"
artifact_file="$MINT_RUNTIME_ROOT/artifacts/artifact_${artifact_id}.yaml"
selected_name="$(echo "$json_out" | jq -r '.selected_attachment.attachment_name')"
downloaded_file="$(echo "$json_out" | jq -r '.selected_attachment.downloaded_file')"
resolved_file_path="$(echo "$json_out" | jq -r '.placement.resolved_file_path')"

[[ "$(echo "$json_out" | jq -r '.status')" == "selected" ]] || fail "resolver should select a clear candidate"
[[ "$(echo "$json_out" | jq -r '.seed.id')" == "seed-papa-1" ]] || fail "resolver should anchor to a governed seed"
[[ "$selected_name" == "papapalooza.pdf" ]] || fail "resolver should prefer the visible forwarded attachment"
[[ -f "$downloaded_file" ]] || fail "downloaded attachment should exist"
[[ -f "$resolved_file_path" ]] || fail "placed attachment should exist in canonical target"
[[ -f "$record_file" ]] || fail "resolver record should exist"
[[ -f "$index_file" ]] || fail "resolver index should exist"
[[ -f "$artifact_file" ]] || fail "resolver should create a governed artifact record"
[[ "$(echo "$json_out" | jq -r '.candidate_count')" == "3" ]] || fail "resolver should inspect forwarded plus related candidates"
[[ "$(echo "$json_out" | jq -r '.artifact.artifact_role')" == "original" ]] || fail "resolver should persist artifact role"
[[ "$(yq '.artifact_role' "$artifact_file")" == "original" ]] || fail "artifact record should preserve role"
[[ "$(yq '.seed_id' "$artifact_file")" == "seed-papa-1" ]] || fail "artifact record should bind to the seed"
[[ "$(jq -r '.receipts.source_get_receipt' "$record_file")" == "/tmp/microsoft.mail.get.receipt.md" ]] || fail "record should keep source receipt"
[[ "$(jq -r '.receipts.seed_ensure_receipt' "$record_file")" == "/tmp/mint.customer.seed.ensure.receipt.md" ]] || fail "record should keep seed ensure receipt"
[[ "$(jq -r '.receipts.artifact_capture_receipt' "$record_file")" == "/tmp/mint.artifact.record.capture.receipt.md" ]] || fail "record should keep artifact capture receipt"
[[ "$(jq -r '.receipts.related_search_receipt' "$record_file")" == "/tmp/microsoft.mail.search.receipt.md" ]] || fail "record should keep search receipt"
[[ "$(jq -r '.receipts.attachment_list_receipts["MSG-SOURCE"]' "$record_file")" == "/tmp/microsoft.mail.attachments.list.receipt.md" ]] || fail "record should keep attachment list receipt"
[[ "$(jq -r '.receipts.attachment_download_receipt' "$record_file")" == "/tmp/microsoft.mail.attachment.download.receipt.md" ]] || fail "record should keep attachment download receipt"
[[ "$(jq -r '.receipts.artwork_place_receipt' "$record_file")" == "/tmp/mint.artwork.place.receipt.md" ]] || fail "record should keep placement receipt"
[[ "$(tail -n 1 "$index_file" | jq -r '.selected_attachment_name')" == "papapalooza.pdf" ]] || fail "resolver index should record selected attachment"
pass "customer-forwarded-attachment-resolve records the selected attachment as governed artifact truth"

json_existing="$("$RESOLVE" MSG-SOURCE --mailbox team@mintprints.com --context "Troy Papa's Raw Bar papapalooza" --json)"
[[ "$(echo "$json_existing" | jq -r '.status')" == "existing_artifact" ]] || fail "second resolve should reuse existing artifact truth"
[[ "$(echo "$json_existing" | jq -r '.artifact.artifact_id')" == "$artifact_id" ]] || fail "existing resolve should reuse the same artifact id"
[[ "$(echo "$json_existing" | jq -r '.placement.placement_state')" == "existing_artifact" ]] || fail "existing resolve should not place a duplicate file"
pass "customer-forwarded-attachment-resolve reuses existing artifact truth before mailbox heuristics"
