"""DB authority open-time guard.

When db_authority.enabled is true in runtime.bootstrap.contract.yaml AND the
local hostname is NOT in db_authority.authority_hostnames, this guard refuses
to open shared_authority.db if the file does not already exist. Without this
guard, SQLite's default behavior auto-creates the DB file on first open,
producing a silent empty stub and false read-success on consumers.

This is defense-in-depth for cap.sh routing: if a cap dispatch went through
cap.sh's routing function, DB-backed caps already routed to the authority
host. But direct subcommand invocations (e.g., `bin/ops loops list`) bypass
cap.sh and could open the DB directly. This guard catches that path.

Usage:
    from db_authority_guard import assert_db_open_safe
    db_path = Path(...) / "shared_authority.db"
    assert_db_open_safe(db_path)  # raises DbAuthorityRoutingRequired if unsafe
    conn = sqlite3.connect(str(db_path))

The guard is no-op when:
- contract is missing (bootstrap edge case; cap.sh would have already returned 126)
- db_authority.enabled is false (D.3a inert state)
- local hostname is in authority_hostnames (this IS the authority)
- the DB file already exists (legitimate open against existing data)
"""
from __future__ import annotations

import os
import socket
from pathlib import Path
from typing import Optional


class DbAuthorityRoutingRequired(RuntimeError):
    """Raised when a consumer attempts to open shared_authority.db that does
    not exist locally, while db_authority.enabled is true. The correct fix is
    to invoke the operation via `bin/ops cap run <cap>` so cap.sh routing
    dispatches to the authority host.
    """


def _resolve_contract_path() -> Optional[Path]:
    spine_code = os.environ.get("SPINE_CODE")
    if not spine_code:
        return None
    candidate = Path(spine_code) / "ops" / "bindings" / "runtime.bootstrap.contract.yaml"
    return candidate if candidate.is_file() else None


def _read_contract_field(contract_path: Path, dotted_path: str) -> Optional[str]:
    """Tiny no-yaml-lib reader: scans the file for top-level 'db_authority:'
    block and returns the value of a nested field. Avoids a yaml dependency
    so this guard works in any python that has stdlib only.
    """
    try:
        text = contract_path.read_text()
    except OSError:
        return None
    in_block = False
    block_indent = -1
    fields: dict[str, str] = {}
    list_collect: dict[str, list[str]] = {}
    list_active: Optional[str] = None
    for raw in text.splitlines():
        stripped = raw.rstrip()
        if not stripped:
            continue
        if not in_block:
            if stripped.startswith("db_authority:"):
                in_block = True
                block_indent = len(raw) - len(raw.lstrip(" "))
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        if indent <= block_indent and stripped and not stripped.startswith("#"):
            break
        line = raw.strip()
        if line.startswith("- ") and list_active is not None:
            value = line[2:].strip()
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            list_collect.setdefault(list_active, []).append(value)
            continue
        if ":" in line:
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip()
            if not value:
                list_active = key
                list_collect.setdefault(key, [])
            else:
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                fields[key] = value
                list_active = None
    if dotted_path in fields:
        return fields[dotted_path]
    if dotted_path in list_collect:
        return ",".join(list_collect[dotted_path])
    return None


def _local_hostname_short() -> str:
    name = socket.gethostname()
    return name.split(".", 1)[0] if name else ""


def assert_db_open_safe(db_path: Path) -> None:
    """Refuse to open shared_authority.db when routing should have been used.

    Raises DbAuthorityRoutingRequired when:
    - db_authority.enabled is true
    - local hostname is NOT in db_authority.authority_hostnames
    - db_path does not exist (would be auto-created by SQLite)

    Returns silently in all other cases.
    """
    contract = _resolve_contract_path()
    if contract is None:
        return
    enabled = (_read_contract_field(contract, "enabled") or "false").strip().lower()
    if enabled != "true":
        return
    authority_hosts = _read_contract_field(contract, "authority_hostnames") or ""
    host = _local_hostname_short()
    if host and host in [h.strip() for h in authority_hosts.split(",") if h.strip()]:
        return
    if db_path.exists():
        return
    raise DbAuthorityRoutingRequired(
        f"db_authority.enabled is true but local DB {db_path} does not exist on host '{host}'. "
        f"This call is bypassing cap.sh routing — invoke via `bin/ops cap run <cap>` so the "
        f"DB-backed read routes to the authority host. Refusing to auto-create an empty stub."
    )
