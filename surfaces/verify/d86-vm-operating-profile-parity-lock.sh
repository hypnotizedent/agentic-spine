#!/usr/bin/env bash
# TRIAGE: Update ops/bindings/vm.operating.profile.yaml to cover all active VMs from vm.lifecycle.yaml. Every active VM needs a profile entry with all required fields.
# D86: VM operating profile parity lock
# Ensures every active VM in vm.lifecycle.yaml has a matching entry in
# vm.operating.profile.yaml with all required fields populated and valid.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LIFECYCLE="$ROOT/ops/bindings/vm.lifecycle.yaml"
PROFILE="$ROOT/ops/bindings/vm.operating.profile.yaml"

fail() { echo "D86 FAIL: $*" >&2; exit 1; }

[[ -f "$LIFECYCLE" ]] || fail "vm.lifecycle.yaml not found"
[[ -f "$PROFILE" ]] || fail "vm.operating.profile.yaml not found"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

ERRORS=0
err() { echo "  $*" >&2; ERRORS=$((ERRORS + 1)); }

REQUIRED_FIELDS="ssh_mode runtime_inspection_mode health_probe_policy startup_policy diagnostic_user_policy backup_policy"

# Valid enum values per field
VALID_SSH_MODES="standard non-standard haos lxc-root none"
VALID_INSPECTION_MODES="docker-group docker-sudo docker-none haos-supervisor none"
VALID_PROBE_POLICIES="full selective none"
VALID_STARTUP_POLICIES="auto manual template"
VALID_DIAG_POLICIES="docker-group-member sudo-only no-docker-access not-applicable"
VALID_BACKUP_POLICIES="vzdump-scheduled vzdump-manual none"

# Get active VM IDs from lifecycle
active_vmids=$(yq -r '.vms[] | select(.status == "active") | .vmid' "$LIFECYCLE")

# Get profile VM IDs
profile_vmids=$(yq -r '.profiles[].vmid' "$PROFILE")

# Check every active VM has a profile
while IFS= read -r vmid; do
  [[ -z "$vmid" ]] && continue
  hostname=$(yq -r ".vms[] | select(.vmid == $vmid) | .hostname" "$LIFECYCLE")

  if ! echo "$profile_vmids" | grep -qx "$vmid"; then
    err "Active VM $vmid ($hostname) missing from vm.operating.profile.yaml"
    continue
  fi

  # Check all required fields are non-null
  for field in $REQUIRED_FIELDS; do
    val=$(yq -r ".profiles[] | select(.vmid == $vmid) | .$field" "$PROFILE")
    if [[ -z "$val" || "$val" == "null" ]]; then
      err "VM $vmid ($hostname): $field is null/missing"
    fi
  done

  # Validate enum values
  validate() {
    local field="$1" val="$2" valid="$3"
    [[ -z "$val" || "$val" == "null" ]] && return
    local found=false
    for v in $valid; do
      [[ "$val" == "$v" ]] && found=true && break
    done
    if [[ "$found" != "true" ]]; then
      err "VM $vmid ($hostname): $field has invalid value '$val'"
    fi
  }

  ssh_mode=$(yq -r ".profiles[] | select(.vmid == $vmid) | .ssh_mode" "$PROFILE")
  inspection=$(yq -r ".profiles[] | select(.vmid == $vmid) | .runtime_inspection_mode" "$PROFILE")
  probes=$(yq -r ".profiles[] | select(.vmid == $vmid) | .health_probe_policy" "$PROFILE")
  startup=$(yq -r ".profiles[] | select(.vmid == $vmid) | .startup_policy" "$PROFILE")
  diag=$(yq -r ".profiles[] | select(.vmid == $vmid) | .diagnostic_user_policy" "$PROFILE")
  backup=$(yq -r ".profiles[] | select(.vmid == $vmid) | .backup_policy" "$PROFILE")

  validate "ssh_mode" "$ssh_mode" "$VALID_SSH_MODES"
  validate "runtime_inspection_mode" "$inspection" "$VALID_INSPECTION_MODES"
  validate "health_probe_policy" "$probes" "$VALID_PROBE_POLICIES"
  validate "startup_policy" "$startup" "$VALID_STARTUP_POLICIES"
  validate "diagnostic_user_policy" "$diag" "$VALID_DIAG_POLICIES"
  validate "backup_policy" "$backup" "$VALID_BACKUP_POLICIES"

done <<< "$active_vmids"

# Check profile doesn't have orphaned entries (VMs not in lifecycle or not active)
while IFS= read -r pvmid; do
  [[ -z "$pvmid" ]] && continue
  lc_status=$(yq -r ".vms[] | select(.vmid == $pvmid) | .status" "$LIFECYCLE")
  if [[ -z "$lc_status" || "$lc_status" == "null" ]]; then
    err "Profile entry for VM $pvmid has no matching lifecycle entry"
  elif [[ "$lc_status" != "active" ]]; then
    err "Profile entry for VM $pvmid but lifecycle status is '$lc_status' (not active)"
  fi
done <<< "$profile_vmids"

if [[ "$ERRORS" -gt 0 ]]; then
  fail "$ERRORS parity errors found"
fi

active_count=$(echo "$active_vmids" | grep -c . || true)
profile_count=$(echo "$profile_vmids" | grep -c . || true)
echo "D86 PASS: VM operating profile parity lock enforced ($active_count active VMs, $profile_count profiles)"
