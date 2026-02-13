#!/usr/bin/env bash
# D58: SSOT freshness lock
# Fails when any SSOT in the registry has a last_reviewed date
# older than SSOT_FRESHNESS_DAYS (default: 21).
#
# Reads: docs/governance/SSOT_REGISTRY.yaml
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY="$SP/docs/governance/SSOT_REGISTRY.yaml"
THRESHOLD="${SSOT_FRESHNESS_DAYS:-21}"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }

parse_epoch_date() {
  local ds="${1:-}"
  [[ -n "$ds" ]] || { echo 0; return; }

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$ds" <<'PY'
import sys
from datetime import datetime, timezone

ds = (sys.argv[1] or "").strip()
try:
    dt = datetime.fromisoformat(ds)
except Exception:
    print(0)
    raise SystemExit(0)

if dt.tzinfo is None:
    dt = dt.replace(tzinfo=timezone.utc)

print(int(dt.timestamp()))
PY
    return
  fi

  if date --version >/dev/null 2>&1; then
    date -d "$ds" +%s 2>/dev/null || echo 0
    return
  fi

  date -j -f "%Y-%m-%d" "$ds" +%s 2>/dev/null || echo 0
}

[[ -f "$REGISTRY" ]] || { err "SSOT_REGISTRY.yaml not found"; exit 1; }
command -v yq >/dev/null 2>&1 || { err "yq not found"; exit 1; }

# Get current date as epoch
NOW=$(date +%s)

# Iterate all SSOTs with last_reviewed
ssot_count=$(yq '.ssots | length' "$REGISTRY")
STALE=0
for ((i=0; i<ssot_count; i++)); do
  id=$(yq -r ".ssots[$i].id" "$REGISTRY")
  reviewed=$(yq -r ".ssots[$i].last_reviewed" "$REGISTRY")

  [[ "$reviewed" == "null" || -z "$reviewed" ]] && continue

  reviewed_epoch=$(parse_epoch_date "$reviewed")

  [[ "$reviewed_epoch" -eq 0 ]] && continue

  age_days=$(( (NOW - reviewed_epoch) / 86400 ))
  if [[ "$age_days" -gt "$THRESHOLD" ]]; then
    err "$id: last_reviewed=$reviewed (${age_days}d ago, threshold=${THRESHOLD}d)"
    STALE=$((STALE + 1))
  fi
done

if [[ "$STALE" -gt 0 ]]; then
  echo "  $STALE SSOTs exceed freshness threshold of ${THRESHOLD} days" >&2
fi

# Second pass: authoritative governance docs with missing/stale last_verified
GOV_DIR="$SP/docs/governance"
MISSING_LV=0
STALE_LV=0
if [[ -d "$GOV_DIR" ]]; then
  while IFS= read -r docfile; do
    # Extract status from frontmatter (first 10 lines)
    doc_status=$(head -10 "$docfile" | grep -E '^status:\s' | head -1 | sed 's/^status:\s*//' | tr -d '"' | tr -d "'" | xargs 2>/dev/null || true)
    [[ "$doc_status" == "authoritative" ]] || continue

    lv=$(head -15 "$docfile" | grep -E '^last_verified:\s' | head -1 | sed 's/^last_verified:\s*//' | tr -d '"' | tr -d "'" | xargs 2>/dev/null || true)
    basename_doc=$(basename "$docfile")

    if [[ -z "$lv" || "$lv" == "null" ]]; then
      echo "  WARN: $basename_doc (authoritative) missing last_verified" >&2
      MISSING_LV=$((MISSING_LV + 1))
      continue
    fi

    lv_epoch=$(parse_epoch_date "$lv")
    [[ "$lv_epoch" -eq 0 ]] && continue

    lv_age=$(( (NOW - lv_epoch) / 86400 ))
    if [[ "$lv_age" -gt "$THRESHOLD" ]]; then
      err "$basename_doc: last_verified=$lv (${lv_age}d ago, threshold=${THRESHOLD}d)"
      STALE_LV=$((STALE_LV + 1))
    fi
  done < <(find "$GOV_DIR" -maxdepth 1 -name '*.md' -type f | sort)

  if [[ "$MISSING_LV" -gt 0 ]]; then
    echo "  $MISSING_LV authoritative docs missing last_verified (warning only)" >&2
  fi
  if [[ "$STALE_LV" -gt 0 ]]; then
    echo "  $STALE_LV authoritative docs exceed freshness threshold" >&2
  fi
fi

# Third pass: binding files with updated: field (non-exempt only)
BINDINGS_DIR="$SP/ops/bindings"
EXEMPTIONS_FILE="$BINDINGS_DIR/binding.freshness.exemptions.yaml"
STALE_BIND=0

if [[ -d "$BINDINGS_DIR" && -f "$EXEMPTIONS_FILE" ]]; then
  # Build exempt file list
  exempt_files=""
  if command -v yq >/dev/null 2>&1; then
    exempt_count=$(yq '.exempt | length' "$EXEMPTIONS_FILE")
    for ((j=0; j<exempt_count; j++)); do
      ef=$(yq -r ".exempt[$j].file" "$EXEMPTIONS_FILE")
      exempt_files="$exempt_files|$ef"
    done
  fi

  for binding in "$BINDINGS_DIR"/*.yaml; do
    [[ -f "$binding" ]] || continue
    bname=$(basename "$binding")

    # Skip the exemptions file itself
    [[ "$bname" == "binding.freshness.exemptions.yaml" ]] && continue

    # Skip exempt files
    if echo "$exempt_files" | grep -qF "|$bname"; then
      continue
    fi

    # Extract updated: from first 20 lines (top-level field)
    bind_updated=$(head -20 "$binding" | grep -E '^updated:\s' | head -1 | sed 's/^updated:\s*//' | tr -d '"' | tr -d "'" | xargs 2>/dev/null || true)
    [[ -z "$bind_updated" || "$bind_updated" == "null" ]] && continue

    bind_epoch=$(parse_epoch_date "$bind_updated")
    [[ "$bind_epoch" -eq 0 ]] && continue

    bind_age=$(( (NOW - bind_epoch) / 86400 ))
    if [[ "$bind_age" -gt "$THRESHOLD" ]]; then
      err "$bname: updated=$bind_updated (${bind_age}d ago, threshold=${THRESHOLD}d)"
      STALE_BIND=$((STALE_BIND + 1))
    fi
  done

  if [[ "$STALE_BIND" -gt 0 ]]; then
    echo "  $STALE_BIND normative bindings exceed freshness threshold" >&2
  fi
fi

exit "$FAIL"
