#!/usr/bin/env bash
# TRIAGE: Keep runtime script names in parity with launchd labels and scheduler registry template paths.
# D297: runtime script registry name parity lock
# Enforce 1:1 naming parity between ops/runtime/*.sh, launchd plist templates,
# and launchd.scheduler.registry label+template mappings.
set -euo pipefail

resolve_root() {
  if [[ -n "${SPINE_ROOT:-}" && -f "${SPINE_ROOT}/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$SPINE_ROOT"
    return 0
  fi
  local detected_root=""
  detected_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$detected_root" && -f "$detected_root/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$detected_root"
    return 0
  fi
  printf '%s\n' "$HOME/code/agentic-spine"
}

ROOT="$(resolve_root)"
RUNTIME_DIR="$ROOT/ops/runtime"
PLIST_DIR="$ROOT/ops/runtime/launchd"
REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"

fail() {
  echo "D297 FAIL: $*" >&2
  exit 1
}

[[ -d "$RUNTIME_DIR" ]] || fail "runtime dir missing: $RUNTIME_DIR"
[[ -d "$PLIST_DIR" ]] || fail "launchd plist dir missing: $PLIST_DIR"
[[ -f "$REGISTRY" ]] || fail "scheduler registry missing: $REGISTRY"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v /usr/libexec/PlistBuddy >/dev/null 2>&1 || fail "missing dependency: PlistBuddy"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

violations=0
scripts_checked=0
bash_compat_checked=0

# Disallow bash 4+ syntax in launchd runtime scripts (macOS default bash is 3.2).
bash32_incompat_re='\b(mapfile|readarray)\b|\$\{[^}]*,,[^}]*\}|\$\{[^}]*\^\^[^}]*\}|\$\{[^}]*@Q\}|\bdeclare[[:space:]]+-A\b|\bcoproc\b'

for script in "$RUNTIME_DIR"/*.sh; do
  [[ -f "$script" ]] || continue
  scripts_checked=$((scripts_checked + 1))

  base="$(basename "$script" .sh)"
  expected_label="com.ronny.${base}"
  expected_plist_rel="ops/runtime/launchd/${expected_label}.plist"
  expected_plist_abs="$ROOT/$expected_plist_rel"

  if [[ ! -f "$expected_plist_abs" ]]; then
    echo "D297 HIT: missing plist template for runtime script ops/runtime/${base}.sh -> $expected_plist_rel" >&2
    violations=$((violations + 1))
    continue
  fi

  plist_label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$expected_plist_abs" 2>/dev/null || true)"
  if [[ "$plist_label" != "$expected_label" ]]; then
    echo "D297 HIT: plist label mismatch for ${expected_plist_rel} (expected=${expected_label}, actual=${plist_label:-missing})" >&2
    violations=$((violations + 1))
  fi

  registry_template="$(yq e -r ".labels[] | select(.label == \"$expected_label\") | .template_path" "$REGISTRY" 2>/dev/null || true)"
  if [[ -z "$registry_template" || "$registry_template" == "null" ]]; then
    echo "D297 HIT: scheduler registry missing label entry for $expected_label" >&2
    violations=$((violations + 1))
  elif [[ "$registry_template" != "$expected_plist_rel" ]]; then
    echo "D297 HIT: scheduler registry template mismatch for $expected_label (expected=${expected_plist_rel}, actual=${registry_template})" >&2
    violations=$((violations + 1))
  fi

  # Bash 3.2 compatibility lock for launchd runtime surfaces.
  if head -n 1 "$script" | grep -Eq 'bash$|bash '; then
    bash_compat_checked=$((bash_compat_checked + 1))
    compat_hit="$(rg -n -m 1 -P "$bash32_incompat_re" "$script" || true)"
    if [[ -n "$compat_hit" ]]; then
      echo "D297 HIT: bash3.2-incompatible syntax in $(basename "$script") -> $compat_hit" >&2
      violations=$((violations + 1))
    fi
  fi

done

if [[ "$scripts_checked" -eq 0 ]]; then
  fail "no runtime scripts found under $RUNTIME_DIR"
fi

if [[ "$violations" -gt 0 ]]; then
  fail "runtime script parity/compat violations=${violations} scripts_checked=${scripts_checked} bash_compat_checked=${bash_compat_checked}"
fi

echo "D297 PASS: runtime script registry name parity + bash3.2 lock clean (scripts_checked=${scripts_checked}, bash_compat_checked=${bash_compat_checked})"
