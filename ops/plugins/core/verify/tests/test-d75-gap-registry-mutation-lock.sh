#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
D75="$ROOT/surfaces/verify/d75-gap-registry-mutation-lock.sh"
CONTRACT="$ROOT/ops/bindings/shared-authority.mutation.contract.yaml"
FIXTURE_ROOT="$(mktemp -d)"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

write_fixture_contract() {
  local repo="$1"
  local enforcement_sha="$2"
  local exempt_sha="${3:-}"

  mkdir -p "$repo/ops/bindings"
  if [[ -n "$exempt_sha" ]]; then
    cat > "$repo/ops/bindings/shared-authority.mutation.contract.yaml" <<EOF
schema_version: "1.0"
status: authoritative
owner: "@fixture"
updated_at: "2026-04-05T19:06:54Z"
gap_projection_enforcement:
  gate_id: D75
  active_projection: ops/bindings/operational.gaps.yaml
  archive_projection: ops/archive/operational.gaps.archive.yaml
  window: 50
  enforcement_after_sha: "$enforcement_sha"
  required_trailers:
    - Gap-Mutation
    - Gap-Capability
    - Gap-Run-Key
  historical_exemptions:
    - commit: "$exempt_sha"
      path: ops/bindings/operational.gaps.yaml
      as_of: "2026-04-05"
      rationale: Fixture exemption for the single historical commit under test.
EOF
  else
    cat > "$repo/ops/bindings/shared-authority.mutation.contract.yaml" <<EOF
schema_version: "1.0"
status: authoritative
owner: "@fixture"
updated_at: "2026-04-05T19:06:54Z"
gap_projection_enforcement:
  gate_id: D75
  active_projection: ops/bindings/operational.gaps.yaml
  archive_projection: ops/archive/operational.gaps.archive.yaml
  window: 50
  enforcement_after_sha: "$enforcement_sha"
  required_trailers:
    - Gap-Mutation
    - Gap-Capability
    - Gap-Run-Key
EOF
  fi
}

echo "D75 gap-registry mutation lock tests"
echo "════════════════════════════════════════"

command -v git >/dev/null 2>&1 || {
  echo "FAIL: missing dependency git" >&2
  exit 1
}
command -v yq >/dev/null 2>&1 || {
  echo "FAIL: missing dependency yq" >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  echo "FAIL: missing dependency python3" >&2
  exit 1
}
command -v rg >/dev/null 2>&1 || {
  echo "FAIL: missing dependency rg" >&2
  exit 1
}

if [[ -x "$D75" ]]; then
  pass "D75 surface is executable"
else
  fail "D75 surface is executable"
  echo "Results: $PASS passed, $FAIL failed"
  exit "$FAIL"
fi

if live_out="$(bash "$D75" 2>&1)"; then
  pass "live D75 passes with governed historical exemption"
else
  fail "live D75 passes with governed historical exemption"
  echo "$live_out" >&2
fi

live_exempt_commit="$(yq e -r '.gap_projection_enforcement.historical_exemptions[]? | select(.commit == "26162aab5c19ae1958b5d320052a89aa29bc266d") | .commit' "$CONTRACT")"
live_exempt_path="$(yq e -r '.gap_projection_enforcement.historical_exemptions[]? | select(.commit == "26162aab5c19ae1958b5d320052a89aa29bc266d") | .path' "$CONTRACT")"
live_exempt_date="$(yq e -r '.gap_projection_enforcement.historical_exemptions[]? | select(.commit == "26162aab5c19ae1958b5d320052a89aa29bc266d") | .as_of' "$CONTRACT")"
if [[ "$live_exempt_commit" == "26162aab5c19ae1958b5d320052a89aa29bc266d" && "$live_exempt_path" == "ops/bindings/operational.gaps.yaml" && "$live_exempt_date" == "2026-04-05" ]]; then
  pass "live contract exemption is commit-specific, path-bound, and dated"
