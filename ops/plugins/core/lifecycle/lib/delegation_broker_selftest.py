#!/usr/bin/env python3
"""Self-test for delegation_broker YAML serialization safety.

Proves that colon-bearing, brace-bearing, and other YAML-sensitive
text in delegation fields round-trips cleanly through the governed
write path and the D433 read path.

Run: python3 delegation_broker_selftest.py
Exit 0 = pass, exit 1 = fail.
"""

from __future__ import annotations

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import yaml
import delegation_broker as db


COLON_BEARING_SPECIMENS = [
    # The original failure shape from DEL-20260426-001031
    (
        'stale_failure still holds; cadence launch is restored on ai-consolidation, '
        'and the proxmox-home SSH relay now succeeds, but the scheduled execution path '
        'reaches a later downstream blocker: network.home.unifi.clients.snapshot now '
        'receives {"error":{"code":502,"message":"Bad Gateway"}} from the '
        'home UniFI API path via proxmox-home.'
    ),
    # Colons at line start
    'blocker: something: else: here',
    # JSON-like braces with colons
    '{"key": "value", "nested": {"a": 1}}',
    # YAML special characters
    'line1\nline2: with colon\nline3: {"json": true}',
    # Hash/comment-like
    'status is # not a comment: real value',
    # Leading/trailing special chars
    ': leading colon',
    '- leading dash',
    '[bracket start]',
    '{brace start}',
    # Empty and null-like
    '',
    'null',
    'true',
    'false',
]


def test_atomic_write_roundtrip() -> int:
    """Test that _atomic_write produces YAML that round-trips cleanly."""
    failures = 0

    with tempfile.TemporaryDirectory() as tmpdir:
        for i, specimen in enumerate(COLON_BEARING_SPECIMENS):
            path = os.path.join(tmpdir, f"DEL-test-{i:03d}.yaml")
            data = {
                "delegation_id": f"DEL-TEST-{i:03d}",
                "loop_id": "LOOP-TEST",
                "packet_id": "PACKET-TEST",
                "delegation_state": "landed",
                "delegated_at_utc": "2026-04-26T00:00:00Z",
                "disposition": specimen,
                "objective": f"test specimen {i}: {specimen[:40]}",
            }

            # Write through governed path
            try:
                db._atomic_write(path, data)
            except db.DelegationError as exc:
                print(f"  FAIL write specimen {i}: {exc}")
                failures += 1
                continue

            # Read back through D433-equivalent path
            try:
                with open(path, encoding="utf-8") as f:
                    loaded = yaml.safe_load(f)
            except yaml.YAMLError as exc:
                print(f"  FAIL parse specimen {i}: {exc}")
                failures += 1
                continue

            if not isinstance(loaded, dict):
                print(f"  FAIL specimen {i}: loaded as {type(loaded).__name__}, not dict")
                failures += 1
                continue

            # Verify the disposition survived round-trip
            got = loaded.get("disposition")
            if got != specimen:
                print(f"  FAIL specimen {i}: disposition mismatch")
                print(f"    expected: {specimen!r}")
                print(f"    got:      {got!r}")
                failures += 1
                continue

    return failures


def main() -> None:
    total_specimens = len(COLON_BEARING_SPECIMENS)
    print(f"delegation_broker_selftest: {total_specimens} specimens")

    failures = test_atomic_write_roundtrip()

    if failures:
        print(f"FAIL: {failures}/{total_specimens} specimens failed")
        sys.exit(1)
    else:
        print(f"PASS: {total_specimens}/{total_specimens} specimens round-tripped cleanly")
        sys.exit(0)


if __name__ == "__main__":
    main()
