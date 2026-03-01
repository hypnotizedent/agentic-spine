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
mapfile -t scan_paths < <(yq -r '.scan_paths[]' "$BINDING" 2>/dev/null || true)
mapfile -t scan_exclude < <(yq -r '.scan_exclude[]' "$BINDING" 2>/dev/null || true)

normalize_rel_path() {
  local p="${1:-}"
  p="${p#./}"
  echo "$p"
}

exclude_glob_from_rel_path() {
  local rel
  rel="$(normalize_rel_path "${1:-}")"
  if [[ "$rel" == */ ]]; then
    # Directory-style entry: exclude all descendants.
    echo "!${rel}**"
  else
    echo "!${rel}"
  fi
}

HITS=0
for ((i=0; i<term_count; i++)); do
  pattern=$(yq -r ".terms[$i].pattern" "$BINDING")

  # Build rg exclude args from per-term exclude_files.
  term_exclude_args=()
  mapfile -t term_excludes < <(yq -r ".terms[$i].exclude_files[]?" "$BINDING" 2>/dev/null || true)
  for ef in "${term_excludes[@]}"; do
    [[ -n "$ef" ]] || continue
    term_exclude_args+=(--glob "$(exclude_glob_from_rel_path "$ef")")
  done

  # Build global scan exclude args.
  global_exclude_args=()
  for ex in "${scan_exclude[@]}"; do
    [[ -n "$ex" ]] || continue
    global_exclude_args+=(--glob "$(exclude_glob_from_rel_path "$ex")")
  done

  # Search across all scan paths.
  for scan_path in "${scan_paths[@]}"; do
    rel_scan_path="$(normalize_rel_path "$scan_path")"
    rel_scan_path="${rel_scan_path%/}"
    [[ -n "$rel_scan_path" ]] || continue
    [[ -d "$SP/$rel_scan_path" ]] || continue

    # Use rg for fast search; suppress missing-path noise.
    matches="$(cd "$SP" && rg --no-messages --files-with-matches --fixed-strings "$pattern" "$rel_scan_path" "${term_exclude_args[@]}" "${global_exclude_args[@]}" || true)"
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
