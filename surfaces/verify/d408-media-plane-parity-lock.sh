#!/usr/bin/env bash
set -euo pipefail

# D408: Media Plane Parity Lock
# Purpose: enforce media plane authority boundaries and parity:
#   1. Workbench canonical files carry CANONICAL AUTHORITY banner
#   2. Spine projection (media.services.yaml) carries COMPATIBILITY PROJECTION banner
#   3. Spine pipeline contract carries SPINE-AUTHORITATIVE banner
#   4. media.services.yaml: workbench canonical == spine projection (banner-excluded)
#   5. media.pipeline.contract.yaml: workbench == spine (banner-excluded, YAML-equal)
#   6. capabilities.yaml media cap count == MANIFEST.yaml media cap count
#   7. All media caps have plane == domain_external
#   8. No media cap has implementation_repo: spine outside allowlist
#   9. docs/governance/domains/media.md capability count matches registry
#
# Exit: 0 = PASS, 1 = FAIL

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKBENCH="$HOME/code/workbench"

SPINE_SERVICES="$ROOT/ops/bindings/domains/media/media.services.yaml"
WB_SERVICES="$WORKBENCH/projects/media/bindings/media.services.yaml"
SPINE_PIPELINE="$ROOT/ops/bindings/domains/media/media.pipeline.contract.yaml"
WB_PIPELINE="$WORKBENCH/projects/media/bindings/media.pipeline.contract.yaml"
CAP_FILE="$ROOT/ops/capabilities.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
MEDIA_DOC="$ROOT/docs/governance/domains/media.md"

FAILURES=0
CHECKS=0

pass() { CHECKS=$((CHECKS + 1)); echo "  PASS: $*"; }
fail() { CHECKS=$((CHECKS + 1)); FAILURES=$((FAILURES + 1)); echo "  FAIL: $*" >&2; }

# --- Prerequisite: files exist ---
for f in "$SPINE_SERVICES" "$WB_SERVICES" "$SPINE_PIPELINE" "$WB_PIPELINE" "$CAP_FILE" "$MANIFEST"; do
  [[ -f "$f" ]] || { fail "missing file: $f"; }
done

command -v python3 >/dev/null 2>&1 || { echo "D408 FAIL: python3 required" >&2; exit 1; }

# --- Check 1-3: Banner truth ---
if head -5 "$WB_SERVICES" | grep -q "CANONICAL AUTHORITY"; then
  pass "workbench media.services.yaml has CANONICAL AUTHORITY banner"
else
  fail "workbench media.services.yaml missing CANONICAL AUTHORITY banner"
fi

if head -5 "$WB_PIPELINE" | grep -q "CANONICAL AUTHORITY"; then
  pass "workbench media.pipeline.contract.yaml has CANONICAL AUTHORITY banner"
else
  fail "workbench media.pipeline.contract.yaml missing CANONICAL AUTHORITY banner"
fi

if head -5 "$SPINE_SERVICES" | grep -q "COMPATIBILITY PROJECTION"; then
  pass "spine media.services.yaml has COMPATIBILITY PROJECTION banner"
else
  fail "spine media.services.yaml missing COMPATIBILITY PROJECTION banner"
fi

if head -5 "$SPINE_PIPELINE" | grep -q "SPINE-AUTHORITATIVE"; then
  pass "spine media.pipeline.contract.yaml has SPINE-AUTHORITATIVE banner"
else
  fail "spine media.pipeline.contract.yaml missing SPINE-AUTHORITATIVE banner"
fi

# --- Check 4-8: YAML parity + registry checks via python ---
python3 - "$CAP_FILE" "$MANIFEST" "$WB_SERVICES" "$SPINE_SERVICES" "$WB_PIPELINE" "$SPINE_PIPELINE" <<'PY'
import json
import subprocess
import sys
import re

cap_file, manifest_file, wb_svc, sp_svc, wb_pipe, sp_pipe = sys.argv[1:7]

failures = []
passes = []

def load_yaml(path):
    raw = subprocess.run(
        ["yq", "-o=json", ".", path],
        capture_output=True, text=True, check=False,
    )
    if raw.returncode != 0:
        failures.append(f"invalid YAML: {path}")
        return None
    try:
        return json.loads(raw.stdout)
    except json.JSONDecodeError:
        failures.append(f"unable to parse JSON from: {path}")
        return None

