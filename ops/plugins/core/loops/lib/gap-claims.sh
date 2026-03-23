#!/usr/bin/env bash
# gap-claims.sh — Shared library for gap claim semantics
#
# Provides functions to claim/unclaim gaps for exclusive work.
# Claims are advisory runtime markers (NOT committed to git).
# They prevent concurrent agents from working on the same gap.
#
# Claim file format (key=value):
#   gap_id=GAP-OP-NNN
#   owner_pid=12345
#   claimed_at=2026-02-12T18:30:00Z
#   action=closing gap
#
# Usage: source this file, then call functions.

GAP_CLAIMS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../" && pwd)"
# Derive the repo root from the library location so clean clones and worktrees
# do not inherit a different checkout's gap registry through ambient SPINE_REPO.
SPINE_REPO="$GAP_CLAIMS_ROOT"
CLAIMS_DIR="${SPINE_STATE:-$HOME/code/.runtime/spine/state}/gaps"
GAPS_FILE="${GAP_CLAIMS_ROOT}/ops/bindings/operational.gaps.yaml"
GAPS_BRIDGE="${GAP_CLAIMS_ROOT}/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"

command -v yq >/dev/null 2>&1 || { echo "ERROR: yq required" >&2; exit 1; }

_ensure_claims_dir() {
  mkdir -p "$CLAIMS_DIR"
}

# Query gap from SQLite authority via bridge. Returns JSON on stdout.
# Falls back to YAML if bridge is unavailable (bootstrap safety).
_bridge_query_gap() {
  local gap_id="$1"
  local result
  if result="$(python3 "$GAPS_BRIDGE" query --id "$gap_id" 2>/dev/null)"; then
    printf '%s' "$result"
    return 0
  fi
  # Fallback: read from YAML projection if bridge unavailable
  local count
  count=$(yq e "[.gaps[] | select(.id == \"$gap_id\")] | length" "$GAPS_FILE" 2>/dev/null)
  if [[ "$count" -gt 0 ]]; then
    local status severity reg_lock
    status=$(yq e ".gaps[] | select(.id == \"$gap_id\") | .status" "$GAPS_FILE" 2>/dev/null)
    severity=$(yq e ".gaps[] | select(.id == \"$gap_id\") | .severity" "$GAPS_FILE" 2>/dev/null)
    reg_lock=$(yq e ".gaps[] | select(.id == \"$gap_id\") | .regression_lock_id // \"\"" "$GAPS_FILE" 2>/dev/null)
    printf '{"exists":true,"gap_id":"%s","status":"%s","severity":"%s","regression_lock_id":"%s"}' \
      "$gap_id" "$status" "$severity" "$reg_lock"
  else
    printf '{"exists":false,"gap_id":"%s"}' "$gap_id"
  fi
}

# Check if a gap exists at all (SQLite authority, YAML fallback)
gap_exists() {
  local gap_id="$1"
  local result
  result="$(_bridge_query_gap "$gap_id")"
  local exists
  exists="$(printf '%s' "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('exists',False))" 2>/dev/null || echo "False")"
  [[ "$exists" == "True" ]]
}

# Check if a gap exists and is open (SQLite authority, YAML fallback)
gap_is_open() {
  local gap_id="$1"
  local result
  result="$(_bridge_query_gap "$gap_id")"
  local status
  status="$(printf '%s' "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")"
  [[ "$status" == "open" ]]
}

# Query gap field from SQLite authority (used by gaps-close for severity/lock checks)
gap_query_field() {
  local gap_id="$1"
  local field="$2"
  local result
  result="$(_bridge_query_gap "$gap_id")"
  printf '%s' "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('$field',''))" 2>/dev/null || echo ""
}

# Get claim file path
claim_file() {
  echo "${CLAIMS_DIR}/${1}.claim"
}

