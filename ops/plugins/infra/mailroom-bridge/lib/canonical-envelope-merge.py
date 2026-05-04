#!/usr/bin/env python3
"""Boring atomic merge of fields into a canonical task envelope.

Single responsibility: read a task envelope YAML at envelope_path, read a
fields YAML at fields_yaml_path, merge fields into the envelope dict at
top level, write back atomically via .tmp + os.replace. No shell tricks,
no nested heredocs, no SSH. Designed to run on the storage_evidence_node
(pve) under the worker's scp+ssh path replacement
(_write_task_fields_via_ssh in mailroom-task-worker).

Usage:
  python3 canonical-envelope-merge.py <envelope_path> <fields_yaml_path>

Exit codes:
  0 — merge applied (or envelope missing, treated as no-op)
  2 — invalid arguments
  3 — fields file unreadable / not a mapping
  4 — envelope file unreadable / not a mapping
  5 — atomic write failed
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import yaml


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        sys.stderr.write(
            "FAIL: usage: canonical-envelope-merge.py <envelope_path> <fields_yaml_path>\n"
        )
        return 2

    envelope_path = Path(argv[1])
    fields_path = Path(argv[2])

    if not envelope_path.is_file():
        # Envelope missing on canonical — treat as no-op rather than error so
        # the worker's writeback path is idempotent across stale state.
        return 0

    try:
        fields_text = fields_path.read_text(encoding="utf-8")
    except OSError as exc:
        sys.stderr.write(f"FAIL: read fields_yaml_path: {exc}\n")
        return 3
    try:
        fields = yaml.safe_load(fields_text) or {}
    except yaml.YAMLError as exc:
        sys.stderr.write(f"FAIL: parse fields_yaml_path: {exc}\n")
        return 3
    if not isinstance(fields, dict):
        sys.stderr.write("FAIL: fields_yaml_path content is not a mapping\n")
        return 3
    if not fields:
        # Nothing to merge — still success.
        return 0

    try:
        envelope_text = envelope_path.read_text(encoding="utf-8")
    except OSError as exc:
        sys.stderr.write(f"FAIL: read envelope_path: {exc}\n")
        return 4
    try:
        envelope = yaml.safe_load(envelope_text) or {}
    except yaml.YAMLError as exc:
        sys.stderr.write(f"FAIL: parse envelope_path: {exc}\n")
        return 4
    if not isinstance(envelope, dict):
        sys.stderr.write("FAIL: envelope_path content is not a mapping\n")
        return 4

    envelope.update(fields)

    tmp_path = envelope_path.with_suffix(envelope_path.suffix + ".tmp")
    try:
        tmp_path.write_text(yaml.safe_dump(envelope, sort_keys=False), encoding="utf-8")
        os.replace(tmp_path, envelope_path)
    except OSError as exc:
        sys.stderr.write(f"FAIL: atomic write: {exc}\n")
        try:
            tmp_path.unlink()
        except OSError:
            pass
        return 5
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
