#!/usr/bin/env bash
# TRIAGE: Clean up stale/orphaned worktrees. Run: ops close loop <LOOP_ID> for merged branches.
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
import re

spine_repo = Path(sys.argv[1]).resolve()
default_workbench = Path("/Users/ronnyworks/code/workbench")
workbench_repo = Path(os.environ.get("WORKBENCH_ROOT", str(default_workbench))).resolve()
if not workbench_repo.exists():
    home_wb = Path.home() / "code" / "workbench"
    workbench_repo = home_wb.resolve() if home_wb.exists() else None

def sh(*args: str, cwd: Path | None = None, check: bool = True) -> str:
    p = subprocess.run(list(args), cwd=str(cwd) if cwd else None, text=True, capture_output=True)
    if check and p.returncode != 0:
        raise SystemExit(p.stderr.strip() or p.stdout.strip() or f"command failed: {' '.join(args)}")
    return p.stdout

def parse_worktrees(repo: Path) -> list[tuple[Path, str]]:
    porcelain = sh("git", "-C", str(repo), "worktree", "list", "--porcelain")
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

    out: list[tuple[Path, str]] = []
    for e in entries:
        p = e.get("worktree", "")
        if not p:
            continue
        wt = Path(p).resolve()
        branch = e.get("branch", "").strip()
        out.append((wt, branch))
    return out

def merged_into_main(repo: Path, branch: str) -> bool:
    out = sh("git", "-C", str(repo), "branch", "--merged", "main", "--list", branch, check=False)
    return bool(out.strip())

def has_origin_branch(repo: Path, branch: str) -> bool:
    p = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "--verify", "--quiet", f"origin/{branch}"],
        text=True,
        capture_output=True,
    )
    return p.returncode == 0

def worktree_loop_id(path: Path) -> str | None:
    m = re.search(r"/orchestration/(LOOP-[^/]+)/", str(path))
    if m:
        return m.group(1)
    return None

def is_closed_loop(loop_id: str) -> bool:
    closed = spine_repo / "mailroom" / "state" / "orchestration" / loop_id / "closed.yaml"
    return closed.exists()

repos = [spine_repo]
if workbench_repo and workbench_repo != spine_repo and workbench_repo.exists():
    repos.append(workbench_repo)

failures: list[str] = []
checked = 0

for repo in repos:
    for wt, raw_branch in parse_worktrees(repo):
        if wt == repo:
            continue
        checked += 1
        branch = (raw_branch or "").strip()
        if branch.startswith("refs/heads/"):
            branch = branch.removeprefix("refs/heads/")
        if not branch:
            p = subprocess.run(["git", "-C", str(wt), "symbolic-ref", "--short", "HEAD"], text=True, capture_output=True)
            branch = p.stdout.strip() if p.returncode == 0 else "<detached>"

        status_msgs: list[str] = []
        if branch != "<detached>":
            if merged_into_main(repo, branch):
                status_msgs.append("stale (merged into main)")
            if not has_origin_branch(repo, branch):
                status_msgs.append(f"orphaned (no remote origin/{branch})")
        else:
            status_msgs.append("detached HEAD")

        loop_id = worktree_loop_id(wt)
        if loop_id and is_closed_loop(loop_id):
            status_msgs.append(f"zombie (loop closed: {loop_id})")

        dirty = sh("git", "-C", str(wt), "status", "--porcelain", check=False).strip()
        if dirty:
            status_msgs.append("dirty (uncommitted changes)")

        if status_msgs:
            failures.append(f"{wt}: {branch or 'unknown'} -> {' '.join(status_msgs)}")

if failures:
    print("D48 FAIL: worktree issues detected")
    for f in failures:
        print(f"  - {f}", file=sys.stderr)
    raise SystemExit(1)

# ── Stash audit ───────────────────────────────────────────────────────────
stash_count = 0
orphaned: list[str] = []
for repo in repos:
    stash_lines = sh("git", "-C", str(repo), "stash", "list", check=False).splitlines()
    for line in stash_lines:
        line = line.strip()
        if not line:
            continue
        stash_count += 1
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

        exists = subprocess.run(
            ["git", "-C", str(repo), "rev-parse", "--verify", "--quiet", f"refs/heads/{stash_branch}"],
            text=True,
            capture_output=True,
        ).returncode == 0
        reason = ""
        if stash_branch in ("main", "master"):
            pass
        elif not exists:
            reason = "branch gone"
        elif merged_into_main(repo, stash_branch):
            reason = "branch merged"
        if reason:
            orphaned.append(f"{repo.name}:{stash_ref} ({stash_branch}): {reason}")

if orphaned:
    print(f"D48 FAIL: orphaned stashes detected ({len(orphaned)} of {stash_count})")
    for o in orphaned:
        print(f"  - {o}", file=sys.stderr)
    print("Fix: git stash drop <ref> for each orphaned entry", file=sys.stderr)
    raise SystemExit(1)

print(f"D48 PASS: worktrees clean (count={checked}), stashes={stash_count} (0 orphaned)")
PY
