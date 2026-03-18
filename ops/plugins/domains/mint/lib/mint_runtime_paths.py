from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import yaml


def _normalize_text(value: Any) -> str:
    return str(value or "").strip()


def _env_path(name: str) -> Path | None:
    raw = _normalize_text(os.environ.get(name))
    if not raw:
        return None
    return Path(raw).expanduser().resolve()


def _load_runtime_contract(spine_root: Path) -> dict[str, Any]:
    contract_file = spine_root / "ops/bindings/mailroom.runtime.contract.yaml"
    if not contract_file.exists():
        return {}
    try:
        payload = yaml.safe_load(contract_file.read_text(encoding="utf-8")) or {}
    except Exception:
        return {}
    return payload if isinstance(payload, dict) else {}


def _guess_workspace_root(spine_root: Path) -> Path:
    parent = spine_root.parent
    if parent.name == "code":
        return parent
    return (Path.home() / "code").resolve()


def _with_mint_leaf(path: Path) -> Path:
    return path if path.name == "mint" else path / "mint"


def resolve_spine_root(current_file: str | Path | None = None) -> Path:
    override = _normalize_text(os.environ.get("SPINE_ROOT"))
    if override:
        return Path(override).expanduser().resolve()
    anchor = Path(current_file or __file__).resolve()
    for parent in (anchor.parent, *anchor.parents):
        if (parent / "ops/capabilities.yaml").exists():
            return parent
    return anchor.parents[5]


def resolve_mint_data_root(*, spine_root: Path | None = None, current_file: str | Path | None = None) -> Path:
    explicit = _env_path("MINT_DATA_ROOT") or _env_path("MINT_RUNTIME_ROOT")
    if explicit is not None:
        return explicit

    domain_root = _env_path("SPINE_DOMAIN_STATE") or _env_path("SPINE_DATA_ROOT")
    if domain_root is not None:
        return _with_mint_leaf(domain_root)

    root = spine_root or resolve_spine_root(current_file)
    contract = _load_runtime_contract(root)
    contract_root_raw = _normalize_text(contract.get("domain_state_root")) or _normalize_text(contract.get("data_root"))
    if contract_root_raw:
        return _with_mint_leaf(Path(contract_root_raw).expanduser().resolve())

    workspace_root = _guess_workspace_root(root)
    return workspace_root / ".data" / "mint"
