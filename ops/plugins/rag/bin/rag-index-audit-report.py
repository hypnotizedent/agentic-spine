#!/usr/bin/env python3
"""Parse AnythingLLM workspace dump and compare against eligible docs."""
import json, sys, os, re
from collections import Counter

if len(sys.argv) < 3:
    print("Usage: rag-index-audit-report.py <workspace.json> <spine_root>")
    sys.exit(1)

ws_file = sys.argv[1]
spine_root = sys.argv[2]

with open(ws_file) as f:
    data = json.load(f)

ws = data.get("workspace", data)
if isinstance(ws, list):
    ws = ws[0]
docs = ws.get("documents", [])


def extract_name(filename):
    """Extract original filename from 'ORIGINAL.md-UUID.json' pattern."""
    name = filename
    if name.endswith(".json"):
        name = name[:-5]
    m = re.match(
        r"^(.+)-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
        name,
    )
    if m:
        return m.group(1)
    return name


# Build indexed set
indexed_names = Counter()
indexed_entries = []
for d in docs:
    fn = d.get("filename", "")
    orig = extract_name(fn)
    indexed_names[orig] += 1
    indexed_entries.append(
        {"id": d["id"], "docId": d.get("docId", ""), "filename": fn, "orig": orig}
    )

# Build eligible set
eligible = set()
skip_patterns = [
    "docs/legacy",
    "_audits",
    "_archived",
    "_imported",
    "receipts/",
    "mailroom/state/",
    "fixtures/",
    ".git/",
    "node_modules/",
    "/.archive/",
]
for root_dir in ["docs", "ops", "surfaces"]:
    full_dir = os.path.join(spine_root, root_dir)
    if not os.path.isdir(full_dir):
        continue
    for dirpath, dirnames, filenames in os.walk(full_dir):
        rel_dir = os.path.relpath(dirpath, spine_root)
        skip = False
        for p in skip_patterns:
            if rel_dir.startswith(p) or p in rel_dir:
                skip = True
                break
        if skip:
            continue
        for fn in filenames:
            if fn.endswith(".md"):
                eligible.add(fn)

# Find stale
stale = [e for e in indexed_entries if e["orig"] not in eligible]

# Find duplicates
dupes = {k: v for k, v in indexed_names.items() if v > 1}

# Find missing
missing = eligible - set(indexed_names.keys())

print(f"indexed_total: {len(docs)}")
print(f"unique_indexed: {len(indexed_names)}")
print(f"eligible_total: {len(eligible)}")
print(f"stale_entries: {len(stale)}")
print(f"duplicate_names: {len(dupes)} (extra entries: {sum(v - 1 for v in dupes.values())})")
print(f"missing_from_index: {len(missing)}")
print()

if stale:
    print("=== STALE (in index, not eligible) ===")
    for s in sorted(stale, key=lambda x: x["orig"]):
        print(f"  [{s['id']}] {s['orig']}")
    print()

if dupes:
    print("=== DUPLICATES (multiple entries for same doc) ===")
    for name, count in sorted(dupes.items()):
        print(f"  {name}: {count} entries")
        entries_for_name = [e for e in indexed_entries if e["orig"] == name]
        for e in entries_for_name:
            print(f"    [{e['id']}] {e['filename']}")
    print()

if missing and len(missing) <= 30:
    print("=== MISSING (eligible but not indexed) ===")
    for m in sorted(missing):
        print(f"  {m}")
    print()
elif missing:
    print(f"=== MISSING: {len(missing)} docs (too many to list) ===")
    print()

excess = len(stale) + sum(v - 1 for v in dupes.values())
print(f"total_excess: {excess}")
print(f"predicted_post_cleanup: {len(docs) - excess}")
if eligible:
    predicted_ratio = (len(docs) - excess) / len(eligible)
    print(f"predicted_inflation_ratio: {predicted_ratio:.2f}")
