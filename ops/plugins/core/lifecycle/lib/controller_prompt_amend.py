"""Controller-prompt packet amend/checkpoint — governed mid-packet surface.

Creates one governed continuity checkpoint between controller_prompt.create and
controller_prompt.close by mutating the packet frontmatter in place.

Transaction model:
  1. validate packet exists, is parseable, and belongs to an active loop
  2. write updated packet frontmatter (primary truth)
  3. sync loop next_action/evidence continuity when requested

If loop continuity sync fails after the packet write, the packet checkpoint is
still durable and the failure is reported explicitly as a detectable partial.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

import controller_prompt_create as cpc
import loops_sql_authority as lsa


class ControllerPromptAmendError(Exception):
    """Raised for validation or write failure during amend."""


def _now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _amendment_id() -> str:
    return "AMEND-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _normalize_string_list(value: Any) -> list[str]:
    if isinstance(value, list):
        items = value
    elif value in (None, ""):
        items = []
    else:
        items = [value]

    result: list[str] = []
    seen: set[str] = set()
    for item in items:
        text = str(item or "").strip()
        if not text or text in seen:
            continue
        seen.add(text)
        result.append(text)
    return result


def _merge_evidence_refs(existing: list[str], incoming: list[str], *, append: bool) -> list[str]:
    if append:
        return _normalize_string_list(existing + incoming)
    return _normalize_string_list(incoming)


def _find_packet_path(packet_id: str, state_root: str) -> Path:
    prompts_dir = Path(state_root) / "controller-prompts"
    if not prompts_dir.is_dir():
        raise ControllerPromptAmendError(f"controller-prompts directory not found: {prompts_dir}")

    for path in prompts_dir.glob("MAILROOM-CONTROLLER-PACKET-*.md"):
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
        if isinstance(fm, dict) and str(fm.get("packet_id", "")).strip() == packet_id:
            return path

    raise ControllerPromptAmendError(f"packet '{packet_id}' not found")


def _parse_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    if not text.startswith("---"):
        raise ControllerPromptAmendError("packet file has no YAML frontmatter")
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise ControllerPromptAmendError("packet file has unclosed YAML frontmatter")
    try:
        fm = yaml.safe_load(parts[1])
    except yaml.YAMLError as exc:
        raise ControllerPromptAmendError(f"frontmatter YAML parse error: {exc}") from exc
    if not isinstance(fm, dict):
        raise ControllerPromptAmendError("frontmatter is not a YAML mapping")
    return fm, parts[2]


def _atomic_write_markdown(path: Path, frontmatter: dict[str, Any], body: str) -> None:
    rendered = yaml.safe_dump(
        frontmatter,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
    )
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    try:
        tmp_path.write_text("---\n" + rendered + "---" + body, encoding="utf-8")
        os.replace(tmp_path, path)
    except OSError as exc:
        try:
            if tmp_path.exists():
                tmp_path.unlink()
        except OSError:
            pass
        raise ControllerPromptAmendError(f"packet write failed: {exc}") from exc


def _sync_loop_continuity(
    *,
    state_root: str,
    loop_id: str,
    next_action: str = "",
    evidence_refs: list[str] | None = None,
    append_evidence_refs: bool = False,
    actor: str = "",
    reason: str = "",
    run_key: str = "",
) -> dict[str, Any]:
    if not next_action and evidence_refs is None:
        return {"status": "not_requested"}

    db_path = Path(
        os.environ.get("LOOPS_DB_PATH", str(Path(state_root) / "shared_authority.db"))
    )
    if not db_path.is_file():
        raise ControllerPromptAmendError(f"loop authority database not found: {db_path}")

    conn = lsa.connect(db_path)
    try:
        row = lsa.update_loop_continuity(
            conn,
            loop_id,
            next_action=next_action or None,
            evidence_refs=evidence_refs,
            append_evidence_refs=append_evidence_refs,
            actor=actor or None,
            reason=reason or None,
            run_key=run_key or None,
            mutation_source="controller_prompt.amend",
        )
        conn.commit()
    except Exception as exc:  # pragma: no cover - surfaced directly to caller
        raise ControllerPromptAmendError(str(exc)) from exc
    finally:
        conn.close()

    if row is None:
        raise ControllerPromptAmendError(f"loop '{loop_id}' not found in authority")

    return {
        "status": "updated",
        "loop_id": loop_id,
        "next_action": row.get("next_action"),
        "evidence_refs": row.get("evidence_refs") or [],
    }


def amend_packet(
    *,
    packet_id: str,
    state_root: str,
    summary: str,
    reason: str,
    next_action: str = "",
    evidence_refs: list[str] | None = None,
    append_evidence_refs: bool = False,
    actor: str = "",
) -> dict[str, Any]:
    if not packet_id or not packet_id.strip():
        raise ControllerPromptAmendError("packet_id is required")
    if not summary or not summary.strip():
        raise ControllerPromptAmendError("summary is required")
    if not reason or not reason.strip():
        raise ControllerPromptAmendError("reason is required")
    if not state_root or not os.path.isdir(state_root):
        raise ControllerPromptAmendError(f"state_root not found: {state_root}")

    packet_path = _find_packet_path(packet_id.strip(), state_root)
    try:
        text = packet_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ControllerPromptAmendError(f"cannot read packet: {exc}") from exc

    fm, body = _parse_frontmatter(text)
    packet_status = str(fm.get("status", "")).strip().lower()
    if packet_status == "closed":
        raise ControllerPromptAmendError(f"packet '{packet_id}' is already closed")

    loop_id = str(fm.get("loop_id", "")).strip()
    cpc._validate_loop_scope(loop_id, state_root)

    actor = (
        str(actor or "").strip()
        or os.environ.get("SPINE_TERMINAL_ID", "").strip()
        or os.environ.get("OPS_TERMINAL_ID", "").strip()
        or os.environ.get("OPS_TERMINAL_ROLE", "").strip()
        or "unknown"
    )
    run_key = os.environ.get("SPINE_CAP_RUN_KEY", "").strip()
    amended_at = _now_utc()
    amendment_id = _amendment_id()

    incoming_refs = _normalize_string_list(evidence_refs)
    existing_refs = _normalize_string_list(fm.get("evidence_refs"))
    merged_refs = existing_refs
    if evidence_refs is not None:
        merged_refs = _merge_evidence_refs(
            existing_refs,
            incoming_refs,
            append=append_evidence_refs,
        )

    history = _normalize_string_list(fm.get("amendment_history"))
    history.append(
        " | ".join([
            amendment_id,
            f"actor={actor}",
            f"reason={reason.strip()}",
            f"summary={summary.strip()}",
            f"next_action={next_action.strip() or '-'}",
            f"evidence_refs={len(merged_refs)}",
            f"run_key={run_key or '-'}",
        ])
    )

    fm["continuity_summary"] = summary.strip()
    if next_action.strip():
        fm["next_action"] = next_action.strip()
    elif "next_action" not in fm:
        fm["next_action"] = ""
    fm["evidence_refs"] = merged_refs
    fm["last_amendment_id"] = amendment_id
    fm["last_amended_at_utc"] = amended_at
    fm["last_amended_by"] = actor
    fm["last_amendment_reason"] = reason.strip()
    if run_key:
        fm["last_amendment_run_key"] = run_key
    fm["checkpoint_status"] = "checkpointed"
    fm["amendment_history"] = history

    _atomic_write_markdown(packet_path, fm, body)

    loop_continuity = _sync_loop_continuity(
        state_root=state_root,
        loop_id=loop_id,
        next_action=next_action.strip(),
        evidence_refs=incoming_refs if evidence_refs is not None else None,
        append_evidence_refs=append_evidence_refs,
        actor=actor,
        reason=reason.strip(),
        run_key=run_key,
    )

    return {
        "status": "amended",
        "packet_id": packet_id,
        "packet_path": str(packet_path),
        "loop_id": loop_id,
        "amendment_id": amendment_id,
        "summary": summary.strip(),
        "next_action": next_action.strip(),
        "evidence_refs": merged_refs,
        "loop_continuity": loop_continuity,
        "checkpoint_status": fm["checkpoint_status"],
    }
