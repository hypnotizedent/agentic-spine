#!/usr/bin/env bash
# TRIAGE: Version compat matrix missing or inconsistent — check ops/bindings/version.compat.matrix.yaml
# D95: version-compat-matrix-lock
# Enforces: version compatibility matrix exists, all source files valid, no missing dependencies
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

MATRIX="$ROOT/ops/bindings/version.compat.matrix.yaml"

# ── Check 1: Matrix exists ──
if [[ ! -f "$MATRIX" ]]; then
  err "version.compat.matrix.yaml does not exist"
  echo "D95 FAIL: $ERRORS check(s) failed"
  exit 1
fi
ok "matrix binding exists"

# ── Check 2: Version field present ──
if grep -q '^version:' "$MATRIX"; then
  ok "version field present"
else
  err "version field missing from matrix"
fi

# ── Check 3: Required components declared ──
REQUIRED_COMPONENTS=(
  drift-gate-runtime
  gate-registry
  policy-presets
  resolve-policy
  cap-runner
  capabilities-registry
  capability-map
  tenant-profile-schema
  plugin-manifest
)
for comp in "${REQUIRED_COMPONENTS[@]}"; do
  if grep -q "^  ${comp}:" "$MATRIX"; then
    ok "component $comp declared"
  else
    err "component $comp not declared in matrix"
  fi
done

# ── Check 4: Each component has source and version ──
for comp in "${REQUIRED_COMPONENTS[@]}"; do
  if grep -q "^  ${comp}:" "$MATRIX"; then
    block="$(sed -n "/^  ${comp}:/,/^  [a-z]/p" "$MATRIX" | head -15)"
    if echo "$block" | grep -q "version:"; then
      ok "$comp has version"
    else
      err "$comp missing version"
    fi
    if echo "$block" | grep -q "source:"; then
      ok "$comp has source"
    else
      err "$comp missing source"
    fi
  fi
done

# ── Check 5: Source files exist ──
while IFS= read -r line; do
  src="$(echo "$line" | sed 's/.*source: *"//' | sed 's/".*//')"
  if [[ -n "$src" ]]; then
    if [[ -f "$ROOT/$src" ]]; then
      ok "source exists: $src"
    else
      err "source file missing: $src"
    fi
  fi
done < <(grep '    source:' "$MATRIX")

# ── Check 6: Dependency references are valid components ──
while IFS= read -r line; do
  dep="$(echo "$line" | sed 's/.*component: *//' | tr -d ' ')"
  if [[ -n "$dep" ]]; then
    if grep -q "^  ${dep}:" "$MATRIX"; then
      ok "dependency $dep exists in matrix"
    else
      err "dependency $dep referenced but not declared"
    fi
  fi
done < <(grep '      - component:' "$MATRIX")

# ── Check 7: Enforcement section present ──
if grep -q '^enforcement:' "$MATRIX"; then
  ok "enforcement section present"
else
  err "enforcement section missing"
fi

# ── Check 8: Product doc exists ──
if [[ -f "$ROOT/docs/product/AOF_VERSION_COMPATIBILITY.md" ]]; then
  ok "product doc exists"
else
  err "docs/product/AOF_VERSION_COMPATIBILITY.md does not exist"
fi

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D95 FAIL: $ERRORS check(s) failed"
  exit 1
fi
exit 0
