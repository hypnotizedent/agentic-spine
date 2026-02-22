#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops board - Terminal-native dashboard for lane/wave orchestration
# ═══════════════════════════════════════════════════════════════════════════
#
# Single-view dashboard showing: active terminals, current wave, lane locks,
# pending handoffs/proposals, last run keys, watcher queue state.
#
# Usage:
#   ops board              Full dashboard
#   ops board --brief      One-line summary
#   ops board --json       Machine-readable JSON
#   ops board --live       Auto-refreshing dashboard (Ctrl-C to stop)
#
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
RUNTIME_ROOT="${SPINE_RUNTIME_ROOT:-$HOME/code/.runtime/spine-mailroom}"
MODE="${1:-}"

# ── Live mode: loop with clear ──
if [[ "$MODE" == "--live" ]]; then
  INTERVAL="${2:-3}"
  trap 'echo; echo "Board stopped."; exit 0' INT TERM
  while true; do
    clear 2>/dev/null || printf '\033[2J\033[H'
    python3 - "$SPINE_REPO" "$RUNTIME_ROOT" "" <<'PYTHON_LIVE'
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

spine = Path(sys.argv[1])
runtime = Path(sys.argv[2])

waves_dir = runtime / "waves"
lanes_state = runtime / "lanes" / "state.json"
proposals_dir = runtime / "outbox" / "proposals"
if not proposals_dir.exists():
    proposals_dir = spine / "mailroom" / "outbox" / "proposals"

# Load data
lanes = {}
try:
    with open(lanes_state) as f:
        lanes = json.load(f).get("lanes", {})
except (FileNotFoundError, json.JSONDecodeError):
    pass

waves = []
active_waves = []
if waves_dir.is_dir():
    for d in sorted(waves_dir.iterdir()):
        sf = d / "state.json"
        if sf.is_file():
            try:
                with open(sf) as f:
                    state = json.load(f)
                waves.append(state)
                if state.get("status") == "active":
                    active_waves.append(state)
            except (json.JSONDecodeError, OSError):
                pass

# Aggregate
all_checks = []
all_run_keys = []
all_dispatches = []
receipt_stats = {"valid": 0, "invalid": 0}

for w in active_waves:
    for c in w.get("watcher_checks", []):
        c["_wave"] = w["wave_id"]
        all_checks.append(c)
        if c.get("run_key"):
            all_run_keys.append(c["run_key"])
    for d in w.get("dispatches", []):
        d["_wave"] = w["wave_id"]
        all_dispatches.append(d)
    # Count receipt artifacts
    wsd = waves_dir / w["wave_id"] / "receipts"
    if wsd.is_dir():
        for fn in wsd.iterdir():
            if fn.suffix == ".json":
                try:
                    with open(fn) as f:
                        json.load(f)
                    receipt_stats["valid"] += 1
                except (json.JSONDecodeError, OSError):
                    receipt_stats["invalid"] += 1
    # Collect receipt run keys from last_collect
    lc = w.get("last_collect", {})
    if lc:
        pass  # already aggregated

now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
print()
print("+" + "=" * 70 + "+")
print("|" + " SPINE ORCHESTRATION BOARD [LIVE]".center(70) + "|")
print("|" + f" {now} ".center(70) + "|")
print("+" + "=" * 70 + "+")
print()

# Lanes
lane_profiles = {
    "control":   {"icon": "C", "mode": "rw", "merge": "Y"},
    "execution": {"icon": "E", "mode": "rw", "merge": "N"},
    "audit":     {"icon": "A", "mode": "ro", "merge": "N"},
    "watcher":   {"icon": "W", "mode": "ro", "merge": "N"}
}

print("  LANES")
print("  " + "-" * 68)
if lanes:
    for name, info in sorted(lanes.items()):
        meta = lane_profiles.get(name, {"icon": "?", "mode": "??", "merge": "?"})
        print(f"  [{meta['icon']}] {name:12s}  term={info['terminal_id']:<8s}  mode={meta['mode']}  merge={meta['merge']}")
else:
    print("  (no lanes open)")
print()

