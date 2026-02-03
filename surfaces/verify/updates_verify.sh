#!/usr/bin/env bash
set -euo pipefail

RULE_PREFIX="UPDATES"
INV="infrastructure/data/updates_inventory.json"

fail() { echo "${RULE_PREFIX}-${1} FAIL: ${2}"; exit 1; }
pass() { echo "${RULE_PREFIX}-${1} PASS: ${2}"; }

[[ -f "$INV" ]] || fail "001" "missing inventory: $INV"
pass "001" "found inventory"

python3 - <<'PY' "$INV" || exit 1
import json,sys
json.load(open(sys.argv[1],'r',encoding='utf-8'))
PY
pass "002" "inventory json parses"

python3 - <<'PY' "$INV"
import json,sys,os
p=sys.argv[1]
data=json.load(open(p,'r',encoding='utf-8'))

meta=data.get("meta",{})
mechs=data.get("mechanisms",None)

for k in ["schema_version","ssot","governance_doc"]:
    if k not in meta:
        print(f"UPDATES-003 FAIL: meta missing key: {k}")
        sys.exit(1)

if mechs is None or not isinstance(mechs,list):
    print("UPDATES-003 FAIL: mechanisms must be an array")
    sys.exit(1)

seen=set()
for m in mechs:
    for k in ["id","tier","name","type","path","owner","automation","enabled"]:
        if k not in m:
            print(f"UPDATES-003 FAIL: mechanism missing key: {k} (id={m.get('id','?')})")
            sys.exit(1)
    if m["id"] in seen:
        print(f"UPDATES-003 FAIL: duplicate id: {m['id']}")
        sys.exit(1)
    seen.add(m["id"])
print("UPDATES-003 PASS: schema + dedupe checks")
PY

python3 - <<'PY' "$INV"
import json,sys,os
p=sys.argv[1]
data=json.load(open(p,'r',encoding='utf-8'))
missing=[]
for m in data.get("mechanisms",[]):
    path=m.get("path",None)
    if path is None:
        continue
    if not os.path.exists(path):
        missing.append(path)

if missing:
    print("UPDATES-004 FAIL: missing paths:")
    for x in missing:
        print(f"  - {x}")
    sys.exit(1)

print("UPDATES-004 PASS: all non-null paths exist")
PY

echo "UPDATES-999 PASS: updates verification complete"
