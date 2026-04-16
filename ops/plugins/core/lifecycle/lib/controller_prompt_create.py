"""Controller-prompt packet create — governed write-side surface.

Creates a controller-prompt packet by:
  1. Validating packet_id format
  2. Checking filesystem uniqueness (derived path must not exist)
  3. Checking packet_id uniqueness across all existing controller-prompt packets
  4. Validating loop scope exists and is active
  5. Composing frontmatter (governed) + body (operator-authored)
  6. Atomic file write via tmp+rename

Transaction model: single write target (packet file). Either the file exists
with valid frontmatter and body, or it does not.

Design authority: CONTROLLER-PROMPT-GOVERNED-CREATE-DESIGN-20260416.md
Approval: Ronny 2026-04-16 (Tranches 1-3 only)
"""

from __future__ import annotations

import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


# ── packet_id format: PACKET-{NN}-{SLUG} ─────────────────────────
# NN = one or more digits, SLUG = uppercase alpha and hyphens
PACKET_ID_RE = re.compile(r"^PACKET-(\d+)-([A-Z][A-Z0-9-]*)$")


class ControllerPromptCreateError(Exception):
    """Raised for validation or write failure during create."""


def _validate_packet_id(packet_id: str) -> tuple[str, str]:
    """Validate and extract (nn, slug) from packet_id.

    Returns (nn_str, slug) on success.
    Raises ControllerPromptCreateError on failure.
    """
    if not packet_id or not isinstance(packet_id, str):
        raise ControllerPromptCreateError("packet_id is required")
    m = PACKET_ID_RE.match(packet_id.strip())
    if not m:
        raise ControllerPromptCreateError(
            f"packet_id format invalid: '{packet_id}' "
            f"(expected PACKET-{{NN}}-{{SLUG}} where NN is digits, "
            f"SLUG is uppercase alpha/hyphens)"
        )
    return m.group(1), m.group(2)


def _derive_packet_path(
    nn: str, slug: str, created_date: str, controller_prompts_dir: str
) -> str:
    """Derive the deterministic packet file path."""
    filename = f"MAILROOM-CONTROLLER-PACKET-{nn}-{slug}-{created_date}.md"
    return os.path.join(controller_prompts_dir, filename)


def _check_filesystem_uniqueness(packet_path: str) -> None:
    """Fail-closed if derived path already exists."""
    if os.path.exists(packet_path):
        raise ControllerPromptCreateError(
            f"packet file already exists at derived path: {packet_path}"
        )


