#!/usr/bin/env bash
# TRIAGE: ssh deployment resolver must use TCP/22 not ICMP ping
# Gate: D389 resolver-ssh-deployment-parity-lock
# Category: process-hygiene
# Ring: standard
# Severity: medium
#
# Deploy/mutation scripts that perform SSH operations must use tcp-based
# ssh_resolve_ssh_host_with_fallback, not ping-based ssh_resolve_host_with_fallback.
# Ping can succeed when SSH port is blocked, causing false-positive reachability.
#
# Check: Grep deploy/mutation scripts for ssh_resolve_host_with_fallback usage
# where they also perform SSH operations (deploy, docker remote, backup via SSH).
#
# See: docs/planning/AOF_NORMALIZATION_DRIFT_AUDIT_20260309.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Focus on deploy/mutation scripts likely to do SSH
SEARCH_PATHS=(
  "$ROOT/ops/plugins/domains/mint/bin/*deploy*"
  "$ROOT/ops/plugins/domains/mint/bin/*sync*"
  "$ROOT/ops/plugins/infra/docker/bin/*"
  "$ROOT/ops/plugins/infra/backup/bin/*"
  "$ROOT/ops/plugins/infra/bin/*docker*"
)

violations=()

for pattern in "${SEARCH_PATHS[@]}"; do
  # shellcheck disable=SC2086
  for script in $pattern; do
    [[ -f "$script" ]] || continue

    # Check if script uses ping-based resolver AND does SSH operations
    uses_ping_resolver=0
    does_ssh=0

    if grep -q "ssh_resolve_host_with_fallback" "$script" 2>/dev/null; then
      uses_ping_resolver=1
    fi

    if grep -q "ssh.*ubuntu@\|ssh.*\$.*@\|docker.*ssh\|rsync.*ssh" "$script" 2>/dev/null; then
      does_ssh=1
    fi

    # Violation: uses ping resolver AND does SSH
    if [[ $uses_ping_resolver -eq 1 && $does_ssh -eq 1 ]]; then
      # Check if it ALSO uses the TCP resolver (mixed usage is OK if TCP is for SSH)
      if ! grep -q "ssh_resolve_ssh_host_with_fallback" "$script" 2>/dev/null; then
        violations+=("$(basename "$script")")
      fi
    fi
  done
done

if [[ ${#violations[@]} -gt 0 ]]; then
  echo "D389 FAIL: ${#violations[@]} script(s) use ping-based resolver for SSH operations"
  echo ""
  echo "Scripts that perform SSH must use ssh_resolve_ssh_host_with_fallback (TCP/22)"
  echo "instead of ssh_resolve_host_with_fallback (ICMP ping)."
  echo ""
  echo "Violations:"
  for v in "${violations[@]}"; do
    echo "  - $v"
  done
  echo ""
  echo "Fix: Replace ssh_resolve_host_with_fallback with ssh_resolve_ssh_host_with_fallback"
  echo "     for all SSH/deploy operations."
  echo ""
  echo "See: docs/planning/AOF_NORMALIZATION_DRIFT_AUDIT_20260309.md"
  exit 1
fi

echo "D389 PASS: deploy scripts use TCP-based SSH resolver"
exit 0
