#!/usr/bin/env python3
"""Minimal regression harness for wave closeout hardening markers."""

from __future__ import annotations

import sys
from pathlib import Path


REQUIRED_MARKERS = [
    'dispatch_pushability_preflight "$sf" "$lane"',
    '"remote", "get-url", remote',
    '"push", "--dry-run", remote',
    "control_lane_override",
]


def main() -> int:
    root = Path(sys.argv[1]).resolve()
    wave = root / "ops" / "commands" / "wave.sh"
    if not wave.exists():
        print("missing wave.sh", file=sys.stderr)
        return 1
    text = wave.read_text(encoding="utf-8")
    missing = [marker for marker in REQUIRED_MARKERS if marker not in text]
    if missing:
        print(f"missing markers: {missing}", file=sys.stderr)
        return 1
    print("wave_hardening_regression PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
