#!/usr/bin/env bash
set -euo pipefail

# D42: Code path case lock
# Fails if runtime .sh scripts or execution YAML fields reference
# the uppercase variant of the code directory instead of lowercase.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

HITS=0

# Scan runtime shell scripts (non-comment lines only)
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  # Skip self (this gate script)
  [[ "$file" == *"d42-code-path-case-lock.sh" ]] && continue
  # Match lines with uppercase Code path, excluding comments
  MATCHES="$(grep -n 'Home/Code\|HOME/Code\|ronnyworks/Code' "$file" 2>/dev/null \
    | grep -v '^\s*#' \
    | grep -v '\.archive/' \
    | grep -v 'docs/' \
    | grep -v 'receipts/' || true)"
  if [[ -n "$MATCHES" ]]; then
    while IFS= read -r line; do
      echo "D42 HIT: uppercase Code path in $file :: $line" >&2
      HITS=$((HITS + 1))
    done <<< "$MATCHES"
  fi
done < <(find "$ROOT/bin" "$ROOT/ops" "$ROOT/surfaces/verify" -name "*.sh" -type f 2>/dev/null)

# Scan capabilities.yaml cwd and command fields only
CAP_FILE="$ROOT/ops/capabilities.yaml"
if [[ -f "$CAP_FILE" ]]; then
  MATCHES="$(grep -nE '^\s*(cwd|command):' "$CAP_FILE" 2>/dev/null \
    | grep 'Code' || true)"
  if [[ -n "$MATCHES" ]]; then
    while IFS= read -r line; do
      echo "D42 HIT: uppercase Code path in $CAP_FILE :: $line" >&2
      HITS=$((HITS + 1))
    done <<< "$MATCHES"
  fi
fi

if (( HITS > 0 )); then
  echo "D42 FAIL: $HITS uppercase Code path reference(s) in runtime scripts" >&2
  exit 1
fi

echo "D42 PASS: code path case lock enforced"
