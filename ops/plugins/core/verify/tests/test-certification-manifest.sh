#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "${SPINE_ROOT:-$ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

BUILD="$ROOT/ops/plugins/core/verify/bin/certification-manifest-build"
CHECK="$ROOT/ops/plugins/core/verify/bin/certification-manifest-check"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected='$expected', got='$actual')"
  fi
}

echo "certification manifest tests"
echo "════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

make_repo() {
  local repo="$1"
  git init -q "$repo"
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
}

seed_repo() {
  local repo="$1"
  local tag="$2"
  mkdir -p \
    "$repo/docs/reference/generated" \
    "$repo/docs/compat" \
    "$repo/docs/archive" \
    "$repo/docs/evidence" \
    "$repo/ops/bindings"

  cat > "$repo/docs/reference/generated/${tag}-projection.md" <<'MD'
---
status: generated
authority_state: projection
projection_of: [ops/bindings/demo.yaml]
---
MD

  cat > "$repo/ops/bindings/${tag}-authority.yaml" <<'YAML'
---
status: authoritative
owner: "@test"
YAML

  cat > "$repo/docs/compat/${tag}-legacy-shim.md" <<'MD'
# legacy shim
MD

  cat > "$repo/docs/archive/${tag}-old.md" <<'MD'
# archived doc
MD

  cat > "$repo/docs/evidence/${tag}-result.receipt.md" <<'MD'
# evidence receipt
MD

  git -C "$repo" add -A
  git -C "$repo" commit -q -m "seed ${tag}"
}

spine="$tmpdir/spine"
foundation="$tmpdir/foundation"
make_repo "$spine"
make_repo "$foundation"
seed_repo "$spine" spine
seed_repo "$foundation" foundation

yaml_out="$tmpdir/CERTIFICATION_MANIFEST.yaml"
md_out="$tmpdir/CERTIFICATION_MANIFEST.md"

"$BUILD" \
  --repo spine="$spine" \
  --repo foundation="$foundation" \
  --yaml-out "$yaml_out" \
  --markdown-out "$md_out" >/dev/null

assert_eq "$(python3 - "$yaml_out" <<'PY'
import sys, yaml
payload = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
print(payload["manifest_title"])
PY
)" "CERTIFICATION_MANIFEST" "manifest title"

assert_eq "$(python3 - "$yaml_out" <<'PY'
import sys, yaml
payload = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
print(len(payload["repos"]))
PY
)" "2" "repo count"

assert_eq "$(python3 - "$yaml_out" <<'PY'
import sys, yaml
payload = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
spine = next(repo for repo in payload["repos"] if repo["label"] == "spine")
print(spine["counts"]["classification_counts"]["projection"])
PY
)" "1" "spine projection count"

assert_eq "$(python3 - "$yaml_out" <<'PY'
import sys, yaml
payload = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
spine = next(repo for repo in payload["repos"] if repo["label"] == "spine")
print(spine["counts"]["coverage_basis_counts"]["inline"])
PY
)" "1" "spine inline coverage basis"

assert_eq "$(python3 - "$yaml_out" <<'PY'
import sys, yaml
payload = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
spine = next(repo for repo in payload["repos"] if repo["label"] == "spine")
entry = next(row for row in spine["files"] if row["path"] == "docs/reference/generated/spine-projection.md")
print(entry["classification"], entry["status"], entry["coverage_basis"])
PY
)" "projection active inline" "projection entry fields"

assert_eq "$(python3 - "$yaml_out" <<'PY'
import sys, yaml
payload = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
foundation = next(repo for repo in payload["repos"] if repo["label"] == "foundation")
entry = next(row for row in foundation["files"] if row["path"] == "docs/archive/foundation-old.md")
print(entry["status"])
PY
)" "deprecated" "deprecated status"

"$CHECK" --manifest "$yaml_out" --repo spine="$spine" --repo foundation="$foundation" >/dev/null
pass "checker passes with full manifest"

manifest_inline_missing="$tmpdir/CERTIFICATION_MANIFEST_INLINE_REMOVED.yaml"
python3 - "$yaml_out" "$manifest_inline_missing" <<'PY'
import sys, yaml
source = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
for repo in source["repos"]:
    if repo["label"] == "spine":
        repo["files"] = [row for row in repo["files"] if row["path"] != "docs/reference/generated/spine-projection.md"]
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    yaml.safe_dump(source, handle, sort_keys=False)
PY

"$CHECK" --manifest "$manifest_inline_missing" --repo spine="$spine" --repo foundation="$foundation" >/dev/null
pass "checker accepts inline-certified file without manifest entry"

manifest_missing_authority="$tmpdir/CERTIFICATION_MANIFEST_AUTHORITY_REMOVED.yaml"
python3 - "$yaml_out" "$manifest_missing_authority" <<'PY'
import sys, yaml
source = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
for repo in source["repos"]:
    if repo["label"] == "spine":
        repo["files"] = [row for row in repo["files"] if row["path"] != "ops/bindings/spine-authority.yaml"]
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    yaml.safe_dump(source, handle, sort_keys=False)
PY

set +e
bad_out="$("$CHECK" --manifest "$manifest_missing_authority" --repo spine="$spine" --repo foundation="$foundation" 2>&1)"
bad_rc=$?
set -e
[[ "$bad_rc" -ne 0 ]] || { fail "checker should fail for uncovered authority file"; exit 1; }
grep "missing coverage: 1" <<<"$bad_out" >/dev/null || { fail "expected missing coverage"; exit 1; }
grep "spine:ops/bindings/spine-authority.yaml" <<<"$bad_out" >/dev/null || { fail "expected missing authority file path"; exit 1; }
pass "checker fails when a non-inline file is neither manifest-covered nor inline-certified"

echo "────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
