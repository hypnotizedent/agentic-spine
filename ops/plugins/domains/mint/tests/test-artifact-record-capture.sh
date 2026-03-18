#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"
CAPTURE="$REPO_ROOT/ops/plugins/domains/mint/bin/artifact-record-capture"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$CAPTURE" ]] || fail "missing artifact-record-capture executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

runtime_root="$tmp/runtime/domain-state/mint"
minio_root="$tmp/minio"
mkdir -p "$runtime_root" "$minio_root/artwork-intake/operator-drop/13823 PapaPalooza/1. Originals" "$minio_root/artwork-intake/operator-drop/13823 PapaPalooza/3. Print Ready" "$tmp/src"

printf 'ORIGINAL-V1' >"$tmp/src/papapalooza_old.pdf"
printf 'ORIGINAL-V2' >"$tmp/src/papapalooza.pdf"
printf 'PRINTREADY' >"$tmp/src/papapalooza.ai"

capture() {
  MINT_RUNTIME_ROOT="$runtime_root" \
  MINIO_MOUNT_ROOT="$minio_root" \
  "$CAPTURE" "$@"
}

json_v1="$(capture "$tmp/src/papapalooza_old.pdf" --seed-id seed-papa-1 --artifact-role original --customer-email troy@papasrawbar.com --customer-name "Troy / Papa's Raw Bar" --job-ref 13823 --source-message-id MSG-OLD --canonical-object-path "$minio_root/artwork-intake/operator-drop/13823 PapaPalooza/1. Originals/papapalooza_old.pdf" --json)"
artifact_v1="$(echo "$json_v1" | jq -r '.artifact_id')"
record_v1="$runtime_root/artifacts/artifact_${artifact_v1}.yaml"

json_v2="$(capture "$tmp/src/papapalooza.pdf" --seed-id seed-papa-1 --artifact-role original --customer-email troy@papasrawbar.com --customer-name "Troy / Papa's Raw Bar" --job-ref 13823 --source-message-id MSG-SOURCE --canonical-object-path "$minio_root/artwork-intake/operator-drop/13823 PapaPalooza/1. Originals/papapalooza.pdf" --json)"
artifact_v2="$(echo "$json_v2" | jq -r '.artifact_id')"
record_v2="$runtime_root/artifacts/artifact_${artifact_v2}.yaml"

[[ -f "$record_v1" ]] || fail "first artifact record should exist"
[[ -f "$record_v2" ]] || fail "second artifact record should exist"
[[ "$(echo "$json_v2" | jq -r '.supersedes[0]')" == "$artifact_v1" ]] || fail "new original should supersede the prior original"
[[ "$(yq '.artifact_status' "$record_v1")" == "superseded" ]] || fail "prior original should be superseded"
[[ "$(yq '.superseded_by' "$record_v1")" == "$artifact_v2" ]] || fail "prior original should point to its replacement"
[[ "$(yq '.artifact_status' "$record_v2")" == "active" ]] || fail "latest original should remain active"
pass "same-role newer imports supersede older versions"

json_print_ready="$(capture "$tmp/src/papapalooza.ai" --seed-id seed-papa-1 --customer-email troy@papasrawbar.com --customer-name "Troy / Papa's Raw Bar" --job-ref 13823 --source-message-id MSG-READY --context "print ready vector for production" --canonical-object-path "$minio_root/artwork-intake/operator-drop/13823 PapaPalooza/3. Print Ready/papapalooza.ai" --json)"
artifact_print_ready="$(echo "$json_print_ready" | jq -r '.artifact_id')"
record_print_ready="$runtime_root/artifacts/artifact_${artifact_print_ready}.yaml"

[[ -f "$record_print_ready" ]] || fail "print-ready artifact record should exist"
[[ "$(echo "$json_print_ready" | jq -r '.artifact_role')" == "print_ready" ]] || fail "vector import should infer print_ready role"
[[ "$(echo "$json_print_ready" | jq -r '.capture_state')" == "recorded" ]] || fail "distinct role import should be recorded"
[[ "$(yq '.artifact_status' "$record_v2")" == "active" ]] || fail "active original should not be superseded by print_ready import"
[[ "$(yq '.artifacts | length' "$runtime_root/artifacts-index.yaml")" == "3" ]] || fail "artifact index should contain all artifact records"
pass "distinct roles stay active side-by-side instead of cross-superseding"

echo "Artifact capture checks passed"
