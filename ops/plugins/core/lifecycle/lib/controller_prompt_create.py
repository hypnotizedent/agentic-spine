"""Controller-prompt packet create — governed write-side surface.

Creates a controller-prompt packet by:
  1. Validating packet_id format
  2. Checking filesystem uniqueness (derived path must not exist)
  3. Checking packet_id uniqueness across all existing controller-prompt packets
  4. Validating loop scope exists and is active
  5. Refusing accidental live sibling packets for the same loop
  6. Composing frontmatter (governed) + body (operator-authored)
  7. Atomic file write via tmp+rename

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

import intent_use_receipts as iur


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


# Filename glob pattern that matches BOTH the new canonical mint
# (CONTROLLER-PACKET-*.md) AND the historical legacy mint
# (MAILROOM-CONTROLLER-PACKET-*.md). Used by every uniqueness/scan loop here
# so that retiring the MAILROOM- prefix does not orphan 300+ historical files.
# The legacy prefix was retired by LOOP-VOCABULARY-READBACK-SUBTRACTION-SLICE-1
# per HUMAN-INPUT-PIPELINE-FULL-TRACE-RESEARCH-20260502.
PACKET_FILENAME_GLOBS = ("CONTROLLER-PACKET-*.md", "MAILROOM-CONTROLLER-PACKET-*.md")


def _iter_packet_files(prompts_path: Path):
    """Yield existing packet files matching either canonical or legacy globs."""
    seen: set[Path] = set()
    for glob in PACKET_FILENAME_GLOBS:
        for path in prompts_path.glob(glob):
            if path in seen:
                continue
            seen.add(path)
            yield path


def _derive_packet_path(
    nn: str, slug: str, created_date: str, controller_prompts_dir: str
) -> str:
    """Derive the deterministic packet file path.

    Canonical mint pattern is CONTROLLER-PACKET-{nn}-{slug}-{date}.md. The
    legacy MAILROOM- prefix is no longer produced; old files remain as
    historical compatibility and are still discovered via the dual-glob
    scan in _iter_packet_files().

    PACKET-685 (collision audit) fix #2: if slug already ends in an
    eight-digit YYYYMMDD suffix, skip the duplicate -{created_date}
    append so we don't produce CONTROLLER-PACKET-NN-...-20260503-20260503.md
    filenames. The double-date class was visible in PACKET-665 / 675 / 631 /
    similar canonical filenames before this fix.
    """
    slug_normalized = slug
    if re.fullmatch(r".*-\d{8}", slug):
        # Slug already carries its own date suffix (operator pasted the full
        # YYYYMMDD-form packet id, or a renamed slug already terminated in
        # date). Strip it and let the canonical -{created_date} re-append once.
        slug_normalized = slug[: -len("-YYYYMMDD")]
    filename = f"CONTROLLER-PACKET-{nn}-{slug_normalized}-{created_date}.md"
    return os.path.join(controller_prompts_dir, filename)


def _check_packet_nn_uniqueness(
    nn: str,
    packet_id: str,
    controller_prompts_dir: str,
    allow_sibling: bool,
    sibling_justification: str,
    supersedes_packet: str,
) -> None:
    """PACKET-685 (collision audit) fix #1: refuse creation when an existing
    controller-prompt packet with a DIFFERENT slug but same NN exists, unless
    --allow-sibling with explicit --sibling-justification (or
    --supersedes-packet) is supplied.

    Complementary to PACKET-675 (commit-msg boundary). PACKET-675 enforces
    at the commit boundary; this guard enforces at the controller-prompt
    birth boundary. Together they refuse same-NN reuse at both surfaces.

    Existing _check_packet_id_uniqueness still covers exact-packet-id
    duplicates. This new guard catches the same-NN/different-slug class
    (e.g., PACKET-665-FORGE-AGENT-BOUNDARY-STAGE-2 vs
    PACKET-665-EMIT-ASSIGNMENT-SCOPE-FILE-FALLBACK-SUBTRACTION-F3).

    PACKET-690 first-class closure: source the NN from each existing
    packet's frontmatter `packet_id` field, NOT from a filename prefix.
    Filename shape varies (canonical CONTROLLER-PACKET-* and legacy
    MAILROOM-CONTROLLER-PACKET-*); the frontmatter packet_id is the
    authoritative semantic identifier and survives any filename drift.
    """
    prompts_path = Path(controller_prompts_dir)
    if not prompts_path.is_dir():
        return  # no directory = no duplicates possible

    existing_with_same_nn: list[Path] = []
    for path in _iter_packet_files(prompts_path):
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
        if not existing_pid:
            continue
        # Extract NN from packet_id (PACKET-{NN}-{SLUG}). This sources NN
        # from the authoritative semantic identifier, not the filename, so
        # legacy MAILROOM-CONTROLLER-PACKET-{nn}-*.md files are correctly
        # included in the same-NN scan.
        pid_match = PACKET_ID_RE.match(existing_pid)
        if not pid_match:
            continue
        if pid_match.group(1) != nn:
            continue
        if existing_pid == packet_id:
            continue  # exact match handled elsewhere
        existing_with_same_nn.append(path)

    if not existing_with_same_nn:
        return

    if supersedes_packet:
        # Operator declared this is a planned supersession. Allow.
        return
    if allow_sibling and sibling_justification.strip():
        # Operator authorized sibling reuse with explicit justification. Allow.
        return

    paths_str = ", ".join(str(p.name) for p in existing_with_same_nn)
    raise ControllerPromptCreateError(
        f"PACKET-{nn} reuse refused: "
        f"existing controller-prompt(s) with same PACKET-NN but different "
        f"slug already on canonical: {paths_str}. "
        f"To intentionally create a sibling, supply "
        f"--allow-sibling AND --sibling-justification '<text>', "
        f"OR --supersedes-packet PACKET-NN-PRIOR-SLUG. "
        f"PACKET-685 (collision audit) enforces same-NN/different-slug "
        f"refusal at the controller-prompt birth boundary; "
        f"PACKET-675 enforces at the commit-message boundary."
    )


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

    for path in _iter_packet_files(prompts_path):
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


def _packet_frontmatter(path: Path) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    if not text.startswith("---"):
        return {}
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    try:
        fm = yaml.safe_load(parts[1])
    except yaml.YAMLError:
        return {}
    return fm if isinstance(fm, dict) else {}


def _live_packets_for_loop(
    loop_id: str, controller_prompts_dir: str
) -> list[dict[str, str]]:
    prompts_path = Path(controller_prompts_dir)
    if not prompts_path.is_dir():
        return []

    packets: list[dict[str, str]] = []
    for path in sorted(_iter_packet_files(prompts_path)):
        fm = _packet_frontmatter(path)
        if str(fm.get("loop_id") or "").strip() != loop_id:
            continue
        status = str(fm.get("status") or "unknown").strip().lower()
        if status in {"closed", "retired"}:
            continue
        packet_id = str(fm.get("packet_id") or "").strip()
        if not packet_id:
            continue
        packets.append({
            "packet_id": packet_id,
            "status": status,
            "path": str(path),
        })
    return packets


def _check_loop_sibling_policy(
    *,
    packet_id: str,
    loop_id: str,
    controller_prompts_dir: str,
    allow_sibling: bool,
    sibling_justification: str,
    supersedes_packet: str,
) -> None:
    siblings = [
        packet
        for packet in _live_packets_for_loop(loop_id, controller_prompts_dir)
        if packet.get("packet_id") != packet_id
    ]
    if not siblings:
        return

    sibling_ids = [packet["packet_id"] for packet in siblings]
    if not allow_sibling and not supersedes_packet:
        raise ControllerPromptCreateError(
            f"loop '{loop_id}' already has live controller packet(s): "
            f"{', '.join(sibling_ids)}. Use controller_prompt.amend for the "
            "existing packet, or rerun with --allow-sibling plus "
            "--sibling-justification, or --supersedes-packet PACKET-ID."
        )

    if supersedes_packet and supersedes_packet not in sibling_ids:
        raise ControllerPromptCreateError(
            f"--supersedes-packet '{supersedes_packet}' is not a live packet "
            f"for loop '{loop_id}' (live: {', '.join(sibling_ids)})"
        )

    if allow_sibling and not sibling_justification.strip() and not supersedes_packet:
        raise ControllerPromptCreateError(
            "--allow-sibling requires --sibling-justification unless "
            "--supersedes-packet is supplied"
        )


def _validate_loop_scope(loop_id: str, state_root: str) -> None:
    """Validate that loop_id references an active loop in SQLite authority.

    SQLite is the sole loop authority. Scope files are projections only.
    """
    if not loop_id or not isinstance(loop_id, str):
        raise ControllerPromptCreateError("loop_id is required")

    import sqlite3

    ACTIVE_STATUSES = frozenset({"active", "open", "draft"})

    # Honor LOOPS_DB_PATH override (canonical resolver uses same env var)
    db_path = Path(
        os.environ.get("LOOPS_DB_PATH", str(Path(state_root) / "shared_authority.db"))
    )
    if not db_path.is_file():
        raise ControllerPromptCreateError(
            f"loop authority database not found: {db_path}"
        )

    try:
        conn = sqlite3.connect(
            f"file:{db_path}?mode=ro", uri=True, timeout=0.5
        )
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT status FROM loops WHERE loop_id = ? LIMIT 1",
            (loop_id,),
        ).fetchone()
        conn.close()
    except (sqlite3.Error, OSError) as exc:
        raise ControllerPromptCreateError(
            f"loop authority query failed for '{loop_id}': {exc}"
        )

    if row is None:
        raise ControllerPromptCreateError(
            f"no loop found for loop_id '{loop_id}' in SQLite authority"
        )

    status = str(row["status"] or "").strip().lower()
    if status not in ACTIVE_STATUSES:
        raise ControllerPromptCreateError(
            f"loop '{loop_id}' exists but status is '{status}' "
            f"(must be one of: {', '.join(sorted(ACTIVE_STATUSES))})"
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
    source_ref: str = "",
    human_intent_id: str = "",
    materialization_status: str = "",
    materialization_ref: str = "",
    allow_sibling: bool = False,
    sibling_justification: str = "",
    supersedes_packet: str = "",
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
    if source_ref:
        fm["source_ref"] = source_ref
    if human_intent_id:
        fm["human_intent_id"] = human_intent_id
        fm["source_human_intent_id"] = human_intent_id
        fm["driven_by_intents"] = [human_intent_id]
    if materialization_status:
        fm["materialization_status"] = materialization_status
    if materialization_ref:
        fm["materialization_ref"] = materialization_ref
    if allow_sibling or sibling_justification or supersedes_packet:
        fm["loop_sibling_policy"] = "supersedes" if supersedes_packet else "explicit_sibling"
        fm["sibling_of_loop"] = loop_id
    if sibling_justification:
        fm["sibling_justification"] = sibling_justification
    if supersedes_packet:
        fm["supersedes_packet"] = supersedes_packet

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
    source_ref: str = "",
    human_intent_id: str = "",
    materialization_status: str = "",
    materialization_ref: str = "",
    allow_sibling: bool = False,
    sibling_justification: str = "",
    supersedes_packet: str = "",
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
    _check_packet_nn_uniqueness(
        nn=nn,
        packet_id=packet_id,
        controller_prompts_dir=controller_prompts_dir,
        allow_sibling=allow_sibling,
        sibling_justification=sibling_justification,
        supersedes_packet=supersedes_packet,
    )

    # ── Loop validation ───────────────────────────────────────────
    _validate_loop_scope(loop_id, state_root)

    # ── Loop sibling policy ───────────────────────────────────────
    _check_loop_sibling_policy(
        packet_id=packet_id,
        loop_id=loop_id,
        controller_prompts_dir=controller_prompts_dir,
        allow_sibling=allow_sibling,
        sibling_justification=sibling_justification,
        supersedes_packet=supersedes_packet,
    )

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
        source_ref=source_ref,
        human_intent_id=human_intent_id,
        materialization_status=materialization_status,
        materialization_ref=materialization_ref,
        allow_sibling=allow_sibling,
        sibling_justification=sibling_justification,
        supersedes_packet=supersedes_packet,
    )

    body = _read_body(body_source, body_inline)

    content = "---\n" + frontmatter + "---\n"
    if body:
        content += "\n" + body

    # ── Atomic write ──────────────────────────────────────────────
    _atomic_write(packet_path, content)

    if human_intent_id:
        try:
            conn = iur.connect(iur.db_path(state_root))
            iur.ensure_schema(conn)
            iur.write_receipt(
                conn,
                human_intent_ref=human_intent_id,
                used_as="birth_input",
                destination_type="packet",
                destination_ref=packet_id,
                reason="Controller packet was created from human intent carried into controller_prompt.create.",
                proof_ref=packet_path,
                capture_mode="automatic",
                source_ref=source_ref,
                created_by="controller_prompt.create",
            )
            conn.commit()
            conn.close()
        except Exception as exc:
            try:
                os.remove(packet_path)
            except OSError:
                pass
            raise ControllerPromptCreateError(
                f"intent-use receipt write failed after packet birth; packet removed: {exc}"
            ) from exc

    return {
        "status": "created",
        "packet_path": packet_path,
        "packet_id": packet_id,
        "loop_id": loop_id,
        "concern": concern,
        "owner": owner,
        "created": created_date,
        "mutation_permitted": mutation_permitted,
        "source_ref": source_ref,
        "human_intent_id": human_intent_id,
        "materialization_status": materialization_status,
        "materialization_ref": materialization_ref,
        "allow_sibling": allow_sibling,
        "sibling_justification": sibling_justification,
        "supersedes_packet": supersedes_packet,
        "message": f"packet created at {packet_path}",
    }
