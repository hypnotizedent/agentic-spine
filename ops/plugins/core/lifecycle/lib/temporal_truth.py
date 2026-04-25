#!/usr/bin/env python3
"""Phase-1 temporal vocabulary reconciliation for live read surfaces."""

from __future__ import annotations

import datetime as dt
import json
import re
from pathlib import Path
from typing import Any

import yaml


VERIFY_SCOPE_PATTERNS: dict[str, tuple[str, ...]] = {
    "spine": ("RCAP-*__spine.verify__*",),
    "infra": ("RCAP-*__verify.infra.run__*", "RCAP-*__verify.run__*"),
    "fast": ("RCAP-*__verify.fast__*", "RCAP-*__verify.run__*"),
}

GATE_LINE_RE = re.compile(r"^(D\d+)\s+.*?\b(FAIL|PASS|WARN)\b", re.IGNORECASE)

DEFAULT_CONTRACT = {
    "temporal_vocabulary": {
        "standing_receipt_count": 2,
        "standing_age_hours": 6,
        "classes": {
            "fresh_request": {
                "meaning": "Newly surfaced signal without standing corroboration yet.",
                "operator_treatment": "Treat as a fresh current ask until it proves standing.",
            },
            "inherited_still_current": {
                "meaning": "Pre-existing signal that is still present now.",
                "operator_treatment": "Read as standing debt, not as a regression from the current lane.",
            },
            "deferred_by_decision": {
                "meaning": "Signal intentionally deferred, parked, non-local, or locality-exempt by contract or operator decision.",
                "operator_treatment": "Do not escalate as local debt unless the governing decision changes.",
            },
            "ambient_background": {
                "meaning": "Ambient background or side-surface telemetry, not controller todo.",
                "operator_treatment": "Read for awareness, not as the front-door work queue.",
            },
        },
    }
}


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def render_dt(value: dt.datetime | None) -> str:
    if value is None:
        return ""
    return value.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(value: Any) -> dt.datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        parsed = dt.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def load_contract(root: Path) -> dict[str, Any]:
    path = root / "ops" / "bindings" / "verify.failure.classification.contract.yaml"
    if not path.exists():
        return DEFAULT_CONTRACT
    try:
        loaded = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception:
        loaded = {}
    contract = dict(DEFAULT_CONTRACT)
    contract.update(loaded if isinstance(loaded, dict) else {})
    tv = dict(DEFAULT_CONTRACT["temporal_vocabulary"])
    tv.update((contract.get("temporal_vocabulary") or {}) if isinstance(contract.get("temporal_vocabulary"), dict) else {})
    classes = dict(DEFAULT_CONTRACT["temporal_vocabulary"]["classes"])
    classes.update((tv.get("classes") or {}) if isinstance(tv.get("classes"), dict) else {})
    tv["classes"] = classes
    contract["temporal_vocabulary"] = tv
    return contract


def _class_payload(contract: dict[str, Any], class_name: str) -> dict[str, str]:
    classes = ((contract.get("temporal_vocabulary") or {}).get("classes") or {})
    meta = classes.get(class_name) if isinstance(classes, dict) else {}
    if not isinstance(meta, dict):
        meta = {}
    return {
        "temporal_class": class_name,
        "meaning": str(meta.get("meaning") or "").strip(),
        "operator_treatment": str(meta.get("operator_treatment") or "").strip(),
    }


def _parse_verify_fail_ids(output_path: Path) -> list[str]:
    try:
        text = output_path.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return []
    try:
        payload = json.loads(text)
    except (json.JSONDecodeError, ValueError):
        payload = None
    if isinstance(payload, dict):
        blocking = payload.get("blocking_fail_ids")
        if isinstance(blocking, list) and blocking:
            return [str(item).strip().upper() for item in blocking if str(item).strip()]
        failing = payload.get("failing_ids")
        if isinstance(failing, list) and failing:
            return [str(item).strip().upper() for item in failing if str(item).strip()]

    failing_ids: list[str] = []
    for line in text.splitlines():
        match = GATE_LINE_RE.match(line.strip())
        if match and match.group(2).upper() == "FAIL":
            failing_ids.append(match.group(1).upper())
    return failing_ids


def _verify_receipt_dirs(receipts_root: Path, scope: str) -> list[Path]:
    patterns = VERIFY_SCOPE_PATTERNS.get(scope, ())
    candidates: list[Path] = []
    for pattern in patterns:
        candidates.extend(p for p in receipts_root.glob(pattern) if p.is_dir())
    candidates.sort(key=lambda p: p.stat().st_mtime)
    return candidates


