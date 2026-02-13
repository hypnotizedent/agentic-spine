#!/usr/bin/env bash
# TRIAGE: Fix capabilities.yaml metadata. API caps need touches_api + requires fields.
set -euo pipefail

# D63: Capabilities metadata lock
#
# Validates ops/capabilities.yaml integrity:
# - registry headers present (.version, .updated)
# - per-capability required fields + enums
# - requires[] references existing capabilities (typo guard)
# - touches_api=true requires secrets preconditions
# - ./relative command targets exist and are executable
#
# Usage:
#   d63-capabilities-metadata-lock.sh
#   d63-capabilities-metadata-lock.sh --file /path/to/capabilities.yaml

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAP_FILE_DEFAULT="$ROOT/ops/capabilities.yaml"
CAP_FILE="$CAP_FILE_DEFAULT"

fail() { echo "D63 FAIL: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      [[ $# -ge 2 ]] || fail "--file requires a path"
      CAP_FILE="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
d63-capabilities-metadata-lock.sh

Usage:
  d63-capabilities-metadata-lock.sh
  d63-capabilities-metadata-lock.sh --file /path/to/capabilities.yaml
EOF
      exit 0
      ;;
    *)
      fail "unknown arg: $1"
      ;;
  esac
done

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CAP_FILE" ]] || fail "missing file: $CAP_FILE"
yq e '.' "$CAP_FILE" >/dev/null 2>&1 || fail "invalid YAML: $CAP_FILE"

version="$(yq e -r '.version // ""' "$CAP_FILE" 2>/dev/null || true)"
[[ -n "${version:-}" ]] || fail "missing .version"

updated="$(yq e -r '.updated // ""' "$CAP_FILE" 2>/dev/null || true)"
[[ "$updated" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "missing/invalid .updated (YYYY-MM-DD): '${updated:-}'"

mapfile -t caps < <(yq e -r '.capabilities | keys | .[]' "$CAP_FILE" 2>/dev/null || true)
(( ${#caps[@]} > 0 )) || fail "no capabilities found under .capabilities"

declare -A cap_exists
for c in "${caps[@]}"; do
  cap_exists["$c"]=1
done

for cap in "${caps[@]}"; do
  desc="$(yq e -r ".capabilities.\"$cap\".description // \"\"" "$CAP_FILE" 2>/dev/null || true)"
  cmd="$(yq e -r ".capabilities.\"$cap\".command // \"\"" "$CAP_FILE" 2>/dev/null || true)"
  safety="$(yq e -r ".capabilities.\"$cap\".safety // \"\"" "$CAP_FILE" 2>/dev/null || true)"
  approval="$(yq e -r ".capabilities.\"$cap\".approval // \"\"" "$CAP_FILE" 2>/dev/null || true)"

  [[ -n "$desc" ]] || fail "$cap missing required field: description"
  [[ -n "$cmd" ]] || fail "$cap missing required field: command"
  [[ -n "$safety" ]] || fail "$cap missing required field: safety"
  [[ -n "$approval" ]] || fail "$cap missing required field: approval"

  case "$safety" in
    read-only|mutating|destructive) ;;
    *) fail "$cap invalid safety: '$safety' (expected read-only|mutating|destructive)" ;;
  esac

  case "$approval" in
    auto|manual|operator) ;;
    *) fail "$cap invalid approval: '$approval' (expected auto|manual|operator)" ;;
  esac

  outputs_len="$(yq e ".capabilities.\"$cap\".outputs | length" "$CAP_FILE" 2>/dev/null || echo 0)"
  [[ "$outputs_len" =~ ^[0-9]+$ ]] || outputs_len=0
  (( outputs_len > 0 )) || fail "$cap missing/empty required field: outputs"

  # requires[] must reference known capabilities (typo guard)
  while IFS= read -r req; do
    [[ -z "${req:-}" || "$req" == "null" ]] && continue
    [[ -n "${cap_exists[$req]:-}" ]] || fail "$cap requires unknown capability: $req"
  done < <(yq e -r ".capabilities.\"$cap\".requires[]?" "$CAP_FILE" 2>/dev/null || true)

  # touches_api=true must require secrets binding + auth status
  touches_api="$(yq e -r ".capabilities.\"$cap\".touches_api // false" "$CAP_FILE" 2>/dev/null || echo "false")"
  if [[ "$touches_api" == "true" ]]; then
    has_binding=0
    has_auth=0
    while IFS= read -r req; do
      [[ -z "${req:-}" || "$req" == "null" ]] && continue
      [[ "$req" == "secrets.binding" ]] && has_binding=1
      [[ "$req" == "secrets.auth.status" ]] && has_auth=1
    done < <(yq e -r ".capabilities.\"$cap\".requires[]?" "$CAP_FILE" 2>/dev/null || true)
    [[ "$has_binding" == "1" && "$has_auth" == "1" ]] || fail "$cap touches_api=true but missing requires: secrets.binding + secrets.auth.status"
  fi

  # ./relative command first token must exist and be executable
  first_token="$(printf '%s\n' "$cmd" | awk '{print $1}')"
  if [[ "$first_token" == ./* ]]; then
    rel="${first_token#./}"
    abs="$ROOT/$rel"
    [[ -f "$abs" ]] || fail "$cap command target missing: $first_token (resolved: $abs)"
    [[ -x "$abs" ]] || fail "$cap command target not executable: $first_token (resolved: $abs)"
  fi
done

echo "D63 PASS: capabilities metadata valid"

