"""Wave close validation and decision logic.

Extracted from the cmd_close_v2 inline Python in ops/commands/wave.sh.
Pure decision logic — no file I/O, no state mutation, no subprocess calls.
All side effects remain in the shell caller.
"""
from __future__ import annotations

import re
from typing import Any

# ── Defaults (overridden by role-runtime contract at call site) ──────

DEFAULT_RUN_KEY_PATTERNS = [
    r"^(CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+|S\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+)$"
]
DEFAULT_COMMIT_REF_PATTERN = r"^[0-9a-f]{7,40}$"
DEFAULT_ALLOWED_BLOCKER_CLASSES = frozenset({
    "none", "deterministic", "freshness", "dependency",
    "cleanup", "policy", "external",
})
DEFAULT_REQUIRED_EVIDENCE_FIELDS = [
    "run_key_refs", "file_refs", "commit_refs", "blocker_class",
]
DEFAULT_STATE_FIELD = "lifecycle_state"
DEFAULT_STATE_TRANSITIONS: dict[str, set[str]] = {
    "active": {"implemented"},
    "implemented": {"validated"},
    "validated": {"closed"},
    "closed": set(),
}
DEFAULT_CLOSE_ALIASES = frozenset({"close", "librarian"})
DEFAULT_ALLOWED_LANES = frozenset({"control", "execution", "audit", "watcher"})
VERIFY_PASS_STATUSES = frozenset({"done", "pass", "passed", "ok", "healthy", "success"})


# ── Helpers ──────────────────────────────────────────────────────────

def compile_run_key_patterns(patterns_text: list[str]) -> list[re.Pattern]:
    """Compile run-key regex patterns. Raises RuntimeError on bad regex."""
    compiled = []
    for text in patterns_text:
        try:
            compiled.append(re.compile(str(text)))
        except re.error as exc:
            raise RuntimeError(f"invalid run key regex '{text}': {exc}")
    if not compiled:
        compiled = [re.compile(r"^CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+$")]
    return compiled


def run_key_matches(value: str, patterns: list[re.Pattern]) -> bool:
    """Check if a run key matches any compiled pattern."""
    return any(pat.match(value) for pat in patterns)


# ── Config ───────────────────────────────────────────────────────────

class CloseConfig:
    """Immutable configuration for close validation."""

    __slots__ = (
        "run_key_patterns", "commit_ref_pattern",
        "allowed_blocker_classes", "required_evidence_fields",
        "state_field", "state_transitions", "close_aliases",
        "allowed_lanes",
    )

    def __init__(
        self,
        run_key_patterns_text: list[str] | None = None,
        commit_ref_pattern: str | None = None,
        allowed_blocker_classes: set[str] | None = None,
        required_evidence_fields: list[str] | None = None,
        state_field: str | None = None,
        state_transitions: dict[str, set[str]] | None = None,
        close_aliases: set[str] | None = None,
        allowed_lanes: set[str] | None = None,
    ):
        self.run_key_patterns = compile_run_key_patterns(
            run_key_patterns_text or list(DEFAULT_RUN_KEY_PATTERNS)
        )
        self.commit_ref_pattern = commit_ref_pattern or DEFAULT_COMMIT_REF_PATTERN
        self.allowed_blocker_classes = (
            allowed_blocker_classes if allowed_blocker_classes is not None
            else set(DEFAULT_ALLOWED_BLOCKER_CLASSES)
        )
        self.required_evidence_fields = (
            required_evidence_fields if required_evidence_fields is not None
            else list(DEFAULT_REQUIRED_EVIDENCE_FIELDS)
        )
        self.state_field = state_field or DEFAULT_STATE_FIELD
        self.state_transitions = (
            state_transitions if state_transitions is not None
            else dict(DEFAULT_STATE_TRANSITIONS)
        )
        self.close_aliases = (
            close_aliases if close_aliases is not None
            else set(DEFAULT_CLOSE_ALIASES)
        )
        self.allowed_lanes = (
            allowed_lanes if allowed_lanes is not None
            else set(DEFAULT_ALLOWED_LANES)
        )

    def matches_run_key(self, value: str) -> bool:
        return run_key_matches(value, self.run_key_patterns)


