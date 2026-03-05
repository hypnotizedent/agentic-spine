#!/usr/bin/env bash
# TRIAGE: Check EXTRACTION_PROTOCOL.md compliance. Extraction queue must be clean.
set -euo pipefail

# D38: Service Extraction Hygiene Lock
# Purpose: Enforce EXTRACTION_PROTOCOL.md classification rules.
#
# Checks:
#   1. No utility sprawl: Services in SERVICE_REGISTRY shouldn't have
#      dedicated docs/<service>/ folders (utilities use registries only)
#   2. Pillar completeness: Any docs/pillars/<name>/ must have:
#      - README.md
#      - ARCHITECTURE.md
#      - EXTRACTION_STATUS.md
#   3. Stack binding hygiene: Stacks marked as "stack" classification
#      should have ops/bindings/<stack>.binding.yaml
#
# Fails on:
#   - docs/<service>/ folder exists for a SERVICE_REGISTRY service
#   - docs/pillars/<name>/ missing required files
#   - Stack classification without binding file
#
# Optional test overrides:
#   D38_SERVICE_REGISTRY=/tmp/SERVICE_REGISTRY.yaml
#   D38_STACK_REGISTRY=/tmp/STACK_REGISTRY.yaml

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICE_REG="${D38_SERVICE_REGISTRY:-$ROOT/docs/governance/SERVICE_REGISTRY.yaml}"
STACK_REG="${D38_STACK_REGISTRY:-$ROOT/docs/governance/STACK_REGISTRY.yaml}"

fail() { echo "D38 FAIL: $*" >&2; exit 1; }

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool yq

FAIL_COUNT=0

# Check 1: No utility sprawl
# Services in SERVICE_REGISTRY shouldn't have dedicated docs/<service>/ folders
echo "Checking utility sprawl (no docs/<service>/ for registry services)..."

if [[ -f "$SERVICE_REG" ]]; then
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue

        # Check for docs/<service>/ folder (case-insensitive match)
        for docs_folder in "$ROOT"/docs/*/; do
            folder_name="$(basename "$docs_folder")"

            # Skip allowed folders
            case "$folder_name" in
                core|governance|legacy|brain|pillars) continue ;;
            esac

            # Check if folder name matches service (case-insensitive)
            if [[ "${folder_name,,}" == "${service,,}" ]]; then
                echo "  SPRAWL: docs/$folder_name/ exists for utility service '$service'"
                echo "         (utilities should only use registry entries, not dedicated folders)"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        done
    done < <(yq e '.services | keys | .[]' "$SERVICE_REG" 2>/dev/null)
else
    echo "  WARN: SERVICE_REGISTRY.yaml not found (skipping utility sprawl check)"
fi

# Check 2: Pillar completeness
# Any docs/pillars/<name>/ must have required files
echo "Checking pillar completeness..."

PILLARS_DIR="$ROOT/docs/pillars"
if [[ -d "$PILLARS_DIR" ]]; then
    for pillar_dir in "$PILLARS_DIR"/*/; do
        [[ ! -d "$pillar_dir" ]] && continue

        pillar_name="$(basename "$pillar_dir")"

        # Check for required files
        for required_file in README.md ARCHITECTURE.md EXTRACTION_STATUS.md; do
            if [[ ! -f "$pillar_dir/$required_file" ]]; then
                echo "  INCOMPLETE: docs/pillars/$pillar_name/ missing $required_file"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        done
    done

    # If no pillars exist, that's fine
    pillar_count=$(find "$PILLARS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$pillar_count" -eq 0 ]]; then
        echo "  OK: No pillar folders exist (no completeness check needed)"
    fi
else
    echo "  OK: No docs/pillars/ directory (no completeness check needed)"
fi

# Check 3: Stack classification hygiene (optional)
# If a stack has classification: stack, it should have a binding file
# Note: This check is advisory; classification field is optional
echo "Checking stack binding hygiene..."

if [[ -f "$STACK_REG" ]]; then
    while IFS= read -r stack_id; do
        [[ -z "$stack_id" ]] && continue

        classification="$(yq e ".stacks[] | select(.stack_id == \"$stack_id\") | .classification // \"unknown\"" "$STACK_REG" 2>/dev/null)"

        # Only check stacks explicitly marked as "stack" classification
        if [[ "$classification" == "stack" ]]; then
            binding_file="$ROOT/ops/bindings/${stack_id}.binding.yaml"
            if [[ ! -f "$binding_file" ]]; then
                echo "  MISSING: $stack_id has classification=stack but no binding file"
                echo "           Expected: ops/bindings/${stack_id}.binding.yaml"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        fi
    done < <(yq e '.stacks[].stack_id' "$STACK_REG" 2>/dev/null)
else
    echo "  WARN: STACK_REGISTRY.yaml not found (skipping stack binding check)"
fi

(( FAIL_COUNT == 0 )) || fail "extraction hygiene violated (${FAIL_COUNT} issue(s))"
echo "D38 PASS: service extraction hygiene enforced"
