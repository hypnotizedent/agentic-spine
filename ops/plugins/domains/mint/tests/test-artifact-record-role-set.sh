#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"
CAPTURE="$REPO_ROOT/ops/plugins/domains/mint/bin/artifact-record-capture"
ROLE_SET="$REPO_ROOT/ops/plugins/domains/mint/bin/artifact-record-role-set"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$CAPTURE" ]] || fail "missing artifact-record-capture executable"
[[ -x "$ROLE_SET" ]] || fail "missing artifact-record-role-set executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

runtime_root="$tmp/runtime/domain-state/mint"
minio_root="$tmp/minio"
mkdir -p "$runtime_root" "$minio_root/artwork-intake/operator-drop/13823 PapaPalooza/2. Proofs" "$tmp/src"

printf 'PROOFDATA' >"$tmp/src/papapalooza-proof.pdf"

capture_json="$(
  MINT_RUNTIME_ROOT="$runtime_root" \
  MINIO_MOUNT_ROOT="$minio_root" \
  "$CAPTURE" "$tmp/src/papapalooza-proof.pdf" \
    --seed-id seed-papa-1 \
    --customer-email troy@papasrawbar.com \
    --source-message-id MSG-PROOF \
    --canonical-object-path "$minio_root/artwork-intake/operator-drop/13823 PapaPalooza/2. Proofs/papapalooza-proof.pdf" \
    --json
)"
artifact_id="$(echo "$capture_json" | jq -r '.artifact_id')"
record_file="$runtime_root/artifacts/artifact_${artifact_id}.yaml"

override_json="$(
  MINT_RUNTIME_ROOT="$runtime_root" \
  "$ROLE_SET" --artifact-id "$artifact_id" --artifact-role proof --operator ronny --note "customer-facing proof" --json
)"
[[ "$(echo "$override_json" | jq -r '.artifact_role')" == "proof" ]] || fail "role override should set proof role"
[[ "$(yq '.artifact_role' "$record_file")" == "proof" ]] || fail "artifact record should persist proof role"
[[ "$(yq '.artifact_status' "$record_file")" == "active" ]] || fail "proof override should remain active"
[[ "$(yq '.provenance.role_assignment.assignment_mode' "$record_file")" == "operator_override" ]] || fail "override should record operator provenance"
pass "role override can promote an imported artifact into explicit proof truth"

retire_json="$(
  MINT_RUNTIME_ROOT="$runtime_root" \
  "$ROLE_SET" --artifact-id "$artifact_id" --artifact-role superseded --operator ronny --superseded-by ART-NEW-0001 --note "bad proof version" --json
)"
[[ "$(echo "$retire_json" | jq -r '.artifact_status')" == "superseded" ]] || fail "superseded override should retire the artifact"
[[ "$(yq '.superseded_by' "$record_file")" == "ART-NEW-0001" ]] || fail "retired artifact should point at replacement"
[[ "$(yq '.role_history | length' "$record_file")" == "3" ]] || fail "role history should keep capture plus both overrides"
pass "role override can retire a bad version while preserving lineage"

echo "Artifact role override checks passed"