# ── Disposition validation ───────────────────────────────────────────

def validate_disposition(disposition: str, allowed: set[str]) -> str | None:
    """Return error message if disposition is invalid, else None."""
    if not disposition:
        return "FAIL: missing required close disposition"
    if allowed and disposition not in allowed:
        return f"FAIL: invalid disposition '{disposition}'"
    return None


# ── Receipt validation ───────────────────────────────────────────────

def validate_receipt(
    receipt: dict[str, Any],
    config: CloseConfig,
    *,
    expected_wave_id: str = "",
) -> list[str]:
    """Validate a single EXEC_RECEIPT against the close contract.

    Returns a list of error strings (empty = valid).
    """
    errors: list[str] = []
    required_fields = [
        "task_id", "terminal_id", "lane", "status", "files_changed",
        "run_keys", "blockers", "ready_for_verify", "timestamp_utc",
    ]
    for field in required_fields:
        if field not in receipt:
            errors.append(f"missing {field}")

    str_fields = ["task_id", "terminal_id", "lane", "status", "timestamp_utc"]
    for f in str_fields:
        if f in receipt and not isinstance(receipt[f], str):
            errors.append(f"{f} not string")

    arr_fields = ["files_changed", "run_keys", "blockers"]
    for f in arr_fields:
        if f in receipt and not isinstance(receipt[f], list):
            errors.append(f"{f} not array")

    if "ready_for_verify" in receipt and not isinstance(receipt["ready_for_verify"], bool):
        errors.append("ready_for_verify not bool")

    if receipt.get("lane") and receipt["lane"] not in config.allowed_lanes:
        errors.append(f"bad lane: {receipt['lane']}")

    if receipt.get("status") and receipt["status"] not in ("done", "failed", "blocked"):
        errors.append(f"bad status: {receipt['status']}")

    ts = receipt.get("timestamp_utc", "")
    if ts and not re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", ts):
        errors.append("bad timestamp format")

    for rk in receipt.get("run_keys", []):
        if not isinstance(rk, str):
            errors.append("run_key not string")
        elif not config.matches_run_key(rk):
            errors.append(f"bad run_key: {rk}")

    if receipt.get("status") == "blocked" and not receipt.get("blockers"):
        errors.append("blocked needs blockers[]")

    if "wave_id" in receipt:
        wid = receipt["wave_id"]
        if not isinstance(wid, str) or not re.match(r"^WAVE-\d{8}-\d{2}$", wid):
            errors.append(f"bad wave_id: {wid}")
        elif expected_wave_id and wid != expected_wave_id:
            errors.append(f"wave_id mismatch: receipt={wid} expected={expected_wave_id}")

    if "commit_hashes" in receipt:
        if not isinstance(receipt["commit_hashes"], list):
            errors.append("commit_hashes not array")
        else:
            commit_pat = re.compile(config.commit_ref_pattern)
            for h in receipt["commit_hashes"]:
                if not isinstance(h, str) or not commit_pat.match(h):
                    errors.append(f"bad commit_hash: {h}")

    if "evidence_refs" not in receipt:
        errors.append("missing evidence_refs")
    else:
        evidence_refs = receipt["evidence_refs"]
        if not isinstance(evidence_refs, dict):
            errors.append("evidence_refs not object")
        else:
            for key in config.required_evidence_fields:
                if key not in evidence_refs:
                    errors.append(f"evidence_refs missing {key}")
            run_key_refs = evidence_refs.get("run_key_refs", [])
            file_refs = evidence_refs.get("file_refs", [])
            commit_refs = evidence_refs.get("commit_refs", [])
            blocker_class = str(evidence_refs.get("blocker_class", "")).strip()

            if not isinstance(run_key_refs, list):
                errors.append("evidence_refs.run_key_refs not array")
            else:
                for rk in run_key_refs:
                    if not isinstance(rk, str) or not config.matches_run_key(rk):
                        errors.append(f"bad evidence run_key_ref: {rk}")

            if not isinstance(file_refs, list):
                errors.append("evidence_refs.file_refs not array")
            else:
                for ref in file_refs:
                    if not isinstance(ref, str) or not ref.strip():
                        errors.append("bad evidence file_ref")

            commit_pat = re.compile(config.commit_ref_pattern)
            if not isinstance(commit_refs, list):
                errors.append("evidence_refs.commit_refs not array")
            else:
                for ref in commit_refs:
                    if not isinstance(ref, str) or not commit_pat.match(ref):
                        errors.append(f"bad evidence commit_ref: {ref}")

            if not blocker_class:
                errors.append("evidence_refs.blocker_class missing")
            elif blocker_class not in config.allowed_blocker_classes:
                errors.append(f"bad evidence blocker_class: {blocker_class}")

    allowed = set(required_fields + [
        "wave_id", "commit_hashes", "loop_id", "gap_ids",
        "evidence_refs", "completion_level", "prompt_lineage",
    ])
    for key in receipt.keys():
        if key not in allowed:
            errors.append(f"unknown field: {key}")

    return errors


