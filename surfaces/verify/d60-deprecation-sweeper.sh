#!/usr/bin/env bash
# TRIAGE: Replace deprecated terms in governance docs. Check ops/bindings/deprecated.terms.yaml.
# D60: Deprecation sweeper
# Greps governance docs for known deprecated terms.
# Fails if any deprecated term is found outside exclusions.
#
# Reads: ops/bindings/deprecated.terms.yaml
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$SP/ops/bindings/deprecated.terms.yaml"

FAIL=0
err() { echo "  D60 FAIL: $1" >&2; FAIL=1; }

[[ -f "$BINDING" ]] || { err "deprecated.terms.yaml not found"; exit 1; }
command -v yq >/dev/null 2>&1 || { err "yq not found"; exit 1; }

term_count=$(yq '.terms | length' "$BINDING")
scan_paths=$(yq -r '.scan_paths[]' "$BINDING" | sed "s|^|$SP/|")
scan_exclude=$(yq -r '.scan_exclude[]' "$BINDING" 2>/dev/null | sed "s|^|$SP/|" || true)

HITS=0
for ((i=0; i<term_count; i++)); do
  pattern=$(yq -r ".terms[$i].pattern" "$BINDING")

  # Build rg exclude args from per-term exclude_files
  exclude_count=$(yq ".terms[$i].exclude_files | length" "$BINDING" 2>/dev/null || echo 0)
  EXCLUDE_ARGS=""
  for ((j=0; j<exclude_count; j++)); do
    ef=$(yq -r ".terms[$i].exclude_files[$j]" "$BINDING")
    EXCLUDE_ARGS="$EXCLUDE_ARGS --glob=!$ef"
  done

  # Build global scan exclude args
  GLOBAL_EXCLUDE=""
  for ex in $scan_exclude; do
    rel="${ex#$SP/}"
    GLOBAL_EXCLUDE="$GLOBAL_EXCLUDE --glob=!${rel}**"
  done

  # Search across all scan paths
  for sp in $scan_paths; do
    [[ -d "$sp" ]] || continue
    # Use rg for fast search; suppress errors for missing paths
    matches=$(cd "$SP" && rg --files-with-matches --fixed-strings "$pattern" "${sp#$SP/}" $EXCLUDE_ARGS $GLOBAL_EXCLUDE 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      while IFS= read -r file; do
        err "deprecated term '$pattern' found in $file"
        HITS=$((HITS + 1))
      done <<< "$matches"
    fi
  done
done

if [[ "$HITS" -gt 0 ]]; then
  echo "  $HITS deprecated term occurrences found" >&2
fi

if [[ "$FAIL" -eq 1 ]]; then
  echo "D60 FAIL: deprecated term violations detected" >&2
  exit 1
fi
echo "D60 PASS: deprecation sweeper clean ($term_count terms checked)"
exit 0
