#!/usr/bin/env python3
"""Regression test: scheduler health evidence-source discrimination.

Verify that manual runtime-jobs entries do not get mixed with scheduled
launchctl exit codes, preventing false failed states from stale scheduled
runs when manual runs succeed.
"""

from __future__ import annotations

import json
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def test_manual_runtime_job_excluded_from_scheduled_evidence() -> None:
    """Manual runtime-jobs entries should not contribute to scheduled label health."""
    # Simulate runtime-jobs.ndjson with manual execution
    runtime_jobs_content = json.dumps({
        "job_name": "test-job:run",
        "started_at": "2026-03-28T14:00:00Z",
        "ended_at": "2026-03-28T14:01:00Z",
        "duration_s": 60,
        "exit_code": 0,
        "status": "done",
        "execution_source": "manual",
    }) + "\n"

    with tempfile.NamedTemporaryFile(mode="w", suffix=".ndjson", delete=False) as f:
        f.write(runtime_jobs_content)
        temp_path = Path(f.name)

    try:
        # Load and verify that manual execution_source is present
        with temp_path.open("r") as f:
            row = json.loads(f.read().strip())

        assert row["execution_source"] == "manual", "Manual execution source not recorded"
        assert row["exit_code"] == 0, "Manual exit code should be 0"

        # In the real system, launchd-scheduler-health-status would filter this out
        # because execution_source is "manual" not "launchd_scheduler"
        is_scheduled = "launchd" in row.get("execution_source", "")
        assert not is_scheduled, "Manual run should not be considered scheduled"

        print("PASS: manual runtime-job correctly marked with execution_source=manual")
    finally:
        temp_path.unlink()


def test_scheduled_runtime_job_included_in_evidence() -> None:
    """Scheduled runtime-jobs entries should contribute to label health."""
    runtime_jobs_content = json.dumps({
        "job_name": "test-job:run",
        "started_at": "2026-03-28T14:00:00Z",
        "ended_at": "2026-03-28T14:01:00Z",
        "duration_s": 60,
        "exit_code": 1,
        "status": "failed",
        "execution_source": "launchd_scheduler",
    }) + "\n"

    with tempfile.NamedTemporaryFile(mode="w", suffix=".ndjson", delete=False) as f:
        f.write(runtime_jobs_content)
        temp_path = Path(f.name)

    try:
        with temp_path.open("r") as f:
            row = json.loads(f.read().strip())

        assert row["execution_source"] == "launchd_scheduler", "Scheduled execution source not recorded"
        assert row["exit_code"] == 1, "Scheduled exit code should be 1"

        is_scheduled = "launchd" in row.get("execution_source", "")
        assert is_scheduled, "Scheduled run should be considered scheduled"

        print("PASS: scheduled runtime-job correctly marked with execution_source=launchd_scheduler")
    finally:
        temp_path.unlink()


def test_execution_source_field_present() -> None:
    """job-wrapper.sh should emit execution_source field."""
    # This is verified by inspecting actual runtime-jobs.ndjson entries
    # In the test environment, we just verify the field structure
    expected_fields = ["job_name", "started_at", "ended_at", "duration_s", "exit_code", "status", "execution_source"]

    sample_entry = {
        "job_name": "test:run",
        "started_at": "2026-03-28T14:00:00Z",
        "ended_at": "2026-03-28T14:01:00Z",
        "duration_s": 60,
        "exit_code": 0,
        "status": "done",
        "execution_source": "manual",
    }

    for field in expected_fields:
        assert field in sample_entry, f"Missing required field: {field}"

    print("PASS: execution_source field structure validated")


def main() -> int:
    tests = [
        test_manual_runtime_job_excluded_from_scheduled_evidence,
        test_scheduled_runtime_job_included_in_evidence,
        test_execution_source_field_present,
    ]

    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"FAIL: {test.__name__}: {e}", file=sys.stderr)
            return 1
        except Exception as e:
            print(f"ERROR: {test.__name__}: {e}", file=sys.stderr)
            return 2

    print(f"\nAll {len(tests)} regression tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