# ── Contract enforcement (the 7 checks) ─────────────────────────────

class CloseViolations:
    """Accumulates infra and DoD violations during close validation."""

    __slots__ = ("infra", "dod")

    def __init__(self) -> None:
        self.infra: list[str] = []
        self.dod: list[str] = []


def check_watcher_status(
    checks: list[dict], is_synthetic: bool, violations: CloseViolations
) -> None:
    """Check 1: watcher checks must be done/failed (synthetic skips)."""
    if is_synthetic:
        return
    running = [c for c in checks if c.get("status") in ("queued", "running")]
    if running:
        statuses = "/".join(sorted(set(c["status"] for c in running)))
        violations.infra.append(f"{len(running)} watcher check(s) still {statuses}")


def check_preflight(
    is_synthetic: bool,
    preflight: Any,
    controller_eligible: bool,
    violations: CloseViolations,
) -> None:
    """Check 2: preflight required (synthetic skips)."""
    if not is_synthetic and not preflight and not controller_eligible:
        violations.infra.append("Preflight has not been run (required by wave.lifecycle contract)")


def check_pending_dispatches(
    dispatches: list[dict],
    lane_outcomes: list[dict],
    force: bool,
    violations: CloseViolations,
    stub_exists_fn: Any = None,
) -> bool:
    """Check 3: pending dispatch force-close guard.

    Returns True if force-close was hard-blocked (caller should exit).
    """
    def _lane_outcome(lane_id: str) -> dict:
        for row in lane_outcomes:
            if not isinstance(row, dict):
                continue
            if str(row.get("lane_id", "")).strip() == lane_id:
                return row
        return {}

    pending = [
        d for d in dispatches
        if isinstance(d, dict) and str(d.get("status", "")).strip() in {"dispatched", "running"}
    ]
    pending_without_stub = []
    for d in pending:
        lane = str(d.get("lane", "")).strip()
        outcome = _lane_outcome(lane)
        lane_status = str(outcome.get("lane_status", "")).strip().lower()
        stub_ref = str(outcome.get("stub_evidence_ref", "")).strip()
        blocked_with_stub = (
            lane_status in {"blocked", "stubbed_blocked", "blocked_stubbed"}
            and stub_exists_fn is not None
            and stub_exists_fn(stub_ref)
        )
        if not blocked_with_stub:
            pending_without_stub.append(lane or "unknown")

    if pending_without_stub:
        msg = (
            "dispatch pending without explicit blocked+stub evidence for lane(s): "
            + ", ".join(sorted(set(pending_without_stub)))
        )
        if force:
            return True  # hard block
        violations.infra.append(msg)
    return False


