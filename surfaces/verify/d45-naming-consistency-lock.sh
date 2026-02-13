#!/usr/bin/env bash
# TRIAGE: Fix cross-file naming inconsistencies. Check identity surfaces for drift.
# D45: Naming consistency lock
# Verifies cross-file consistency of host identity surfaces.
# File-only checks — does NOT SSH to hosts or test reachability.
#
# Reads: ops/bindings/naming.policy.yaml (authoritative)
# Cross-refs: ssh.targets.yaml, infra.placement.policy.yaml,
#             docker.compose.targets.yaml, DEVICE_IDENTITY_SSOT.md
#
# LOOP-NAMING-GOVERNANCE-20260207 (P1)

set -euo pipefail

SP="${SPINE_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"

NAMING="$SP/ops/bindings/naming.policy.yaml"
SSH_TARGETS="$SP/ops/bindings/ssh.targets.yaml"
PLACEMENT="$SP/ops/bindings/infra.placement.policy.yaml"
COMPOSE="$SP/ops/bindings/docker.compose.targets.yaml"
DEVICE_ID="$SP/docs/governance/DEVICE_IDENTITY_SSOT.md"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }

# ── Pre-checks ────────────────────────────────────────────────────
[[ -f "$NAMING" ]]      || { err "naming.policy.yaml not found"; exit 1; }
[[ -f "$SSH_TARGETS" ]] || { err "ssh.targets.yaml not found"; exit 1; }
[[ -f "$PLACEMENT" ]]   || { err "infra.placement.policy.yaml not found"; exit 1; }
[[ -f "$COMPOSE" ]]     || { err "docker.compose.targets.yaml not found"; exit 1; }
[[ -f "$DEVICE_ID" ]]   || { err "DEVICE_IDENTITY_SSOT.md not found"; exit 1; }

command -v yq >/dev/null 2>&1 || { err "yq not found"; exit 1; }

# ── Iterate hosts in naming policy ────────────────────────────────
host_count=$(yq '.hosts | length' "$NAMING")

for ((i=0; i<host_count; i++)); do
  name=$(yq -r ".hosts[$i].canonical_name" "$NAMING")

  # ── SSH target check ──
  needs_ssh=$(yq -r ".hosts[$i].surfaces.ssh_target" "$NAMING")
  if [[ "$needs_ssh" == "true" ]]; then
    match=$(yq -r ".ssh.targets[] | select(.id == \"$name\") | .id" "$SSH_TARGETS")
    if [[ -z "$match" ]]; then
      err "$name: missing from ssh.targets.yaml"
    fi
  fi

  # ── Placement check ──
  needs_placement=$(yq -r ".hosts[$i].surfaces.placement" "$NAMING")
  if [[ "$needs_placement" == "true" ]]; then
    placement_entry=$(yq -r ".hosts[\"$name\"]" "$PLACEMENT")
    if [[ "$placement_entry" == "null" ]]; then
      err "$name: missing from infra.placement.policy.yaml"
    else
      # Kind consistency between naming policy and placement policy
      policy_kind=$(yq -r ".hosts[$i].kind" "$NAMING")
      placement_kind=$(yq -r ".hosts[\"$name\"].kind" "$PLACEMENT")
      if [[ "$placement_kind" != "null" && "$policy_kind" != "$placement_kind" ]]; then
        err "$name: kind mismatch — naming=$policy_kind, placement=$placement_kind"
      fi
    fi
  fi

  # ── Compose target check ──
  needs_compose=$(yq -r ".hosts[$i].surfaces.compose_target" "$NAMING")
  if [[ "$needs_compose" == "true" ]]; then
    compose_entry=$(yq -r ".targets[\"$name\"]" "$COMPOSE")
    if [[ "$compose_entry" == "null" ]]; then
      err "$name: missing from docker.compose.targets.yaml"
    fi
  fi

  # ── Device identity doc check ──
  needs_identity=$(yq -r ".hosts[$i].surfaces.device_identity" "$NAMING")
  if [[ "$needs_identity" == "true" ]]; then
    if ! grep -q "\`$name\`" "$DEVICE_ID" 2>/dev/null; then
      err "$name: not found (backtick-quoted) in DEVICE_IDENTITY_SSOT.md"
    fi
  fi
done

exit "$FAIL"