# Check if a gap is currently claimed (non-stale)
is_claimed() {
  local gap_id="$1"
  local cf
  cf=$(claim_file "$gap_id")
  [[ -f "$cf" ]] || return 1
  local pid
  pid=$(_read_claim_field "$cf" "owner_pid")
  [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1
}

# Read a field from a claim file
_read_claim_field() {
  local file="$1" field="$2"
  awk -F= -v f="$field" '$1==f{print $2; exit}' "$file" 2>/dev/null
}

# Get claim owner PID
get_claim_pid() {
  local gap_id="$1"
  local cf
  cf=$(claim_file "$gap_id")
  [[ -f "$cf" ]] || return 1
  _read_claim_field "$cf" "owner_pid"
}

# Claim a gap for the current process
claim_gap() {
  local gap_id="$1"
  local action="${2:-unspecified}"

  _ensure_claims_dir

  local cf
  cf=$(claim_file "$gap_id")

  # Check for existing claim
  if [[ -f "$cf" ]]; then
    local existing_pid
    existing_pid=$(_read_claim_field "$cf" "owner_pid")
    if [[ -n "$existing_pid" ]] && ps -p "$existing_pid" >/dev/null 2>&1; then
      echo "STOP: $gap_id already claimed by PID $existing_pid" >&2
      return 1
    fi
    # Stale claim — clean up
    echo "WARN: Recovering stale claim on $gap_id (PID $existing_pid dead)" >&2
    rm -f "$cf"
  fi

  # Write claim
  cat > "$cf" <<EOF
gap_id=$gap_id
owner_pid=$$
claimed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
action=$action
EOF

  return 0
}

# Release a claim
unclaim_gap() {
  local gap_id="$1"
  local cf
  cf=$(claim_file "$gap_id")

  if [[ ! -f "$cf" ]]; then
    echo "WARN: No claim exists for $gap_id" >&2
    return 0
  fi

  local owner_pid
  owner_pid=$(_read_claim_field "$cf" "owner_pid")
  if [[ "$owner_pid" != "$$" ]]; then
    # Allow unclaim if PID is dead (stale)
    if ps -p "$owner_pid" >/dev/null 2>&1; then
      echo "STOP: Cannot unclaim $gap_id — owned by PID $owner_pid (still running)" >&2
      return 1
    fi
  fi

  rm -f "$cf"
  return 0
}

# Verify current process owns the claim (or no claim exists = Terminal C direct)
verify_claim_ownership() {
  local gap_id="$1"
  local cf
  cf=$(claim_file "$gap_id")

  if [[ ! -f "$cf" ]]; then
    # No claim = Terminal C direct mode (allowed)
    return 0
  fi

  local owner_pid
  owner_pid=$(_read_claim_field "$cf" "owner_pid")

  if [[ "$owner_pid" == "$$" ]]; then
    return 0
  fi

  # Check if owner is dead (stale claim)
  if ! ps -p "$owner_pid" >/dev/null 2>&1; then
    echo "WARN: Stale claim on $gap_id (PID $owner_pid dead) — proceeding" >&2
    rm -f "$cf"
    return 0
  fi

  echo "STOP: $gap_id claimed by PID $owner_pid — cannot mutate without ownership" >&2
  return 1
}

# Clean up all stale claims. Prints count of cleaned claims.
cleanup_stale_claims() {
  _ensure_claims_dir
  local cleaned=0
  for cf in "$CLAIMS_DIR"/*.claim; do
    [[ -f "$cf" ]] || continue
    local pid
    pid=$(_read_claim_field "$cf" "owner_pid")
    if [[ -n "$pid" ]] && ! ps -p "$pid" >/dev/null 2>&1; then
      local gap_id
      gap_id=$(_read_claim_field "$cf" "gap_id")
      echo "Cleaned stale claim: $gap_id (PID $pid)" >&2
      rm -f "$cf"
      cleaned=$((cleaned + 1))
    fi
  done
  echo "$cleaned"
}
