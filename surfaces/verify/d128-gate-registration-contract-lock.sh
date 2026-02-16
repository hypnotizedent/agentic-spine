#!/usr/bin/env bash
# TRIAGE: mutate gate registry/topology via governed capabilities only (gate.registry.*, gate.topology.*, domain.onboard.new), with commit provenance trailers.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
POLICY_FILE="$ROOT/ops/bindings/d128-gate-mutation-policy.yaml"

fail() {
  echo "D128 FAIL: $*" >&2
  exit 1
}

need_file() {
  [[ -f "$1" ]] || fail "missing required file: $1"
}

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
need_file "$POLICY_FILE"
yq e '.' "$POLICY_FILE" >/dev/null 2>&1 || fail "invalid YAML: $POLICY_FILE"

WINDOW="$(yq e -r '.window // 50' "$POLICY_FILE")"
ENFORCEMENT_SHA="$(yq e -r '.enforcement_after_sha // ""' "$POLICY_FILE")"
[[ -n "$ENFORCEMENT_SHA" ]] || fail "policy missing enforcement_after_sha"

mapfile -t TARGET_FILES < <(yq e -r '.files[]?' "$POLICY_FILE")
[[ "${#TARGET_FILES[@]}" -gt 0 ]] || fail "policy files[] is empty"

mapfile -t ALLOWED_CAPS < <(yq e -r '.allowed_capabilities[]?' "$POLICY_FILE")
[[ "${#ALLOWED_CAPS[@]}" -gt 0 ]] || fail "policy allowed_capabilities[] is empty"

for rel in "${TARGET_FILES[@]}"; do
  [[ -n "$rel" ]] || continue
  abs="$ROOT/$rel"
  [[ -f "$abs" ]] || fail "tracked file missing: $rel"

  if ! git -C "$ROOT" diff --quiet -- "$rel" 2>/dev/null; then
    fail "unstaged mutation detected in $rel"
  fi
  if ! git -C "$ROOT" diff --cached --quiet -- "$rel" 2>/dev/null; then
    fail "staged mutation detected in $rel"
  fi
done

if ! git -C "$ROOT" merge-base --is-ancestor "$ENFORCEMENT_SHA" HEAD 2>/dev/null; then
  echo "D128 PASS: enforcement boundary not in current ancestry (commit provenance check skipped)"
  exit 0
fi

violations=()

while IFS= read -r sha; do
  [[ -n "$sha" ]] || continue
  msg="$(git -C "$ROOT" log -1 --format="%B" "$sha")"
  # Normalize escaped newlines from non-interactive commit wrappers.
  msg="${msg//\\n/$'\n'}"

  missing=()
  grep -q '^Gate-Mutation:' <<<"$msg" || missing+=("Gate-Mutation")
  grep -q '^Gate-Capability:' <<<"$msg" || missing+=("Gate-Capability")
  grep -q '^Gate-Run-Key:' <<<"$msg" || missing+=("Gate-Run-Key")

  gate_cap="$(sed -n 's/^Gate-Capability:[[:space:]]*//p' <<<"$msg" | head -n1 | xargs || true)"
  if [[ -n "$gate_cap" ]]; then
    allowed=0
    for cap in "${ALLOWED_CAPS[@]}"; do
      if [[ "$gate_cap" == "$cap" ]]; then
        allowed=1
        break
      fi
    done
    [[ "$allowed" -eq 1 ]] || missing+=("Gate-Capability(not-allowed:$gate_cap)")
  fi

  if [[ "${#missing[@]}" -gt 0 ]]; then
    short="$(git -C "$ROOT" log -1 --format="%h %s" "$sha")"
    violations+=("$short (missing: ${missing[*]})")
  fi
done < <(git -C "$ROOT" log --max-count="$WINDOW" "${ENFORCEMENT_SHA}..HEAD" --format="%H" -- "${TARGET_FILES[@]}" 2>/dev/null)

if [[ "${#violations[@]}" -gt 0 ]]; then
  fail "gate registration provenance violations:\n$(printf '  - %s\n' "${violations[@]}")"
fi

echo "D128 PASS: gate registration contract lock enforced (files clean, provenance valid)"
