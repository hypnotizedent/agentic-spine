#!/usr/bin/env bash
# TRIAGE: Verify infra-core baseline contract completeness — all systems defined with authority, lifecycle, self-heal, and auth posture; recovery actions registered; smoke runner present.
# D320: infra-core-baseline-contract-lock
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/infra.core.baseline.contract.yaml"
RECOVERY="$ROOT/ops/bindings/recovery.actions.yaml"
SMOKE_RUNNER="$ROOT/ops/runtime/infra-core-smoke.sh"
SLO="$ROOT/ops/bindings/infra.core.slo.yaml"

ERRORS=0
err() {
  echo "  FAIL: $*" >&2
  ERRORS=$((ERRORS + 1))
}

need_file() {
  [[ -f "$1" ]] || err "missing file: $1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "missing command: $1"
}

# ── Preconditions ──
need_cmd yq
need_file "$CONTRACT"
need_file "$RECOVERY"
need_file "$SMOKE_RUNNER"
need_file "$SLO"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D320 FAIL: $ERRORS precondition error(s)"
  exit 1
fi

if grep -q "capability_rerun" "$CONTRACT" "$RECOVERY"; then
  err "unsupported legacy recovery type 'capability_rerun' found in contract/binding"
fi

[[ -x "$SMOKE_RUNNER" ]] || err "smoke runner not executable: $SMOKE_RUNNER"

# ── Check 1: All four systems defined in contract ──
for system in cloudflare vaultwarden infisical authentik; do
  authority="$(yq -r ".systems.$system.authority // \"\"" "$CONTRACT")"
  if [[ -z "$authority" || "$authority" == "null" ]]; then
    err "contract missing system: $system (no authority defined)"
  fi
done

# ── Check 2: Each system has self_heal.recovery_action_id ──
for system in cloudflare vaultwarden infisical authentik; do
  recovery_id="$(yq -r ".systems.$system.self_heal.recovery_action_id // \"\"" "$CONTRACT")"
  contract_recovery_type="$(yq -r ".systems.$system.self_heal.recovery_type // \"\"" "$CONTRACT")"
  if [[ -z "$recovery_id" || "$recovery_id" == "null" ]]; then
    err "contract system $system missing self_heal.recovery_action_id"
    continue
  fi

  if [[ -z "$contract_recovery_type" || "$contract_recovery_type" == "null" ]]; then
    err "contract system $system missing self_heal.recovery_type"
    continue
  fi
  case "$contract_recovery_type" in
    docker_compose_restart|launchd_restart|capability_retry|capability_commit|alert_only) ;;
    *)
      err "contract system $system uses unsupported self_heal.recovery_type '$contract_recovery_type'"
      continue
      ;;
  esac

  # Verify the recovery action exists in recovery.actions.yaml
  found="$(yq -r ".actions[] | select(.id == \"$recovery_id\") | .id // \"\"" "$RECOVERY")"
  if [[ "$found" != "$recovery_id" ]]; then
    err "recovery action '$recovery_id' (system: $system) not found in recovery.actions.yaml"
    continue
  fi

  action_recovery_type="$(yq -r ".actions[] | select(.id == \"$recovery_id\") | .recovery.type // \"\"" "$RECOVERY")"
  if [[ "$action_recovery_type" != "$contract_recovery_type" ]]; then
    err "contract/binding recovery type mismatch for '$system' action '$recovery_id' (contract='$contract_recovery_type' binding='$action_recovery_type')"
  fi

  if [[ "$action_recovery_type" == "capability_retry" ]]; then
    retry_capability="$(yq -r ".actions[] | select(.id == \"$recovery_id\") | .recovery.capability // \"\"" "$RECOVERY")"
    retry_max_attempts="$(yq -r ".actions[] | select(.id == \"$recovery_id\") | .recovery.max_attempts // \"\"" "$RECOVERY")"
    retry_backoff_count="$(yq -r ".actions[] | select(.id == \"$recovery_id\") | (.recovery.backoff_seconds // []) | length" "$RECOVERY" 2>/dev/null || echo 0)"

    if [[ -z "$retry_capability" || "$retry_capability" == "null" ]]; then
      err "capability_retry action '$recovery_id' missing recovery.capability"
    fi

    if [[ ! "$retry_max_attempts" =~ ^[0-9]+$ ]] || [[ "$retry_max_attempts" -lt 1 ]]; then
      err "capability_retry action '$recovery_id' must define recovery.max_attempts >= 1"
    fi

    if [[ ! "$retry_backoff_count" =~ ^[0-9]+$ ]] || [[ "$retry_backoff_count" -lt 1 ]]; then
      err "capability_retry action '$recovery_id' missing recovery.backoff_seconds"
    fi
  fi
done

# ── Check 3: Each system has auth_posture ──
for system in cloudflare vaultwarden infisical authentik; do
  has_auth="$(yq -r ".systems.$system.auth_posture | length" "$CONTRACT" 2>/dev/null || echo "0")"
  if [[ "$has_auth" -eq 0 ]]; then
    err "contract system $system missing auth_posture"
  fi
done

# ── Check 4: SLO contract exists and lists required services ──
slo_count="$(yq -r '.target.required_service_ids | length' "$SLO" 2>/dev/null || echo "0")"
if [[ "$slo_count" -lt 4 ]]; then
  err "SLO contract has fewer than 4 required services (got $slo_count)"
fi

# ── Summary ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D320 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D320 PASS: infra-core baseline contract enforced (4 systems, recovery actions wired with type parity, smoke runner present, SLO $slo_count services)"