def check_packet_presence(
    packet: dict, violations: CloseViolations
) -> None:
    """Check 4: canonical packet presence required at close."""
    required = [
        "wave_id", "loop_id", "owner_terminal", "current_role",
        "next_role", "deadline_utc", "horizon", "execution_readiness",
        "claimed_paths",
    ]
    missing = [k for k in required if packet.get(k) in (None, "", [])]
    if missing:
        violations.infra.append(
            f"wave packet missing required field(s): {', '.join(missing)}"
        )


def check_receipts(
    receipts_valid: list[dict],
    invalid_receipt_details: list[str],
    violations: CloseViolations,
) -> None:
    """Check 5: receipt validation."""
    if invalid_receipt_details:
        violations.infra.append(
            f"{len(invalid_receipt_details)} invalid receipt(s) in wave evidence/"
        )


def check_watcher_completions(
    checks: list[dict], violations: CloseViolations
) -> None:
    """Check 6: verify/preflight checks present."""
    done_checks = [c for c in checks if c.get("status") == "done"]
    if checks and not done_checks:
        violations.infra.append("No watcher checks completed successfully")


def collect_verify_results(
    checks: list[dict],
    valid_receipts: list[dict],
    dispatches: list[dict],
    controller_context: dict,
    config: CloseConfig,
) -> list[str]:
    """Collect all verify run keys from checks, receipts, and dispatches."""
    verify_results: list[str] = []
    for c in checks:
        rk = c.get("run_key")
        if isinstance(rk, str) and rk:
            verify_results.append(rk)
    for r in valid_receipts:
        for rk in r.get("run_keys", []):
            if isinstance(rk, str) and rk:
                verify_results.append(rk)
        evidence_refs = r.get("evidence_refs") if isinstance(r.get("evidence_refs"), dict) else {}
        for rk in (evidence_refs.get("run_key_refs", []) if isinstance(evidence_refs.get("run_key_refs"), list) else []):
            if isinstance(rk, str) and rk:
                verify_results.append(rk)
    for d in dispatches:
        if not isinstance(d, dict):
            continue
        expected = d.get("expected_output_refs") if isinstance(d.get("expected_output_refs"), dict) else {}
        verify_ref = str(expected.get("verify_ref", "")).strip() if expected else ""
        if verify_ref and config.matches_run_key(verify_ref):
            verify_results.append(verify_ref)
        if str(d.get("lane", "")).strip() == "audit":
            rk = d.get("run_key")
            if isinstance(rk, str) and rk and config.matches_run_key(rk):
                verify_results.append(rk)
    if controller_context.get("verify_run_key"):
        verify_results.append(controller_context["verify_run_key"])
    return verify_results


