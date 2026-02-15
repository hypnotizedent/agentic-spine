#!/usr/bin/env bash
# contract-read-check — Enforce/inspect environment contract acknowledgement.
set -euo pipefail

CONTRACT_FILE="${CONTRACT_FILE:-.environment.yaml}"
STATUS_ONLY=0
ACK=0

usage() {
  cat <<'EOF'
Usage:
  contract-read-check.sh [--contract-file <path>] [--status] [--ack]

Modes:
  default  Enforce acknowledgement marker is newer than contract.
  --status Print current contract/marker state only.
  --ack    Create today's acknowledgement marker.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --contract-file) CONTRACT_FILE="${2:-}"; shift 2 ;;
    --status) STATUS_ONLY=1; shift ;;
    --ack) ACK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

MARKER_FILE=".contract_read_$(date +%Y%m%d)"

mtime() {
  local f="$1"
  stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0
}

[[ -f "$CONTRACT_FILE" ]] || { echo "ERROR: contract not found: $CONTRACT_FILE" >&2; exit 1; }

if [[ "$ACK" -eq 1 ]]; then
  touch "$MARKER_FILE"
  echo "ACKNOWLEDGED: $MARKER_FILE"
  exit 0
fi

CONTRACT_MTIME="$(mtime "$CONTRACT_FILE")"
MARKER_MTIME=0
if [[ -f "$MARKER_FILE" ]]; then
  MARKER_MTIME="$(mtime "$MARKER_FILE")"
fi

TIER="$(yq -r '.environment.tier // "unknown"' "$CONTRACT_FILE" 2>/dev/null || echo unknown)"

if [[ "$STATUS_ONLY" -eq 1 ]]; then
  echo "AOF Contract Status"
  echo "  contract_file: $CONTRACT_FILE"
  echo "  tier:          $TIER"
  echo "  marker_file:   $MARKER_FILE"
  if [[ -f "$MARKER_FILE" && "$MARKER_MTIME" -ge "$CONTRACT_MTIME" ]]; then
    echo "  marker_state:  current"
    exit 0
  fi
  if [[ -f "$MARKER_FILE" ]]; then
    echo "  marker_state:  stale"
  else
    echo "  marker_state:  missing"
  fi
  exit 0
fi

if [[ -f "$MARKER_FILE" && "$MARKER_MTIME" -ge "$CONTRACT_MTIME" ]]; then
  echo "OK: contract acknowledgement is current"
  exit 0
fi

echo "ENVIRONMENT CONTRACT READING REQUIRED"
echo ""
cat "$CONTRACT_FILE"
echo ""
echo "Tier: $TIER"
echo "To acknowledge:"
echo "  ./ops/plugins/aof/bin/contract-read-check.sh --ack"
echo ""
echo "Mutating actions should be blocked until acknowledged."
exit 2
