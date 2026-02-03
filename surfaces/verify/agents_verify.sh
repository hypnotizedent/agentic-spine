#!/usr/bin/env bash
set -euo pipefail

RULE_PREFIX="AGENTS"
INV="infrastructure/data/agents_inventory.json"

fail() { echo "${RULE_PREFIX}-${1} FAIL: ${2}"; exit 1; }
pass() { echo "${RULE_PREFIX}-${1} PASS: ${2}"; }

# AGENTS-001: inventory exists
[[ -f "$INV" ]] || fail "001" "missing inventory: $INV"
pass "001" "found inventory: $INV"

# AGENTS-002: JSON parses
python3 - <<'PY' "$INV" || exit 1
import json,sys
p=sys.argv[1]
with open(p,'r',encoding='utf-8') as f:
    json.load(f)
PY
pass "002" "inventory json parses"

# AGENTS-003: validate required structure + dedupe
python3 - <<'PY' "$INV"
import json,sys,os
p=sys.argv[1]
data=json.load(open(p,'r',encoding='utf-8'))

meta=data.get("meta",{})
agents=data.get("agents",None)

req_meta=["schema_version","ssot","governance_doc"]
for k in req_meta:
    if k not in meta:
        print(f"AGENTS-003 FAIL: meta missing key: {k}")
        sys.exit(1)

if agents is None or not isinstance(agents,list):
    print("AGENTS-003 FAIL: agents must be an array")
    sys.exit(1)

seen_ids=set()
seen_paths=set()
for a in agents:
    for k in ["id","name","path","type","category","owner","schedule","enabled","docs","dependencies"]:
        if k not in a:
            print(f"AGENTS-003 FAIL: agent missing key: {k} (path={a.get('path','?')})")
            sys.exit(1)
    if a["id"] in seen_ids:
        print(f"AGENTS-003 FAIL: duplicate id: {a['id']}")
        sys.exit(1)
    seen_ids.add(a["id"])
    if a["path"] in seen_paths:
        print(f"AGENTS-003 FAIL: duplicate path: {a['path']}")
        sys.exit(1)
    seen_paths.add(a["path"])
print("AGENTS-003 PASS: schema + dedupe checks")
PY

# AGENTS-004: each agent path exists; shell scripts executable
python3 - <<'PY' "$INV"
import json,sys,os,stat
p=sys.argv[1]
data=json.load(open(p,'r',encoding='utf-8'))
agents=data.get("agents",[])

missing=[]
not_exec=[]
for a in agents:
    path=a["path"]
    if not os.path.exists(path):
        missing.append(path)
        continue
    if path.endswith(".sh"):
        mode=os.stat(path).st_mode
        if not (mode & stat.S_IXUSR):
            not_exec.append(path)

if missing:
    print("AGENTS-004 FAIL: missing agent paths:")
    for m in missing:
        print(f"  - {m}")
    sys.exit(1)

# default: treat non-executable .sh as FAIL for consistency
if not_exec:
    print("AGENTS-004 FAIL: non-executable shell scripts:")
    for n in not_exec:
        print(f"  - {n}")
    sys.exit(1)

print("AGENTS-004 PASS: all paths exist; .sh executable")
PY

echo "AGENTS-999 PASS: agents verification complete"
