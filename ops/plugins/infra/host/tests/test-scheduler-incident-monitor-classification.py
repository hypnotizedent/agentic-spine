#!/usr/bin/env python3
"""Regression tests for launchd incident-monitor classification."""

from __future__ import annotations

import os
import plistlib
import runpy
import shutil
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[5]
SCRIPT_PATH = REPO_ROOT / "ops/plugins/infra/host/bin/launchd-scheduler-health-status"


def load_scheduler_module() -> dict[str, object]:
    return runpy.run_path(str(SCRIPT_PATH), run_name="launchd_scheduler_health_status")


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    now = datetime.now(timezone.utc).timestamp()
    os.utime(path, (now, now))


def write_plist(path: Path, stdout_path: Path, stderr_path: Path, start_interval: int = 300) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        plistlib.dump(
            {
                "Label": path.stem,
                "ProgramArguments": ["/bin/bash", "/tmp/fake-job.sh"],
                "StartInterval": start_interval,
                "StandardOutPath": str(stdout_path),
                "StandardErrorPath": str(stderr_path),
            },
            handle,
        )


def make_temp_root(include_incident_markers: bool) -> Path:
    root = Path(tempfile.mkdtemp(prefix="launchd-scheduler-health-"))
    logs_root = root / "mailroom" / "logs"
    monitor_stdout = logs_root / "launchd-health-check.out"
    monitor_stderr = logs_root / "launchd-health-check.err"
    downstream_stdout = logs_root / "downstream-failed.out"
    downstream_stderr = logs_root / "downstream-failed.err"

    monitor_output = "[launchd-health-check] start 2026-03-28T20:00:00Z\n"
    if include_incident_markers:
        monitor_output += (
            "[2026-03-28T20:00:00Z] OK com.ronny.launchd-health-check\n"
            "[launchd-health-check] scheduler_status=error total=2 stale=0 failed=1 unknown=0\n"
        )
    else:
        monitor_output += "[2026-03-28T20:00:00Z] FAIL launchd-health-check bootstrap error\n"

    write_text(monitor_stdout, monitor_output)
    write_text(monitor_stderr, "")
    write_text(downstream_stdout, "[2026-03-28T20:00:00Z] downstream failure\n")
    write_text(downstream_stderr, "")

    write_text(
        root / "ops/bindings/launchd.scheduler.registry.yaml",
        "\n".join(
            [
                'schedule_timezone: "America/New_York"',
                "labels:",
                "  - label: com.ronny.launchd-health-check",
                "    state: active",
                "    mode: scheduled",
                "    monitor: true",
                "    template_path: ops/plugins/infra/host/launchd/com.ronny.launchd-health-check.plist",
                "  - label: com.ronny.downstream-failed",
                "    state: active",
                "    mode: scheduled",
                "    monitor: true",
                "    template_path: ops/plugins/infra/host/launchd/com.ronny.downstream-failed.plist",
                "",
            ]
        ),
    )

    write_text(
        root / "ops/bindings/launchd.runtime.contract.yaml",
        "\n".join(
            [
                'version: "1.5"',
                'updated_at: "2026-03-28"',
                "recency:",
                "  exempt_labels: []",
                "  allow_nonzero_exit_labels: []",
                "scheduler_expectations:",
                "  com.ronny.launchd-health-check:",
                "    incident_monitor:",
                "      status: allowed_nonzero",
                "      allowed_exit_codes:",
                "        - 1",
                '      stdout_run_start_marker: "[launchd-health-check] start "',
                "      required_stdout_markers:",
                '        - "OK com.ronny.launchd-health-check"',
                '        - "[launchd-health-check] scheduler_status="',
                "",
            ]
        ),
    )

    write_plist(
        root / "ops/plugins/infra/host/launchd/com.ronny.launchd-health-check.plist",
        monitor_stdout,
        monitor_stderr,
    )
    write_plist(
        root / "ops/plugins/infra/host/launchd/com.ronny.downstream-failed.plist",
        downstream_stdout,
        downstream_stderr,
    )
    return root


def test_incident_monitor_classifies_as_allowed_nonzero() -> None:
    module = load_scheduler_module()
    build_payload = module["build_payload"]
    build_payload.__globals__["launchctl_last_exit_code"] = lambda label: {
        "com.ronny.launchd-health-check": 1,
        "com.ronny.downstream-failed": 1,
    }.get(label)

    temp_root = make_temp_root(include_incident_markers=True)
    try:
        payload = build_payload(temp_root)
    finally:
        shutil.rmtree(temp_root)

    rows = {row["label"]: row for row in payload["data"]["rows"]}
    assert rows["com.ronny.launchd-health-check"]["status"] == "allowed_nonzero"
    assert rows["com.ronny.downstream-failed"]["status"] == "failed"
    assert payload["data"]["summary"]["allowed_nonzero"] == 1
    assert payload["data"]["summary"]["failed"] == 1
    assert payload["data"]["allowed_nonzero_labels"] == ["com.ronny.launchd-health-check"]
    assert payload["data"]["failed_labels"] == ["com.ronny.downstream-failed"]
    assert payload["status"] == "error"
    print("PASS: incident monitor classified as allowed_nonzero while downstream failure remains visible")


def test_broken_incident_monitor_stays_failed() -> None:
    module = load_scheduler_module()
    build_payload = module["build_payload"]
    build_payload.__globals__["launchctl_last_exit_code"] = lambda label: {
        "com.ronny.launchd-health-check": 1,
    }.get(label, 0)

    temp_root = make_temp_root(include_incident_markers=False)
    try:
        payload = build_payload(temp_root)
    finally:
        shutil.rmtree(temp_root)

    rows = {row["label"]: row for row in payload["data"]["rows"]}
    assert rows["com.ronny.launchd-health-check"]["status"] == "failed"
    assert "com.ronny.launchd-health-check" in payload["data"]["failed_labels"]
    assert payload["data"]["summary"]["allowed_nonzero"] == 0
    print("PASS: broken incident monitor remains failed")


def main() -> int:
    tests = [
        test_incident_monitor_classifies_as_allowed_nonzero,
        test_broken_incident_monitor_stays_failed,
    ]

    for test in tests:
        try:
            test()
        except AssertionError as err:
            print(f"FAIL: {test.__name__}: {err}", file=sys.stderr)
            return 1
        except Exception as err:
            print(f"ERROR: {test.__name__}: {err}", file=sys.stderr)
            return 2

    print(f"\nAll {len(tests)} regression tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
