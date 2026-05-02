"""Completion-state reconciler — read-side classification engine.

Classifies work items (loops, worktrees, stashes, parked branches, unpushed
commit sets, controller-prompt packets) into one of six states: open, parked,
landed_local, delivered, owned_elsewhere, orphaned. When evidence is
insufficient, emits 'ambiguous' with a named reason instead of guessing.

Design authority: PACKET-38 COMPLETION-STATE-RECONCILER-DESIGN-20260416.md

Public API:
    reconcile(repo_root, state_root, *, current_worktree=None) -> dict

Contract:
  - Pure read-side. No mutations.
  - Uses subprocess for git commands only.
  - Uses SQLite for loop state (sole authority), filesystem reads for handoffs and controller-prompts.
  - Never raises on missing state; degrades to empty classifications.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

# ── Constants ────────────────────────────────────────────────────────

OPEN_LOOP_STATUSES = frozenset({"active", "open", "draft"})
CLOSED_LOOP_STATUSES = frozenset(
    {"closed", "superseded", "abandoned", "deferred", "completed", "landed"}
)
LIVE_LOOP_STATUSES = OPEN_LOOP_STATUSES | frozenset({"parked"})

HANDOFF_NON_LIVE_STATES = frozenset({"closed", "expired", "archived"})
HANDOFF_RESOLVED_PATTERNS = (
    r"\bdelivered\b",
    r"\bclosed\b",
    r"\barchived\b",
    r"\blanded\b",
    r"\bcomplete(?:d)?\b",
    r"\bdone\b",
    r"\bresolved\b",
    r"\bretired\b",
    r"\bmerged to main\b",
    r"\bcheckpoint satisfied\b",
    r"\bno further\b",
)
HANDOFF_CONTINUING_PATTERNS = (
    r"\bblocker\b",
    r"\bblocked\b",
    r"\bawait(?:ing)?\b",
    r"\bpending\b",
    r"\bneeds?\b",
    r"\brequires?\b",
    r"\bdecision\b",
    r"\bapproval\b",
    r"\bunresolved\b",
    r"\bremaining\b",
    r"\bremains\b",
    r"\blive\b",
    r"\bgap remains bounded and live\b",
    r"\bfollow-?up\b",
    r"\bnext move\b",
    r"\bnext action\b",
)
HANDOFF_SEPARATE_FOLLOWON_PATTERNS = (
    r"\boptional\b",
    r"\bseparate slice\b",
    r"\bseparate follow-?on\b",
    r"\bnext frontier\b",
    r"\bfuture work\b",
    r"\boutside this slice\b",
    r"\bas separate slice\b",
)

# Object-class × state applicability matrix (from PACKET-38 design §4)
# True = legal, False = illegal for this combination
APPLICABILITY = {
    "loop": {
        "open": True, "parked": True, "landed_local": False,
        "delivered": False, "owned_elsewhere": True, "orphaned": True,
    },
    "worktree": {
        "open": True, "parked": True, "landed_local": False,
        "delivered": False, "owned_elsewhere": True, "orphaned": True,
    },
    "stash": {
        "open": False, "parked": True, "landed_local": False,
        "delivered": False, "owned_elsewhere": False, "orphaned": True,
    },
    "parked_branch": {
        "open": False, "parked": True, "landed_local": True,
        "delivered": True, "owned_elsewhere": False, "orphaned": True,
    },
    "unpushed_commit_set": {
        "open": False, "parked": False, "landed_local": True,
        "delivered": True, "owned_elsewhere": False, "orphaned": False,
    },
    "controller_prompt_packet": {
        "open": False, "parked": True, "landed_local": False,
        "delivered": True, "owned_elsewhere": False, "orphaned": True,
    },
}


# ── Helpers ──────────────────────────────────────────────────────────

def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _run_git(cmd: list[str], cwd: str) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            ["git"] + cmd,
            cwd=cwd, capture_output=True, text=True, check=False, timeout=10,
        )
        return proc.returncode, proc.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""


def _parse_frontmatter(path: Path) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    if not text.startswith("---"):
        return {}
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    raw = parts[1]
    try:
        payload = yaml.safe_load(raw) or {}
        if isinstance(payload, dict):
            return payload
    except yaml.YAMLError:
        pass
    # Fallback: extract key fields via regex when YAML parsing fails
    # (common cause: unquoted colons in objective/description fields)
    result: dict[str, Any] = {}
    for key in ("loop_id", "status", "owner", "disposition", "created"):
        match = re.search(rf"^{key}:\s*(.+)$", raw, re.MULTILINE)
        if match:
            val = match.group(1).strip().strip("'\"")
            result[key] = val
    return result


def _has_structural_parked_evidence(message: str) -> tuple[bool, str]:
    """Check if a PARKED: stash message has structural evidence (Rule P4).

    Returns (has_evidence, reason).
    """
    if "PARKED:" not in message:
        return False, "no PARKED: prefix"

    # Structural evidence patterns:
    # - explicit file path references (e.g., RECEIPT-*.md, *.yaml)
    has_receipt = bool(re.search(
        r"(?:RECEIPT|receipt|Evidence:|evidence:).*?[-\w]+\.\w{2,4}",
        message,
    ))
    has_governed_followup = bool(re.search(
        r"governed follow-up:|provision\.\w+|ops cap run",
        message,
    ))
    has_handoff_ref = bool(re.search(r"HO-\d{8}-\d{6}", message))

    if has_receipt or has_governed_followup or has_handoff_ref:
        return True, "structural"

    # Vague references like "April 15 continuity artifacts" are NOT structural
    if re.search(r"(?:referenced|Referenced) by .+artifacts?", message, re.IGNORECASE):
        return False, "vague reference, not a concrete artifact path"

    return False, "PARKED: prefix present but no structural evidence reference"


def _matches_any_pattern(text: str, patterns: tuple[str, ...]) -> bool:
    return any(re.search(pattern, text, re.IGNORECASE) for pattern in patterns)


def _normalize_text_fragment(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip().lower()


def _collect_handoff_text(payload: dict[str, Any]) -> str:
    fragments: list[str] = [
        payload.get("summary", ""),
        payload.get("close_note", ""),
    ]
    for key in ("notes", "actions"):
        raw = payload.get(key)
        if isinstance(raw, list):
            fragments.extend(str(item or "") for item in raw)
        elif raw:
            fragments.append(str(raw))
    return " ".join(
        fragment for fragment in (_normalize_text_fragment(item) for item in fragments)
        if fragment
    )


def _runtime_reference_paths(state_root: str, tokens: list[str]) -> list[str]:
    """Find concrete runtime artifacts that reference any given token."""
    search_tokens = [str(token).strip() for token in tokens if str(token).strip()]
    if not search_tokens:
        return []

    state_path = Path(state_root)
    search_roots: list[Path] = [
        state_path / "controller-prompts" / "_intake-artifacts",
        state_path / "domain-state",
        state_path / "handoffs",
        state_path / "path.claims.yaml",
        state_path / "traffic.index.yaml",
    ]
    matches: list[str] = []
    seen_paths: set[str] = set()
    for root in search_roots:
        if not root.exists():
            continue
        candidate_paths = [root] if root.is_file() else sorted(root.rglob("*"))
        for path in candidate_paths:
            if not path.is_file():
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            if any(token in text for token in search_tokens):
                rel_path = str(path.relative_to(state_path))
                if rel_path not in seen_paths:
                    seen_paths.add(rel_path)
                    matches.append(rel_path)
    return matches


def build_loop_state_index(state_root: str) -> dict[str, dict[str, str]]:
    """Build a loop-id -> status/location index from SQLite authority.

    SQLite is the sole loop authority. Scope files are projections only.
    Falls back to empty index on SQLite failure (read-side, never raises).
    """
    import sqlite3

    items: dict[str, dict[str, str]] = {}
    db_path = Path(state_root) / "shared_authority.db"
    if not db_path.is_file():
        return items

    live_statuses = {"active", "open", "draft", "planned", "blocked"}
    try:
        conn = sqlite3.connect(
            f"file:{db_path}?mode=ro", uri=True, timeout=0.5
        )
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT loop_id, status FROM loops ORDER BY loop_id"
        ).fetchall()
        conn.close()
    except (sqlite3.Error, OSError):
        return items

    for row in rows:
        loop_id = str(row["loop_id"] or "").strip()
        status = str(row["status"] or "unknown").strip().lower()
        if not loop_id.startswith("LOOP-"):
            continue
        location = "active" if status in live_statuses else "archive"
        items[loop_id] = {
            "status": status,
            "location": location,
            "path": "",
        }
    return items


def classify_handoff_continuity(
    payload: dict[str, Any],
    loop_index: dict[str, dict[str, str]] | None = None,
) -> dict[str, Any]:
    """Classify whether a handoff is still live continuity or historical residue."""
    loop_index = loop_index or {}
    raw_state = str(payload.get("state") or "unknown").strip().lower()
    loop_refs = [
        str(loop).strip()
        for loop in (payload.get("loops") or [])
        if str(loop).strip()
    ]
    loop_states: list[str] = []
    live_loop_refs: list[str] = []
    missing_loop_refs: list[str] = []
    for loop_id in loop_refs:
        info = loop_index.get(loop_id)
        if not info:
            loop_states.append(f"{loop_id}=missing")
            missing_loop_refs.append(loop_id)
            continue
        status = str(info.get("status") or "unknown").strip().lower()
        location = str(info.get("location") or "unknown").strip().lower()
        loop_states.append(f"{loop_id}={status}@{location}")
        if status in LIVE_LOOP_STATUSES and location != "archive":
            live_loop_refs.append(loop_id)

    text_blob = _collect_handoff_text(payload)
    resolved = _matches_any_pattern(text_blob, HANDOFF_RESOLVED_PATTERNS)
    continuing = _matches_any_pattern(text_blob, HANDOFF_CONTINUING_PATTERNS)
    separate_follow_on = _matches_any_pattern(text_blob, HANDOFF_SEPARATE_FOLLOWON_PATTERNS)

    if raw_state in HANDOFF_NON_LIVE_STATES:
        return {
            "raw_state": raw_state,
            "effective_state": raw_state,
            "continuity_live": False,
            "confidence": "definitive",
            "reason": f"state={raw_state}",
            "loop_states": loop_states,
        }

    if raw_state != "active":
        return {
            "raw_state": raw_state,
            "effective_state": "ambiguous",
            "continuity_live": False,
            "confidence": "probable",
            "reason": f"unrecognized handoff state '{raw_state}'",
            "loop_states": loop_states,
        }

    all_loops_non_live = bool(loop_refs) and not live_loop_refs and not missing_loop_refs
    if all_loops_non_live:
        if continuing:
            return {
                "raw_state": raw_state,
                "effective_state": "ambiguous",
                "continuity_live": False,
                "confidence": "probable",
                "reason": "active handoff points only at closed/archived loops but still reads unresolved",
                "loop_states": loop_states,
            }
        return {
            "raw_state": raw_state,
            "effective_state": "historical",
            "continuity_live": False,
            "confidence": "definitive",
            "reason": "active handoff points only at closed/archived loops",
            "loop_states": loop_states,
        }

    if resolved and separate_follow_on and not continuing:
        return {
            "raw_state": raw_state,
            "effective_state": "historical",
            "continuity_live": False,
            "confidence": "definitive",
            "reason": "delivered handoff only names optional/separate follow-on work",
            "loop_states": loop_states,
        }

    if resolved and not continuing:
        return {
            "raw_state": raw_state,
            "effective_state": "historical",
            "continuity_live": False,
            "confidence": "definitive",
            "reason": "delivery/close language with no unresolved continuity markers",
            "loop_states": loop_states,
        }

    if continuing:
        return {
            "raw_state": raw_state,
            "effective_state": "active",
            "continuity_live": True,
            "confidence": "definitive" if live_loop_refs or not loop_refs else "probable",
            "reason": "unresolved blocker/approval/live-work markers remain",
            "loop_states": loop_states,
        }

    if live_loop_refs:
        return {
            "raw_state": raw_state,
            "effective_state": "active",
            "continuity_live": True,
            "confidence": "probable",
            "reason": "raw state active and referenced loop remains live",
            "loop_states": loop_states,
        }

    return {
        "raw_state": raw_state,
        "effective_state": "ambiguous",
        "continuity_live": False,
        "confidence": "probable",
        "reason": "raw state active but continuity could not be proven live",
        "loop_states": loop_states,
    }


# ── Collectors ───────────────────────────────────────────────────────

def _collect_loops(state_root: str) -> list[dict[str, Any]]:
    """Collect loop specimens from SQLite authority.

    SQLite is the sole loop authority. Only active (live) loops are classified
    individually. Closed loops are counted but not enumerated.
    """
    import sqlite3

    items: list[dict[str, Any]] = []
    db_path = Path(state_root) / "shared_authority.db"
    if not db_path.is_file():
        _collect_loops._archived_count = 0  # type: ignore[attr-defined]
        return items

    live_statuses = ("active", "open", "draft", "planned", "blocked")
    try:
        conn = sqlite3.connect(
            f"file:{db_path}?mode=ro", uri=True, timeout=0.5
        )
        conn.row_factory = sqlite3.Row
        live_rows = conn.execute(
            "SELECT loop_id, status, owner, disposition FROM loops "
            "WHERE LOWER(status) IN ({}) ORDER BY loop_id".format(
                ",".join("?" for _ in live_statuses)
            ),
            live_statuses,
        ).fetchall()
        archived_count = conn.execute(
            "SELECT COUNT(*) FROM loops "
            "WHERE LOWER(status) NOT IN ({})".format(
                ",".join("?" for _ in live_statuses)
            ),
            live_statuses,
        ).fetchone()[0]
        conn.close()
    except (sqlite3.Error, OSError):
        _collect_loops._archived_count = 0  # type: ignore[attr-defined]
        return items

    for row in live_rows:
        loop_id = str(row["loop_id"] or "").strip()
        if not loop_id.startswith("LOOP-"):
            continue
        items.append({
            "object_class": "loop",
            "identity": loop_id,
            "location": "active",
            "status": str(row["status"] or "unknown").strip().lower(),
            "owner": str(row["owner"] or "").strip(),
            "disposition": str(row["disposition"] or "").strip().lower(),
            "path": "",
        })

    _collect_loops._archived_count = archived_count  # type: ignore[attr-defined]
    return items

# Module-level accessor for archived count
_collect_loops._archived_count = 0  # type: ignore[attr-defined]


def _collect_worktrees(repo_root: str) -> list[dict[str, Any]]:
    """Collect worktree specimens from git.

    The first entry from `git worktree list --porcelain` is always the
    primary checkout, regardless of which worktree we run from.
    """
    items: list[dict[str, Any]] = []
    rc, out = _run_git(["worktree", "list", "--porcelain"], repo_root)
    if rc != 0:
        return items

    raw_entries: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in out.splitlines():
        if line.startswith("worktree "):
            if current:
                raw_entries.append(current)
            current = {"worktree": line.split(" ", 1)[1]}
        elif line.startswith("HEAD "):
            current["head"] = line.split(" ", 1)[1]
        elif line.startswith("branch "):
            current["branch"] = line.split(" ", 1)[1].replace("refs/heads/", "")
        elif line.strip() == "detached":
            current["detached"] = "true"
    if current:
        raw_entries.append(current)

    for idx, entry in enumerate(raw_entries):
        items.append(_worktree_to_item(entry, repo_root, is_first=(idx == 0)))

    return items


def _worktree_to_item(wt: dict[str, str], repo_root: str, *, is_first: bool) -> dict[str, Any]:
    path = wt.get("worktree", "")
    branch = wt.get("branch", "")
    head = wt.get("head", "")
    # The first entry in git worktree list is always the primary checkout
    is_primary = is_first

    # Count unique commits vs main
    unique_count = 0
    if branch and branch != "main" and not wt.get("detached"):
        rc, count_out = _run_git(
            ["rev-list", "--count", f"main..{head}"],
            repo_root,
        )
        if rc == 0 and count_out.isdigit():
            unique_count = int(count_out)

    return {
        "object_class": "worktree",
        "identity": path,
        "branch": branch,
        "head": head,
        "is_primary": is_primary,
        "unique_commits": unique_count,
        "detached": wt.get("detached") == "true",
    }


def _collect_stashes(repo_root: str) -> list[dict[str, Any]]:
    """Collect stash specimens."""
    items: list[dict[str, Any]] = []
    rc, out = _run_git(["stash", "list"], repo_root)
    if rc != 0 or not out:
        return items

    for line in out.splitlines():
        # Format: stash@{N}: On BRANCH: MESSAGE
        match = re.match(r"(stash@\{\d+\}): On ([^:]+): (.+)", line)
        if not match:
            continue
        ref, parent_branch, message = match.group(1), match.group(2), match.group(3)
        items.append({
            "object_class": "stash",
            "identity": ref,
            "parent_branch": parent_branch,
            "message": message,
            "raw": line,
        })

    return items


def _collect_parked_branches(repo_root: str) -> list[dict[str, Any]]:
    """Collect parked/* branches."""
    items: list[dict[str, Any]] = []
    rc, out = _run_git(["branch", "--list", "parked/*", "-v"], repo_root)
    if rc != 0 or not out:
        return items

    for line in out.splitlines():
        line = line.strip().lstrip("* ")
        parts = line.split(None, 2)
        if len(parts) < 2:
            continue
        branch_name = parts[0]
        tip_sha = parts[1]
        commit_msg = parts[2] if len(parts) > 2 else ""

        # Check if merged into main
        rc_merged, _ = _run_git(
            ["merge-base", "--is-ancestor", tip_sha, "main"],
            repo_root,
        )
        is_merged = rc_merged == 0

        items.append({
            "object_class": "parked_branch",
            "identity": branch_name,
            "tip_sha": tip_sha,
            "commit_message": commit_msg,
            "merged_into_main": is_merged,
        })

    return items


def _collect_unpushed(repo_root: str) -> list[dict[str, Any]]:
    """Collect unpushed commit set."""
    rc, out = _run_git(
        ["log", "origin/main..main", "--oneline"],
        repo_root,
    )
    if rc != 0:
        return []

    commits = []
    for line in out.splitlines():
        if not line.strip():
            continue
        parts = line.split(None, 1)
        commits.append({
            "sha": parts[0],
            "message": parts[1] if len(parts) > 1 else "",
        })

    if not commits:
        return []

    return [{
        "object_class": "unpushed_commit_set",
        "identity": f"origin/main..main ({len(commits)} commits)",
        "commit_count": len(commits),
        "commits": commits,
    }]


def _collect_controller_prompt_packets(state_root: str) -> list[dict[str, Any]]:
    """Collect controller-prompt packet specimens from runtime state.

    Reads packet frontmatter from controller-prompts/ directory and checks
    for matching governed EXEC_RECEIPT in domain-state/.
    """
    items: list[dict[str, Any]] = []
    prompts_dir = Path(state_root) / "controller-prompts"
    receipts_dir = Path(state_root) / "domain-state"

    if not prompts_dir.is_dir():
        return items

    # Dual glob: canonical (CONTROLLER-PACKET-*) + legacy (MAILROOM-CONTROLLER-PACKET-*).
    # Legacy prefix retired by LOOP-VOCABULARY-READBACK-SUBTRACTION-SLICE-1.
    _seen: set = set()
    _all = []
    for _glob in ("CONTROLLER-PACKET-*.md", "MAILROOM-CONTROLLER-PACKET-*.md"):
        for _p in prompts_dir.glob(_glob):
            if _p in _seen:
                continue
            _seen.add(_p)
            _all.append(_p)
    for path in sorted(_all):
        front = _parse_frontmatter(path)
        packet_id = str(front.get("packet_id") or "").strip()
        status = str(front.get("status") or "unknown").strip().lower()
        loop_id = str(front.get("loop_id") or "").strip()
        disposition = str(front.get("disposition") or "").strip().lower()
        pkt_type = str(front.get("type") or "").strip().lower()

        # Check for governed EXEC_RECEIPT
        has_receipt = False
        if packet_id and receipts_dir.is_dir():
            safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", packet_id)
            has_receipt = any(receipts_dir.glob(f"EXEC_RECEIPT-CONTROLLER-PROMPT-{safe_id}-*.yaml"))

        items.append({
            "object_class": "controller_prompt_packet",
            "identity": packet_id or path.stem,
            "status": status,
            "disposition": disposition,
            "loop_id": loop_id,
            "packet_type": pkt_type,
            "has_packet_id": bool(packet_id),
            "has_governed_receipt": has_receipt,
            "path": str(path),
        })

    return items


# ── Handoff scanner (for ownership evidence) ────────────────────────

def _scan_active_handoffs(state_root: str) -> list[dict[str, Any]]:
    """Scan active handoffs for ownership evidence."""
    handoffs_dir = Path(state_root) / "handoffs"
    if not handoffs_dir.is_dir():
        return []

    loop_index = build_loop_state_index(state_root)
    results: list[dict[str, Any]] = []
    for path in sorted(handoffs_dir.glob("HO-*.yaml")):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
            payload = yaml.safe_load(text)
        except (OSError, yaml.YAMLError):
            continue
        if not isinstance(payload, dict):
            continue
        continuity = classify_handoff_continuity(payload, loop_index)
        if continuity.get("effective_state") != "active":
            continue
        results.append({
            "id": path.stem,
            "summary": str(payload.get("summary") or "").strip(),
            "loops": payload.get("loops", []) if isinstance(payload.get("loops"), list) else [],
            "effective_state": continuity.get("effective_state"),
            "continuity_reason": continuity.get("reason", ""),
            "loop_states": continuity.get("loop_states", []),
        })

    return results


# ── Classifier ───────────────────────────────────────────────────────

def _classify_loop(item: dict[str, Any]) -> dict[str, Any]:
    """Classify a loop specimen. Rule P1: scope status is authoritative."""
    status = item.get("status", "unknown")
    location = item.get("location", "")

    if status in CLOSED_LOOP_STATUSES or location == "archive":
        return {
            "computed_state": None,
            "is_live": False,
            "confidence": "definitive",
            "evidence": f"status={status}, location={location}",
            "rule": "P1",
            "note": "closed/non-live — not classified into six-state set",
        }

    if status in OPEN_LOOP_STATUSES and location == "active":
        return {
            "computed_state": "open",
            "is_live": True,
            "confidence": "definitive",
            "evidence": f"scope file in active dir, status={status}",
            "rule": "P1",
        }

    if status == "parked":
        return {
            "computed_state": "parked",
            "is_live": True,
            "confidence": "definitive",
            "evidence": f"status=parked, disposition={item.get('disposition', '')}",
            "rule": "P1",
        }

    return {
        "computed_state": "orphaned",
        "is_live": True,
        "confidence": "probable",
        "evidence": f"status={status}, location={location}",
        "rule": "P1+P7",
        "ambiguity_reason": f"unexpected status '{status}' in {location}",
    }


def _classify_worktree(
    item: dict[str, Any],
    current_worktree: str | None,
    handoffs: list[dict[str, Any]],
) -> dict[str, Any]:
    """Classify a worktree. Rule P3: existence + unique commits = active signal."""
    if item.get("is_primary"):
        return {
            "computed_state": None,
            "is_live": False,
            "confidence": "definitive",
            "evidence": "primary checkout — not classified as a work item",
            "rule": "N/A",
            "note": "primary checkout is the base, not a work item",
        }

    branch = item.get("branch", "")
    unique = item.get("unique_commits", 0)
    path = item.get("identity", "")

    # Is this worktree the one we're currently operating in?
    if current_worktree and os.path.normpath(path) == os.path.normpath(current_worktree):
        if unique > 0:
            return {
                "computed_state": "open",
                "is_live": True,
                "confidence": "definitive",
                "evidence": f"current terminal worktree, {unique} unique commits",
                "rule": "P3",
            }
        return {
            "computed_state": "open",
            "is_live": True,
            "confidence": "definitive",
            "evidence": "current terminal worktree, no unique commits yet",
            "rule": "P3",
        }

    # Another worktree — check for ownership signals
    has_handoff_ref = any(
        branch in ho.get("summary", "") or path in ho.get("summary", "")
        for ho in handoffs
    )

    if unique > 0:
        if has_handoff_ref:
            return {
                "computed_state": "owned_elsewhere",
                "is_live": True,
                "confidence": "definitive",
                "evidence": f"{unique} unique commits, handoff references this worktree",
                "rule": "P3",
            }
        return {
            "computed_state": "owned_elsewhere",
            "is_live": True,
            "confidence": "probable",
            "evidence": f"{unique} unique commits, not current terminal",
            "rule": "P3+P7",
            "ambiguity_reason": "no handoff or loop binds this worktree to a specific owner",
        }

    # No unique commits
    return {
        "computed_state": "orphaned",
        "is_live": True,
        "confidence": "probable",
        "evidence": "non-primary worktree with 0 unique commits",
        "rule": "P3+P7",
        "ambiguity_reason": "worktree exists but has no unique commits and no ownership signal",
    }


def _classify_stash(item: dict[str, Any]) -> dict[str, Any]:
    """Classify a stash. Rule P4: parked evidence must be structural."""
    message = item.get("message", "")

    if "PARKED:" not in message:
        return {
            "computed_state": "orphaned",
            "is_live": True,
            "confidence": "definitive",
            "evidence": "stash without PARKED: prefix",
            "rule": "P4",
        }

    has_evidence, reason = _has_structural_parked_evidence(message)
    if has_evidence:
        return {
            "computed_state": "parked",
            "is_live": True,
            "confidence": "definitive",
            "evidence": f"PARKED: with structural evidence ({reason})",
            "rule": "P4",
        }

    return {
        "computed_state": "ambiguous",
        "is_live": True,
        "confidence": "probable",
        "evidence": f"PARKED: prefix present but {reason}",
        "rule": "P4+P7",
        "ambiguity_reason": reason,
    }


def _classify_parked_branch(
    item: dict[str, Any],
    stashes: list[dict[str, Any]],
    handoffs: list[dict[str, Any]],
    state_root: str,
) -> dict[str, Any]:
    """Classify a parked branch."""
    branch = item.get("identity", "")
    merged = item.get("merged_into_main", False)

    if merged:
        # Check if also pushed to origin (we detect this via the unpushed set)
        return {
            "computed_state": "delivered",
            "is_live": True,
            "confidence": "probable",
            "evidence": f"branch {branch} is ancestor of main",
            "rule": "P2",
            "note": "merged to main; delivery status depends on push state",
        }

    # Check for structural evidence across stashes and handoffs
    has_stash_ref = any(
        branch in s.get("message", "") or branch in s.get("raw", "")
        for s in stashes
    )
    has_handoff_ref = any(
        branch in ho.get("summary", "")
        for ho in handoffs
    )

    if has_stash_ref or has_handoff_ref:
        evidence_parts = []
        if has_stash_ref:
            evidence_parts.append("referenced by stash")
        if has_handoff_ref:
            evidence_parts.append("referenced by handoff")
        return {
            "computed_state": "parked",
            "is_live": True,
            "confidence": "definitive",
            "evidence": f"unmerged, {', '.join(evidence_parts)}",
            "rule": "P4",
        }

    branch_text = " ".join(
        [
            str(item.get("identity") or ""),
            str(item.get("commit_message") or ""),
        ]
    )
    wave_tokens = sorted(set(re.findall(r"WAVE-\d{8}-\d+", branch_text)))
    runtime_refs = _runtime_reference_paths(state_root, wave_tokens)
    if runtime_refs:
        preview = ", ".join(runtime_refs[:2])
        if len(runtime_refs) > 2:
            preview += f", +{len(runtime_refs) - 2} more"
        evidence = "referenced by runtime artifacts"
        if wave_tokens:
            evidence += f" for {', '.join(wave_tokens)}"
        evidence += f" ({preview})"
        return {
            "computed_state": "parked",
            "is_live": True,
            "confidence": "definitive",
            "evidence": f"unmerged, {evidence}",
            "rule": "P4",
        }

    # parked/ prefix is a hint, not authority
    return {
        "computed_state": "ambiguous",
        "is_live": True,
        "confidence": "probable",
        "evidence": f"parked/ prefix but no structural evidence (no stash, no handoff)",
        "rule": "P4+P7",
        "ambiguity_reason": "branch name suggests parked but no cross-reference evidence exists",
    }


def _classify_unpushed(item: dict[str, Any]) -> dict[str, Any]:
    """Classify unpushed commit set. Rule P2: git ref state is authoritative."""
    count = item.get("commit_count", 0)
    if count == 0:
        return {
            "computed_state": "delivered",
            "is_live": False,
            "confidence": "definitive",
            "evidence": "no commits in origin/main..main",
            "rule": "P2",
        }

    return {
        "computed_state": "landed_local",
        "is_live": True,
        "confidence": "definitive",
        "evidence": f"{count} commits ahead of origin/main",
        "rule": "P2",
    }


def _classify_controller_prompt_packet(item: dict[str, Any]) -> dict[str, Any]:
    """Classify a controller-prompt packet.

    Rules:
      - closed + governed receipt → delivered (non-live: work is done)
      - retired → non-live (excluded from classification)
      - draft + no packet_id (index file) → parked with honest reason
      - draft + governed receipt absent → ambiguous
    """
    status = item.get("status", "unknown")
    has_receipt = item.get("has_governed_receipt", False)
    has_pid = item.get("has_packet_id", False)
    disposition = item.get("disposition", "")
    pkt_type = item.get("packet_type", "")

    # Retired packets are done — exclude from live classification
    if status == "retired":
        return {
            "computed_state": None,
            "is_live": False,
            "confidence": "definitive",
            "evidence": "status=retired",
            "rule": "P5",
            "note": "retired packet — excluded from live classification",
        }

    # Closed with governed receipt → delivered
    if status == "closed" and has_receipt:
        return {
            "computed_state": "delivered",
            "is_live": True,
            "confidence": "definitive",
            "evidence": f"status=closed, disposition={disposition}, governed EXEC_RECEIPT present",
            "rule": "P5",
        }

    # Closed without receipt — still delivered but with lower confidence
    if status == "closed":
        return {
            "computed_state": "delivered",
            "is_live": True,
            "confidence": "probable",
            "evidence": f"status=closed, disposition={disposition}, no governed EXEC_RECEIPT",
            "rule": "P5",
            "note": "closed packet without governed receipt",
        }

    # Draft: index file without packet_id → parked (honest structural reason)
    if status == "draft" and not has_pid:
        return {
            "computed_state": "parked",
            "is_live": True,
            "confidence": "definitive",
            "evidence": "status=draft, no packet_id (index/meta-document)",
            "rule": "P5",
            "note": f"packet_type={pkt_type}; cannot use governed close without packet_id",
        }

    # Draft with packet_id but no receipt → ambiguous
    if status == "draft":
        return {
            "computed_state": "ambiguous",
            "is_live": True,
            "confidence": "probable",
            "evidence": "status=draft, no governed close or receipt",
            "rule": "P5+P7",
            "ambiguity_reason": "draft packet with no governed close — may be abandoned or pending",
        }

    # Unknown status
    return {
        "computed_state": "orphaned",
        "is_live": True,
        "confidence": "probable",
        "evidence": f"unexpected packet status '{status}'",
        "rule": "P5+P7",
        "ambiguity_reason": f"unrecognized status: {status}",
    }


# ── Public API ───────────────────────────────────────────────────────

def reconcile(
    repo_root: str,
    state_root: str,
    *,
    current_worktree: str | None = None,
) -> dict[str, Any]:
    """Run the completion-state reconciler against live state.

    Returns a structured payload with per-item classifications, summary
    counts, and snapshot metadata.

    Args:
        repo_root: Path to the git repository root.
        state_root: Path to SPINE_STATE (e.g., .runtime/spine/state).
        current_worktree: Path to the worktree the current terminal is
            operating in (used for owned_elsewhere vs open distinction).
    """
    snapshot_ts = _utc_now_iso()

    # Collect all specimens
    loops = _collect_loops(state_root)
    worktrees = _collect_worktrees(repo_root)
    stashes = _collect_stashes(repo_root)
    parked_branches = _collect_parked_branches(repo_root)
    unpushed = _collect_unpushed(repo_root)
    packets = _collect_controller_prompt_packets(state_root)
    handoffs = _scan_active_handoffs(state_root)

    # Classify each specimen
    classifications: list[dict[str, Any]] = []

    for item in loops:
        result = _classify_loop(item)
        classifications.append({
            **item,
            **result,
        })

    for item in worktrees:
        result = _classify_worktree(item, current_worktree, handoffs)
        classifications.append({
            **item,
            **result,
        })

    for item in stashes:
        result = _classify_stash(item)
        classifications.append({
            **item,
            **result,
        })

    for item in parked_branches:
        result = _classify_parked_branch(item, stashes, handoffs, state_root)
        classifications.append({
            **item,
            **result,
        })

    for item in unpushed:
        result = _classify_unpushed(item)
        classifications.append({
            **item,
            **result,
        })

    for item in packets:
        result = _classify_controller_prompt_packet(item)
        classifications.append({
            **item,
            **result,
        })

    # Compute summary counts
    live_items = [c for c in classifications if c.get("is_live")]
    state_counts: dict[str, int] = {
        "open": 0, "parked": 0, "landed_local": 0,
        "delivered": 0, "owned_elsewhere": 0, "orphaned": 0,
    }
    ambiguous_count = 0
    for c in live_items:
        state = c.get("computed_state")
        if state == "ambiguous":
            ambiguous_count += 1
        elif state in state_counts:
            state_counts[state] += 1

    non_live = [c for c in classifications if not c.get("is_live")]
    archived_loops = getattr(_collect_loops, "_archived_count", 0)

    return {
        "schema_version": "1.0",
        "snapshot_timestamp": snapshot_ts,
        "total_specimens": len(classifications),
        "live_specimens": len(live_items),
        "non_live_specimens": len(non_live),
        "archived_loops": archived_loops,
        "state_counts": state_counts,
        "ambiguous_count": ambiguous_count,
        "classifications": classifications,
        "handoff_count": len(handoffs),
    }


def summary_for_joined_state(reconciliation: dict[str, Any]) -> dict[str, Any]:
    """Extract a summary suitable for embedding in joined-state payload."""
    counts = reconciliation.get("state_counts", {})
    return {
        "snapshot_timestamp": reconciliation.get("snapshot_timestamp", ""),
        "total_specimens": reconciliation.get("total_specimens", 0),
        "live_specimens": reconciliation.get("live_specimens", 0),
        "non_live_specimens": reconciliation.get("non_live_specimens", 0),
        "open": counts.get("open", 0),
        "parked": counts.get("parked", 0),
        "landed_local": counts.get("landed_local", 0),
        "delivered": counts.get("delivered", 0),
        "owned_elsewhere": counts.get("owned_elsewhere", 0),
        "orphaned": counts.get("orphaned", 0),
        "ambiguous": reconciliation.get("ambiguous_count", 0),
    }