def check_dod_guard(
    checks: list[dict],
    valid_receipts: list[dict],
    dispatches: list[dict],
    packet: dict,
    controller_context: dict,
    config: CloseConfig,
    violations: CloseViolations,
) -> dict:
    """Check 7: DoD guard completeness.

    Returns the assembled DoD dict for the wave state.
    """
    verify_results = collect_verify_results(
        checks, valid_receipts, dispatches, controller_context, config,
    )
    if not verify_results and not controller_context.get("minimal_shell"):
        violations.dod.append(
            "DoD missing verify results (no run keys in watcher checks or receipts)"
        )

    blocker_classes: list[str] = []
    cleanup_proof: list[str] = []
    linkage_errors: list[str] = []
    packet_loop_id = str(packet.get("loop_id", "")).strip()
    blocked_or_failed = [
        d for d in dispatches if d.get("status") in ("blocked", "failed")
    ]

    if packet_loop_id and packet_loop_id.lower() == "null":
        packet_loop_id = ""
    if not packet_loop_id:
        linkage_errors.append("packet.loop_id missing")

    for r in valid_receipts:
        evidence_refs = r.get("evidence_refs") if isinstance(r.get("evidence_refs"), dict) else {}
        blocker_class = str(evidence_refs.get("blocker_class", "")).strip() if evidence_refs else ""
        if blocker_class:
            blocker_classes.append(blocker_class)

        for ref in (evidence_refs.get("file_refs", []) if isinstance(evidence_refs.get("file_refs"), list) else []):
            if isinstance(ref, str) and ref and ("cleanup" in ref.lower() or "clean" in ref.lower()):
                cleanup_proof.append(ref)

        receipt_loop = str(r.get("loop_id", "")).strip()
        if packet_loop_id and receipt_loop != packet_loop_id:
            linkage_errors.append(
                f"receipt task_id={r.get('task_id', '?')} loop_id mismatch "
                f"(expected {packet_loop_id}, got {receipt_loop or 'missing'})"
            )

        for gap_id in (r.get("gap_ids", []) if isinstance(r.get("gap_ids"), list) else []):
            if not isinstance(gap_id, str) or not re.match(r"^GAP-[A-Z0-9-]+$", gap_id):
                linkage_errors.append(
                    f"receipt task_id={r.get('task_id', '?')} has invalid gap_id '{gap_id}'"
                )

    for d in dispatches:
        expected = d.get("expected_output_refs") if isinstance(d.get("expected_output_refs"), dict) else {}
        cleanup_ref = str(expected.get("cleanup_ref", "")).strip() if expected else ""
        if cleanup_ref:
            cleanup_proof.append(cleanup_ref)
    if controller_context.get("cleanup_ref"):
        cleanup_proof.append(controller_context["cleanup_ref"])

    if blocked_or_failed and not blocker_classes:
        violations.dod.append("DoD missing blocker classification for blocked/failed dispatches")
    elif not blocker_classes:
        blocker_classes.append("none")

    if not cleanup_proof and not controller_context.get("minimal_shell"):
        violations.dod.append("DoD missing cleanup proof (no cleanup refs in evidence/output refs)")

    if linkage_errors:
        violations.dod.append("DoD linkage integrity failed: " + "; ".join(linkage_errors))

    return {
        "verify_results": sorted(set(verify_results)),
        "blocker_classification": sorted(set(blocker_classes)),
        "cleanup_proof": sorted(set(cleanup_proof)),
        "linkage": {
            "packet_loop_id": packet_loop_id,
            "valid_receipts": len(valid_receipts),
            "errors": linkage_errors,
        },
    }


def check_state_machine(
    state: dict,
    controller_context: dict,
    config: CloseConfig,
    violations: CloseViolations,
) -> None:
    """Check lifecycle state machine allows transition to closed."""
    lifecycle_state = str(
        state.get(config.state_field, state.get("lifecycle_state", "active"))
    ).strip() or "active"
    if lifecycle_state not in config.state_transitions:
        violations.infra.append(f"state machine unknown state '{lifecycle_state}'")
    elif not controller_context.get("eligible") and not controller_context.get("minimal_shell"):
        allowed = config.state_transitions.get(lifecycle_state, set())
        if "closed" not in allowed:
            violations.infra.append(
                f"state machine blocked: {lifecycle_state} -> closed not allowed"
            )


