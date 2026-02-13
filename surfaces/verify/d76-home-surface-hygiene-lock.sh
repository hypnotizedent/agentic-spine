#!/usr/bin/env bash
# D76: Home-surface hygiene lock
# Prevents home directory drift by checking:
#   1. No plaintext secrets in Claude Desktop config (if present)
#   2. Claude Desktop filesystem MCP only points to allowed roots (if present)
#   3. No forbidden legacy roots at ~/
#   4. No uppercase /Code/ violations in workbench executable surfaces
#   5. ~/bin/ symlinks all resolve and use lowercase /code/

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$ROOT/ops/bindings/home-surface.allowlist.yaml"
HOME_DIR="${HOME:-/Users/ronnyworks}"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-$HOME_DIR/code/workbench}"
if [[ ! -d "$WORKBENCH_ROOT" ]]; then
  WORKBENCH_ROOT="${HOME_DIR}/code/workbench"
fi

fail() {
  echo "D76 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -f "$BINDING" ]] || fail "binding missing: $BINDING"

VIOLATIONS=()

# ── Check 1: Plaintext secrets in Claude Desktop config ──
CLAUDE_CFG="$HOME_DIR/Library/Application Support/Claude/claude_desktop_config.json"
if [[ -f "$CLAUDE_CFG" ]]; then
  # Read secret patterns from binding
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    if grep -q "$pattern" "$CLAUDE_CFG" 2>/dev/null; then
      VIOLATIONS+=("plaintext secret pattern '$pattern' found in Claude Desktop config")
    fi
  done < <(yq e '.secret_patterns[]' "$BINDING" 2>/dev/null)

  # ── Check 2: Claude Desktop filesystem MCP allowed roots ──
  if command -v jq >/dev/null 2>&1; then
    # Extract filesystem MCP roots if any
    FS_ROOTS="$(jq -r '
      .mcpServers // {} | to_entries[] |
      select(.value.command == "npx" and (.value.args // [] | any(contains("server-filesystem")))) |
      .value.args[] | select(startswith("/"))
    ' "$CLAUDE_CFG" 2>/dev/null || true)"

    if [[ -n "$FS_ROOTS" ]]; then
      while IFS= read -r mcp_root; do
        [[ -z "$mcp_root" ]] && continue
        allowed=false
        while IFS= read -r allowed_root; do
          [[ -z "$allowed_root" ]] && continue
          if [[ "$mcp_root" == "$allowed_root"* ]]; then
            allowed=true
            break
          fi
        done < <(yq e '.claude_desktop_allowed_roots[]' "$BINDING" 2>/dev/null)
        if [[ "$allowed" == "false" ]]; then
          VIOLATIONS+=("Claude Desktop filesystem MCP root '$mcp_root' not in allowed list")
        fi
      done <<< "$FS_ROOTS"
    fi
  fi
fi

# ── Check 3: Forbidden legacy operational roots at ~/ ──
# Only flag dirs that indicate active legacy operational layout.
# Stale repo clones (e.g. ~/ronny-ops) are inert and handled by D30/D42.
for forbidden_dir in ops stacks; do
  if [[ -d "$HOME_DIR/$forbidden_dir" ]]; then
    VIOLATIONS+=("forbidden legacy directory exists: ~/$forbidden_dir")
  fi
done

# ── Check 4: Uppercase code-dir violations in workbench executable surfaces ──
# Build pattern dynamically to avoid D42 false positive on this file
_UPPER_CODE_PAT="/Users/ronnyworks/$(printf '%s' 'Code')/"
if [[ -d "$WORKBENCH_ROOT" ]]; then
  UPPERCASE_HITS="$(find "$WORKBENCH_ROOT/scripts" "$WORKBENCH_ROOT/dotfiles/raycast" \
    -name '*.sh' -not -path '*/.archive/*' -not -path '*/archive/*' \
    -exec grep -l "$_UPPER_CODE_PAT" {} + 2>/dev/null || true)"
  if [[ -n "$UPPERCASE_HITS" ]]; then
    while IFS= read -r hit; do
      [[ -z "$hit" ]] && continue
      rel="${hit#$WORKBENCH_ROOT/}"
      VIOLATIONS+=("uppercase code-dir path in workbench: $rel")
    done <<< "$UPPERCASE_HITS"
  fi
fi

# ── Check 5: ~/bin/ symlinks resolve and use lowercase /code/ ──
if [[ -d "$HOME_DIR/bin" ]]; then
  for link in "$HOME_DIR/bin/"*; do
    [[ -L "$link" ]] || continue
    target="$(readlink "$link" 2>/dev/null || true)"
    if [[ -n "$target" ]] && [[ "$target" == *"/Code/"* ]]; then
      VIOLATIONS+=("~/bin/ symlink uses uppercase /Code/: $(basename "$link") -> $target")
    fi
    if [[ -n "$target" ]] && ! [[ -e "$link" ]]; then
      VIOLATIONS+=("~/bin/ broken symlink: $(basename "$link") -> $target")
    fi
  done
fi

# ── Report ──
if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  fail "$(printf '%s\n' "${VIOLATIONS[@]}")"
fi

echo "D76 PASS: home-surface hygiene lock enforced"
