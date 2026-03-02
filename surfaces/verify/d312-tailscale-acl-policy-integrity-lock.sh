#!/usr/bin/env bash
# TRIAGE: Tailscale ACL policy must exist in git, parse as valid HuJSON, and be wired to authority contract.
# D312: Tailscale ACL policy integrity lock.
# Ensures the canonical ACL policy file exists, parses, contains required sections,
# and is referenced from the authority contract.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACL_POLICY="$ROOT/ops/bindings/tailscale.acl.policy.hujson"
AUTHORITY="$ROOT/docs/CANONICAL/TAILSCALE_AUTHORITY_CONTRACT_V1.yaml"

fail=0
err() { echo "D312 FAIL: $*" >&2; fail=1; }

# 1) ACL policy file must exist
[[ -f "$ACL_POLICY" ]] || { err "ACL policy file missing: $ACL_POLICY"; exit 1; }

# 2) Must parse as valid HuJSON (strip comments + trailing commas → JSON)
python3 -c "
import json, re, sys

text = open('$ACL_POLICY').read()
text = re.sub(r'//[^\n]*', '', text)
text = re.sub(r',(\s*[}\]])', r'\1', text)
try:
    data = json.loads(text)
except json.JSONDecodeError as e:
    print(f'D312 FAIL: HuJSON parse error: {e}', file=sys.stderr)
    sys.exit(1)

# 3) Must contain grants or acls section
has_grants = 'grants' in data and len(data['grants']) > 0
has_acls = 'acls' in data and len(data['acls']) > 0
if not has_grants and not has_acls:
    print('D312 FAIL: policy has neither grants nor acls section', file=sys.stderr)
    sys.exit(1)

# 4) Must contain tagOwners
if 'tagOwners' not in data or len(data.get('tagOwners', {})) == 0:
    print('D312 FAIL: policy missing tagOwners section', file=sys.stderr)
    sys.exit(1)

# 5) Must contain tests
if 'tests' not in data or len(data.get('tests', [])) == 0:
    print('D312 FAIL: policy missing tests section', file=sys.stderr)
    sys.exit(1)
" || { fail=1; }

# 6) Authority contract must reference ACL policy
command -v yq >/dev/null 2>&1 || { err "missing dependency: yq"; exit 1; }
if [[ -f "$AUTHORITY" ]]; then
  acl_ref=$(yq -r '.lifecycle_bindings.acl_policy // ""' "$AUTHORITY" 2>/dev/null || true)
  if [[ -z "$acl_ref" || "$acl_ref" == "null" ]]; then
    err "authority contract missing lifecycle_bindings.acl_policy reference"
  fi
else
  err "authority contract missing: $AUTHORITY"
fi

if [[ "$fail" -eq 1 ]]; then
  exit 1
fi

echo "D312 PASS: ACL policy integrity valid (file exists, parses, has grants+tagOwners+tests, authority wired)"