def check_role_flow(
    state: dict,
    dispatches: list[dict],
    controller_context: dict,
    config: CloseConfig,
    violations: CloseViolations,
) -> None:
    """Check role flow allows close (and fix up current_role from close dispatches)."""
    role_flow = state.get("role_flow") if isinstance(state.get("role_flow"), dict) else {}
    current_role = str(role_flow.get("current_role", "")).strip()
    completed_close_dispatches = [
        d for d in dispatches
        if isinstance(d, dict)
        and str(d.get("status", "")).strip() == "done"
        and str(d.get("to_role", "")).strip() in config.close_aliases
    ]
    if completed_close_dispatches and current_role not in config.close_aliases:
        def _dispatch_order(dispatch: dict) -> int:
            task_id = str(dispatch.get("task_id", "")).strip()
            if task_id.startswith("D") and task_id[1:].isdigit():
                return int(task_id[1:])
            return 0

        completed_close_dispatches.sort(
            key=lambda d: (
                _dispatch_order(d),
                str(d.get("completed_at") or d.get("dispatched_at") or ""),
            )
        )
        authoritative_close = completed_close_dispatches[-1]
        current_role = str(authoritative_close.get("to_role", "")).strip()
        role_flow["current_role"] = current_role
        role_flow["next_role"] = ""
        role_flow.pop("pending_transition", None)
        role_flow["last_transition"] = {
            "task_id": authoritative_close.get("task_id"),
            "from_role": str(authoritative_close.get("from_role", "")).strip(),
            "to_role": current_role,
            "completed_at": authoritative_close.get("completed_at"),
            "run_key": authoritative_close.get("run_key"),
        }
        state["role_flow"] = role_flow

    if (
        config.close_aliases
        and current_role
        and current_role not in config.close_aliases
        and not controller_context.get("eligible")
        and not controller_context.get("minimal_shell")
    ):
        violations.infra.append(
            f"role flow blocked close: current_role={current_role} "
            f"expected one of {sorted(config.close_aliases)}"
        )


# ── Synthetic fast-close filter ──────────────────────────────────────

ZERO_WORK_DISPOSITIONS = frozenset({"abandoned", "superseded"})


def detect_zero_work(state: dict) -> bool:
    """Return True when a wave carried no real work.

    Zero-work means:
      - no dispatches created
      - no watcher checks enqueued
      - no results recorded
      - no preflight run
      - no valid receipts

    Used to gate the lightweight close path that skips ceremony
    meant to certify real work landing.
    """
    if state.get("dispatches"):
        return False
    if state.get("watcher_checks"):
        return False
    results = state.get("results")
    if isinstance(results, list) and results:
        return False
    if state.get("preflight"):
        return False
    valid_receipts = state.get("_valid_receipts")
    if isinstance(valid_receipts, list) and valid_receipts:
        return False
    return True


def apply_zero_work_fast_close(
    is_zero_work: bool,
    violations: CloseViolations,
    state: dict,
    packet: dict,
) -> None:
    """Clear ceremony-only violations for zero-work abandoned/superseded closes.

    A wave that never dispatched any work does not need DoD, preflight,
    state-machine, or role-flow ceremony to close honestly. The honest
    outcome is "abandoned with no work", not "forced past guards".

    Mirrors apply_synthetic_fast_close but stamps a distinct close label
    so the receipt records why ceremony was waived.
    """
    if not is_zero_work:
        return

    violations.dod.clear()
    violations.infra[:] = [
        v for v in violations.infra
        if not any(skip in v for skip in [
            "state machine", "role flow blocked", "Preflight has not been run",
            "watcher check", "receipt", "DoD",
        ])
    ]
    state["zero_work_fast_close"] = True
    if "dod" not in state or not state.get("dod"):
        state["dod"] = {
            "verify_results": [],
            "blocker_classification": ["none"],
            "cleanup_proof": ["zero_work_fast_close"],
            "linkage": {
                "packet_loop_id": str(packet.get("loop_id", "")).strip(),
                "valid_receipts": 0,
                "errors": [],
            },
        }