# Waves
print("  WAVES")
print("  " + "-" * 68)
if active_waves:
    for w in active_waves:
        checks = w.get("watcher_checks", [])
        done = sum(1 for c in checks if c["status"] in ("done", "failed"))
        total = len(checks)
        dispatches = w.get("dispatches", [])
        d_done = sum(1 for d in dispatches if d["status"] == "done")
        d_blocked = sum(1 for d in dispatches if d["status"] == "blocked")
        d_pending = sum(1 for d in dispatches if d["status"] == "dispatched")
        pf = w.get("preflight", {})
        pf_str = f"  pf={pf.get('verdict', '?')}" if pf else ""
        lc = w.get("last_collect", {})
        rcpt_str = ""
        if lc:
            rcpt_str = f"  rcpt={lc.get('receipts_valid', 0)}v/{lc.get('receipts_invalid', 0)}i"

        print(f"  {w['wave_id']}  D={d_done}/{d_blocked}/{d_pending}(d/b/p)  chk={done}/{total}{pf_str}{rcpt_str}")
        if w.get("objective"):
            print(f"    {w['objective'][:60]}")
else:
    print("  (no active waves)")
print()

# Watcher Queue
if all_checks:
    print("  WATCHER QUEUE")
    print("  " + "-" * 68)
    status_icons = {"queued": "..", "running": "~~", "done": "OK", "failed": "XX"}
    for c in all_checks:
        icon = status_icons.get(c["status"], "??")
        rk = f"  R={c['run_key']}" if c.get("run_key") else ""
        ec = f"  exit={c['exit_code']}" if c.get("exit_code") is not None else ""
        print(f"  {icon} {c['cap']}{ec}{rk}")
    print()

# Receipt Artifacts
if receipt_stats["valid"] or receipt_stats["invalid"]:
    print("  RECEIPTS")
    print("  " + "-" * 68)
    print(f"  {receipt_stats['valid']} valid | {receipt_stats['invalid']} invalid")
    print()

# Dispatches
pending_handoffs = [d for d in all_dispatches if d["status"] == "dispatched"]
if pending_handoffs:
    print("  PENDING HANDOFFS")
    print("  " + "-" * 68)
    for d in pending_handoffs:
        tid = d.get("task_id", "?")
        print(f"  -> {tid} [{d['lane']:10s}] {d.get('task', '')[:45]}")
    print()

# Run Keys
if all_run_keys:
    print("  RUN KEYS")
    print("  " + "-" * 68)
    for rk in all_run_keys[-5:]:  # Last 5 in live mode
        print(f"  {rk}")
    if len(all_run_keys) > 5:
        print(f"  ... and {len(all_run_keys) - 5} more")
    print()

# Summary
checks_done = sum(1 for c in all_checks if c["status"] in ("done", "failed"))
checks_running = sum(1 for c in all_checks if c["status"] == "running")

print("+" + "=" * 70 + "+")
summary_parts = [
    f"{len(lanes)} lanes",
    f"{len(active_waves)} waves",
    f"{len(all_dispatches)} dispatches",
]
if all_checks:
    summary_parts.append(f"chk {checks_done}/{len(all_checks)}")
if receipt_stats["valid"] or receipt_stats["invalid"]:
    summary_parts.append(f"rcpt {receipt_stats['valid']}v")
if all_run_keys:
    summary_parts.append(f"{len(all_run_keys)} rk")
print("|" + f"  {' | '.join(summary_parts)}".ljust(70) + "|")
print("|" + "  Ctrl-C to stop".ljust(70) + "|")
print("+" + "=" * 70 + "+")
PYTHON_LIVE
    sleep "$INTERVAL"
  done
  exit 0
fi

exec python3 - "$SPINE_REPO" "$RUNTIME_ROOT" "$MODE" <<'PYTHON'
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

spine = Path(sys.argv[1])
runtime = Path(sys.argv[2])
mode = sys.argv[3] if len(sys.argv) > 3 else ""

waves_dir = runtime / "waves"
lanes_state = runtime / "lanes" / "state.json"
proposals_dir = runtime / "outbox" / "proposals"
gaps_file = spine / "ops" / "bindings" / "operational.gaps.yaml"

# Also check in-repo proposals if runtime ones don't exist
if not proposals_dir.exists():
    proposals_dir = spine / "mailroom" / "outbox" / "proposals"

