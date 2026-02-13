#!/usr/bin/env bash
# D82: Share publish governance lock
#
# Enforces share channel governance parity:
# 1. Protocol doc exists
# 2. Allowlist + denylist + remote bindings exist
# 3. Share capabilities registered in capabilities.yaml
# 4. Share plugin scripts exist and are executable
# 5. MANIFEST parity (share plugin in MANIFEST)
set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"
cd "$SP"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }

# 1. Protocol doc
[[ -f "$SP/docs/governance/WORKBENCH_SHARE_PROTOCOL.md" ]] \
  || err "WORKBENCH_SHARE_PROTOCOL.md missing"

# 2. Bindings
for f in \
  "ops/bindings/share.publish.allowlist.yaml" \
  "ops/bindings/share.publish.denylist.yaml" \
  "ops/bindings/share.publish.remote.yaml"; do
  [[ -f "$SP/$f" ]] || err "$f missing"
done

# 3. Capabilities registered
CAP_FILE="$SP/ops/capabilities.yaml"
for cap in share.publish.preflight share.publish.preview share.publish.apply; do
  grep -q "^  $cap:" "$CAP_FILE" 2>/dev/null \
    || err "capability $cap not registered in capabilities.yaml"
done

# 4. Plugin scripts exist and executable
for script in \
  "ops/plugins/share/bin/share-publish-preflight" \
  "ops/plugins/share/bin/share-publish-preview" \
  "ops/plugins/share/bin/share-publish-apply"; do
  if [[ ! -f "$SP/$script" ]]; then
    err "$script missing"
  elif [[ ! -x "$SP/$script" ]]; then
    err "$script not executable"
  fi
done

# 5. MANIFEST parity
MANIFEST="$SP/ops/plugins/MANIFEST.yaml"
if [[ -f "$MANIFEST" ]]; then
  if ! yq -e '.plugins[] | select(.name == "share")' "$MANIFEST" >/dev/null 2>&1; then
    err "share plugin not in MANIFEST.yaml"
  fi
else
  err "MANIFEST.yaml not found"
fi

# 6. Remote binding internal consistency
REMOTE_BINDING="$SP/ops/bindings/share.publish.remote.yaml"
if [[ -f "$REMOTE_BINDING" ]]; then
  mode=$(yq -r '.flow.mode' "$REMOTE_BINDING" 2>/dev/null || true)
  dry_run=$(yq -r '.flow.dry_run_default' "$REMOTE_BINDING" 2>/dev/null || true)
  [[ "$mode" == "one-way" ]] \
    || err "remote binding flow.mode must be 'one-way' (got: $mode)"
  [[ "$dry_run" == "true" ]] \
    || err "remote binding flow.dry_run_default must be true (got: $dry_run)"
fi

if [[ "$FAIL" -gt 0 ]]; then
  echo "  share publish governance: $FAIL issue(s)" >&2
fi
exit "$FAIL"
