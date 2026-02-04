#!/usr/bin/env bash
set -euo pipefail

# D22: Nodes Surface Lock
# Ensures SSH/nodes tooling is read-only and non-leaky.
#
# FORBID:
#   - ssh -v / -vv / -vvv (verbose leaks host keys/handshake)
#   - cat ~/.ssh/* (credential reading)
#   - printenv | env | set | (env dumping)
#   - reboot | shutdown | rm | pct stop | qm stop (remote mutations)
#
# ALLOW:
#   - ssh <target> true / uptime / hostname
#   - pvesh get (read-only Proxmox API)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "D22 FAIL: $*" >&2; exit 1; }

# Scope: SSH plugin surface + binding
FILES=(
  ops/plugins/ssh/bin/ssh-*
  ops/bindings/ssh*.yaml
)

expanded=()
for f in "${FILES[@]}"; do
  while IFS= read -r path; do expanded+=("$path"); done < <(ls -1 $f 2>/dev/null || true)
done

((${#expanded[@]})) || fail "no nodes surface files found to check"

# 1) Forbid verbose SSH (leaks handshake/keys)
if rg -n '\bssh\b.*\s-v\b' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' | grep -v 'LogLevel' >/dev/null; then
  fail "verbose ssh (-v) detected in nodes surface"
fi

# 2) Forbid credential file reading
if rg -n 'cat\s+.*\.ssh/' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "SSH credential file reading detected"
fi

# 3) Forbid env dumping
if rg -n '\b(printenv|^env\s|set\s+-x)\b' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "env dumping detected in nodes surface"
fi

# 4) Forbid remote mutations
if rg -n '\b(reboot|shutdown|halt|poweroff)\b' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "remote mutation command (reboot/shutdown) detected"
fi

if rg -n '\brm\s+-[rf]' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "destructive rm command detected in nodes surface"
fi

if rg -n '\b(pct\s+stop|qm\s+stop|pct\s+destroy|qm\s+destroy)\b' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "Proxmox mutation (stop/destroy) detected"
fi

# 5) Token/secret leak guardrail
if rg -n '(echo|printf).*(TOKEN|SECRET|API_KEY|PASSWORD|PRIVATE_KEY)' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "potential secret printing detected in nodes surface"
fi

echo "D22 PASS: nodes surface drift locked"
