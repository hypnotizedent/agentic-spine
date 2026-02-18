#!/usr/bin/env bash
# ops ssot - SSOT registry discovery helper
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
REGISTRY="$SPINE_REPO/docs/governance/SSOT_REGISTRY.yaml"

usage() {
  cat <<'EOF'
ops ssot - SSOT registry discovery

Usage:
  ops ssot list [--all] [--priority <1-5>] [--json]

Commands:
  list      List SSOT entries from docs/governance/SSOT_REGISTRY.yaml

Flags (list):
  --all           Include archived SSOT entries (default: active only)
  --priority N    Filter by priority (1-5)
  --json          Emit JSON envelope
EOF
}

need_file() {
  local file="$1"
  [[ -f "$file" ]] || { echo "FAIL: missing file: $file" >&2; exit 1; }
}

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: missing command: $cmd" >&2; exit 1; }
}

list_ssots() {
  local include_archived=0
  local priority=""
  local json_mode=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) include_archived=1; shift ;;
      --priority)
        priority="${2:?--priority requires a value}"
        shift 2
        ;;
      --json) json_mode=1; shift ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "FAIL: unknown arg: $1" >&2
        exit 2
        ;;
    esac
  done

  if [[ -n "$priority" ]] && [[ ! "$priority" =~ ^[1-5]$ ]]; then
    echo "FAIL: --priority must be an integer from 1 to 5" >&2
    exit 2
  fi

  need_file "$REGISTRY"
  need_cmd yq
  need_cmd python3

  python3 - "$include_archived" "$priority" "$json_mode" "$REGISTRY" <<'PY'
import json
import pathlib
import subprocess
import sys

include_archived = bool(int(sys.argv[1]))
priority_filter = sys.argv[2]
json_mode = bool(int(sys.argv[3]))
registry = sys.argv[4]

try:
    result = subprocess.run(
        ["yq", "e", "-o=json", ".ssots", registry],
        check=True,
        text=True,
        capture_output=True,
    )
    raw = result.stdout.strip()
    ssots = json.loads(raw) if raw else []
except Exception as exc:
    print(f"FAIL: unable to parse SSOT registry JSON: {exc}", file=sys.stderr)
    sys.exit(1)

rows = []
for entry in ssots:
    if not isinstance(entry, dict):
        continue
    archived = bool(entry.get("archived", False))
    if not include_archived and archived:
        continue
    prio = entry.get("priority")
    if priority_filter:
        try:
            if int(prio) != int(priority_filter):
                continue
        except Exception:
            continue
    rows.append({
        "id": entry.get("id", ""),
        "name": entry.get("name", ""),
        "path": entry.get("path", ""),
        "scope": entry.get("scope", ""),
        "priority": prio,
        "owner": entry.get("owner", ""),
        "last_reviewed": entry.get("last_reviewed", ""),
        "archived": archived,
    })

def prio_key(v):
    try:
        return int(v)
    except Exception:
        return 99

rows.sort(key=lambda r: (prio_key(r.get("priority")), str(r.get("id", ""))))

if json_mode:
    print(json.dumps({
        "registry": registry,
        "count": len(rows),
        "include_archived": include_archived,
        "priority_filter": int(priority_filter) if priority_filter else None,
        "entries": rows,
    }, indent=2))
    sys.exit(0)

registry_rel = registry
home = str(pathlib.Path.home())
if registry_rel.startswith(home + "/"):
    registry_rel = "~/" + registry_rel[len(home)+1:]

print("=== SSOT REGISTRY ===")
print(f"Registry: {registry_rel}")
print(f"Entries: {len(rows)}")
print(f"Mode: {'all (including archived)' if include_archived else 'active only'}")
if priority_filter:
    print(f"Priority filter: {priority_filter}")
print("")

if not rows:
    print("(no entries matched)")
    sys.exit(0)

for row in rows:
    prio = row.get("priority")
    prio_label = f"P{prio}" if prio is not None else "P?"
    archived_tag = " archived" if row.get("archived") else ""
    print(f"[{prio_label}] {row.get('id','')} -> {row.get('path','')}{archived_tag}")
    print(f"  owner={row.get('owner','')} scope={row.get('scope','')} last_reviewed={row.get('last_reviewed','')}")
PY
}

cmd="${1:-list}"
shift || true

case "$cmd" in
  list) list_ssots "$@" ;;
  -h|--help|help) usage ;;
  *)
    echo "FAIL: unknown ssot command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
