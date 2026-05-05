"""Slice D: deterministic rule engine for commit.narrator.status.

The rule engine compares per-commit facts (paths, shortstat, optional bounded
diff body) against COMMITTED governance. It does not read memory files, local
caches, or projections. It does not mutate, decide, gate, or close.

Rule outcomes carry citations (source + anchor text) so verdicts are auditable.
Honest unknown is mandatory: when no rule applies, the engine emits
`unknown_no_rule_applies` with explicit reasoning. When a rule needs the diff
body but the caller did not supply --include-diff, the rule emits
honest_unknown with reason `diff_body_not_collected`.

Witness-only by construction: the engine reads, classifies, and reports. It
adds no fields to the row that imply mutation_access or decision_authority.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Callable


# ───────────────────────── Governance bundle loader ─────────────────────────

_GOVERNANCE_DOCS = (
    "AGENTS.md",
    "NORTH_STAR.md",
    "docs/governance/SPINE.md",
    "docs/governance/SESSION_PROTOCOL.md",
)
_CONTRACT_DIR = "ops/bindings"
_VERIFY_DIR = "surfaces/verify"
_CAPS_FILE = "ops/capabilities.yaml"


def load_governance_bundle(repo_root: Path) -> dict[str, Any]:
    """Load committed governance text + verify-gate inventory.

    Returns a dict whose keys are governance source paths (relative to
    repo_root) and whose values are file text. Also includes a small
    verify-gate inventory dict.
    """
    bundle: dict[str, Any] = {"docs": {}, "contracts": {}, "verify_gates": []}
    for rel in _GOVERNANCE_DOCS:
        path = repo_root / rel
        if path.is_file():
            try:
                bundle["docs"][rel] = path.read_text(encoding="utf-8")
            except OSError:
                bundle["docs"][rel] = ""
    contracts_dir = repo_root / _CONTRACT_DIR
    if contracts_dir.is_dir():
        for path in sorted(contracts_dir.glob("*.yaml")):
            try:
                bundle["contracts"][f"{_CONTRACT_DIR}/{path.name}"] = path.read_text(encoding="utf-8")
            except OSError:
                pass
    verify_dir = repo_root / _VERIFY_DIR
    if verify_dir.is_dir():
        bundle["verify_gates"] = sorted(p.name for p in verify_dir.glob("d*.sh"))
    caps = repo_root / _CAPS_FILE
    if caps.is_file():
        bundle["capabilities_text"] = caps.read_text(encoding="utf-8")
    manifest = repo_root / "ops/plugins/MANIFEST.yaml"
    if manifest.is_file():
        bundle["manifest_text"] = manifest.read_text(encoding="utf-8")
    return bundle


# ───────────────────────── Rule outcome helpers ─────────────────────────

def _outcome_matched(rule_id: str, *, verdict_signal: str, confidence: str,
                     reason: str, citations: list[dict] | None = None) -> dict:
    return {
        "rule_id": rule_id,
        "outcome": "matched",
        "verdict_signal": verdict_signal,
        "confidence": confidence,
        "reason": reason,
        "citations": citations or [],
    }


def _outcome_inapplicable(rule_id: str, *, reason: str) -> dict:
    return {
        "rule_id": rule_id,
        "outcome": "inapplicable",
        "verdict_signal": "none",
        "confidence": "high",
        "reason": reason,
        "citations": [],
    }


def _outcome_unknown(rule_id: str, *, reason: str, citations: list[dict] | None = None) -> dict:
    return {
        "rule_id": rule_id,
        "outcome": "honest_unknown",
        "verdict_signal": "none",
        "confidence": "low",
        "reason": reason,
        "citations": citations or [],
    }


# ───────────────────────── Rule implementations ─────────────────────────

_GATE_RE = re.compile(r"^surfaces/verify/d\d+.*\.sh$")


def rule_surface_expansion_discipline(row: dict, bundle: dict) -> dict:
    rule_id = "surface_expansion_discipline"
    path_status = row.get("path_status") or {}
    if not isinstance(path_status, dict) or not path_status:
        return _outcome_inapplicable(rule_id, reason="commit lacks per-path status data")
    gate_paths = [p for p in path_status if _GATE_RE.match(p)]
    if not gate_paths:
        return _outcome_inapplicable(rule_id, reason="commit does not touch surfaces/verify/d*.sh gates")
    gates_added = [p for p in gate_paths if path_status.get(p) == "A"]
    gates_deleted = [p for p in gate_paths if path_status.get(p) == "D"]
    gates_modified = [p for p in gate_paths if path_status.get(p) == "M"]
    citations = [
        {
            "source": "AGENTS.md",
            "anchor": "every first-class L1/L2 improvement, and every doctrine or rule change that names a live specimen of the disease it labels, must subtract the old surface or named specimen it replaces in the same slice",
        },
        {
            "source": f"commit:{row.get('short_sha')}",
            "anchor": "; ".join(gate_paths[:3]),
        },
    ]
    if gates_added and gates_deleted:
        return _outcome_matched(
            rule_id,
            verdict_signal="good_direction",
            confidence="high",
            reason=f"D-gate add ({len(gates_added)}) balanced by deletion ({len(gates_deleted)}) in same commit",
            citations=citations,
        )
    if gates_added and not gates_deleted:
        return _outcome_matched(
            rule_id,
            verdict_signal="regression_risk",
            confidence="high",
            reason=f"new D-gate file(s) added without offsetting deletion: {', '.join(gates_added[:3])}",
            citations=citations,
        )
    if gates_deleted and not gates_added:
        return _outcome_matched(
            rule_id,
            verdict_signal="good_direction",
            confidence="high",
            reason=f"D-gate file(s) deleted (gate budget tightening): {', '.join(gates_deleted[:3])}",
            citations=citations,
        )
    if gates_modified and not gates_added and not gates_deleted:
        return _outcome_inapplicable(
            rule_id,
            reason=f"commit modifies existing D-gate(s) without add/delete: {', '.join(gates_modified[:3])}",
        )
    return _outcome_inapplicable(
        rule_id,
        reason="commit touches gate scripts but classification did not match expansion/subtraction shape",
    )


def rule_witness_authority_integrity(row: dict, bundle: dict) -> dict:
    rule_id = "witness_authority_integrity"
    diff = row.get("diff_body") or {}
    body = diff.get("body") if isinstance(diff, dict) else None
    if not body:
        return _outcome_unknown(
            rule_id,
            reason="diff_body_not_collected_or_disabled (rerun with --include-diff for diff-anchored verdict)",
        )
    tokens_widening = []
    for needle, label in (
        ("decision_authority: allowed", "decision_authority widening"),
        ("mutation_access: allowed", "mutation_access widening"),
        ("decision_authority=\"allowed\"", "decision_authority widening (string form)"),
    ):
        if needle in body:
            tokens_widening.append(label)
    tokens_subtractive = []
    for needle, label in (
        ("decision_authority: forbidden", "decision_authority hardening"),
        ("mutation_access: forbidden", "mutation_access hardening"),
        ("retired", "explicit retirement language"),
    ):
        if needle in body:
            tokens_subtractive.append(label)
    if tokens_widening and not tokens_subtractive:
        return _outcome_matched(
            rule_id,
            verdict_signal="regression_risk",
            confidence="low",
            reason=f"diff body shows authority-widening tokens without offsetting hardening: {', '.join(tokens_widening)}",
            citations=[{
                "source": "ops/bindings/node.role.contract.yaml#authority_matrix",
                "anchor": "authority_matrix per-role allowed/forbidden",
            }],
        )
    if tokens_subtractive and not tokens_widening:
        return _outcome_matched(
            rule_id,
            verdict_signal="good_direction",
            confidence="low",
            reason=f"diff body shows authority-hardening tokens: {', '.join(tokens_subtractive)}",
            citations=[{
                "source": "AGENTS.md",
                "anchor": "Old operational jobs may continue only as operational jobs with canonical readback",
            }],
        )
    return _outcome_inapplicable(
        rule_id,
        reason="diff body has no authority-mutating tokens",
    )


def rule_manifest_capability_parity(row: dict, bundle: dict) -> dict:
    rule_id = "manifest_capability_parity"
    paths = row.get("paths") or []
    touches_caps = any(p == "ops/capabilities.yaml" for p in paths)
    touches_manifest = any(p == "ops/plugins/MANIFEST.yaml" for p in paths)
    if not touches_caps and not touches_manifest:
        return _outcome_inapplicable(
            rule_id,
            reason="commit does not touch capability registry or plugin manifest",
        )
    if touches_caps and touches_manifest:
        return _outcome_matched(
            rule_id,
            verdict_signal="good_direction",
            confidence="medium",
            reason="commit touches both ops/capabilities.yaml and ops/plugins/MANIFEST.yaml — parity preserved at commit level (E8 still authoritative for the gate)",
            citations=[{
                "source": "verify.engine.run#E8",
                "anchor": "MANIFEST script parity + plugin capability parity",
            }],
        )
    if touches_caps and not touches_manifest:
        return _outcome_unknown(
            rule_id,
            reason="commit edits ops/capabilities.yaml without touching ops/plugins/MANIFEST.yaml — narrator cannot confirm parity from outside (description-only edits are fine; new bindings need MANIFEST mirror). Defer to E8.",
            citations=[{
                "source": "verify.engine.run#E8",
                "anchor": "MANIFEST script parity + plugin capability parity",
            }],
        )
    return _outcome_unknown(
        rule_id,
        reason="commit edits ops/plugins/MANIFEST.yaml without touching ops/capabilities.yaml — possible orphan entry but narrator cannot confirm. Defer to E8.",
        citations=[{
            "source": "verify.engine.run#E8",
            "anchor": "MANIFEST script parity + plugin capability parity",
        }],
    )


_SUBTRACTION_TOKENS = {
    "subtract", "subtraction", "retire", "retired", "demote", "demoted",
    "fold", "folded", "delete", "deleted", "remove", "removed", "trim",
}
_EXPANSION_TOKENS = {
    "add", "added", "create", "created", "new", "promote", "promoted",
    "register", "registered", "emit", "integrate",
}


def _token_hits(text: str, tokens: set[str]) -> list[str]:
    lower = text.lower()
    return sorted(t for t in tokens if t in lower)


def rule_governance_subtraction_balance(row: dict, bundle: dict) -> dict:
    rule_id = "governance_subtraction_balance"
    subject = row.get("subject") or ""
    diff = row.get("diff_body") or {}
    body = diff.get("body") if isinstance(diff, dict) else ""
    text = subject + "\n" + (body or "")
    sub = _token_hits(text, _SUBTRACTION_TOKENS)
    exp = _token_hits(text, _EXPANSION_TOKENS)
    if not sub and not exp:
        return _outcome_inapplicable(
            rule_id,
            reason="commit subject/body lacks subtraction or expansion vocabulary",
        )
    if sub and not exp:
        return _outcome_matched(
            rule_id,
            verdict_signal="good_direction",
            confidence="low",
            reason=f"subtraction-language present without offsetting expansion: {', '.join(sub)}",
            citations=[{
                "source": "AGENTS.md",
                "anchor": "Subtraction aperture discipline",
            }],
        )
    if exp and not sub:
        return _outcome_matched(
            rule_id,
            verdict_signal="regression_risk",
            confidence="low",
            reason=f"expansion-language present without offsetting subtraction: {', '.join(exp)}",
            citations=[{
                "source": "AGENTS.md",
                "anchor": "Construction is not completion",
            }],
        )
    return _outcome_matched(
        rule_id,
        verdict_signal="neutral",
        confidence="low",
        reason=f"both subtraction ({', '.join(sub)}) and expansion ({', '.join(exp)}) language present — balance unclear from text",
        citations=[{
            "source": "AGENTS.md",
            "anchor": "Subtraction aperture discipline",
        }],
    )


_REGISTERED_RULES: list[Callable[[dict, dict], dict]] = [
    rule_surface_expansion_discipline,
    rule_witness_authority_integrity,
    rule_manifest_capability_parity,
    rule_governance_subtraction_balance,
]


# ───────────────────────── Rule engine entry ─────────────────────────

_VERDICT_PRIORITY = {
    "regression_seen": 4,
    "regression_risk": 3,
    "neutral": 2,
    "good_direction": 1,
    "none": 0,
}


def _aggregate_verdict(outcomes: list[dict]) -> tuple[str, str, str | None]:
    """Choose a single verdict + confidence + honest_unknown_reason.

    Strongest matched signal wins; if all rules are inapplicable, verdict is
    unknown_no_rule_applies. If at least one matched, honest_unknown_reason
    is None unless the only matched signal was 'none'.
    """
    matched = [o for o in outcomes if o.get("outcome") == "matched"]
    honest_unknowns = [o for o in outcomes if o.get("outcome") == "honest_unknown"]
    if matched:
        ranked = sorted(
            matched,
            key=lambda o: _VERDICT_PRIORITY.get(o.get("verdict_signal") or "none", 0),
            reverse=True,
        )
        top = ranked[0]
        signal = top.get("verdict_signal") or "neutral"
        if signal == "regression_risk":
            verdict = "regression_risk"
            honest_reason: str | None = None
        elif signal == "good_direction":
            verdict = "good_direction"
            honest_reason = None
        elif signal == "neutral":
            verdict = "unknown_requires_human_eye"
            honest_reason = (
                f"matched rules produced neutral signals only (top rule {top.get('rule_id')}: {top.get('reason')})"
            )
        else:
            verdict = "unknown_no_rule_applies"
            honest_reason = "matched rules produced no actionable verdict signal"
        confidence = top.get("confidence") or "low"
        return verdict, confidence, honest_reason
    if honest_unknowns:
        reasons = "; ".join(o.get("reason", "") for o in honest_unknowns if o.get("reason"))
        return "unknown_requires_human_eye", "low", reasons or "rules emitted honest_unknown"
    return (
        "unknown_no_rule_applies",
        "low",
        "no rule produced a matched outcome and no honest_unknown was emitted",
    )


def evaluate_commit(row: dict, bundle: dict) -> dict:
    """Run the registered rule set against a single commit row.

    Returns a rule_layer dict suitable to attach to row["rule_layer"] and
    persist into the artifact's rule_layer slot (Slice C schema).
    """
    outcomes = []
    for rule in _REGISTERED_RULES:
        try:
            outcomes.append(rule(row, bundle))
        except Exception as exc:  # rule-level isolation
            outcomes.append({
                "rule_id": getattr(rule, "__name__", "unknown_rule"),
                "outcome": "honest_unknown",
                "verdict_signal": "none",
                "confidence": "low",
                "reason": f"rule_evaluation_error: {exc!r}",
                "citations": [],
            })
    verdict, confidence, honest_reason = _aggregate_verdict(outcomes)
    return {
        "status": "evaluated",
        "verdict": verdict,
        "confidence": confidence,
        "rules_evaluated": len(outcomes),
        "rules_matched": sum(1 for o in outcomes if o.get("outcome") == "matched"),
        "rules_inapplicable": sum(1 for o in outcomes if o.get("outcome") == "inapplicable"),
        "rules_honest_unknown": sum(1 for o in outcomes if o.get("outcome") == "honest_unknown"),
        "rule_outcomes": outcomes,
        "honest_unknown_reason": honest_reason,
    }
