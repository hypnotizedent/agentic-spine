#!/usr/bin/env bash
# TRIAGE: enforce cluster lifecycle receipts as evidence-only L2 readback, not node/runtime authority.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/cluster.lifecycle.receipt.contract.yaml"
CAP_FILE="$ROOT/ops/capabilities.yaml"
MANIFEST_FILE="$ROOT/ops/plugins/MANIFEST.yaml"
EMIT="$ROOT/ops/plugins/infra/bin/cluster-lifecycle-receipt-emit"
STATUS="$ROOT/ops/plugins/infra/bin/cluster-lifecycle-status"

fail() {
  echo "D458 FAIL: $*" >&2
  exit 1
}

for file in "$CONTRACT" "$CAP_FILE" "$MANIFEST_FILE"; do
  [[ -f "$file" ]] || fail "missing required file: ${file#$ROOT/}"
done
[[ -x "$EMIT" ]] || fail "missing executable script: ${EMIT#$ROOT/}"
[[ -x "$STATUS" ]] || fail "missing executable script: ${STATUS#$ROOT/}"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"

yq -e '.authority.emit_capability == "cluster.lifecycle.receipt.emit"' "$CONTRACT" >/dev/null 2>&1 || fail "contract emit capability mismatch"
yq -e '.authority.status_capability == "cluster.lifecycle.status"' "$CONTRACT" >/dev/null 2>&1 || fail "contract status capability mismatch"
yq -e '.truth_boundary.does_not_own[] | select(. == "kubernetes_or_k3s_cluster_authority")' "$CONTRACT" >/dev/null 2>&1 || fail "contract must not own k3s authority"
yq -e '.truth_boundary.does_not_own[] | select(. == "node_role_assignment")' "$CONTRACT" >/dev/null 2>&1 || fail "contract must not own node role assignment"
yq -e '.truth_boundary.authority_effect == "evidence_only_not_activation"' "$CONTRACT" >/dev/null 2>&1 || fail "contract authority effect must be evidence-only"
yq -e '.truth_boundary.canonical_node_readback == "node.admission.status"' "$CONTRACT" >/dev/null 2>&1 || fail "contract must join node.admission.status"
yq -e '.subtraction.old_surfaces_demoted[] | select(. == "raw_kubectl_output_as_lifecycle_truth")' "$CONTRACT" >/dev/null 2>&1 || fail "contract must demote raw kubectl output"
yq -e '.receipt_schema.schema_id == "cluster.lifecycle.receipt.v1"' "$CONTRACT" >/dev/null 2>&1 || fail "receipt schema id mismatch"

yq -e '.capabilities."cluster.lifecycle.receipt.emit".script_path == "./ops/plugins/infra/bin/cluster-lifecycle-receipt-emit"' "$CAP_FILE" >/dev/null 2>&1 || fail "emit capability script path mismatch"
yq -e '.capabilities."cluster.lifecycle.receipt.emit".safety == "mutating"' "$CAP_FILE" >/dev/null 2>&1 || fail "emit capability must be mutating"
yq -e '.capabilities."cluster.lifecycle.receipt.emit".layer == "L2_shared_infrastructure"' "$CAP_FILE" >/dev/null 2>&1 || fail "emit capability must be L2 shared infrastructure"
yq -e '.capabilities."cluster.lifecycle.status".safety == "read-only"' "$CAP_FILE" >/dev/null 2>&1 || fail "status capability must be read-only"
yq -e '.plugins[] | select(.name == "infra") | .scripts[] | select(. == "bin/cluster-lifecycle-receipt-emit")' "$MANIFEST_FILE" >/dev/null 2>&1 || fail "MANIFEST infra plugin missing emit script"
yq -e '.plugins[] | select(.name == "infra") | .capabilities[] | select(. == "cluster.lifecycle.receipt.emit")' "$MANIFEST_FILE" >/dev/null 2>&1 || fail "MANIFEST infra plugin missing emit capability"
yq -e '.plugins[] | select(.name == "infra") | .capabilities[] | select(. == "cluster.lifecycle.status")' "$MANIFEST_FILE" >/dev/null 2>&1 || fail "MANIFEST infra plugin missing status capability"

"$EMIT" --self-check >/dev/null || fail "emit self-check failed"
"$STATUS" --self-check >/dev/null || fail "status self-check failed"

tmp_state="$(mktemp -d)"
trap 'rm -rf "$tmp_state"' EXIT

payload="$(SPINE_STATE="$tmp_state" "$EMIT" \
  --lab-id optiplex-k3s-lab \
  --cluster-id optiplex-k3s-v1 \
  --event-type install-attestation \
  --node-id optiplex-9020-001 \
  --result pass \
  --source-ref verify::D458 \
  --image-hash sha256:verify-image \
  --config-hash sha256:verify-config \
  --dry-run \
  --json)"

jq -e '.receipt.schema == "cluster.lifecycle.receipt.v1"' >/dev/null <<<"$payload" || fail "dry-run receipt schema mismatch"
jq -e '.receipt.node.node_id == "optiplex-9020-001"' >/dev/null <<<"$payload" || fail "dry-run receipt missing node admission join"
jq -e '.receipt.boundary.authority_effect == "evidence_only_not_activation"' >/dev/null <<<"$payload" || fail "dry-run receipt boundary mismatch"
jq -e '.receipt.boundary.does_not_own[] | select(. == "node_role_assignment")' >/dev/null <<<"$payload" || fail "dry-run receipt must reject node role ownership"

SPINE_STATE="$tmp_state" "$EMIT" \
  --lab-id optiplex-k3s-lab \
  --cluster-id optiplex-k3s-v1 \
  --event-type install-attestation \
  --node-id optiplex-9020-001 \
  --result pass \
  --source-ref verify::D458 \
  --image-hash sha256:verify-image \
  --config-hash sha256:verify-config \
  --json >/dev/null

status_payload="$(SPINE_STATE="$tmp_state" "$STATUS" --lab-id optiplex-k3s-lab --cluster-id optiplex-k3s-v1 --json)"
jq -e '.capability == "cluster.lifecycle.status"' >/dev/null <<<"$status_payload" || fail "status capability marker missing"
jq -e '.count == 1' >/dev/null <<<"$status_payload" || fail "status must read written receipt"
jq -e '.by_event.install_attestation == 1' >/dev/null <<<"$status_payload" || fail "status by_event missing install_attestation"

echo "D458 PASS: cluster lifecycle receipt rail stays evidence-only and wired to node admission readback"
