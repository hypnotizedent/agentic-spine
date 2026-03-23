#!/usr/bin/env python3
"""Canonical calendar domain-state path helpers."""

from __future__ import annotations

import os
from pathlib import Path


LEGACY_CALENDAR_STATE_PREFIX = "runtime/domain-state/calendar"


def spine_domain_state_root() -> Path:
    override = (os.environ.get("SPINE_DOMAIN_STATE") or "").strip()
    if override:
        return Path(override).expanduser().resolve()
    return (Path.home() / "code/.data").resolve()


def calendar_state_root() -> Path:
    return spine_domain_state_root() / "calendar"


def calendar_state_path(subpath: str = "") -> Path:
    root = calendar_state_root()
    normalized = subpath.strip().strip("/")
    if not normalized:
        return root.resolve()
    return (root / normalized).resolve()


def resolve_calendar_state_path(raw_value: str | Path | None, default_subpath: str) -> Path:
    raw = str(raw_value or "").strip()
    if not raw:
        return calendar_state_path(default_subpath)

    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()

    normalized = raw.replace("\\", "/").strip()
    while normalized.startswith("./"):
        normalized = normalized[2:]
    normalized = normalized.lstrip("/")

    if normalized == LEGACY_CALENDAR_STATE_PREFIX:
        normalized = ""
    elif normalized.startswith(f"{LEGACY_CALENDAR_STATE_PREFIX}/"):
        normalized = normalized[len(LEGACY_CALENDAR_STATE_PREFIX) + 1 :]

    return calendar_state_path(normalized)
