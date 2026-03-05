#!/usr/bin/env python3
"""Deterministic regression harness for wave.sh hardening controls."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Tuple

NOW = "2099-01-01T00:00:00Z"
VERIFY_RUN_KEY = "CAP-20990101-000000__verify.run__Rabc123"


def fail(message: str, output: str | None = None) -> None:
    print(f"D331 FAIL: wave regression: {message}", file=sys.stderr)
    if output:
        print(output, file=sys.stderr)
    raise SystemExit(1)


def run(cmd: List[str], env: Dict[str, str], cwd: Path | None = None) -> Tuple[int, str]:
    proc = subprocess.run(cmd, text=True, capture_output=True, cwd=str(cwd) if cwd else None, env=env)
    combined = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, combined


def run_checked(cmd: List[str], env: Dict[str, str], *, label: str) -> None:
    rc, out = run(cmd, env)
    if rc != 0:
        fail(f"{label} failed (rc={rc})", out)


def ensure_contains(output: str, needle: str, case: str) -> None:
    if needle not in output:
        fail(f"{case}: expected output containing '{needle}'", output)


def create_fixture(real_root: Path, fixture_root: Path) -> None:
    (fixture_root / "ops" / "bindings").mkdir(parents=True, exist_ok=True)
    (fixture_root / "mailroom" / "state").mkdir(parents=True, exist_ok=True)

    for rel in [
        "ops/bindings/role.runtime.control.contract.yaml",
        "ops/bindings/terminal.role.contract.yaml",
        "ops/bindings/worktree.lifecycle.contract.yaml",
    ]:
        src = real_root / rel
        dst = fixture_root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    (fixture_root / "mailroom" / "state" / "path.claims.yaml").write_text(
        json.dumps({"schema_version": "1.0", "updated_at": NOW, "claims": []}, indent=2) + "\n",
        encoding="utf-8",
    )
    (fixture_root / "mailroom" / "state" / "traffic.index.yaml").write_text(
        json.dumps({"schema_version": "1.0", "updated_at": NOW, "items": []}, indent=2) + "\n",
        encoding="utf-8",
    )


def init_git_repo_with_remote(base: Path) -> Tuple[Path, Path]:
    bare = base / "remote.git"
    work = base / "repo-with-remote"
    run_checked(["git", "init", "--bare", str(bare)], os.environ.copy(), label="init bare remote")
    run_checked(["git", "init", str(work)], os.environ.copy(), label="init working repo")
    run_checked(
        ["git", "-C", str(work), "config", "user.email", "regression@example.com"],
        os.environ.copy(),
        label="set git email",
    )
    run_checked(
        ["git", "-C", str(work), "config", "user.name", "Regression Bot"],
        os.environ.copy(),
        label="set git name",
    )
    (work / "README.md").write_text("regression\n", encoding="utf-8")
    run_checked(["git", "-C", str(work), "add", "README.md"], os.environ.copy(), label="git add")
    run_checked(["git", "-C", str(work), "commit", "-m", "init"], os.environ.copy(), label="git commit")
    run_checked(["git", "-C", str(work), "branch", "-M", "main"], os.environ.copy(), label="rename main")
    run_checked(["git", "-C", str(work), "remote", "add", "origin", str(bare)], os.environ.copy(), label="add origin")
    run_checked(["git", "-C", str(work), "push", "-u", "origin", "main"], os.environ.copy(), label="push main")
    return work, bare


def init_git_repo_without_remote(base: Path) -> Path:
    work = base / "repo-no-remote"
    run_checked(["git", "init", str(work)], os.environ.copy(), label="init no-remote repo")
    run_checked(
        ["git", "-C", str(work), "config", "user.email", "regression@example.com"],
        os.environ.copy(),
        label="set no-remote email",
    )
    run_checked(
        ["git", "-C", str(work), "config", "user.name", "Regression Bot"],
        os.environ.copy(),
        label="set no-remote name",
    )
    (work / "README.md").write_text("regression\n", encoding="utf-8")
    run_checked(["git", "-C", str(work), "add", "README.md"], os.environ.copy(), label="no-remote add")
    run_checked(["git", "-C", str(work), "commit", "-m", "init"], os.environ.copy(), label="no-remote commit")
    run_checked(["git", "-C", str(work), "branch", "-M", "main"], os.environ.copy(), label="no-remote rename main")
    return work


def pending_dispatch(lane: str) -> Dict[str, object]:
    return {
        "task_id": "D1",
        "lane": lane,
        "task": "pending regression task",
        "from_role": "researcher",
        "to_role": "worker",
        "status": "dispatched",
        "assigned_at": NOW,
        "expected_output_refs": {"cleanup_ref": "mailroom/state/cleanup/regression-proof.md"},
    }


def write_state(
    runtime_root: Path,
    wave_id: str,
    repo: Path,
    branch: str,
    *,
    dispatches: List[Dict[str, object]] | None = None,
    lane_outcomes: List[Dict[str, object]] | None = None,
    stub_matrix: List[Dict[str, object]] | None = None,
    single_terminal_mode: bool = True,
    lifecycle_state: str = "active",
    role_current: str = "researcher",
    role_next: str = "worker",
) -> Path:
    dispatches = dispatches or []
    lane_outcomes = lane_outcomes or []
    stub_matrix = stub_matrix or []

    wave_dir = runtime_root / "waves" / wave_id
    wave_dir.mkdir(parents=True, exist_ok=True)
    state_file = wave_dir / "state.json"

    state = {
        "wave_id": wave_id,
        "objective": "wave hardening regression",
        "status": "active",
        "created_at": NOW,
        "updated_at": NOW,
        "dispatches": dispatches,
        "watcher_checks": [{"id": "verify_fast", "cap": "verify.run -- fast", "status": "done", "run_key": VERIFY_RUN_KEY}],
        "preflight": {
            "domain": "regression",
            "started_at": NOW,
            "finished_at": NOW,
            "duration_s": 0,
            "verdict": "go",
            "blockers": [],
            "next_action": "dispatch",
        },
        "lifecycle_state": lifecycle_state,
        "role_flow": {
            "current_role": role_current,
            "next_role": role_next,
        },
        "workspace": {
            "enabled": True,
            "repo": str(repo),
            "worktree": str(repo),
            "branch": branch,
            "note": "regression-fixture",
        },
        "packet": {
            "wave_id": wave_id,
            "loop_id": f"LOOP-{wave_id}",
            "owner_terminal": "SPINE-CONTROL-01",
            "current_role": "researcher",
            "next_role": "worker",
            "deadline_utc": "2099-01-02T00:00:00Z",
            "horizon": "now",
            "execution_readiness": "runnable",
            "claimed_paths": ["ops/"],
            "single_terminal_mode": single_terminal_mode,
            "cross_repo_pushability_gate": {
                "status": "PENDING",
                "checked_at_utc": "PENDING_CLOSEOUT",
                "repo": str(repo),
                "branch": branch,
                "remote": "origin",
                "failure": "",
            },
            "lane_outcomes": lane_outcomes,
            "stub_matrix": stub_matrix,
            "plan_transition": {
                "status": "pending",
                "updated_at_utc": NOW,
                "run_key": "PENDING_CLOSEOUT",
            },
        },
    }
    state_file.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    return state_file


def read_state(runtime_root: Path, wave_id: str) -> Dict[str, object]:
    state_file = runtime_root / "waves" / wave_id / "state.json"
    return json.loads(state_file.read_text(encoding="utf-8"))


def run_wave(
    wave_cmd: Path,
    base_env: Dict[str, str],
    args: List[str],
    *,
    extra_env: Dict[str, str] | None = None,
) -> Tuple[int, str]:
    env = dict(base_env)
    if extra_env:
        env.update(extra_env)
    return run([str(wave_cmd), *args], env)


def main() -> None:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[3]
    wave_cmd = root / "ops" / "commands" / "wave.sh"
    if not wave_cmd.exists():
        fail(f"missing wave command at {wave_cmd}")

    with tempfile.TemporaryDirectory(prefix="wave-hardening-regression-") as tmpdir:
        tmp = Path(tmpdir)
        fixture_root = tmp / "spine-fixture"
        runtime_root = tmp / "runtime"
        runtime_root.mkdir(parents=True, exist_ok=True)
        (runtime_root / "waves").mkdir(parents=True, exist_ok=True)

        create_fixture(root, fixture_root)
        repo_with_remote, _ = init_git_repo_with_remote(tmp)
        repo_no_remote = init_git_repo_without_remote(tmp)

        base_env = os.environ.copy()
        base_env["SPINE_REPO"] = str(fixture_root)
        base_env["SPINE_RUNTIME_ROOT"] = str(runtime_root)

        # 1) Pushability preflight: negative + positive.
        wave = "WAVE-20990101-01"
        write_state(runtime_root, wave, repo_no_remote, "main")
        rc, out = run_wave(
            wave_cmd,
            base_env,
            [
                "dispatch",
                wave,
                "--lane",
                "control",
                "--task",
                "neg pushability",
                "--from-role",
                "researcher",
                "--to-role",
                "worker",
            ],
        )
        if rc == 0:
            fail("pushability negative case unexpectedly succeeded", out)
        ensure_contains(out, "BLOCKED: dispatch pushability preflight failed", "pushability negative")
        ensure_contains(out, "remote 'origin' is not configured", "pushability negative")
        state = read_state(runtime_root, wave)
        if state.get("dispatches"):
            fail("pushability negative case created dispatch rows unexpectedly", out)
        gate = ((state.get("packet") or {}).get("cross_repo_pushability_gate") or {})
        if gate.get("status") != "FAIL":
            fail("pushability negative case did not persist FAIL gate status")

        wave = "WAVE-20990101-02"
        write_state(runtime_root, wave, repo_with_remote, "main")
        rc, out = run_wave(
            wave_cmd,
            base_env,
            [
                "dispatch",
                wave,
                "--lane",
                "control",
                "--task",
                "pos pushability",
                "--from-role",
                "researcher",
                "--to-role",
                "worker",
            ],
        )
        if rc != 0:
            fail("pushability positive case failed", out)
        ensure_contains(out, "dispatch pushability preflight: PASS", "pushability positive")
        state = read_state(runtime_root, wave)
        dispatches = state.get("dispatches") or []
        if len(dispatches) != 1 or dispatches[0].get("status") != "dispatched":
            fail("pushability positive case did not create dispatched row")

        # 2) Single-terminal ack override semantics: negative + positive.
        wave = "WAVE-20990101-03"
        write_state(runtime_root, wave, repo_with_remote, "main", lifecycle_state="active")
        rc, out = run_wave(
            wave_cmd,
            base_env,
            [
                "dispatch",
                wave,
                "--lane",
                "control",
                "--task",
                "ack setup",
                "--from-role",
                "researcher",
                "--to-role",
                "worker",
            ],
        )
        if rc != 0:
            fail("ack setup dispatch failed", out)

        rc, out = run_wave(
            wave_cmd,
            base_env,
            ["ack", wave, "--dispatch", "D1", "--result", "unauthorized ack"],
            extra_env={"OPS_TERMINAL_ROLE": "SPINE-EXECUTION-01", "SPINE_RUNTIME_ROLE": "researcher"},
        )
        if rc == 0:
            fail("ack negative case unexpectedly succeeded", out)
        ensure_contains(out, "Lane-role authorization failed", "ack negative")

        rc, out = run_wave(
            wave_cmd,
            base_env,
            ["ack", wave, "--dispatch", "D1", "--result", "override ack"],
            extra_env={"OPS_TERMINAL_ROLE": "SPINE-CONTROL-01", "SPINE_RUNTIME_ROLE": "researcher"},
        )
        if rc != 0:
            fail("ack positive override case failed", out)
        ensure_contains(out, "Lane-role override", "ack positive")
        state = read_state(runtime_root, wave)
        dispatches = state.get("dispatches") or []
        if not dispatches or dispatches[0].get("status") != "done":
            fail("ack positive case did not mark dispatch done")

        # 3) Force-close guard for pending dispatches: negative.
        wave = "WAVE-20990101-04"
        write_state(
            runtime_root,
            wave,
            repo_with_remote,
            "main",
            dispatches=[pending_dispatch("execution")],
            lifecycle_state="validated",
            role_current="close",
            role_next="",
        )
        rc, out = run_wave(
            wave_cmd,
            base_env,
            ["close", wave, "--force", "--dod-override", "regression pending force-close"],
        )
        if rc == 0:
            fail("force-close pending-dispatch negative case unexpectedly succeeded", out)
        ensure_contains(out, "force-close denied while dispatches are pending without stub evidence", "force-close negative")

        # 4) Stub evidence requirement: negative + positive.
        wave = "WAVE-20990101-05"
        missing_stub = str(tmp / "missing-stub.md")
        write_state(
            runtime_root,
            wave,
            repo_with_remote,
            "main",
            dispatches=[pending_dispatch("execution")],
            lane_outcomes=[
                {
                    "lane_id": "execution",
                    "owner_terminal": "SPINE-CONTROL-01",
                    "lane_status": "BLOCKED",
                    "stub_evidence_ref": missing_stub,
                    "updated_at_utc": NOW,
                }
            ],
            lifecycle_state="validated",
            role_current="close",
            role_next="",
        )
        rc, out = run_wave(
            wave_cmd,
            base_env,
            ["close", wave, "--force", "--dod-override", "regression missing stub"],
        )
        if rc == 0:
            fail("stub-missing negative case unexpectedly succeeded", out)
        ensure_contains(out, "force-close denied while dispatches are pending without stub evidence", "stub negative")

        wave = "WAVE-20990101-06"
        stub_file = tmp / "stub-evidence.md"
        stub_file.write_text("stub evidence\n", encoding="utf-8")
        write_state(
            runtime_root,
            wave,
            repo_with_remote,
            "main",
            dispatches=[pending_dispatch("execution")],
            lane_outcomes=[
                {
                    "lane_id": "execution",
                    "owner_terminal": "SPINE-CONTROL-01",
                    "lane_status": "BLOCKED",
                    "stub_evidence_ref": str(stub_file),
                    "updated_at_utc": NOW,
                }
            ],
            stub_matrix=[
                {
                    "id": "STUB-regression-execution",
                    "path": str(stub_file),
                    "blocker_class": "test",
                    "state": "open",
                }
            ],
            lifecycle_state="validated",
            role_current="close",
            role_next="",
        )
        rc, out = run_wave(
            wave_cmd,
            base_env,
            ["close", wave, "--force", "--dod-override", "regression valid stub"],
        )
        if rc != 0:
            fail("stub-positive force-close case failed", out)
        ensure_contains(out, "Wave 'WAVE-20990101-06' closed.", "stub positive")
        state = read_state(runtime_root, wave)
        if state.get("status") != "closed":
            fail("stub-positive case did not persist closed status")

        print("D331 PASS: wave.sh regression harness passed (pushability, ack override, force-close guard, stub evidence)")


if __name__ == "__main__":
    main()
