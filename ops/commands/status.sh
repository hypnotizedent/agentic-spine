#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops status - Unified work tracker for the agentic spine
# ═══════════════════════════════════════════════════════════════════════════
#
# Shows a single view of all open work: loops, gaps, inbox items, anomalies.
# This is the canonical agent entry point — replaces `ops loops list --open`.
#
# Usage:
#   ops status              Full status view
#   ops status --json       Machine-readable JSON output
#   ops status --brief      Counts only (for hooks/banners)
#
# See: LOOP-MAILROOM-CONSOLIDATION-20260210
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
MODE="${1:-}"

exec python3 - "$SPINE_REPO" "$MODE" <<'PYTHON'
import json
import os
import re
import sys
from collections import Counter
from pathlib import Path

spine = Path(sys.argv[1])
mode = sys.argv[2] if len(sys.argv) > 2 else ""

scopes_dir = spine / "mailroom" / "state" / "loop-scopes"
gaps_file = spine / "ops" / "bindings" / "operational.gaps.yaml"
inbox_dir = spine / "mailroom" / "inbox"
parked_dir = spine / "mailroom" / "parked"
done_dir = spine / "mailroom" / "done"

FM_RE = re.compile(r"^---\s*$")

# ── Parse scope files ─────────────────────────────────────────────────────

def parse_scope(path):
    """Extract YAML frontmatter fields from a scope file."""
    lines = path.read_text().splitlines()
    in_fm = False
    fm = {}
    for line in lines:
        if FM_RE.match(line):
            if in_fm:
                break
            in_fm = True
            continue
        if in_fm and ":" in line:
            key, _, val = line.partition(":")
            fm[key.strip()] = val.strip().strip('"')

    # Extract title from first heading after frontmatter
    past_fm = False
    fm_count = 0
    for line in lines:
        if FM_RE.match(line):
            fm_count += 1
            if fm_count >= 2:
                past_fm = True
            continue
        if past_fm and line.startswith("#"):
            title = re.sub(r"^#+\s*", "", line)
            title = re.sub(r"^Loop Scope:\s*", "", title)
            fm["_title"] = title
            break

    return fm


open_loops = []
closed_loops = []
all_scopes = []

if scopes_dir.is_dir():
    for f in sorted(scopes_dir.glob("*.scope.md")):
        fm = parse_scope(f)
        status = fm.get("status", "")
        if status not in ("active", "draft", "open", "closed"):
            continue

        entry = {
            "loop_id": fm.get("loop_id", f.stem),
            "status": status,
            "severity": fm.get("severity", "-"),
            "owner": fm.get("owner", "unassigned"),
            "title": fm.get("_title", f.stem),
            "file": str(f.relative_to(spine)),
        }
        all_scopes.append(entry)
        if status in ("active", "draft", "open"):
            open_loops.append(entry)
        else:
            closed_loops.append(entry)

# ── Parse gaps ────────────────────────────────────────────────────────────

open_gaps = []
linked_gaps = []
unlinked_gaps = []

if gaps_file.exists():
    # Simple YAML parsing for gaps (avoids yq/pyyaml dependency)
    content = gaps_file.read_text()
    # Split on gap entries
    gap_blocks = re.split(r"\n  - id: ", content)
    for i, block in enumerate(gap_blocks):
        if i == 0:
            continue  # header
        block = "id: " + block
        lines_dict = {}
        for line in block.splitlines():
            line = line.strip()
            if ":" in line and not line.startswith("#") and not line.startswith("-"):
                key, _, val = line.partition(":")
                key = key.strip()
                val = val.strip().strip('"')
                if key in ("id", "status", "severity", "description", "parent_loop", "discovered_by"):
                    lines_dict[key] = val

        if lines_dict.get("status") == "open":
            gap = {
                "id": lines_dict.get("id", "?"),
                "severity": lines_dict.get("severity", "?"),
                "parent_loop": lines_dict.get("parent_loop", ""),
                "description": lines_dict.get("description", "").rstrip("|").strip(),
            }
            open_gaps.append(gap)
            if gap["parent_loop"] and gap["parent_loop"] != "null":
                linked_gaps.append(gap)
            else:
                unlinked_gaps.append(gap)

# ── Parse inbox/parked/done ───────────────────────────────────────────────

def list_md_files(directory):
    """List .md files in a directory (excluding archived/)."""
    result = []
    if directory.is_dir():
        for f in sorted(directory.glob("*.md")):
            if f.parent.name == "archived":
                continue
            result.append({"name": f.stem, "file": str(f.relative_to(spine))})
    return result

