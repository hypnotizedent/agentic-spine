#!/usr/bin/env bash
# TRIAGE: Ensure staged media compose files match deployed compose files on media VMs.
set -euo pipefail

source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"

fail() {
  echo "D303 FAIL: $*" >&2
  exit 1
}

err() {
  echo "  FAIL: $*" >&2
  ERRORS=$((ERRORS + 1))
}

ok() {
  [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    return 1
  fi
}

get_vm_ssh_ref() {
  local vm="$1"
  local target user

  target="$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_target // .hostname // \"\"" "$VM_BINDING" 2>/dev/null || true)"
  user="$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_user // \"\"" "$VM_BINDING" 2>/dev/null || true)"

  if [[ -z "$target" || "$target" == "null" ]]; then
    echo ""
    return 1
  fi

  if [[ -n "$user" && "$user" != "null" ]]; then
    echo "${user}@${target}"
  else
    echo "$target"
  fi
}

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v ssh >/dev/null 2>&1 || fail "missing dependency: ssh"
sha256_file "$ROOT/ops/bindings/gate.registry.yaml" >/dev/null 2>&1 || fail "missing sha256 utility (need sha256sum or shasum)"
[[ -f "$VM_BINDING" ]] || fail "missing VM binding: $VM_BINDING"

ERRORS=0
COMPARED=0
SKIPPED=0

for stack in download-stack streaming-stack; do
  local_compose="$ROOT/ops/staged/${stack}/docker-compose.yml"
  if [[ ! -f "$local_compose" ]]; then
    err "${stack}: missing staged compose file: $local_compose"
    continue
  fi

  local_sha="$(sha256_file "$local_compose" 2>/dev/null || true)"
  if [[ -z "$local_sha" ]]; then
    err "${stack}: failed to compute local SHA256"
    continue
  fi

  ssh_ref="$(get_vm_ssh_ref "$stack" 2>/dev/null || true)"
  if [[ -z "$ssh_ref" ]]; then
    err "${stack}: no ssh target found in vm.lifecycle binding"
    continue
  fi

  remote_compose="/opt/stacks/${stack}/docker-compose.yml"
  remote_cmd=$(cat <<REMOTE
set -euo pipefail
compose_path="$remote_compose"
if [[ ! -f "\$compose_path" ]]; then
  echo "__MISSING__"
  exit 0
fi
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "\$compose_path" | awk '{print \$1}'
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "\$compose_path" | awk '{print \$1}'
else
  echo "__NOSHA__"
fi
REMOTE
)

  remote_sha="$(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$ssh_ref" "$remote_cmd" 2>/dev/null || true)"

  if [[ -z "$remote_sha" ]]; then
    echo "  SKIP: ${stack} unreachable (tailscale/ssh unavailable)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  if [[ "$remote_sha" == "__MISSING__" ]]; then
    err "${stack}: remote compose missing at ${remote_compose}"
    continue
  fi
  if [[ "$remote_sha" == "__NOSHA__" ]]; then
    err "${stack}: remote host missing sha256 utility"
    continue
  fi

  COMPARED=$((COMPARED + 1))
  if [[ "$local_sha" != "$remote_sha" ]]; then
    err "${stack}: compose SHA drift (staged=${local_sha} remote=${remote_sha})"
  else
    ok "${stack}: compose SHA parity OK (${local_sha})"
  fi
done

if (( ERRORS > 0 )); then
  fail "compose parity drift detected (errors=$ERRORS compared=$COMPARED skipped=$SKIPPED)"
fi

if (( COMPARED == 0 )); then
  echo "D303 PASS: media compose parity skipped (no reachable media VM targets; skipped=$SKIPPED)"
  exit 0
fi

echo "D303 PASS: media compose parity lock enforced (compared=$COMPARED skipped=$SKIPPED)"
