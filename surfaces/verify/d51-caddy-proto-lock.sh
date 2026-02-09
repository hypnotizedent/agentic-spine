#!/usr/bin/env bash
# D51: Caddy proto lock
# Validates that the staged Caddyfile has X-Forwarded-Proto https
# on ALL reverse_proxy blocks targeting Authentik (port 9000).
#
# Why: Cloudflare tunnel terminates TLS → Caddy sees HTTP → Authentik
# generates http:// OIDC URLs → downstream OAuth2 clients break.
# This gate prevents regression.
set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CADDYFILE="$SP/ops/staged/caddy-auth/Caddyfile"

if [[ ! -f "$CADDYFILE" ]]; then
  echo "FAIL: staged Caddyfile not found at $CADDYFILE" >&2
  exit 1
fi

# Count reverse_proxy blocks targeting port 9000 (Authentik)
PROXY_BLOCKS=$(grep -c 'reverse_proxy.*127\.0\.0\.1:9000' "$CADDYFILE" 2>/dev/null || echo 0)

if [[ "$PROXY_BLOCKS" -eq 0 ]]; then
  echo "FAIL: no reverse_proxy blocks targeting :9000 found in Caddyfile" >&2
  exit 1
fi

# Count proto header directives
PROTO_HEADERS=$(grep -c 'header_up X-Forwarded-Proto https' "$CADDYFILE" 2>/dev/null || echo 0)

# Every reverse_proxy :9000 block MUST have the proto header
# (commented-out blocks are excluded from grep -c since they start with #)
ACTIVE_PROXY_BLOCKS=$(grep 'reverse_proxy.*127\.0\.0\.1:9000' "$CADDYFILE" | grep -cv '^\s*#' 2>/dev/null || echo 0)
ACTIVE_PROTO_HEADERS=$(grep 'header_up X-Forwarded-Proto https' "$CADDYFILE" | grep -cv '^\s*#' 2>/dev/null || echo 0)

if [[ "$ACTIVE_PROTO_HEADERS" -lt "$ACTIVE_PROXY_BLOCKS" ]]; then
  echo "FAIL: $ACTIVE_PROXY_BLOCKS active reverse_proxy :9000 blocks but only $ACTIVE_PROTO_HEADERS have X-Forwarded-Proto https" >&2
  exit 1
fi

# Verify deploy.dependencies.yaml exists
DEPS="$SP/ops/bindings/deploy.dependencies.yaml"
if [[ ! -f "$DEPS" ]]; then
  echo "FAIL: deploy.dependencies.yaml not found" >&2
  exit 1
fi

exit 0
