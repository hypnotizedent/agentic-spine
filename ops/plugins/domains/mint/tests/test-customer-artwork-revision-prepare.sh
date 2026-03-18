#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
PREPARE="$ROOT/ops/plugins/domains/mint/bin/customer-artwork-revision-prepare"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$PREPARE" ]] || fail "missing customer-artwork-revision-prepare executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_DATA_ROOT="$tmp/mint-runtime"
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE"

cat >"$tmp/papapalooza.pdf" <<'EOF_PDF'
Serving our community since 1976, Lighthouse Point, FL
EOF_PDF

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
{"id":"MSG-SOURCE","subject":"FW: Troy / Papa's Raw Bar / papapalooza","receivedDateTime":"2026-03-12T13:20:00Z","bodyPreview":"Need more info before we quote, but use the latest papapalooza revision for the next correction pass.","body":{"contentType":"Text","content":"Need more info before we quote, but use the latest papapalooza revision for the next correction pass."},"from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}}}
JSON
    ;;
  mint.customer.forwarded.attachment.resolve)
    cat <<'JSON'
{"status":"selected","record_file":"/tmp/resolve-record.json","selected_attachment":{"attachment_name":"papapalooza.pdf","downloaded_file":"__TMP__/papapalooza.pdf","sha256":"abc123"},"artifact":{"artifact_id":"artifact-papa-1","artifact_role":"original","artifact_status":"active","original_filename":"papapalooza.pdf","canonical_object_key":"artwork-intake/operator-drop/13823 PapaPalooza/1. Originals/papapalooza.pdf","canonical_object_path":"__TMP__/papapalooza.pdf","sha256":"abc123"},"placement":{"placement_state":"placed","resolved_file_path":"__TMP__/papapalooza.pdf","resolved_target_key":"artwork-intake/operator-drop/13823 PapaPalooza"}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"
python3 - <<'PY' "$SPINE_ROOT/bin/ops" "$tmp"
from pathlib import Path
import sys

path = Path(sys.argv[1])
tmp = sys.argv[2]
path.write_text(path.read_text(encoding="utf-8").replace("__TMP__", tmp), encoding="utf-8")
PY

json_out="$("$PREPARE" MSG-SOURCE --mailbox team@mintprints.com --customer "Papa's Raw Bar" --job "13823" --operator-context "Use the latest papapalooza revision for Sheik." --json)"
record_file="$(echo "$json_out" | jq -r '.record_file')"
index_file="$(echo "$json_out" | jq -r '.index_file')"

[[ "$(echo "$json_out" | jq -r '.status')" == "ok" ]] || fail "prepare should succeed when the attachment is resolved"
[[ "$(echo "$json_out" | jq -r '.quote_status')" == "clarification_needed" ]] || fail "prepare should infer quote clarification when message says more info is needed"
[[ "$(echo "$json_out" | jq -r '.handoff_state')" == "ready_for_artie" ]] || fail "prepare should create a ready Artie handoff"
[[ "$(echo "$json_out" | jq -r '.selected_artwork_ref.original_filename')" == "papapalooza.pdf" ]] || fail "prepare should surface selected artifact filename"
[[ "$(echo "$json_out" | jq -r '.selected_artwork_ref.artifact_id')" == "artifact-papa-1" ]] || fail "prepare should surface the governed artifact id"
[[ "$(echo "$json_out" | jq -r '.selected_artwork_preflight.owner')" == "Artie" ]] || fail "prepare should surface Artie-owned preflight truth for the selected artwork"
[[ "$(echo "$json_out" | jq -r '.selected_artwork_preflight.record_file | length')" -gt 0 ]] || fail "prepare should persist a governed preflight record for the selected artwork"
[[ -f "$record_file" ]] || fail "handoff record should exist"
[[ -f "$index_file" ]] || fail "handoff index should exist"
[[ "$(jq -r '.customer_identity' "$record_file")" == "Papa's Raw Bar" ]] || fail "handoff should persist customer identity"
[[ "$(jq -r '.job_identity' "$record_file")" == "13823" ]] || fail "handoff should persist job identity"
[[ "$(jq -r '.selected_artwork_preflight.owner' "$record_file")" == "Artie" ]] || fail "handoff should persist the selected artwork preflight truth"
[[ "$(jq -r '.receipts.resolve_receipt' "$record_file")" == "/tmp/mint.customer.forwarded.attachment.resolve.receipt.md" ]] || fail "handoff should keep resolve receipt"
[[ "$(tail -n 1 "$index_file" | jq -r '.handoff_state')" == "ready_for_artie" ]] || fail "handoff index should record ready state"
pass "customer-artwork-revision-prepare creates a bounded Artie handoff from governed artifact truth"
