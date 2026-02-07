#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# ops ai - Bundle governance docs for AI agents
# ═══════════════════════════════════════════════════════════════
#
# Usage:
#   ops ai                        List what's in the manifest
#   ops ai --bundle               Bundle session + core (default)
#   ops ai --bundle builder       Bundle for builder lane
#   ops ai --bundle runner        Bundle for runner lane
#   ops ai --bundle clerk         Bundle for clerk lane
#   ops ai --validate             Check all paths exist
#   ops ai --clipboard            Bundle and copy to clipboard
#   ops ai --print                Bundle and print to stdout
#
# The manifest (infrastructure/GOVERNANCE_MANIFEST.yaml) defines:
#   - Categories: session, core, infrastructure, mint_os, etc.
#   - Bundles: named combos like "builder" that include multiple categories
#
# NO yq required - uses grep/sed for simplicity
# ═══════════════════════════════════════════════════════════════

set -eo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || true)}"
if [[ -z "${REPO_ROOT:-}" ]]; then
  echo "ERROR: REPO_ROOT not set and not in a git repo." >&2
  echo "Run from inside agentic-spine or set REPO_ROOT=$HOME/code/agentic-spine" >&2
  exit 1
fi
MANIFEST="$REPO_ROOT/infrastructure/GOVERNANCE_MANIFEST.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

die() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }

[[ -f "$MANIFEST" ]] || die "Manifest not found: $MANIFEST"

# ─────────────────────────────────────────────────────────────────
# Parse YAML without yq (simple line-based parsing)
# ─────────────────────────────────────────────────────────────────