# ── Load lanes ──────────────────────────────────────────────────────────

lanes = {}
try:
    with open(lanes_state) as f:
        lanes = json.load(f).get("lanes", {})
except (FileNotFoundError, json.JSONDecodeError):
    pass

# ── Load waves ──────────────────────────────────────────────────────────

waves = []
active_waves = []
if waves_dir.is_dir():
    for d in sorted(waves_dir.iterdir()):
        sf = d / "state.json"
        if sf.is_file():
            try:
                with open(sf) as f:
                    state = json.load(f)
                waves.append(state)
                if state.get("status") == "active":
                    active_waves.append(state)
            except (json.JSONDecodeError, OSError):
                pass

# ── Load proposals ──────────────────────────────────────────────────────

proposal_counts = {"pending": 0, "applied": 0, "draft_hold": 0}
if proposals_dir.is_dir():
    for cp_dir in proposals_dir.iterdir():
        if not cp_dir.is_dir() or not cp_dir.name.startswith("CP-"):
            continue
        applied = (cp_dir / ".applied").exists()
        if applied:
            proposal_counts["applied"] += 1
        else:
            proposal_counts["pending"] += 1

# ── Aggregate watcher checks ───────────────────────────────────────────

all_checks = []
all_run_keys = []
for w in active_waves:
    for c in w.get("watcher_checks", []):
        c["_wave"] = w["wave_id"]
        all_checks.append(c)
        if c.get("run_key"):
            all_run_keys.append(c["run_key"])

# ── Aggregate dispatches ───────────────────────────────────────────────

all_dispatches = []
for w in active_waves:
    for d in w.get("dispatches", []):
        d["_wave"] = w["wave_id"]
        all_dispatches.append(d)

# ── Aggregate receipt stats ───────────────────────────────────────────

receipt_stats = {"valid": 0, "invalid": 0}
for w in active_waves:
    lc = w.get("last_collect", {})
    if lc:
        receipt_stats["valid"] += lc.get("receipts_valid", 0)
        receipt_stats["invalid"] += lc.get("receipts_invalid", 0)

# ── Brief mode ──────────────────────────────────────────────────────────

if mode == "--brief":
    checks_done = sum(1 for c in all_checks if c["status"] in ("done", "failed"))
    checks_total = len(all_checks)
    parts = [
        f"Lanes: {len(lanes)}",
        f"Waves: {len(active_waves)} active",
        f"Dispatches: {len(all_dispatches)}",
        f"Checks: {checks_done}/{checks_total}",
        f"Run keys: {len(all_run_keys)}",
        f"Receipts: {receipt_stats['valid']}v/{receipt_stats['invalid']}i",
        f"Proposals: {proposal_counts['pending']} pending"
    ]
    print(" | ".join(parts))
    sys.exit(0)

# ── JSON mode ───────────────────────────────────────────────────────────

if mode == "--json":
    print(json.dumps({
        "lanes": lanes,
        "active_waves": [w["wave_id"] for w in active_waves],
        "dispatches": len(all_dispatches),
        "dispatch_status": {
            "done": sum(1 for d in all_dispatches if d.get("status") == "done"),
            "blocked": sum(1 for d in all_dispatches if d.get("status") == "blocked"),
            "pending": sum(1 for d in all_dispatches if d.get("status") == "dispatched"),
            "failed": sum(1 for d in all_dispatches if d.get("status") == "failed")
        },
        "watcher_checks": all_checks,
        "run_keys": all_run_keys,
        "receipt_stats": receipt_stats,
        "proposals": proposal_counts,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    }, indent=2))
    sys.exit(0)

# ── Full dashboard ──────────────────────────────────────────────────────

now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
print()
print("+" + "=" * 70 + "+")
print("|" + " SPINE ORCHESTRATION BOARD".center(70) + "|")
print("|" + f" {now} ".center(70) + "|")
print("+" + "=" * 70 + "+")
print()

# ── Lanes ──
lane_profiles = {
    "control":   {"icon": "C", "mode": "rw", "merge": "Y"},
    "execution": {"icon": "E", "mode": "rw", "merge": "N"},
    "audit":     {"icon": "A", "mode": "ro", "merge": "N"},
    "watcher":   {"icon": "W", "mode": "ro", "merge": "N"}
}