def _check_packet_id_uniqueness(
    packet_id: str, controller_prompts_dir: str
) -> None:
    """Scan existing packets for duplicate packet_id. Fail-closed if found."""
    prompts_path = Path(controller_prompts_dir)
    if not prompts_path.is_dir():
        return  # no directory = no duplicates possible

    for path in prompts_path.glob("MAILROOM-CONTROLLER-PACKET-*.md"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if not text.startswith("---"):
            continue
        parts = text.split("---", 2)
        if len(parts) < 3:
            continue
        try:
            fm = yaml.safe_load(parts[1])
        except yaml.YAMLError:
            continue
        if not isinstance(fm, dict):
            continue
        existing_pid = str(fm.get("packet_id") or "").strip()
        if existing_pid == packet_id:
            raise ControllerPromptCreateError(
                f"duplicate packet_id '{packet_id}' found in: {path}"
            )


def _validate_loop_scope(loop_id: str, state_root: str) -> None:
    """Validate that loop_id references an active loop scope.

    Checks that a scope file exists in loop-scopes/ with matching loop_id
    and status in {active, open, draft}.
    """
    if not loop_id or not isinstance(loop_id, str):
        raise ControllerPromptCreateError("loop_id is required")

    loop_scopes_dir = Path(state_root) / "loop-scopes"
    if not loop_scopes_dir.is_dir():
        raise ControllerPromptCreateError(
            f"loop-scopes directory not found: {loop_scopes_dir}"
        )

    ACTIVE_STATUSES = frozenset({"active", "open", "draft"})

    for path in loop_scopes_dir.glob("*.scope.md"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if not text.startswith("---"):
            continue
        parts = text.split("---", 2)
        if len(parts) < 3:
            continue
        try:
            fm = yaml.safe_load(parts[1])
        except yaml.YAMLError:
            continue
        if not isinstance(fm, dict):
            continue
        scope_loop_id = str(fm.get("loop_id") or "").strip()
        scope_status = str(fm.get("status") or "").strip().lower()
        if scope_loop_id == loop_id:
            if scope_status in ACTIVE_STATUSES:
                return  # valid
            raise ControllerPromptCreateError(
                f"loop '{loop_id}' exists but status is '{scope_status}' "
                f"(must be one of: {', '.join(sorted(ACTIVE_STATUSES))})"
            )

    raise ControllerPromptCreateError(
        f"no scope file found for loop_id '{loop_id}' in {loop_scopes_dir}"
    )


def _compose_frontmatter(
    packet_id: str,
    loop_id: str,
    concern: str,
    owner: str,
    created_date: str,
    mutation_permitted: bool,
    *,
    parent_loop: str = "",
    origin_packet: str = "",
    anti_drift_rule: str = "",
    packet_type: str = "",
) -> str:
    """Compose YAML frontmatter for the packet."""
    fm: dict[str, Any] = {
        "status": "draft",
        "owner": owner,
        "created": created_date,
        "loop_id": loop_id,
        "packet_id": packet_id,
        "concern": concern,
        "mutation_permitted": mutation_permitted,
    }
    if parent_loop:
        fm["parent_loop"] = parent_loop
    if origin_packet:
        fm["origin_packet"] = origin_packet
    if anti_drift_rule:
        fm["anti_drift_rule"] = anti_drift_rule
    if packet_type:
        fm["type"] = packet_type

    return yaml.safe_dump(
        fm,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
    )


def _read_body(body_source: str | None, body_inline: bool) -> str:
    """Read body content from file path or stdin.

    Returns the body text (may be empty string if no body provided).
    """
    if body_inline:
        return sys.stdin.read()
    if body_source:
        if not os.path.isfile(body_source):
            raise ControllerPromptCreateError(
                f"body source file not found: {body_source}"
            )
        try:
            return Path(body_source).read_text(encoding="utf-8")
        except OSError as exc:
            raise ControllerPromptCreateError(
                f"cannot read body source: {exc}"
            ) from exc
    return ""


def _atomic_write(packet_path: str, content: str) -> None:
    """Atomically write content via tmp+rename."""
    parent = os.path.dirname(packet_path)
    if parent:
        os.makedirs(parent, exist_ok=True)

    tmp_path = f"{packet_path}.tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(tmp_path, packet_path)
    except OSError as exc:
        try:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
        except OSError:
            pass
        raise ControllerPromptCreateError(
            f"filesystem write failed: {exc}"
        ) from exc


def create_packet(
    packet_id: str,
    loop_id: str,
    concern: str,
    state_root: str,
    *,
    body_source: str | None = None,
    body_inline: bool = False,
    owner: str = "@ronny",
    created_date: str = "",
    mutation_permitted: bool = False,
    parent_loop: str = "",
    origin_packet: str = "",
    anti_drift_rule: str = "",
    packet_type: str = "",
) -> dict[str, Any]:
    """Create a controller-prompt packet with governed frontmatter.

    Returns a result dict with packet_path, packet_id, loop_id, status.
    Raises ControllerPromptCreateError on failure.
    """
    # ── Input validation ──────────────────────────────────────────
    if not concern or not isinstance(concern, str) or not concern.strip():
        raise ControllerPromptCreateError("concern is required")

    if not state_root or not os.path.isdir(state_root):
        raise ControllerPromptCreateError(
            f"state_root not found: {state_root}"
        )

    nn, slug = _validate_packet_id(packet_id)

    if not created_date:
        created_date = datetime.now(timezone.utc).strftime("%Y%m%d")

    controller_prompts_dir = os.path.join(state_root, "controller-prompts")

    # ── Derive path ───────────────────────────────────────────────
    packet_path = _derive_packet_path(nn, slug, created_date, controller_prompts_dir)

    # ── Uniqueness checks ─────────────────────────────────────────
    _check_filesystem_uniqueness(packet_path)
    _check_packet_id_uniqueness(packet_id, controller_prompts_dir)

    # ── Loop validation ───────────────────────────────────────────
    _validate_loop_scope(loop_id, state_root)

    # ── Compose content ───────────────────────────────────────────
    frontmatter = _compose_frontmatter(
        packet_id=packet_id,
        loop_id=loop_id,
        concern=concern,
        owner=owner,
        created_date=created_date,
        mutation_permitted=mutation_permitted,
        parent_loop=parent_loop,
        origin_packet=origin_packet,
        anti_drift_rule=anti_drift_rule,
        packet_type=packet_type,
    )

    body = _read_body(body_source, body_inline)

    content = "---\n" + frontmatter + "---\n"
    if body:
        content += "\n" + body

    # ── Atomic write ──────────────────────────────────────────────
    _atomic_write(packet_path, content)

    return {
        "status": "created",
        "packet_path": packet_path,
        "packet_id": packet_id,
        "loop_id": loop_id,
        "concern": concern,
        "owner": owner,
        "created": created_date,
        "mutation_permitted": mutation_permitted,
        "message": f"packet created at {packet_path}",
    }
