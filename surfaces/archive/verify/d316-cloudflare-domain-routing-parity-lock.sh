#!/usr/bin/env bash
# TRIAGE: reconcile DOMAIN_ROUTING_REGISTRY.yaml with live tunnel ingress using cloudflare.tunnel.ingress.set and rerun cloudflare.domain_routing.diff.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"
DIFF_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-domain-routing-diff"

fail() {
  echo "D316 FAIL: $*" >&2
  exit 1
}

[[ -x "$SECRETS_EXEC" ]] || fail "missing executable: $SECRETS_EXEC"
[[ -x "$DIFF_SCRIPT" ]] || fail "missing executable: $DIFF_SCRIPT"

if ! DIFF_OUT="$("$SECRETS_EXEC" -- env SPINE_SECRETS_INJECTED=1 "$DIFF_SCRIPT" 2>&1)"; then
  echo "$DIFF_OUT" >&2
  fail "Cloudflare routing registry parity drift detected"
fi

echo "$DIFF_OUT" | grep -q 'status: OK (no diffs)' || fail "unexpected diff output; expected clean parity"
echo "D316 PASS: DOMAIN_ROUTING_REGISTRY parity with Cloudflare tunnel ingress"
