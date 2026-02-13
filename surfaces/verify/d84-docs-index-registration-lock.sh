#!/usr/bin/env bash
# D84: Docs index registration lock
#
# Fails if:
# - Any .md file in docs/governance/ (excluding _audits/ and _imported/) is
#   missing from docs/governance/_index.yaml
# - Any .md file referenced in _index.yaml does not exist on disk
#
# Reads: docs/governance/_index.yaml
#        docs/governance/*.md
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INDEX="$SP/docs/governance/_index.yaml"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }

[[ -f "$INDEX" ]] || { err "_index.yaml not found"; exit 1; }
command -v yq >/dev/null 2>&1 || { err "yq not found"; exit 1; }

# Extract all file entries from _index.yaml (documents section only)
# Keep raw paths for phantom check; create basename list for registration check
indexed_raw=$(yq -r '.documents[].file' "$INDEX" 2>/dev/null | sort -u)
indexed_files=$(echo "$indexed_raw" | xargs -I{} basename {} | sort -u)

# List actual .md files in docs/governance/ (excluding subdirs _audits/ _imported/)
actual_files=$(find "$SP/docs/governance" -maxdepth 1 -name '*.md' -exec basename {} \; | sort -u)

# Check: every actual file must be in index
MISSING=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if ! echo "$indexed_files" | grep -qF "$f"; then
    err "governance doc '$f' not registered in _index.yaml"
    MISSING=$((MISSING + 1))
  fi
done <<< "$actual_files"

# Check: every indexed file must exist on disk (resolve relative paths)
PHANTOM=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # Resolve relative paths from docs/governance/
  if [[ "$f" == ../* ]]; then
    resolved="$SP/docs/governance/$f"
  else
    resolved="$SP/docs/governance/$f"
  fi
  resolved=$(cd "$(dirname "$resolved")" 2>/dev/null && echo "$(pwd)/$(basename "$resolved")" || echo "$resolved")
  if [[ ! -f "$resolved" ]]; then
    err "indexed file '$f' does not exist (resolved: $resolved)"
    PHANTOM=$((PHANTOM + 1))
  fi
done <<< "$indexed_raw"

if [[ "$MISSING" -gt 0 ]]; then
  echo "  $MISSING unregistered governance doc(s)" >&2
fi
if [[ "$PHANTOM" -gt 0 ]]; then
  echo "  $PHANTOM phantom index entries" >&2
fi

exit "$FAIL"
