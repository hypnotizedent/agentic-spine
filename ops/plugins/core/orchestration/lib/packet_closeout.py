"""Packet closeout truth updater.

Loads an existing orchestration packet.yaml and completes the
contract-required closeout fields from caller-provided evidence.
Never invents values — fails closed on missing or ambiguous sources.

Contract (Packet 2, Lane A):
  - Pure stdlib.  No subprocess.  No network.
  - Reads and writes only the packet.yaml at the caller-provided path.
  - Atomic write via temp file + os.replace.
  - Validates packet belongs to the expected loop_id before mutating.
  - Never adds or removes non-closeout fields.

Required closeout fields (from orchestration.packet.contract.yaml v1.1):
  - reconciliation_summary
  - receipt_refs
  - verify_matrix
  - finalized_at_utc

Optional (updated only when honest):
  - plan_transition
  - lane_outcomes (status upgrade from DISPATCHED → caller-provided)

Public API:
    complete_packet_closeout(packet_path, evidence, expected_loop_id) -> dict
"""

from __future__ import annotations

import os
import tempfile
from datetime import datetime, timezone
from typing import Any


# ── YAML helpers (pure stdlib, no PyYAML dependency) ─────────────────

def _parse_flow_sequence(val: str) -> list:
    """Parse a YAML inline flow sequence like [a, b] or ["a", "b"] into a list."""
    inner = val[1:-1].strip()
    if not inner:
        return []
    items = []
    for part in inner.split(","):
        part = part.strip()
        if part.startswith('"') and part.endswith('"'):
            part = part[1:-1]
        elif part.startswith("'") and part.endswith("'"):
            part = part[1:-1]
        items.append(part)
    return items


def _parse_value(val: str) -> Any:
    """Parse a YAML value, handling flow sequences and scalars."""
    if val.startswith("[") and val.endswith("]"):
        return _parse_flow_sequence(val)
    return _unquote(val)


def _load_yaml_simple(path: str) -> dict[str, Any]:
    """Load a flat-ish YAML file into a dict.

    Handles the subset of YAML used by orchestration packets:
    top-level scalars, lists of dicts, and nested objects.  This is NOT
    a general YAML parser — it covers the packet schema only.
    """
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()

    # Use a line-based state machine for the packet YAML subset.
    result: dict[str, Any] = {}
    lines = text.split("\n")
    current_key = ""
    current_list: list[Any] | None = None
    current_dict: dict[str, Any] | None = None
    indent_stack: list[int] = []

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.rstrip()
        i += 1

        if not stripped or stripped.startswith("#"):
            continue

        indent = len(line) - len(line.lstrip())

        # Top-level key: value
        if indent == 0 and ":" in stripped:
            # Flush any pending list
            if current_list is not None and current_key:
                result[current_key] = current_list
                current_list = None
            if current_dict is not None and current_key:
                result[current_key] = current_dict
                current_dict = None

            key, _, val = stripped.partition(":")
            key = key.strip()
            val = val.strip()

            if val == "" or val == "[]" or (val.startswith("[") and val.endswith("]")):
                # Could be a list or object starting on next line
                current_key = key
                if val.startswith("[") and val.endswith("]"):
                    result[key] = _parse_flow_sequence(val)
                    current_key = ""
                else:
                    # Peek ahead to determine type
                    if i < len(lines):
                        next_stripped = lines[i].lstrip()
                        if next_stripped.startswith("- "):
                            current_list = []
                        else:
                            current_dict = {}
                    else:
                        result[key] = val
                        current_key = ""
            else:
                result[key] = _unquote(val)
                current_key = ""
            continue

        # List item under current_key
        if current_list is not None and stripped.lstrip().startswith("- "):
            item_text = stripped.lstrip()[2:].strip()
            if ":" in item_text:
                # Inline dict item: - key: value  OR  start of multi-line dict
                item_dict: dict[str, Any] = {}
                k, _, v = item_text.partition(":")
                item_dict[k.strip()] = _parse_value(v.strip())
                # Read continuation lines at deeper indent
                while i < len(lines):
                    nline = lines[i]
                    nstripped = nline.rstrip()
                    if not nstripped:
                        i += 1
                        continue
                    nindent = len(nline) - len(nline.lstrip())
                    nlstripped = nstripped.lstrip()
                    if nindent <= indent and not nlstripped.startswith("- "):
                        break
                    if nlstripped.startswith("- "):
                        break
                    if ":" in nlstripped:
                        nk, _, nv = nlstripped.partition(":")
                        item_dict[nk.strip()] = _parse_value(nv.strip())
                    i += 1
                current_list.append(item_dict)
            else:
                current_list.append(_parse_value(item_text))
            continue

        # Nested dict under current_key
        if current_dict is not None and ":" in stripped:
            k, _, v = stripped.strip().partition(":")
            current_dict[k.strip()] = _parse_value(v.strip())
            continue

    # Flush
    if current_list is not None and current_key:
        result[current_key] = current_list
    if current_dict is not None and current_key:
        result[current_key] = current_dict

    return result