def classify_spine_verify(root: Path, receipts_root: Path, latest_verify: dict[str, Any]) -> dict[str, Any]:
    contract = load_contract(root)
    status = str(latest_verify.get("status") or "unknown").strip().lower()
    scope = str(latest_verify.get("scope") or "spine").strip() or "spine"
    current_fails = sorted({
        str(item).strip().upper()
        for item in (latest_verify.get("blocking_fail_ids") or latest_verify.get("failing_ids") or [])
        if str(item).strip()
    })
    if not current_fails or status not in {"failed", "warn"}:
        return {
            "status": status,
            "scope": scope,
            "current_blocking_fail_ids": current_fails,
            "standing_evidence_count": 0,
            "known_since_utc": "",
            "gate_first_seen_utc": {},
            "receipt_count_scanned": 0,
            "summary": "no current blocking verify standing signal",
        }

    standing_min = int(((contract.get("temporal_vocabulary") or {}).get("standing_receipt_count")) or 2)
    current_fail_set = set(current_fails)
    gate_first_seen: dict[str, str] = {}
    standing_evidence_count = 0
    known_since: dt.datetime | None = None
    receipt_count = 0

    for receipt_dir in _verify_receipt_dirs(receipts_root, scope):
        output_path = receipt_dir / "output.txt"
        if not output_path.exists():
            continue
        receipt_count += 1
        failing_ids = set(_parse_verify_fail_ids(output_path))
        if not failing_ids:
            continue
        output_mtime = dt.datetime.fromtimestamp(output_path.stat().st_mtime, tz=dt.timezone.utc)
        for gate_id in current_fails:
            if gate_id in failing_ids and gate_id not in gate_first_seen:
                gate_first_seen[gate_id] = render_dt(output_mtime)
        if current_fail_set.issubset(failing_ids):
            standing_evidence_count += 1
            if known_since is None:
                known_since = output_mtime

    if known_since is None:
        known_candidates = [parse_iso(ts) for ts in gate_first_seen.values()]
        known_candidates = [candidate for candidate in known_candidates if candidate is not None]
        if known_candidates:
            known_since = min(known_candidates)

    if standing_evidence_count >= standing_min:
        payload = _class_payload(contract, "inherited_still_current")
    else:
        payload = _class_payload(contract, "fresh_request")

    payload.update(
        {
            "status": status,
            "scope": scope,
            "current_blocking_fail_ids": current_fails,
            "standing_evidence_count": standing_evidence_count,
            "known_since_utc": render_dt(known_since),
            "gate_first_seen_utc": gate_first_seen,
            "receipt_count_scanned": receipt_count,
            "summary": (
                f"{len(current_fails)} blocking gate(s) present across "
                f"{standing_evidence_count} corroborating {scope}.verify receipt(s)"
            ),
        }
    )
    return payload


def classify_comms_queue(root: Path, comms_queue: dict[str, Any]) -> dict[str, Any]:
    contract = load_contract(root)
    controller_todo = bool(comms_queue.get("controller_todo", False))
    pending = int(comms_queue.get("pending", 0) or 0)
    oldest_age_seconds = int(comms_queue.get("oldest_age_seconds", 0) or 0)
    standing_age_hours = int(((contract.get("temporal_vocabulary") or {}).get("standing_age_hours")) or 6)

    if not controller_todo:
        payload = _class_payload(contract, "ambient_background")
    elif pending > 0 and oldest_age_seconds >= standing_age_hours * 3600:
        payload = _class_payload(contract, "inherited_still_current")
    else:
        payload = _class_payload(contract, "fresh_request")

    known_since = ""
    if pending > 0 and oldest_age_seconds > 0:
        known_since = render_dt(utc_now() - dt.timedelta(seconds=oldest_age_seconds))

    payload.update(
        {
            "controller_todo": controller_todo,
            "known_since_utc": known_since,
            "summary": (
                f"pending={pending} oldest={oldest_age_seconds}s "
                f"slo={str(comms_queue.get('slo_status') or 'unknown')}"
            ),
            "evidence": {
                "pending": pending,
                "oldest_age_seconds": oldest_age_seconds,
                "slo_status": str(comms_queue.get("slo_status") or "unknown"),
                "drain_state": str(comms_queue.get("drain_state") or "unknown"),
            },
        }
    )
    return payload


def classify_daemons(root: Path, daemons: dict[str, Any]) -> dict[str, Any]:
    contract = load_contract(root)
    missing = int(daemons.get("missing", 0) or 0)
    non_local = list(daemons.get("non_local_deferred") or [])
    breakdown = daemons.get("non_local_breakdown") or {}
    active_elsewhere = list((breakdown.get("active_elsewhere") or [])) if isinstance(breakdown, dict) else []
    parked_required = list((breakdown.get("parked_required") or [])) if isinstance(breakdown, dict) else []
    locality_exempt = list((breakdown.get("locality_exempt") or [])) if isinstance(breakdown, dict) else []

    if missing == 0 and non_local:
        payload = _class_payload(contract, "deferred_by_decision")
    elif missing > 0:
        payload = _class_payload(contract, "fresh_request")
    else:
        payload = {
            "temporal_class": "",
            "meaning": "",
            "operator_treatment": "",
        }

    payload.update(
        {
            "summary": (
                f"missing={missing} non_local={len(non_local)} "
                f"(elsewhere={len(active_elsewhere)} parked={len(parked_required)} locality_exempt={len(locality_exempt)})"
            ),
            "evidence": {
                "missing": missing,
                "non_local_deferred": len(non_local),
                "active_elsewhere": len(active_elsewhere),
                "parked_required": len(parked_required),
                "locality_exempt": len(locality_exempt),
            },
        }
    )
    return payload
