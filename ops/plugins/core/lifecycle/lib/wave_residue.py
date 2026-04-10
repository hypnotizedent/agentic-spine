"""Wave residue detection and safe sweep surface.

Called from `ops wave residue`. Pairs with Packet 2's unified wave close
lifecycle: when a wave is closed and its workspace.lifecycle_state is
"cleaned", any remaining worktree directory or local codex/WAVE-* branch
is residue. This module enumerates residue deterministically and sweeps
only items it can prove are safe.

Residue classes:
  - stale_worktree: worktree dir exists for a closed wave
  - stale_wave_branch: local codex/WAVE-* branch exists for a closed wave
  - inconsistent_cleaned_workspace: wave says workspace cleaned but
    filesystem/branch still holds residue (strongest signal)

Pure stdlib. No dependencies. No global state. Never touches remotes.
Never operates outside the canonical worktrees prefix for deletions.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from typing import Any

# ── Canonical paths ──────────────────────────────────────────────────

WORKTREES_PREFIX = (
    "/Users/ronnyworks/code/.runtime/spine/tmp/worktrees/agentic-spine/"
)
WAVE_DIR_PREFIX = "WAVE-"
WAVE_BRANCH_PREFIX = "codex/WAVE-"


# ── Subprocess helper ────────────────────────────────────────────────

def _run(
    args: list[str], cwd: str | None = None
) -> tuple[int, str, str]:
    """Run a subprocess, capture stdout/stderr, never raise."""
    try:
        proc = subprocess.run(
            args,
            cwd=cwd,
            check=False,
            capture_output=True,
            text=True,
        )
        return proc.returncode, proc.stdout or "", proc.stderr or ""
    except (OSError, ValueError) as exc:
        return 1, "", str(exc)


def _git(repo_path: str, *args: str) -> tuple[int, str, str]:
    return _run(["git", "-C", repo_path, *args])


# ── Wave state loading ───────────────────────────────────────────────

def _wave_state_path(runtime_root: str, wave_id: str) -> str:
    return os.path.join(runtime_root, "waves", wave_id, "state.json")


def _load_wave_state(runtime_root: str, wave_id: str) -> dict[str, Any] | None:
    path = _wave_state_path(runtime_root, wave_id)
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    return data


def _wave_status(state: dict[str, Any] | None) -> str:
    if not state:
        return "unknown"
    status = state.get("status")
    if isinstance(status, str) and status.strip():
        return status.strip()
    return "unknown"


def _workspace_lifecycle_state(state: dict[str, Any] | None) -> str | None:
    if not state:
        return None
    workspace = state.get("workspace")
    if not isinstance(workspace, dict):
        return None
    ls = workspace.get("lifecycle_state")
    if isinstance(ls, str) and ls.strip():
        return ls.strip()
    return None


# ── Discovery ────────────────────────────────────────────────────────

def _list_worktree_dirs() -> list[str]:
    """List WAVE-* directory names under the canonical worktrees prefix."""
    if not os.path.isdir(WORKTREES_PREFIX):
        return []
    try:
        entries = os.listdir(WORKTREES_PREFIX)
    except OSError:
        return []
    return sorted(
        name for name in entries
        if name.startswith(WAVE_DIR_PREFIX)
        and os.path.isdir(os.path.join(WORKTREES_PREFIX, name))
    )


def _registered_worktrees(repo_path: str) -> set[str]:
    """Return the set of registered worktree paths under our prefix."""
    rc, out, _ = _git(repo_path, "worktree", "list", "--porcelain")
    if rc != 0:
        return set()
    paths: set[str] = set()
    for line in out.splitlines():
        if line.startswith("worktree "):
            p = line[len("worktree "):].strip()
            if p.startswith(WORKTREES_PREFIX):
                paths.add(os.path.normpath(p))
    return paths


def _list_wave_branches(repo_path: str) -> list[str]:
    """List local refs/heads/codex/WAVE-* branch short names."""
    rc, out, _ = _git(
        repo_path,
        "for-each-ref",
        "--format=%(refname:short)",
        "refs/heads/codex/",
    )
    if rc != 0:
        return []
    names: list[str] = []
    for line in out.splitlines():
        name = line.strip()
        if name.startswith(WAVE_BRANCH_PREFIX):
            names.append(name)
    return sorted(names)


def _current_branch(repo_path: str) -> str:
    rc, out, _ = _git(repo_path, "symbolic-ref", "--quiet", "--short", "HEAD")
    if rc != 0:
        return ""
    return out.strip()


def _branch_to_wave_id(branch: str) -> str | None:
    """codex/<WAVE_ID> → <WAVE_ID>. The wave id is the full tail after 'codex/'."""
    if not branch.startswith(WAVE_BRANCH_PREFIX):
        return None
    wave_id = branch[len("codex/"):]
    if not wave_id.startswith(WAVE_DIR_PREFIX):
        return None
    return wave_id


def _dir_to_wave_id(dirname: str) -> str | None:
    """The worktree directory basename IS the wave id."""
    if not dirname.startswith(WAVE_DIR_PREFIX):
        return None
    return dirname


# ── Dirty / ambiguity checks ─────────────────────────────────────────

def _worktree_is_dirty(worktree_path: str) -> tuple[bool, str | None]:
    """Return (is_dirty, error_or_none).

    is_dirty True if `git status --porcelain` reports any entries.
    If git status errors, caller should treat as ambiguous.
    """
    if not os.path.isdir(worktree_path):
        return False, "worktree path missing"
    rc, out, err = _run(
        ["git", "-C", worktree_path, "status", "--porcelain"],
    )
    if rc != 0:
        return False, f"git status failed: {err.strip() or 'unknown error'}"
    return bool(out.strip()), None


def _branch_is_head(repo_path: str, branch: str) -> bool:
    return _current_branch(repo_path) == branch


# ── Item construction ───────────────────────────────────────────────

def _make_item(
    class_: str,
    *,
    wave_id: str | None,
    path: str | None,
    branch: str | None,
    wave_status: str,
    workspace_lifecycle_state: str | None,
    safe_to_sweep: bool,
    ambiguous_reason: str | None,
    identity: str,
) -> dict[str, Any]:
    return {
        "class": class_,
        "wave_id": wave_id,
        "path": path,
        "branch": branch,
        "wave_status": wave_status,
        "workspace_lifecycle_state": workspace_lifecycle_state,
        "safe_to_sweep": bool(safe_to_sweep),
        "ambiguous_reason": ambiguous_reason,
        "identity": identity,
    }


def _item_sort_key(item: dict[str, Any]) -> tuple[str, str, str]:
    return (
        str(item.get("class") or ""),
        str(item.get("wave_id") or ""),
        str(item.get("identity") or ""),
    )


# ── Collection ───────────────────────────────────────────────────────

def collect_residue(runtime_root: str, repo_path: str) -> dict[str, Any]:
    """Enumerate wave residue under the canonical worktrees prefix and repo.

    See module docstring for residue classes and safety rules.
    """
    items: list[dict[str, Any]] = []

    runtime_root = os.path.normpath(runtime_root)
    repo_path = os.path.normpath(repo_path)

    current_head_branch = _current_branch(repo_path)

    # ── Worktree directories ─────────────────────────────────────────
    worktree_dirs = _list_worktree_dirs()
    registered = _registered_worktrees(repo_path)

    # Also include any registered worktree paths under our prefix that may
    # not be listed by os.listdir (unlikely, but cross-reference for truth).
    extra_registered_names: list[str] = []
    for reg_path in registered:
        name = os.path.basename(reg_path.rstrip("/"))
        if name and name.startswith(WAVE_DIR_PREFIX) and name not in worktree_dirs:
            extra_registered_names.append(name)
    worktree_dirs = sorted(set(worktree_dirs) | set(extra_registered_names))

    for name in worktree_dirs:
        full_path = os.path.normpath(os.path.join(WORKTREES_PREFIX, name))
        wave_id = _dir_to_wave_id(name)
        wave_state = _load_wave_state(runtime_root, wave_id) if wave_id else None
        wave_status = _wave_status(wave_state)
        ws_lifecycle = _workspace_lifecycle_state(wave_state)
        identity = f"worktree:{full_path}"

        # Refuse to consider anything outside the canonical prefix as sweepable.
        in_canonical = (full_path + "/").startswith(WORKTREES_PREFIX)
        if not in_canonical:
            items.append(_make_item(
                "stale_worktree",
                wave_id=wave_id,
                path=full_path,
                branch=None,
                wave_status=wave_status,
                workspace_lifecycle_state=ws_lifecycle,
                safe_to_sweep=False,
                ambiguous_reason="worktree path outside canonical prefix",
                identity=identity,
            ))
            continue

        if not wave_id or wave_state is None:
            items.append(_make_item(
                "stale_worktree",
                wave_id=wave_id,
                path=full_path,
                branch=None,
                wave_status="unknown",
                workspace_lifecycle_state=ws_lifecycle,
                safe_to_sweep=False,
                ambiguous_reason="no matching wave state.json",
                identity=identity,
            ))
            continue

        if wave_status != "closed":
            items.append(_make_item(
                "stale_worktree",
                wave_id=wave_id,
                path=full_path,
                branch=None,
                wave_status=wave_status,
                workspace_lifecycle_state=ws_lifecycle,
                safe_to_sweep=False,
                ambiguous_reason=f"wave status is {wave_status!r}, not closed",
                identity=identity,
            ))
            continue

        # Wave is closed. Decide inconsistent_cleaned vs stale_worktree.
        is_inconsistent_cleaned = (ws_lifecycle == "cleaned")

        dirty, dirty_err = _worktree_is_dirty(full_path)
        if dirty_err is not None:
            items.append(_make_item(
                "inconsistent_cleaned_workspace" if is_inconsistent_cleaned
                else "stale_worktree",
                wave_id=wave_id,
                path=full_path,
                branch=None,
                wave_status=wave_status,
                workspace_lifecycle_state=ws_lifecycle,
                safe_to_sweep=False,
                ambiguous_reason=dirty_err,
                identity=identity,
            ))
            continue

        if dirty:
            items.append(_make_item(
                "inconsistent_cleaned_workspace" if is_inconsistent_cleaned
                else "stale_worktree",
                wave_id=wave_id,
                path=full_path,
                branch=None,
                wave_status=wave_status,
                workspace_lifecycle_state=ws_lifecycle,
                safe_to_sweep=False,
                ambiguous_reason="worktree has uncommitted changes",
                identity=identity,
            ))
            continue

        if os.path.normpath(full_path) == repo_path:
            items.append(_make_item(
                "stale_worktree",
                wave_id=wave_id,
                path=full_path,
                branch=None,
                wave_status=wave_status,
                workspace_lifecycle_state=ws_lifecycle,
                safe_to_sweep=False,
                ambiguous_reason="refuses to sweep primary checkout",
                identity=identity,
            ))
            continue

        items.append(_make_item(
            "inconsistent_cleaned_workspace" if is_inconsistent_cleaned
            else "stale_worktree",
            wave_id=wave_id,
            path=full_path,
            branch=None,
            wave_status=wave_status,
            workspace_lifecycle_state=ws_lifecycle,
            safe_to_sweep=True,
            ambiguous_reason=None,
            identity=identity,
        ))

    # ── Wave branches ───────────────────────────────────────────────
    branches = _list_wave_branches(repo_path)
    for branch in branches:
        wave_id = _branch_to_wave_id(branch)
        wave_state = _load_wave_state(runtime_root, wave_id) if wave_id else None
        wave_status = _wave_status(wave_state)
        ws_lifecycle = _workspace_lifecycle_state(wave_state)
        identity = f"branch:{branch}"

        if wave_id is None or wave_state is None:
            items.append(_make_item(
                "stale_wave_branch",
                wave_id=wave_id,
                path=None,
                branch=branch,
                wave_status="unknown",
                workspace_lifecycle_state=ws_lifecycle,
                safe_to_sweep=False,
                ambiguous_reason="no matching wave state.json",
                identity=identity,
            ))
            continue

        if wave_status != "closed":
            items.append(_make_item(
                "stale_wave_branch",
                wave_id=wave_id,
                path=None,
                branch=branch,
                wave_status=wave_status,
                workspace_lifecycle_state=ws_lifecycle,
                safe_to_sweep=False,
                ambiguous_reason=f"wave status is {wave_status!r}, not closed",
                identity=identity,
            ))
            continue

        if branch == current_head_branch:
            items.append(_make_item(
                "stale_wave_branch",
                wave_id=wave_id,
                path=None,
                branch=branch,
                wave_status=wave_status,
                workspace_lifecycle_state=ws_lifecycle,
                safe_to_sweep=False,
                ambiguous_reason="branch is currently checked out (HEAD)",
                identity=identity,
            ))
            continue

        # Classify: inconsistent_cleaned_workspace if workspace said cleaned;
        # otherwise stale_wave_branch.
        class_ = (
            "inconsistent_cleaned_workspace"
            if ws_lifecycle == "cleaned"
            else "stale_wave_branch"
        )

        # Wave is closed and branch is not HEAD. Per contract, the wave being
        # closed is the authoritative signal: safe to sweep.
        items.append(_make_item(
            class_,
            wave_id=wave_id,
            path=None,
            branch=branch,
            wave_status=wave_status,
            workspace_lifecycle_state=ws_lifecycle,
            safe_to_sweep=True,
            ambiguous_reason=None,
            identity=identity,
        ))

    items.sort(key=_item_sort_key)

    # Counts
    by_class: dict[str, int] = {}
    safe_count = 0
    ambiguous_count = 0
    for it in items:
        cls = str(it["class"])
        by_class[cls] = by_class.get(cls, 0) + 1
        if it["safe_to_sweep"]:
            safe_count += 1
        else:
            ambiguous_count += 1

    return {
        "runtime_root": runtime_root,
        "repo_path": repo_path,
        "items": items,
        "counts": {
            "total": len(items),
            "safe_to_sweep": safe_count,
            "ambiguous": ambiguous_count,
            "by_class": by_class,
        },
    }


# ── Sweep ────────────────────────────────────────────────────────────

def _in_canonical_worktree_prefix(path: str) -> bool:
    norm = os.path.normpath(path)
    return (norm + "/").startswith(WORKTREES_PREFIX)


def _sweep_worktree(
    repo_path: str, worktree_path: str
) -> tuple[str, str | None]:
    """Remove a worktree directory. Returns (action_taken, error_or_none)."""
    if not _in_canonical_worktree_prefix(worktree_path):
        return ("refused", "path outside canonical worktrees prefix")
    if os.path.normpath(worktree_path) == os.path.normpath(repo_path):
        return ("refused", "path is primary checkout")
    if not os.path.exists(worktree_path):
        return ("noop_missing", None)

    rc, _out, err = _git(
        repo_path, "worktree", "remove", "--force", worktree_path
    )
    if rc == 0:
        return ("git_worktree_remove", None)

    # Fallback: only if path is canonical AND confirmed not dirty.
    dirty, dirty_err = _worktree_is_dirty(worktree_path)
    if dirty_err is not None:
        return ("refused", f"fallback dirty-check failed: {dirty_err}")
    if dirty:
        return ("refused", "fallback aborted: worktree dirty")

    if not _in_canonical_worktree_prefix(worktree_path):
        return ("refused", "path outside canonical worktrees prefix")

    try:
        shutil.rmtree(worktree_path)
    except OSError as exc:
        return ("refused", f"rmtree failed: {exc}")

    # Prune stale worktree metadata so git forgets it.
    _git(repo_path, "worktree", "prune")
    return ("shutil_rmtree", None)


def _sweep_branch(
    repo_path: str, branch: str
) -> tuple[str, str | None]:
    """Delete a local branch. Returns (action_taken, error_or_none)."""
    if _branch_is_head(repo_path, branch):
        return ("refused", "branch is currently HEAD")
    # Confirm branch still exists (idempotency).
    rc_exists, _out, _err = _git(
        repo_path, "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"
    )
    if rc_exists != 0:
        return ("noop_missing", None)

    rc, _out, err = _git(repo_path, "branch", "-D", branch)
    if rc != 0:
        return ("refused", f"git branch -D failed: {err.strip()}")
    return ("git_branch_delete", None)


def sweep_residue(
    runtime_root: str,
    repo_path: str,
    report: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Sweep only safe-to-sweep residue. Idempotent. Never touches active waves."""
    runtime_root = os.path.normpath(runtime_root)
    repo_path = os.path.normpath(repo_path)

    if report is None:
        report = collect_residue(runtime_root, repo_path)

    swept: list[dict[str, Any]] = []
    skipped_ambiguous: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []

    items = list(report.get("items") or [])
    # Deterministic sweep order: worktrees before branches within each wave,
    # and wave_id ordered. collect_residue already sorts by (class, wave_id,
    # identity). Re-sort defensively.
    items.sort(key=_item_sort_key)

    for item in items:
        if not isinstance(item, dict):
            continue
        cls = str(item.get("class") or "")
        identity = str(item.get("identity") or "")

        if not item.get("safe_to_sweep"):
            skipped_ambiguous.append({
                "class": cls,
                "identity": identity,
                "reason": item.get("ambiguous_reason") or "not safe_to_sweep",
            })
            continue

        # Re-verify wave is closed before touching anything.
        wave_id = item.get("wave_id")
        if wave_id:
            live_state = _load_wave_state(runtime_root, wave_id)
            if _wave_status(live_state) != "closed":
                skipped_ambiguous.append({
                    "class": cls,
                    "identity": identity,
                    "reason": "wave no longer closed at sweep time",
                })
                continue

        try:
            if cls in ("stale_worktree", "inconsistent_cleaned_workspace") and item.get("path"):
                action, err = _sweep_worktree(repo_path, str(item["path"]))
                if err is not None:
                    errors.append({
                        "class": cls,
                        "identity": identity,
                        "error": err,
                    })
                    continue
                swept.append({
                    "class": cls,
                    "identity": identity,
                    "action_taken": action,
                })
                # If this item also has a branch, fall through is not needed
                # here — branches are separate items in collect_residue.
                continue

            if cls in ("stale_wave_branch", "inconsistent_cleaned_workspace") and item.get("branch"):
                action, err = _sweep_branch(repo_path, str(item["branch"]))
                if err is not None:
                    errors.append({
                        "class": cls,
                        "identity": identity,
                        "error": err,
                    })
                    continue
                swept.append({
                    "class": cls,
                    "identity": identity,
                    "action_taken": action,
                })
                continue

            # Unknown shape — treat as ambiguous.
            skipped_ambiguous.append({
                "class": cls,
                "identity": identity,
                "reason": "item has no sweepable path or branch",
            })
        except Exception as exc:  # noqa: BLE001 — defensive per contract
            errors.append({
                "class": cls,
                "identity": identity,
                "error": f"unexpected sweep error: {exc}",
            })

    swept.sort(key=lambda e: (str(e.get("class") or ""), str(e.get("identity") or "")))
    skipped_ambiguous.sort(
        key=lambda e: (str(e.get("class") or ""), str(e.get("identity") or ""))
    )
    errors.sort(key=lambda e: (str(e.get("class") or ""), str(e.get("identity") or "")))

    return {
        "swept": swept,
        "skipped_ambiguous": skipped_ambiguous,
        "errors": errors,
    }


# ── Debug entrypoint ─────────────────────────────────────────────────

if __name__ == "__main__":  # pragma: no cover
    import argparse

    parser = argparse.ArgumentParser(
        description="Print wave residue report as JSON (debug only; never sweeps).",
    )
    parser.add_argument("--runtime-root", required=True)
    parser.add_argument("--repo", required=True)
    ns = parser.parse_args()

    result = collect_residue(ns.runtime_root, ns.repo)
    print(json.dumps(result, indent=2, sort_keys=True))
