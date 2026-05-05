#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BAD_TARGET="$HOME/code/workbench"
[[ -d "$BAD_TARGET" ]] || BAD_TARGET="/tmp"

binding_output="$(
  SPINE_TARGET_REPO="$BAD_TARGET" \
  SPINE_REPO="$BAD_TARGET" \
  SPINE_CODE="$BAD_TARGET" \
  SPINE_ROOT="$BAD_TARGET" \
  "$ROOT/ops/plugins/infra/secrets/bin/secrets-binding"
)"

if ! printf '%s\n' "$binding_output" | rg -q "^SPINE_REPO: $ROOT$"; then
  echo "D212 FAIL: secrets.binding followed ambient target/root instead of control root" >&2
  printf '%s\n' "$binding_output" >&2
  exit 1
fi

# infisical-agent.sh is invoked directly (not through cap.sh) by the Workbench
# shim and other call sites that don't export SPINE_ROOT. Its script-derived
# fallback must land at the repo root, not at ops/plugins/. PACKET-1327
# follow-up: parse the SPINE_ROOT fallback line from the script, extract the
# relative ../-walk, anchor it at the script's own dirname, and assert the
# resolved path contains ops/bindings/secrets.binding.yaml.
agent_script="$ROOT/ops/plugins/providers/bin/infisical-agent.sh"
fallback_line="$(grep -E '^SPINE_ROOT="\$\{SPINE_ROOT:-\$\(cd' "$agent_script" | head -1)"
if [[ -z "$fallback_line" ]]; then
  echo "D212 FAIL: infisical-agent.sh has no recognizable SPINE_ROOT fallback line" >&2
  exit 1
fi
relative_walk="$(printf '%s' "$fallback_line" | sed -nE 's|.*BASH_SOURCE\[0\]\}"\)/([^"]+)".*|\1|p')"
if [[ -z "$relative_walk" ]]; then
  echo "D212 FAIL: could not extract relative walk from infisical-agent.sh fallback line" >&2
  echo "  line: $fallback_line" >&2
  exit 1
fi
agent_resolved="$(cd "$(dirname "$agent_script")/$relative_walk" 2>/dev/null && pwd)"
if [[ -z "$agent_resolved" || ! -f "$agent_resolved/ops/bindings/secrets.binding.yaml" ]]; then
  echo "D212 FAIL: infisical-agent.sh SPINE_ROOT fallback walk '$relative_walk' resolves to '$agent_resolved' which lacks ops/bindings/secrets.binding.yaml" >&2
  exit 1
fi

exec "$ROOT/ops/plugins/infra/secrets/bin/secrets-namespace-status"
