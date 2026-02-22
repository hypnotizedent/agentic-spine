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
orch_dir = spine / "mailroom" / "state" / "orchestration"
gaps_file = spine / "ops" / "bindings" / "operational.gaps.yaml"
inbox_dir = spine / "mailroom" / "inbox"

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
planned_loops = []
all_scopes = []
anomalies = []

if scopes_dir.is_dir():
    for f in sorted(scopes_dir.glob("*.scope.md")):
        fm = parse_scope(f)
        status = fm.get("status", "")
        if status not in ("active", "draft", "open", "closed", "planned"):
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
        if status == "planned":
            planned_loops.append(entry)
        elif status in ("active", "draft", "open"):
            open_loops.append(entry)
        else:
            closed_loops.append(entry)

# ── Parse orchestration manifests (bridge to scope-only view) ────────────
# Orchestration loops may exist without a scope file in loop-scopes/.
# Scan manifests and merge any open loops not already seen from scopes.

scope_loop_ids = {e["loop_id"] for e in all_scopes}

if orch_dir.is_dir():
    for manifest_path in sorted(orch_dir.glob("*/manifest.yaml")):
        try:
            text = manifest_path.read_text()
        except OSError:
            continue
        # Simple YAML parse for manifest fields
        mf = {}
        for line in text.splitlines():
            if ":" in line and not line.startswith(" ") and not line.startswith("#"):
                key, _, val = line.partition(":")
                mf[key.strip()] = val.strip().strip('"').strip("'")

        loop_id = mf.get("loop_id", "")
        orch_status = mf.get("status", "")
        if not loop_id:
            continue

        # Skip if already tracked via scope file
        if loop_id in scope_loop_ids:
            continue

        entry = {
            "loop_id": loop_id,
            "status": orch_status,
            "severity": "-",
            "owner": mf.get("apply_owner", "unassigned"),
            "title": loop_id,
            "file": str(manifest_path.relative_to(spine)),
            "source": "orchestration",
        }

        if orch_status in ("active", "open"):
            open_loops.append(entry)
            # Flag missing scope file as anomaly
            anomaly_msg = f"ORCH-SCOPE MISMATCH: {loop_id} has orchestration manifest but no scope file in loop-scopes/"
            anomalies.append(anomaly_msg)
        elif orch_status == "closed":
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

# ── Parse inbox lanes ─────────────────────────────────────────────────────

def count_lane_files(base_dir):
    """Count .md files per lane subdirectory, excluding .keep files."""
    lanes = {}
    if base_dir.is_dir():
        for lane_dir in sorted(base_dir.iterdir()):
            if lane_dir.is_dir() and not lane_dir.name.startswith('.'):
                files = [f for f in lane_dir.glob("*.md") if f.name != ".keep"]
                if files:
                    lanes[lane_dir.name] = len(files)
    return lanes

inbox_lanes = count_lane_files(inbox_dir)
inbox_active = inbox_lanes.get("queued", 0) + inbox_lanes.get("running", 0)
inbox_total = sum(inbox_lanes.values())

# ── Parse proposals queue ─────────────────────────────────────────────────

proposals_dir = spine / "mailroom" / "outbox" / "proposals"
proposal_counts = Counter()

if proposals_dir.is_dir():
    for cp_dir in sorted(proposals_dir.iterdir()):
        if not cp_dir.is_dir() or not cp_dir.name.startswith("CP-"):
            continue
        manifest = cp_dir / "manifest.yaml"
        applied_marker = cp_dir / ".applied"

        if applied_marker.exists():
            proposal_counts["applied"] += 1
            continue

        if not manifest.exists():
            proposal_counts["malformed"] += 1
            continue

        status = "pending"
        text = manifest.read_text()
        for line in text.splitlines():
            if line.startswith("status:"):
                status = line.split(":", 1)[1].strip().strip('"').strip("'")
                break

        proposal_counts[status] += 1

proposal_total = sum(proposal_counts.values())

# ── Communications queue health ──────────────────────────────────────────
import subprocess as _sp

comms_status_bin = spine / "ops" / "plugins" / "communications" / "bin" / "communications-alerts-runtime-status"
comms_oneliner = ""
comms_slo_status = "unknown"
comms_pending = 0
comms_oldest = 0
comms_escalations = 0

if comms_status_bin.exists() and os.access(str(comms_status_bin), os.X_OK):
    try:
        _proc = _sp.run(
            [str(comms_status_bin), "--json"],
            capture_output=True, text=True, timeout=15,
            cwd=str(spine),
        )
        if _proc.returncode == 0 and _proc.stdout.strip():
            _cdata = json.loads(_proc.stdout)
            _cd = _cdata.get("data", {})
            comms_oneliner = _cd.get("oneliner", "")
            comms_slo_status = _cd.get("slo_status", "unknown")
            comms_pending = int(_cd.get("queue_pending_count", 0))
            comms_oldest = int(_cd.get("queue_oldest_age_seconds", 0))
            comms_escalations = int(_cd.get("pending_escalation_task_count", 0))
    except Exception:
        pass

