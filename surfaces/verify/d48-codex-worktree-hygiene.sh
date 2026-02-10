#!/usr/bin/env bash
# D48: Codex worktree hygiene — detect stale/dirty/orphaned worktrees and orphaned stashes.
#
# NOTE: This must run on macOS default bash (3.2). Do not use bash4 features
# like associative arrays. Use python3 for parsing and checks.
set -euo pipefail

SPINE_CODE=${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
SPINE_REPO=${SPINE_REPO:-$(git -C "$SPINE_CODE" rev-parse --show-toplevel 2>/dev/null || echo "$SPINE_CODE")}

python3 - "$SPINE_REPO" <<'PY'
import os
import subprocess
import sys
from pathlib import Path

spine_repo = Path(sys.argv[1]).resolve()

def sh(*args: str, cwd: Path | None = None, check: bool = True) -> str:
    p = subprocess.run(list(args), cwd=str(cwd) if cwd else None, text=True, capture_output=True)
    if check and p.returncode != 0:
        raise SystemExit(p.stderr.strip() or p.stdout.strip() or f"command failed: {' '.join(args)}")
    return p.stdout

# ── Worktree inventory ────────────────────────────────────────────────────
porcelain = sh("git", "-C", str(spine_repo), "worktree", "list", "--porcelain")
entries: list[dict[str, str]] = []
cur: dict[str, str] = {}
for raw in porcelain.splitlines():
    line = raw.strip()
    if not line:
        if cur:
            entries.append(cur)
            cur = {}
        continue
    if " " not in line:
        continue
    k, v = line.split(" ", 1)
    cur[k] = v.strip()
if cur:
    entries.append(cur)

worktrees: list[tuple[Path, str]] = []
for e in entries:
    p = e.get("worktree", "")
    if not p:
        continue
    wt = Path(p).resolve()
    branch = e.get("branch", "").strip()  # may be absent for detached HEAD
    worktrees.append((wt, branch))

codex_paths: list[tuple[Path, str]] = []
for wt, branch in worktrees:
    if wt == spine_repo:
        continue
    if wt.name.startswith("codex-"):
        codex_paths.append((wt, branch))

failures: list[str] = []

def merged_into_main(branch: str) -> bool:
    out = sh("git", "-C", str(spine_repo), "branch", "--merged", "main", "--list", branch, check=False)
    return bool(out.strip())

def has_origin_branch(branch: str) -> bool:
    p = subprocess.run(
        ["git", "-C", str(spine_repo), "rev-parse", "--verify", "--quiet", f"origin/{branch}"],
        text=True,
        capture_output=True,
    )
    return p.returncode == 0

for wt, raw_branch in codex_paths:
    branch = (raw_branch or "").strip()
    if branch.startswith("refs/heads/"):
        branch = branch.removeprefix("refs/heads/")

    if not branch:
        # Best-effort; if the worktree is detached this will fail.
        p = subprocess.run(["git", "-C", str(wt), "symbolic-ref", "--short", "HEAD"], text=True, capture_output=True)
        branch = p.stdout.strip() if p.returncode == 0 else "<detached>"

    status_msgs: list[str] = []
    if branch != "<detached>":
        if merged_into_main(branch):
            status_msgs.append("stale (merged into main)")
        if not has_origin_branch(branch):
            status_msgs.append(f"orphaned (no remote origin/{branch})")
    else:
        status_msgs.append("detached HEAD")

    dirty = sh("git", "-C", str(wt), "status", "--porcelain", check=False).strip()
    if dirty:
        status_msgs.append("dirty (uncommitted changes)")

    if status_msgs:
        failures.append(f"{wt.name}: {branch or 'unknown'} -> {' '.join(status_msgs)}")

if failures:
    print("Detected codex worktree issues:")
    for f in failures:
        print(f"  - {f}")
    raise SystemExit(1)

# ── Stash audit ───────────────────────────────────────────────────────────
stash_lines = sh("git", "-C", str(spine_repo), "stash", "list", check=False).splitlines()
stash_count = 0
orphaned: list[str] = []
for line in stash_lines:
    line = line.strip()
    if not line:
        continue
    stash_count += 1
    # "stash@{N}: On <branch>: <msg>" or "stash@{N}: WIP on <branch>: <sha> <msg>"
    stash_ref = line.split(":", 1)[0].strip()
    if " On " in line:
        branch_part = line.split(" On ", 1)[1]
    elif " on " in line:
        branch_part = line.split(" on ", 1)[1]
    else:
        continue
    stash_branch = branch_part.split(":", 1)[0].strip()
    if not stash_branch:
        continue

    # Branch existence
    exists = subprocess.run(
        ["git", "-C", str(spine_repo), "rev-parse", "--verify", "--quiet", f"refs/heads/{stash_branch}"],
        text=True,
        capture_output=True,
    ).returncode == 0
    reason = ""
    if stash_branch in ("main", "master"):
        pass  # stashes on the default branch are not orphaned
    elif not exists:
        reason = "branch gone"
    elif merged_into_main(stash_branch):
        reason = "branch merged"
    if reason:
        orphaned.append(f"{stash_ref} ({stash_branch}): {reason}")

if orphaned:
    print(f"Orphaned stashes detected ({len(orphaned)} of {stash_count}):")
    for o in orphaned:
        print(f"  - {o}")
    print("Fix: git stash drop <ref> for each orphaned entry")
    raise SystemExit(1)

print(f"Codex worktrees clean (count={len(codex_paths)}). Stashes: {stash_count} (0 orphaned).")
PY
