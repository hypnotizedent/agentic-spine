#!/usr/bin/env bash
# TRIAGE: Check share publish allowlist/denylist. Ensure capability wiring is correct.
# D82: Share publish governance lock
#
# Enforces share channel governance parity:
# 1. Protocol doc exists
# 2. Allowlist + denylist + remote bindings exist
# 3. Share capabilities registered in capabilities.yaml
# 4. Share plugin scripts exist and are executable
# 5. MANIFEST parity (share plugin in MANIFEST)
# 6. Remote binding internal consistency
# 7. Semantic parity: preflight invokes drift-gate.sh
# 8. Semantic parity: preview scans all 5 denylist sections
# 9. Semantic parity: apply reads remote/branch from binding (no hardcoded push)
set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"
cd "$SP"

FAIL=0
err() { echo "  D82 FAIL: $1" >&2; FAIL=1; }

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

# 7. Semantic: preflight must invoke drift-gate.sh (not just claim it)
PREFLIGHT="$SP/ops/plugins/share/bin/share-publish-preflight"
if [[ -f "$PREFLIGHT" ]]; then
  if ! grep -q 'drift-gate\.sh' "$PREFLIGHT" 2>/dev/null; then
    err "preflight does not invoke drift-gate.sh (verify enforcement missing)"
  fi
fi

# 8. Semantic: preview must scan all 5 denylist sections
PREVIEW="$SP/ops/plugins/share/bin/share-publish-preview"
if [[ -f "$PREVIEW" ]]; then
  for section in secret_patterns credential_patterns identity_patterns infrastructure_patterns runtime_patterns; do
    if ! grep -q "$section" "$PREVIEW" 2>/dev/null; then
      err "preview does not scan denylist section: $section"
    fi
  done
fi

# 9. Semantic: apply must read remote from binding, not hardcode
APPLY="$SP/ops/plugins/share/bin/share-publish-apply"
if [[ -f "$APPLY" ]]; then
  # Must reference remote binding file
  if ! grep -q 'share\.publish\.remote\.yaml' "$APPLY" 2>/dev/null; then
    err "apply does not reference share.publish.remote.yaml binding"
  fi
  # Must NOT contain raw 'git push share HEAD:main' pattern
  if grep -q 'git push share HEAD:main' "$APPLY" 2>/dev/null; then
    err "apply contains hardcoded 'git push share HEAD:main' (must use binding)"
  fi
  # Must build curated workspace (not push full HEAD)
  if ! grep -q 'curated' "$APPLY" 2>/dev/null; then
    err "apply does not build curated payload (pushes full HEAD)"
  fi
fi

if [[ "$FAIL" -gt 0 ]]; then
  echo "D82 FAIL: share publish governance violations detected" >&2
  exit 1
fi
echo "D82 PASS: share publish governance valid"
exit 0