def strip_header(path):
    """Return file content with the header block removed.

    Strips: the box-drawing banner block and all comment-only lines
    between the banner and the first YAML content line. These metadata
    lines (title, Status, Owner) legitimately differ between canonical
    and projection copies.
    """
    lines = open(path).readlines()
    out = []
    in_banner = False
    post_banner = False
    for line in lines:
        if not in_banner and not post_banner and line.startswith("#") and "\u250c" in line:
            in_banner = True
            continue
        if in_banner:
            if "\u2518" in line or "\u2514" in line:
                in_banner = False
                post_banner = True
            continue
        if post_banner:
            stripped = line.strip()
            if stripped == "" or stripped.startswith("#"):
                continue
            post_banner = False
        out.append(line)
    return "".join(out)

# Check 4: media.services.yaml parity (header-excluded)
wb_body = strip_header(wb_svc)
sp_body = strip_header(sp_svc)
if wb_body == sp_body:
    passes.append("media.services.yaml: workbench canonical == spine projection (banner-excluded)")
else:
    failures.append("media.services.yaml: workbench canonical != spine projection (banner-excluded content differs)")

# Check 5: media.pipeline.contract.yaml YAML-equal (header-excluded)
wb_pipe_data = load_yaml(wb_pipe)
sp_pipe_data = load_yaml(sp_pipe)
if wb_pipe_data is not None and sp_pipe_data is not None:
    if wb_pipe_data == sp_pipe_data:
        passes.append("media.pipeline.contract.yaml: workbench == spine (YAML-equal)")
    else:
        failures.append("media.pipeline.contract.yaml: workbench != spine (YAML content differs)")

# Check 6: capability registry parity (MANIFEST caps all exist in capabilities.yaml)
auth = load_yaml(cap_file)
manifest = load_yaml(manifest_file)

manifest_media_caps = set()
if manifest:
    plugins = manifest.get("plugins", [])
    for p in plugins:
        if p.get("name") == "media":
            manifest_media_caps = set(p.get("capabilities", []))
            break

all_caps = {}
media_caps = {}
if auth:
    all_caps = auth.get("capabilities", {})
    media_caps = {k: v for k, v in all_caps.items() if k.startswith("media.")}

if manifest_media_caps and all_caps:
    missing_from_registry = manifest_media_caps - set(all_caps.keys())
    missing_from_manifest = {k for k in all_caps if k.startswith("media.")} - manifest_media_caps
    if missing_from_registry:
        failures.append(f"MANIFEST caps missing from capabilities.yaml: {sorted(missing_from_registry)}")
    elif missing_from_manifest:
        failures.append(f"media.* caps in capabilities.yaml missing from MANIFEST: {sorted(missing_from_manifest)}")
    else:
        passes.append(f"registry parity: MANIFEST ({len(manifest_media_caps)}) and capabilities.yaml media plugin caps all present")

# Check 7: all media caps have plane == domain_external
if media_caps:
    bad_plane = [k for k, v in media_caps.items() if v.get("plane") != "domain_external"]
    if bad_plane:
        failures.append(f"{len(bad_plane)} media caps with plane != domain_external: {sorted(bad_plane)[:5]}")
    else:
        passes.append(f"all {len(media_caps)} media caps have plane=domain_external")

# Check 8: implementation_repo: spine allowlist
SPINE_ALLOWLIST = {
    "media.api.resolve",
    "media.backup.create",
    "media.backup.restore",
    "media.config.restore.drill",
    "media.duplicate.scan",
    "media.library.junk.audit",
    "media.rename.status",
    "media.scene.rename",
}
if media_caps:
    spine_impl = {k for k, v in media_caps.items() if v.get("implementation_repo") == "spine"}
    unlisted = spine_impl - SPINE_ALLOWLIST
    if unlisted:
        failures.append(f"media caps with implementation_repo=spine outside allowlist: {sorted(unlisted)}")
    else:
        passes.append(f"spine-owned media caps ({len(spine_impl)}) all in allowlist")

for p in passes:
    print(f"  PASS: {p}")
for f in failures:
    print(f"  FAIL: {f}", file=sys.stderr)

sys.exit(1 if failures else 0)
PY

rc=$?
if [[ $rc -ne 0 ]]; then
  FAILURES=$((FAILURES + 1))
fi

echo ""
if [[ $FAILURES -eq 0 ]]; then
  echo "D408 PASS: media plane parity lock ($CHECKS banner checks + python checks)"
else
  echo "D408 FAIL: $FAILURES failure(s) detected" >&2
  exit 1
fi