def _unquote(val: str) -> Any:
    """Remove surrounding quotes and convert obvious types."""
    if val.startswith('"') and val.endswith('"'):
        return val[1:-1]
    if val.startswith("'") and val.endswith("'"):
        return val[1:-1]
    if val.lower() in ("true", "yes"):
        return True
    if val.lower() in ("false", "no"):
        return False
    try:
        return int(val)
    except ValueError:
        pass
    return val


def _yaml_scalar(val: Any) -> str:
    """Render a scalar value as YAML."""
    if val is None or val == "":
        return '""'
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, int):
        return str(val)
    s = str(val)
    if any(c in s for c in (":", "#", "{", "}", "[", "]", ",", "&", "*", "?", "|", "-", "<", ">", "=", "!", "%", "@", "`")):
        return f'"{s}"'
    if s.startswith('"') or s.startswith("'"):
        return s
    return f'"{s}"'


def _dump_yaml_simple(data: dict[str, Any]) -> str:
    """Render packet dict back to YAML preserving the packet schema shape."""
    lines: list[str] = []

    for key, val in data.items():
        if isinstance(val, list):
            if not val:
                lines.append(f"{key}: []")
            else:
                lines.append(f"{key}:")
                for item in val:
                    if isinstance(item, dict):
                        first = True
                        for ik, iv in item.items():
                            prefix = "  - " if first else "    "
                            lines.append(f"{prefix}{ik}: {_yaml_scalar(iv)}")
                            first = False
                    else:
                        lines.append(f"  - {_yaml_scalar(item)}")
        elif isinstance(val, dict):
            lines.append(f"{key}:")
            for dk, dv in val.items():
                lines.append(f"  {dk}: {_yaml_scalar(dv)}")
        else:
            lines.append(f"{key}: {_yaml_scalar(val)}")

    return "\n".join(lines) + "\n"


# ── Public API ───────────────────────────────────────────────────────

def complete_packet_closeout(
    packet_path: str,
    evidence: dict[str, Any],
    expected_loop_id: str,
) -> dict[str, Any]:
    """Update packet.yaml closeout fields from evidence.

    Args:
        packet_path: Absolute path to the orchestration packet.yaml.
        evidence: Dict with keys matching closeout field names.
            Required: reconciliation_summary, receipt_refs,
                      verify_matrix, finalized_at_utc.
            Optional: plan_transition, lane_outcomes.
        expected_loop_id: The loop_id this packet must belong to.

    Returns:
        Dict with before/after snapshots of updated fields.

    Raises:
        FileNotFoundError: If packet_path does not exist.
        ValueError: If packet loop_id does not match expected.
        ValueError: If required evidence keys are missing.
    """
    if not os.path.isfile(packet_path):
        raise FileNotFoundError(f"packet not found: {packet_path}")

    packet = _load_yaml_simple(packet_path)

    # Validate ownership
    packet_loop_id = str(packet.get("loop_id", "")).strip().strip('"')
    if packet_loop_id != expected_loop_id:
        raise ValueError(
            f"packet loop_id mismatch: expected {expected_loop_id}, "
            f"got {packet_loop_id}"
        )

    # Validate required evidence
    required = ("reconciliation_summary", "receipt_refs", "verify_matrix", "finalized_at_utc")
    missing = [k for k in required if k not in evidence]
    if missing:
        raise ValueError(f"missing required evidence keys: {missing}")

    # Snapshot before
    before: dict[str, Any] = {}
    for field in (*required, "plan_transition", "lane_outcomes"):
        before[field] = packet.get(field)

    # Apply closeout fields
    packet["reconciliation_summary"] = evidence["reconciliation_summary"]
    packet["receipt_refs"] = evidence["receipt_refs"]
    packet["verify_matrix"] = evidence["verify_matrix"]
    packet["finalized_at_utc"] = evidence["finalized_at_utc"]

    # Optional: plan_transition
    if "plan_transition" in evidence:
        packet["plan_transition"] = evidence["plan_transition"]

    # Optional: lane_outcomes status upgrade
    if "lane_outcomes" in evidence:
        packet["lane_outcomes"] = evidence["lane_outcomes"]

    # Atomic write
    dir_path = os.path.dirname(packet_path)
    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".yaml.tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(_dump_yaml_simple(packet))
        os.replace(tmp_path, packet_path)
    except BaseException:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise

    # Snapshot after
    after: dict[str, Any] = {}
    for field in (*required, "plan_transition", "lane_outcomes"):
        after[field] = packet.get(field)

    return {"before": before, "after": after, "packet_path": packet_path}


# ── CLI entrypoint ───────────────────────────────────────────────────

if __name__ == "__main__":  # pragma: no cover
    import argparse
    import json

    parser = argparse.ArgumentParser(
        description="Complete packet.yaml closeout fields from JSON evidence on stdin."
    )
    parser.add_argument("--packet-path", required=True)
    parser.add_argument("--loop-id", required=True)
    ns = parser.parse_args()

    import sys
    evidence = json.loads(sys.stdin.read())
    result = complete_packet_closeout(ns.packet_path, evidence, ns.loop_id)
    print(json.dumps(result, indent=2, default=str))
