#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"
CAPTURE="$REPO_ROOT/ops/plugins/domains/mint/bin/artifact-record-capture"
SNAPSHOT="$REPO_ROOT/ops/plugins/domains/mint/bin/artifact-record-snapshot"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$CAPTURE" ]] || fail "missing artifact-record-capture executable"
[[ -x "$SNAPSHOT" ]] || fail "missing artifact-record-snapshot executable"

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

snapshot() {
  MINT_RUNTIME_ROOT="$runtime_root" \
  MINIO_MOUNT_ROOT="$minio_root" \
  "$SNAPSHOT" "$@"
}

capture "$tmp/src/papapalooza_old.pdf" --seed-id seed-papa-1 --artifact-role original --customer-email troy@papasrawbar.com --job-ref 13823 --source-message-id MSG-OLD --canonical-object-path "$minio_root/artwork-intake/operator-drop/13823 PapaPalooza/1. Originals/papapalooza_old.pdf" >/dev/null
json_active="$(capture "$tmp/src/papapalooza.pdf" --seed-id seed-papa-1 --artifact-role original --customer-email troy@papasrawbar.com --job-ref 13823 --source-message-id MSG-SOURCE --canonical-object-path "$minio_root/artwork-intake/operator-drop/13823 PapaPalooza/1. Originals/papapalooza.pdf" --json)"
artifact_active="$(echo "$json_active" | jq -r '.artifact_id')"
capture "$tmp/src/papapalooza.ai" --seed-id seed-papa-1 --customer-email troy@papasrawbar.com --job-ref 13823 --source-message-id MSG-READY --context "print ready vector for production" --canonical-object-path "$minio_root/artwork-intake/operator-drop/13823 PapaPalooza/3. Print Ready/papapalooza.ai" >/dev/null

seed_json="$(snapshot --seed-id seed-papa-1 --json)"
[[ "$(echo "$seed_json" | jq -r '.state')" == "active_artifacts_present" ]] || fail "seed snapshot should report active artifacts"
[[ "$(echo "$seed_json" | jq -r '.match_count')" == "2" ]] || fail "default snapshot should hide superseded records"
[[ "$(echo "$seed_json" | jq -r '.active_count')" == "2" ]] || fail "default snapshot should count active artifacts"
[[ "$(echo "$seed_json" | jq -r '.role_counts.original')" == "1" ]] || fail "default snapshot should keep active original count"
[[ "$(echo "$seed_json" | jq -r '.role_counts.print_ready')" == "1" ]] || fail "default snapshot should keep print_ready count"
pass "seed snapshot returns active artifact truth by default"

seed_all_json="$(snapshot --seed-id seed-papa-1 --include-superseded --json)"
[[ "$(echo "$seed_all_json" | jq -r '.match_count')" == "3" ]] || fail "include-superseded snapshot should return all records"
[[ "$(echo "$seed_all_json" | jq -r '.role_counts.superseded')" == "1" ]] || fail "include-superseded snapshot should count retired records"
pass "snapshot can include superseded versions for recoverability"

message_json="$(snapshot --source-message-id MSG-SOURCE --json)"
[[ "$(echo "$message_json" | jq -r '.latest.artifact_id')" == "$artifact_active" ]] || fail "message snapshot should locate the exact message-bound artifact"

email_json="$(snapshot --email troy@papasrawbar.com --json)"
[[ "$(echo "$email_json" | jq -r '.match_count')" == "2" ]] || fail "email snapshot should return active artifacts for the customer"

job_json="$(snapshot --job-ref 13823 --json)"
[[ "$(echo "$job_json" | jq -r '.match_count')" == "2" ]] || fail "job snapshot should return job-bound active artifacts"
pass "snapshot supports message, email, and job lookup modes"

echo "Artifact snapshot checks passed"