print("  LANES")
print("  " + "-" * 68)
if lanes:
    for name, info in sorted(lanes.items()):
        meta = lane_profiles.get(name, {"icon": "?", "mode": "??", "merge": "?"})
        print(f"  [{meta['icon']}] {name:12s}  term={info['terminal_id']:<8s}  mode={meta['mode']}  merge={meta['merge']}  since={info['opened_at']}")
else:
    print("  (no lanes open)")
print()

# ── Active Waves ──
print("  WAVES")
print("  " + "-" * 68)
if active_waves:
    for w in active_waves:
        checks = w.get("watcher_checks", [])
        done = sum(1 for c in checks if c["status"] in ("done", "failed"))
        total = len(checks)
        dispatches = w.get("dispatches", [])
        d_done = sum(1 for d in dispatches if d.get("status") == "done")
        d_blocked = sum(1 for d in dispatches if d.get("status") == "blocked")
        d_pending = sum(1 for d in dispatches if d.get("status") == "dispatched")
        pf = w.get("preflight", {})
        pf_str = ""
        if pf:
            pf_str = f"  pf={pf.get('verdict', '?')}"
        lc = w.get("last_collect", {})
        rcpt_str = ""
        if lc:
            rcpt_str = f"  rcpt={lc.get('receipts_valid', 0)}v/{lc.get('receipts_invalid', 0)}i"

        print(f"  {w['wave_id']}  D={d_done}/{d_blocked}/{d_pending}(d/b/p)  chk={done}/{total}{pf_str}{rcpt_str}")
        if w.get("objective"):
            print(f"    objective: {w['objective'][:60]}")
else:
    print("  (no active waves)")
print()

# ── Watcher Queue ──
if all_checks:
    print("  WATCHER QUEUE")
    print("  " + "-" * 68)
    status_icons = {"queued": "..", "running": "~~", "done": "OK", "failed": "XX"}
    for c in all_checks:
        icon = status_icons.get(c["status"], "??")
        rk = f"  R={c['run_key']}" if c.get("run_key") else ""
        ec = f"  exit={c['exit_code']}" if c.get("exit_code") is not None else ""
        print(f"  {icon} {c['cap']}{ec}{rk}")
    print()

# ── Run Keys ──
if all_run_keys:
    print("  RUN KEYS")
    print("  " + "-" * 68)
    for rk in all_run_keys:
        print(f"  {rk}")
    print()

# ── Dispatches ──
if all_dispatches:
    print("  DISPATCHES")
    print("  " + "-" * 68)
    for d in all_dispatches:
        status_icon = {"dispatched": "->", "done": "OK", "failed": "XX", "blocked": "!!"}.get(d.get("status", ""), "??")
        tid = d.get("task_id", "?")
        rcpt = " [rcpt]" if d.get("receipt_validated") else ""
        print(f"  {status_icon} {tid} [{d.get('lane', '?'):10s}] {d.get('task', '')[:40]} {d.get('status', '')}{rcpt}")
    print()

# ── Proposals ──
if proposal_counts["pending"] > 0:
    print("  PROPOSALS")
    print("  " + "-" * 68)
    print(f"  {proposal_counts['pending']} pending | {proposal_counts['applied']} applied")
    print()

# ── Summary ──
checks_done = sum(1 for c in all_checks if c["status"] in ("done", "failed"))
checks_running = sum(1 for c in all_checks if c["status"] == "running")

print("+" + "=" * 70 + "+")
summary_parts = [
    f"{len(lanes)} lanes",
    f"{len(active_waves)} waves",
    f"{len(all_dispatches)} dispatches",
]
if all_checks:
    summary_parts.append(f"checks {checks_done}/{len(all_checks)}")
if checks_running:
    summary_parts.append(f"{checks_running} running")
if receipt_stats["valid"] or receipt_stats["invalid"]:
    summary_parts.append(f"rcpt {receipt_stats['valid']}v/{receipt_stats['invalid']}i")
if all_run_keys:
    summary_parts.append(f"{len(all_run_keys)} run keys")
print("|" + f"  {' | '.join(summary_parts)}".ljust(70) + "|")
print("+" + "=" * 70 + "+")
print()
PYTHON
