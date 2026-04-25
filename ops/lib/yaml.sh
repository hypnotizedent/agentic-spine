#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# yaml.sh - Canonical YAML query helper (yq → jq bridge)
# ═══════════════════════════════════════════════════════════════
#
# Solves the "boolean false trap" and null-coalescing surprises in yq:
#   - yq e '.field // ""' returns "" for false values (wrong!)
#   - yq -r '.field // ""' has same issue
#
# Usage:
#   yaml_query <file> <jq_expression>
#   yaml_query -e <file> <jq_expression>   # existence check (exit 0/1)
#
# Design:
#   1. yq -o=json converts YAML to JSON (preserves types)
#   2. jq evaluates the expression with proper type handling
#   3. Normalizes null → "" for string fields
#   4. Preserves boolean false literally (no conversion)
#   5. -e flag: returns 0 if value exists and is not null, 1 otherwise
#
# Examples:
#   # Read a string field (null becomes "")
#   yaml_query "$file" '.services.myapp.host'
#
#   # Read with default value
#   yaml_query "$file" '.services.myapp.port // 8080'
#
#   # Check if field exists (exit code)
#   if yaml_query -e "$file" '.services.myapp'; then ...
#
#   # Boolean field (preserves false literally)
#   enabled=$(yaml_query "$file" '.features.enabled')
#   if [[ "$enabled" == "true" ]]; then ...
#
# POSIX-compatible (macOS bash 3.2 safe)
# ═══════════════════════════════════════════════════════════════

set -eo pipefail

# ── Dependency check ──
_yaml_query_check_deps() {
  if ! command -v yq >/dev/null 2>&1; then
    echo "ERROR: yq required for YAML parsing" >&2
    echo "Install: brew install yq" >&2
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq required for JSON processing" >&2
    echo "Install: brew install jq" >&2
    return 1
  fi
}

# ── Core query function ──
# Usage: _yaml_query_core <file> <expr> [mode]
# mode: "value" (default) or "exists"
_yaml_query_core() {
  local file="$1"
  local expr="$2"
  local mode="${3:-value}"

  if [[ ! -f "$file" ]]; then
    echo "ERROR: File not found: $file" >&2
    return 1
  fi

  local json_result
  json_result="$(yq -o=json "$expr" "$file" 2>/dev/null)" || {
    # yq failed - likely invalid expression or file
    if [[ "$mode" == "exists" ]]; then
      return 1
    fi
    echo ""
    return 0
  }

  if [[ "$mode" == "exists" ]]; then
    # Existence check: return 0 if value is not null, 1 otherwise
    if [[ "$json_result" == "null" ]] || [[ -z "$json_result" ]]; then
      return 1
    fi
    return 0
  fi

  # Value mode: normalize output
  # - null → ""
  # - boolean true/false → "true"/"false" (preserved)
  # - numbers → as-is
  # - strings → unquoted
  local output
  output="$(echo "$json_result" | jq -r '
    if . == null then
      ""
    elif type == "boolean" then
      if . then "true" else "false" end
    elif type == "number" then
      . | tostring
    elif type == "string" then
      .
    elif type == "array" or type == "object" then
      . | tojson
    else
      . | tostring
    end
  ' 2>/dev/null)" || output=""

  echo "$output"
}

# ── Public interface ──
# yaml_query <file> <expr>
# yaml_query -e <file> <expr>
yaml_query() {
  _yaml_query_check_deps || return 1

  local mode="value"
  local file=""
  local expr=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--exists)
        mode="exists"
        shift
        ;;
      -h|--help)
        cat <<'EOF'
yaml_query - Canonical YAML query helper

Usage:
  yaml_query <file> <jq_expression>
  yaml_query -e <file> <jq_expression>   # existence check (exit 0/1)

Examples:
  yaml_query config.yaml '.services.api.host'
  yaml_query config.yaml '.services.api.port // 8080'
  yaml_query -e config.yaml '.services.api'

Design:
  - Uses yq -o=json | jq for reliable type handling
  - Normalizes null → "" for string fields
  - Preserves boolean false literally (no "false → empty" trap)
  - POSIX-compatible (bash 3.2 safe)
EOF
        return 0
        ;;
      *)
        if [[ -z "$file" ]]; then
          file="$1"
        elif [[ -z "$expr" ]]; then
          expr="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$file" ]] || [[ -z "$expr" ]]; then
    echo "ERROR: Usage: yaml_query [-e] <file> <expression>" >&2
    return 1
  fi

  _yaml_query_core "$file" "$expr" "$mode"
}

# ── Convenience wrappers for common patterns ──

# yaml_get <file> <path> [default]
# Reads a value from a YAML file at the given path, with optional default.
# Path uses dot notation: "services.api.host"
yaml_get() {
  local file="$1"
  local path="$2"
  local default="${3:-}"

  _yaml_query_check_deps || return 1

  # Convert dot path to jq expression
  local expr=".$(echo "$path" | sed 's/\./\./g')"

  local val
  val="$(yaml_query "$file" "$expr")"

  if [[ -z "$val" ]]; then
    echo "$default"
  else
    echo "$val"
  fi
}

# yaml_has <file> <path>
# Returns 0 if the path exists and is not null, 1 otherwise.
yaml_has() {
  local file="$1"
  local path="$2"

  _yaml_query_check_deps || return 1

  # Convert dot path to jq expression
  local expr=".$(echo "$path" | sed 's/\./\./g')"

  yaml_query -e "$file" "$expr"
}

# yaml_bool <file> <path>
# Returns "true" or "false" (string) for boolean fields.
# Defaults to "false" if path doesn't exist.
yaml_bool() {
  local file="$1"
  local path="$2"

  _yaml_query_check_deps || return 1

  # Convert dot path to jq expression
  local expr=".$(echo "$path" | sed 's/\./\./g')"

  local val
  val="$(yaml_query "$file" "$expr")"

  if [[ "$val" == "true" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# yaml_list <file> <path>
# Returns list items as newline-separated output.
# For arrays, outputs each element on its own line.
yaml_list() {
  local file="$1"
  local path="$2"

  _yaml_query_check_deps || return 1

  # Convert dot path to jq expression
  local expr=".$(echo "$path" | sed 's/\./\./g')"

  local json_result
  json_result="$(yq -o=json "$expr" "$file" 2>/dev/null)" || return 1

  if [[ "$json_result" == "null" ]] || [[ -z "$json_result" ]]; then
    return 0
  fi

  echo "$json_result" | jq -r '
    if type == "array" then
      .[]
    elif type == "object" then
      to_entries[] | "\(.key): \(.value)"
    else
      .
    end
  ' 2>/dev/null || true
}
