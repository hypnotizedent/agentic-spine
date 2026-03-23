#!/usr/bin/env python3
"""Canonical Mint domain-state path helpers."""

from __future__ import annotations

import os
from pathlib import Path


def spine_domain_state_root() -> Path:
    override = (os.environ.get("SPINE_DOMAIN_STATE") or "").strip()
    if override:
        return Path(override).expanduser()
    return Path.home() / "code/.data"


def mint_state_root() -> Path:
    return spine_domain_state_root() / "mint"


def mint_state_path(subpath: str = "") -> Path:
    root = mint_state_root()
    if not subpath:
        return root
    return root / subpath


def mint_override_path(env_var: str, default_subpath: str) -> Path:
    override = (os.environ.get(env_var) or "").strip()
    if override:
        return Path(override).expanduser()
    return mint_state_path(default_subpath)