inbox_items = list_md_files(inbox_dir)
parked_items = list_md_files(parked_dir)
done_items = list_md_files(done_dir)

# ── Anomaly detection ─────────────────────────────────────────────────────

anomalies = []

# Check for done items that say OPEN
for item in done_items:
    full_path = spine / item["file"]
    if full_path.exists():
        text = full_path.read_text()
        if "Status:** OPEN" in text or "status: open" in text.lower()[:200]:
            anomalies.append(f"MISLABELED: {item['name']} is in done/ but says OPEN")

# Check for unlinked gaps
for gap in unlinked_gaps:
    anomalies.append(f"UNLINKED GAP: {gap['id']} ({gap['severity']}) has no parent_loop")

# Check for stale inbox (items that have been sitting > 48h would need mtime check)
# For now, just flag if inbox is non-empty
if inbox_items:
    anomalies.append(f"INBOX: {len(inbox_items)} unprocessed item(s) — promote to scope or archive")

# ── Output ────────────────────────────────────────────────────────────────

if mode == "--json":
    print(json.dumps({
        "open_loops": open_loops,
        "open_gaps": open_gaps,
        "inbox": inbox_items,
        "parked": parked_items,
        "anomalies": anomalies,
        "counts": {
            "open_loops": len(open_loops),
            "closed_loops": len(closed_loops),
            "open_gaps": len(open_gaps),
            "linked_gaps": len(linked_gaps),
            "unlinked_gaps": len(unlinked_gaps),
            "inbox": len(inbox_items),
            "parked": len(parked_items),
            "anomalies": len(anomalies),
        }
    }, indent=2))
    sys.exit(0)

if mode == "--brief":
    print(f"Loops: {len(open_loops)} open | Gaps: {len(open_gaps)} open ({len(unlinked_gaps)} unlinked) | Inbox: {len(inbox_items)} | Anomalies: {len(anomalies)}")
    sys.exit(0 if len(anomalies) == 0 else 1)

# Full output
print("=" * 72)
print("  SPINE STATUS")
print("=" * 72)
print()

# ── Open Loops ──
sev_order = {"critical": 0, "high": 1, "medium": 2, "low": 3, "-": 4, "unknown": 5}
sorted_loops = sorted(open_loops, key=lambda x: sev_order.get(x["severity"], 9))

print(f"OPEN LOOPS ({len(open_loops)})")
print("-" * 72)
if not open_loops:
    print("  (none)")
else:
    for loop in sorted_loops:
        print(f"  [{loop['severity']:8s}] {loop['owner']:15s} {loop['loop_id']}")
        if loop["title"] != loop["loop_id"]:
            print(f"  {'':8s}  {'':15s} {loop['title']}")
print()

# ── Open Gaps ──
print(f"OPEN GAPS ({len(open_gaps)})")
print("-" * 72)
if not open_gaps:
    print("  (none)")
else:
    for gap in open_gaps:
        parent = f" -> {gap['parent_loop']}" if gap["parent_loop"] and gap["parent_loop"] != "null" else " (UNLINKED)"
        desc = gap["description"][:60] if gap["description"] else ""
        print(f"  [{gap['severity']:8s}] {gap['id']:12s}{parent}")
print()

# ── Inbox ──
if inbox_items:
    print(f"INBOX ({len(inbox_items)}) — needs triage")
    print("-" * 72)
    for item in inbox_items:
        print(f"  {item['name']}")
    print()

# ── Parked ──
if parked_items:
    print(f"PARKED ({len(parked_items)})")
    print("-" * 72)
    for item in parked_items:
        print(f"  {item['name']}")
    print()

# ── Anomalies ──
if anomalies:
    print(f"ANOMALIES ({len(anomalies)})")
    print("-" * 72)
    for a in anomalies:
        print(f"  ! {a}")
    print()

# ── Summary line ──
print("=" * 72)
parts = [f"{len(open_loops)} loops"]
if open_gaps:
    parts.append(f"{len(open_gaps)} gaps")
if inbox_items:
    parts.append(f"{len(inbox_items)} inbox")
if anomalies:
    parts.append(f"{len(anomalies)} anomalies")
print(f"  {' | '.join(parts)}")
print("=" * 72)

# Exit code: 0 if clean, 1 if anomalies exist
sys.exit(0 if len(anomalies) == 0 else 1)
PYTHON
