#!/usr/bin/env bash
# TRIAGE: Use governed gap/friction lifecycle capabilities only. No repo-local
# gap YAML authority.
# D75: Gap runtime projection lock.
# Enforces SQLite authority plus generated runtime projection parity, and keeps
# the retired repo-local gap projections absent.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEMA_FILE="$ROOT/ops/bindings/gap.schema.yaml"
GAPS_BRIDGE="$ROOT/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"
RUNTIME_PATHS="$ROOT/ops/lib/runtime-paths.sh"

fail() {
  echo "D75 FAIL: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "python3 required"

[[ -f "$SCHEMA_FILE" ]] || fail "gap schema contract missing: $SCHEMA_FILE"
[[ -x "$GAPS_BRIDGE" ]] || fail "gaps authority bridge missing: $GAPS_BRIDGE"

schema_payload="$(
  python3 - "$SCHEMA_FILE" <<'PY'
import json
import sys
from pathlib import Path

import yaml

path = Path(sys.argv[1])
payload = yaml.safe_load(path.read_text(encoding="utf-8"))
if not isinstance(payload, dict):
    raise SystemExit("gap schema must be a mapping")
if payload.get("status") != "authoritative":
    raise SystemExit("gap schema must be authoritative")

projection = payload.get("projection_authority")
if not isinstance(projection, dict):
    raise SystemExit("projection_authority block missing")

expected = {
    "source_authority": "shared_authority.db",
    "source_table": "gaps",
    "active_projection": "$SPINE_STATE/projections/operational-gaps.runtime.yaml",
    "archive_projection": "$SPINE_STATE/archive/operational.gaps.archive.yaml",
}
for key, value in expected.items():
    if projection.get(key) != value:
        raise SystemExit(f"projection_authority.{key} must be {value}")

retired = projection.get("retired_repo_projections")
if not isinstance(retired, list) or not retired:
    raise SystemExit("projection_authority.retired_repo_projections must be a non-empty list")

required_retired = {
    "ops/bindings/operational.gaps.yaml",
    "ops/archive/operational.gaps.archive.yaml",
}
if set(str(item) for item in retired) != required_retired:
    raise SystemExit("projection_authority.retired_repo_projections must name the retired active/archive repo projections")

mutation_caps = set(str(item) for item in projection.get("governed_mutation_capabilities") or [])
if "gaps.file" not in mutation_caps or "friction.reconcile" not in mutation_caps:
    raise SystemExit("projection_authority.governed_mutation_capabilities must include gaps.file and friction.reconcile")

print(json.dumps({"retired_repo_projections": sorted(required_retired)}))
PY
)" || fail "invalid projection_authority in $SCHEMA_FILE"

# Retired repo-local projections must not remain tracked or materialized.
while IFS= read -r retired_path; do
  [[ -n "$retired_path" ]] || continue
  if git -C "$ROOT" ls-files --error-unmatch "$retired_path" >/dev/null 2>&1; then
    fail "retired gap projection is still tracked: $retired_path"
  fi
  if [[ -e "$ROOT/$retired_path" ]]; then
    fail "retired gap projection exists in worktree: $retired_path"
  fi
done < <(python3 -c 'import json,sys; [print(p) for p in json.loads(sys.stdin.read())["retired_repo_projections"]]' <<< "$schema_payload")

# Direct writers must stay inside the SQLite authority projector.
direct_writer_hits="$(
  rg -n \
    "gaps_yaml\\.write_text|gaps_file\\.write_text|operational\\.gaps\\.yaml.*write_text|operational-gaps\\.runtime\\.yaml.*write_text|projections/operational-gaps\\.runtime\\.yaml.*write_text|yq e -i .*operational\\.gaps\\.yaml|yq e -i .*operational-gaps\\.runtime\\.yaml" \
    "$ROOT/ops/plugins/core" \
    -g '!**/tests/**' \
    -g '!**/node_modules/**' 2>/dev/null || true
)"
direct_writer_hits="$(printf '%s\n' "$direct_writer_hits" | grep -v 'ops/plugins/core/lifecycle/lib/gaps_sql_authority.py:' || true)"
if [[ -n "${direct_writer_hits//$'\n'/}" ]]; then
  fail "direct gap registry writers remain outside SQLite authority:
$direct_writer_hits"
fi

if [[ -z "${SPINE_STATE:-}" && -f "$RUNTIME_PATHS" ]]; then
  # shellcheck source=/dev/null
  source "$RUNTIME_PATHS"
  spine_runtime_resolve_paths >/dev/null 2>&1 || true
fi

[[ -n "${SPINE_STATE:-}" ]] || fail "SPINE_STATE unresolved"
[[ -f "$SPINE_STATE/shared_authority.db" ]] || fail "shared authority DB missing: $SPINE_STATE/shared_authority.db"
[[ -f "$SPINE_STATE/projections/operational-gaps.runtime.yaml" ]] || fail "runtime gap projection missing: $SPINE_STATE/projections/operational-gaps.runtime.yaml"
[[ -f "$SPINE_STATE/archive/operational.gaps.archive.yaml" ]] || fail "runtime gap archive projection missing: $SPINE_STATE/archive/operational.gaps.archive.yaml"

parity_json="$(python3 "$GAPS_BRIDGE" parity)"
parity_summary="$(
  printf '%s' "$parity_json" | python3 -c '
import json
import sys

payload = json.load(sys.stdin)
if not payload.get("match"):
    raise SystemExit("mismatch")
if int(payload.get("db_count") or 0) != int(payload.get("yaml_count") or 0):
    raise SystemExit("count mismatch")
print(
    "db_count={db_count} yaml_count={yaml_count} archived={archived}".format(
        db_count=payload.get("db_count"),
        yaml_count=payload.get("yaml_count"),
        archived=payload.get("archived_in_db", 0),
    )
)
' 2>/dev/null
)" || fail "SQLite authority parity mismatch for runtime gap projection: $parity_json"

echo "D75 PASS: gap runtime projection lock (retired_repo_projection=absent, writers=authority-only, parity=valid, $parity_summary)"