else
  fail "live contract exemption is commit-specific, path-bound, and dated"
fi

repo="$FIXTURE_ROOT/repo"
mkdir -p \
  "$repo/surfaces/verify" \
  "$repo/ops/plugins/core/lifecycle/bin" \
  "$repo/ops/bindings"

cp "$D75" "$repo/surfaces/verify/d75-gap-registry-mutation-lock.sh"
chmod +x "$repo/surfaces/verify/d75-gap-registry-mutation-lock.sh"

cat > "$repo/ops/plugins/core/lifecycle/bin/gaps-authority-bridge" <<'PY'
#!/usr/bin/env python3
import json
import sys

if len(sys.argv) > 1 and sys.argv[1] == "parity":
    print(json.dumps({"match": True}))
    raise SystemExit(0)

print(json.dumps({"match": False, "error": "unsupported command"}))
raise SystemExit(1)
PY
chmod +x "$repo/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"

cat > "$repo/ops/bindings/operational.gaps.yaml" <<'YAML'
gaps:
  - id: GAP-OP-FIXTURE
    doc: baseline-path
YAML

write_fixture_contract "$repo" "BASELINE_SHA_PLACEHOLDER"

git init -q "$repo"
git -C "$repo" config user.name "Fixture"
git -C "$repo" config user.email "fixture@example.com"
git -C "$repo" add .
git -C "$repo" commit -qm "fixture baseline"
baseline_sha="$(git -C "$repo" rev-parse HEAD)"

cat > "$repo/ops/bindings/operational.gaps.yaml" <<'YAML'
gaps:
  - id: GAP-OP-FIXTURE
    doc: historical-exempt-touch
YAML
git -C "$repo" add ops/bindings/operational.gaps.yaml
git -C "$repo" commit -qm "fixture historical gap touch without trailers"
historical_sha="$(git -C "$repo" rev-parse HEAD)"

write_fixture_contract "$repo" "$baseline_sha" "$historical_sha"
git -C "$repo" add ops/bindings/shared-authority.mutation.contract.yaml
git -C "$repo" commit -qm "fixture D75 contract with historical exemption"

cat > "$repo/ops/bindings/operational.gaps.yaml" <<'YAML'
gaps:
  - id: GAP-OP-FIXTURE
    doc: governed-projection-touch
YAML
git -C "$repo" add ops/bindings/operational.gaps.yaml
git -C "$repo" commit -qm "$(cat <<'EOF'
fixture governed projection touch

Gap-Mutation: projection
Gap-Capability: gaps.projection.commit
Gap-Run-Key: CAP-20260405-190654__gaps.projection.commit__Rfixture001
EOF
)"

if fixture_pass_out="$(bash "$repo/surfaces/verify/d75-gap-registry-mutation-lock.sh" 2>&1)"; then
  pass "fixture D75 passes with one explicit historical exemption"
else
  fail "fixture D75 passes with one explicit historical exemption"
  echo "$fixture_pass_out" >&2
fi

cat > "$repo/ops/bindings/operational.gaps.yaml" <<'YAML'
gaps:
  - id: GAP-OP-FIXTURE
    doc: future-unlisted-touch
YAML
git -C "$repo" add ops/bindings/operational.gaps.yaml
git -C "$repo" commit -qm "fixture future gap touch without trailers"
future_short="$(git -C "$repo" rev-parse --short HEAD)"

set +e
fixture_fail_out="$(bash "$repo/surfaces/verify/d75-gap-registry-mutation-lock.sh" 2>&1)"
fixture_fail_rc=$?
set -e

if [[ "$fixture_fail_rc" -ne 0 ]]; then
  pass "fixture D75 still fails future unlisted commits"
else
  fail "fixture D75 still fails future unlisted commits"
fi

if echo "$fixture_fail_out" | grep -q "$future_short fixture future gap touch without trailers"; then
  pass "fixture failure points at the unlisted future commit"
else
  fail "fixture failure points at the unlisted future commit"
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