def apply_synthetic_fast_close(
    is_synthetic: bool,
    violations: CloseViolations,
    state: dict,
    packet: dict,
) -> None:
    """Clear ceremony-only violations for synthetic waves.

    Mutates violations in-place. Sets default DoD if absent.
    """
    if not is_synthetic:
        return

    _wave_kind = str(state.get("wave_kind") or "synthetic").strip()
    _close_label = f"{_wave_kind}_fast_close"

    violations.dod.clear()
    violations.infra[:] = [
        v for v in violations.infra
        if not any(skip in v for skip in [
            "state machine", "role flow blocked", "Preflight has not been run",
            "watcher check", "receipt",
        ])
    ]
    if "dod" not in state or not state.get("dod"):
        state["dod"] = {
            "verify_results": [],
            "blocker_classification": ["none"],
            "cleanup_proof": [_close_label],
            "linkage": {
                "packet_loop_id": str(packet.get("loop_id", "")).strip(),
                "valid_receipts": 0,
                "errors": [],
            },
        }


# ── Gate decision ────────────────────────────────────────────────────

class GateDecision:
    """Result of the close gate evaluation."""

    __slots__ = ("blocked", "infra_violations", "dod_violations", "force_used", "dod_overridden")

    def __init__(
        self,
        blocked: bool,
        infra_violations: list[str],
        dod_violations: list[str],
        force_used: bool,
        dod_overridden: bool,
    ):
        self.blocked = blocked
        self.infra_violations = infra_violations
        self.dod_violations = dod_violations
        self.force_used = force_used
        self.dod_overridden = dod_overridden


def evaluate_gate(
    violations: CloseViolations,
    force: bool,
    dod_override_reason: str,
) -> GateDecision:
    """Evaluate whether close is blocked or allowed."""
    infra_blocked = bool(violations.infra) and not force
    dod_blocked = bool(violations.dod) and not dod_override_reason
    blocked = infra_blocked or dod_blocked
    return GateDecision(
        blocked=blocked,
        infra_violations=list(violations.infra),
        dod_violations=list(violations.dod),
        force_used=bool(violations.infra) and force,
        dod_overridden=bool(violations.dod) and bool(dod_override_reason),
    )


# ── Close receipt assembly ───────────────────────────────────────────

def build_close_receipt(
    state: dict,
    disposition: str,
    now_utc: str,
    dispatches: list[dict],
    checks: list[dict],
    valid_receipt_count: int,
    invalid_receipt_count: int,
    run_keys: list[str],
    gate: GateDecision,
    controller_only: bool,
    controller_precheck_path: str,
    controller_context: dict,
    dod_override_reason: str,
    lock_override_reason: str,
) -> dict:
    """Build the JSON close receipt payload."""
    residual_blockers: list[str] = []
    for v in gate.infra_violations:
        if gate.force_used:
            residual_blockers.append(f"Infra violation (force-closed): {v}")
    for v in gate.dod_violations:
        if gate.dod_overridden:
            residual_blockers.append(f"DoD violation (override): {v}")
    for c in checks:
        if c.get("status") == "failed":
            residual_blockers.append(
                f"Watcher check failed: {c['cap']} (exit={c.get('exit_code', '?')})"
            )
    pf = state.get("preflight")
    if pf and isinstance(pf, dict) and pf.get("verdict") == "no-go":
        for b in pf.get("blockers", []):
            residual_blockers.append(f"Preflight blocker: {b}")

    workspace = state.get("workspace") if isinstance(state.get("workspace"), dict) else {}

    return {
        "wave_id": state.get("wave_id", ""),
        "objective": state.get("objective", ""),
        "created_at": state.get("created_at", ""),
        "closed_at": now_utc,
        "disposition": disposition,
        "force_closed": gate.force_used,
        "dod_overridden": gate.dod_overridden,
        "dod_override_reason": dod_override_reason if gate.dod_overridden else "",
        "controller_only": bool(controller_only),
        "controller_precheck_path": controller_precheck_path if controller_only else "",
        "fixed_in": controller_context.get("fixed_in", ""),
        "verify_receipt_path": controller_context.get("verify_receipt_path", ""),
        "lock_overridden": bool(lock_override_reason),
        "lock_override_reason": lock_override_reason,
        "dispatches": len(dispatches),
        "dispatches_done": sum(1 for d in dispatches if d.get("status") == "done"),
        "dispatches_blocked": sum(1 for d in dispatches if d.get("status") == "blocked"),
        "watcher_checks_done": sum(1 for c in checks if c.get("status") == "done"),
        "watcher_checks_failed": sum(1 for c in checks if c.get("status") == "failed"),
        "valid_receipts": valid_receipt_count,
        "invalid_receipts": invalid_receipt_count,
        "run_keys": run_keys,
        "residual_blockers": residual_blockers,
        "READY_FOR_ADOPTION": not residual_blockers,
        "dod": state.get("dod", {}),
        "workspace": workspace if workspace else None,
    }


