#!/usr/bin/env bash
set -euo pipefail

# D30: Active Config Lock
# Fails if active host config files contain legacy runtime references
# or plaintext credential patterns.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$ROOT/ops/bindings/host.audit.allowlist.yaml"

fail() { echo "D30 FAIL: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool rg
require_tool yq

[[ -f "$BINDING" ]] || fail "binding missing: $BINDING"
yq e '.' "$BINDING" >/dev/null 2>&1 || fail "binding is not valid YAML"

LEGACY_RE='(/Users/ronnyworks/ronny-ops|~/ronny-ops|\$HOME/ronny-ops|/ronny-ops/)'
LEGACY_DOC_RE='(00_CLAUDE\.md|AGENT_CONTEXT_PACK\.md)'
JWT_RE='eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
SECRET_ASSIGN_RE='((API_KEY|TOKEN|SECRET|PASSWORD|HA_API_TOKEN)[^=\n]{0,20}[=:][^\n]{8,})'

HITS=0

while IFS= read -r file; do
  [[ -n "${file:-}" && "${file:-}" != "null" ]] || continue
  [[ -f "$file" ]] || continue

  LEGACY_HITS="$(rg -n --pcre2 "$LEGACY_RE" "$file" 2>/dev/null || true)"
  if [[ -n "${LEGACY_HITS:-}" ]]; then
    while IFS= read -r hit; do
      [[ -n "${hit:-}" ]] || continue
      # Contract exception: LEGACY_ROOT is a declared host variable, not a runtime entrypoint.
      if [[ "$file" == "$HOME/.zshrc" ]] && [[ "$hit" == *"export LEGACY_ROOT="* ]]; then
        continue
      fi
      echo "D30 HIT: legacy runtime reference in $file :: $hit" >&2
      HITS=$((HITS + 1))
    done <<< "$LEGACY_HITS"
  fi

  if rg -n --pcre2 "$LEGACY_DOC_RE" "$file" >/dev/null 2>&1; then
    echo "D30 HIT: legacy startup doc reference in $file" >&2
    HITS=$((HITS + 1))
  fi

  if rg -n --pcre2 "$JWT_RE" "$file" >/dev/null 2>&1; then
    echo "D30 HIT: JWT-like plaintext token in $file" >&2
    HITS=$((HITS + 1))
  fi

  if rg -n --pcre2 "$SECRET_ASSIGN_RE" "$file" >/dev/null 2>&1; then
    echo "D30 HIT: plaintext credential assignment in $file" >&2
    HITS=$((HITS + 1))
  fi
done < <(yq e '.active_config_files[]' "$BINDING")

(( HITS == 0 )) || fail "active config lock violated (${HITS} hit(s))"
echo "D30 PASS: active config lock enforced"