# ── Anomaly detection ─────────────────────────────────────────────────────

# Check for unlinked gaps
for gap in unlinked_gaps:
    anomalies.append(f"UNLINKED GAP: {gap['id']} ({gap['severity']}) has no parent_loop")

# Check for active inbox items (queued or running)
if inbox_active > 0:
    anomalies.append(f"INBOX: {inbox_active} active item(s) in queue — {inbox_lanes.get('queued', 0)} queued, {inbox_lanes.get('running', 0)} running")

failed_count = inbox_lanes.get("failed", 0)
if failed_count > 0:
    anomalies.append(f"INBOX: {failed_count} failed item(s) — investigate or archive")

# Check communications queue health
if comms_slo_status == "incident":
    anomalies.append(f"COMMS QUEUE INCIDENT: pending={comms_pending} oldest={comms_oldest}s escalations={comms_escalations}")
elif comms_slo_status == "warn":
    anomalies.append(f"COMMS QUEUE WARN: pending={comms_pending} oldest={comms_oldest}s")

# ── Output ────────────────────────────────────────────────────────────────

if mode == "--json":
    print(json.dumps({
        "open_loops": open_loops,
        "planned_loops": planned_loops,
        "open_gaps": open_gaps,
        "inbox_lanes": inbox_lanes,
        "inbox_active": inbox_active,
        "inbox_total": inbox_total,
        "proposals": dict(proposal_counts),
        "anomalies": anomalies,
        "comms_queue": {
            "slo_status": comms_slo_status,
            "pending": comms_pending,
            "oldest_age_seconds": comms_oldest,
            "escalations": comms_escalations,
            "oneliner": comms_oneliner,
        },
        "counts": {
            "open_loops": len(open_loops),
            "planned_loops": len(planned_loops),
            "closed_loops": len(closed_loops),
            "open_gaps": len(open_gaps),
            "linked_gaps": len(linked_gaps),
            "unlinked_gaps": len(unlinked_gaps),
            "inbox_active": inbox_active,
            "inbox_total": inbox_total,
            "proposals_total": proposal_total,
            "anomalies": len(anomalies),
        }
    }, indent=2))
    sys.exit(0)

if mode == "--brief":
    parts = [f"Loops: {len(open_loops)} open"]
    if planned_loops:
        parts[0] += f" + {len(planned_loops)} planned"
    parts.append(f"Gaps: {len(open_gaps)} open ({len(unlinked_gaps)} unlinked)")
    parts.append(f"Proposals: {proposal_counts.get('pending', 0)} pending / {proposal_counts.get('draft_hold', 0)} held")
    parts.append(f"Inbox: {inbox_active} active / {inbox_total} total")
    if comms_oneliner:
        parts.append(comms_oneliner)
    parts.append(f"Anomalies: {len(anomalies)}")
    print(" | ".join(parts))
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

# ── Planned Loops ──
if planned_loops:
    print(f"PLANNED LOOPS ({len(planned_loops)})")
    print("-" * 72)
    for loop in planned_loops:
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

# ── Inbox Lanes ──
if inbox_total > 0:
    print(f"INBOX LANES ({inbox_total} total)")
    print("-" * 72)
    for lane_name in ["queued", "running", "failed", "parked", "done", "archived"]:
        count = inbox_lanes.get(lane_name, 0)
        if count > 0:
            marker = " !" if lane_name in ("queued", "running", "failed") else ""
            print(f"  {lane_name:12s} {count}{marker}")
    print()

# ── Communications Queue ──
if comms_oneliner:
    print("COMMS QUEUE")
    print("-" * 72)
    print(f"  {comms_oneliner}")
    print()

# ── Proposals Queue ──
if proposal_total > 0:
    print(f"PROPOSALS ({proposal_total})")
    print("-" * 72)
    for status_name in ["pending", "draft_hold", "applied", "superseded", "draft", "read-only", "invalid", "malformed"]:
        count = proposal_counts.get(status_name, 0)
        if count > 0:
            print(f"  {status_name:15s} {count}")
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
if planned_loops:
    parts.append(f"{len(planned_loops)} planned")
if open_gaps:
    parts.append(f"{len(open_gaps)} gaps")
pending_count = proposal_counts.get("pending", 0)
if pending_count:
    parts.append(f"{pending_count} pending proposals")
if inbox_active:
    parts.append(f"{inbox_active} inbox active")
if anomalies:
    parts.append(f"{len(anomalies)} anomalies")
print(f"  {' | '.join(parts)}")
print("=" * 72)

# Exit code: 0 if clean, 1 if anomalies exist
sys.exit(0 if len(anomalies) == 0 else 1)
PYTHON