# ── Full validation pipeline ────────────────────────────────────────

def validate_close(
    state: dict,
    force: bool,
    disposition: str,
    allowed_dispositions: set[str],
    dod_override_reason: str,
    controller_context: dict,
    config: CloseConfig,
    stub_exists_fn: Any = None,
) -> tuple[CloseViolations, dict, bool]:
    """Run the full close validation pipeline.

    Returns (violations, dod_dict, hard_blocked).
    hard_blocked is True if force-close was denied on pending dispatches.
    """
    violations = CloseViolations()

    _wave_kind = str(state.get("wave_kind") or "production").strip()
    # Engineering waves get the same ceremony-skip treatment as synthetic:
    # no preflight, no watcher, no state-machine, no role-flow ceremony.
    # Dispatch integrity and DoD are still enforced.
    is_synthetic = _wave_kind in ("synthetic", "engineering")
    checks = state.get("watcher_checks", [])
    pf = state.get("preflight")
    dispatches = state.get("dispatches", [])
    packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
    lane_outcomes = packet.get("lane_outcomes") if isinstance(packet.get("lane_outcomes"), list) else []

    # Check 1: watcher status
    check_watcher_status(checks, is_synthetic, violations)

    # Check 2: preflight
    check_preflight(is_synthetic, pf, controller_context.get("eligible", False), violations)

    # Check 3: pending dispatches
    hard_blocked = check_pending_dispatches(
        dispatches, lane_outcomes, force, violations, stub_exists_fn,
    )
    if hard_blocked:
        return violations, {}, True

    # Check 4: packet presence
    check_packet_presence(packet, violations)

    # Check 5: (receipt validation is done by caller before this, results passed in)
    # Just aggregate invalid receipt count into violations
    # Caller handles this via check_receipts()

    # Check 6: watcher completions
    check_watcher_completions(checks, violations)

    # Check 7: DoD guard
    valid_receipts = state.get("_valid_receipts", [])
    invalid_receipts_details = state.get("_invalid_receipt_details", [])
    check_receipts(valid_receipts, invalid_receipts_details, violations)

    dod = check_dod_guard(
        checks, valid_receipts, dispatches, packet,
        controller_context, config, violations,
    )
    state["dod"] = dod

    # State machine check
    check_state_machine(state, controller_context, config, violations)

    # Role flow check
    check_role_flow(state, dispatches, controller_context, config, violations)

    # Controller-only violations
    if controller_context.get("requested") and not controller_context.get("eligible"):
        violations.infra.extend(controller_context.get("controller_infra_violations", []))
        violations.dod.extend(controller_context.get("controller_dod_violations", []))

    # Synthetic fast-close
    apply_synthetic_fast_close(is_synthetic, violations, state, packet)

    # Zero-work fast-close: a wave that never dispatched any work can
    # close lightly with abandoned/superseded, without --force or
    # --dod-override ceremony. Gated on disposition so that real waves
    # still go through the full close contract.
    is_zero_work = (
        disposition in ZERO_WORK_DISPOSITIONS
        and not is_synthetic
        and detect_zero_work(state)
    )
    apply_zero_work_fast_close(is_zero_work, violations, state, packet)

    return violations, dod, False