# Get all paths from a category (e.g., "session", "core")
get_category_paths() {
  local category="$1"
  local in_category=false

  while IFS= read -r line; do
    # Start of our category
    if [[ "$line" =~ ^${category}: ]]; then
      in_category=true
      continue
    fi

    # Another top-level key (not indented) = end of our category
    if $in_category && [[ "$line" =~ ^[a-z_]+: ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
      break
    fi

    # Array item in our category
    if $in_category && [[ "$line" =~ ^[[:space:]]*-[[:space:]](.+)$ ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  done < "$MANIFEST"
}

# Get bundle definition (which categories to include)
get_bundle_includes() {
  local bundle="$1"
  local in_bundle=false
  local in_include=false

  while IFS= read -r line; do
    # Find the bundle
    if [[ "$line" =~ ^[[:space:]]+${bundle}: ]]; then
      in_bundle=true
      continue
    fi

    # Another bundle = end
    if $in_bundle && [[ "$line" =~ ^[[:space:]]{2}[a-z_]+: ]] && [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
      break
    fi

    # Include section
    if $in_bundle && [[ "$line" =~ include: ]]; then
      in_include=true
      continue
    fi

    # Extra section = end of include
    if $in_bundle && [[ "$line" =~ extra: ]]; then
      in_include=false
    fi

    # Category in include list
    if $in_bundle && $in_include && [[ "$line" =~ ^[[:space:]]*-[[:space:]](.+)$ ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  done < "$MANIFEST"
}

# ─────────────────────────────────────────────────────────────────
# Bundle functions
# ─────────────────────────────────────────────────────────────────

bundle_category() {
  local category="$1"
  local paths
  paths=$(get_category_paths "$category")

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    local full="$REPO_ROOT/$path"
    if [[ -f "$full" ]]; then
      echo ""
      echo "═══════════════════════════════════════════════════════════════"
      echo "FILE: $path"
      echo "═══════════════════════════════════════════════════════════════"
      cat "$full"
    else
      echo "# WARNING: $path not found" >&2
    fi
  done <<< "$paths"
}

bundle_named() {
  local name="$1"
  local categories
  categories=$(get_bundle_includes "$name")

  # Always include session first
  bundle_category "session"

  # Then the bundle's categories
  while IFS= read -r cat; do
    [[ -z "$cat" ]] && continue
    [[ "$cat" == "session" ]] && continue  # Already included
    bundle_category "$cat"
  done <<< "$categories"
}

do_bundle() {
  local bundle="${1:-}"

  echo "╔═══════════════════════════════════════════════════════════════╗"
  echo "║ GOVERNANCE BUNDLE                                             ║"
  echo "║ Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)                       ║"
  if [[ -n "$bundle" ]]; then
    printf "║ Bundle: %-56s ║\n" "$bundle"
  else
    echo "║ Bundle: session + core                                        ║"
  fi
  echo "║                                                               ║"
  echo "║ READ ALL DOCS BELOW BEFORE TAKING ANY ACTION                  ║"
  echo "╚═══════════════════════════════════════════════════════════════╝"

  if [[ -n "$bundle" ]]; then
    bundle_named "$bundle"
  else
    bundle_category "session"
    bundle_category "core"
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "END OF GOVERNANCE BUNDLE"
  echo "═══════════════════════════════════════════════════════════════"
}

# ─────────────────────────────────────────────────────────────────
# Commands
# ─────────────────────────────────────────────────────────────────

cmd_list() {
  echo "╔═══════════════════════════════════════════════════════════════╗"
  echo "║ GOVERNANCE MANIFEST                                           ║"
  echo "║ Source: infrastructure/GOVERNANCE_MANIFEST.yaml               ║"
  echo "╚═══════════════════════════════════════════════════════════════╝"
  echo ""

  for category in session core infrastructure mint_os registries runbooks; do
    local paths
    paths=$(get_category_paths "$category")
    [[ -z "$paths" ]] && continue

    echo -e "${GREEN}$category:${NC}"
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      if [[ -f "$REPO_ROOT/$path" ]]; then
        echo "  ✓ $path"
      else
        echo -e "  ${RED}✗ $path (missing)${NC}"
      fi
    done <<< "$paths"
    echo ""
  done

  local count
  count=$(grep -c '^  - ' "$MANIFEST" 2>/dev/null || echo "0")
  echo "Total: $count docs in manifest"
  echo ""
  echo "Bundles available: builder, runner, clerk, mint_os, media, finance"
}

cmd_validate() {
  echo "Validating governance manifest..."
  local missing=0
  local total=0

  for category in session core infrastructure mint_os registries runbooks; do
    local paths
    paths=$(get_category_paths "$category")

    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      total=$((total + 1))
      if [[ ! -f "$REPO_ROOT/$path" ]]; then
        echo -e "${RED}MISSING:${NC} $path"
        missing=$((missing + 1))
      fi
    done <<< "$paths"
  done

  echo ""
  if [[ $missing -eq 0 ]]; then
    echo -e "${GREEN}✓ All $total files exist${NC}"
  else
    echo -e "${YELLOW}⚠ $missing of $total files missing${NC}"
    exit 1
  fi
}

cmd_help() {
  cat <<'HELP'
ops ai - Bundle governance docs for AI agents

USAGE:
  ops ai                        List manifest contents
  ops ai --bundle [name]        Bundle docs (default: session + core)
  ops ai --validate             Check all paths exist
  ops ai --clipboard            Bundle and copy to clipboard
  ops ai --print                Bundle and print to stdout

BUNDLES:
  builder     Code/infrastructure work (core + infrastructure + registries)
  runner      Deployments/operations (core + infrastructure + runbooks)
  clerk       Documentation/monitoring (core + infrastructure)
  mint_os     Mint OS API work (core + mint_os)
  media       Media stack work (core + media runbooks)
  finance     Finance work (core + finance runbooks)

EXAMPLES:
  ops ai --bundle builder --clipboard   # Copy builder bundle to clipboard
  ops ai --bundle runner --print        # Print runner bundle
  ops ai --validate                     # Check manifest integrity

MANIFEST: infrastructure/GOVERNANCE_MANIFEST.yaml
HELP
}

# ─────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────

BUNDLE_NAME=""
DO_CLIPBOARD=false
DO_PRINT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle|-b)
      BUNDLE_NAME="${2:-}"
      shift
      [[ -n "$BUNDLE_NAME" && "$BUNDLE_NAME" != -* ]] && shift
      ;;
    --clipboard|-c)
      DO_CLIPBOARD=true
      shift
      ;;
    --print|-p)
      DO_PRINT=true
      shift
      ;;
    --validate|-v)
      cmd_validate
      exit 0
      ;;
    --help|-h|help)
      cmd_help
      exit 0
      ;;
    --list|list|"")
      cmd_list
      exit 0
      ;;
    *)
      # Assume it's a bundle name if nothing else matches
      if [[ -z "$BUNDLE_NAME" ]]; then
        BUNDLE_NAME="$1"
      fi
      shift
      ;;
  esac
done

# If no action specified, list
if [[ -z "$BUNDLE_NAME" ]] && ! $DO_CLIPBOARD && ! $DO_PRINT; then
  cmd_list
  exit 0
fi

# Do the bundle
if $DO_CLIPBOARD; then
  if command -v pbcopy &>/dev/null; then
    do_bundle "$BUNDLE_NAME" | pbcopy
    echo -e "${GREEN}✓ Bundle copied to clipboard${NC}"
  elif command -v xclip &>/dev/null; then
    do_bundle "$BUNDLE_NAME" | xclip -selection clipboard
    echo -e "${GREEN}✓ Bundle copied to clipboard${NC}"
  else
    die "No clipboard tool (pbcopy/xclip) found"
  fi
elif $DO_PRINT; then
  do_bundle "$BUNDLE_NAME"
else
  # Default: bundle to temp file and show summary
  tmp="/tmp/governance_bundle_$$.md"
  do_bundle "$BUNDLE_NAME" > "$tmp"
  lines=$(wc -l < "$tmp" | tr -d ' ')
  echo -e "${GREEN}✓ Bundle ready${NC} ($lines lines)"
  echo "  File: $tmp"
  echo ""
  echo "Usage:"
  echo "  ops ai --bundle $BUNDLE_NAME --clipboard   # Copy to clipboard"
  echo "  ops ai --bundle $BUNDLE_NAME --print       # Print to stdout"
  echo "  cat $tmp                                   # View bundle"
fi
