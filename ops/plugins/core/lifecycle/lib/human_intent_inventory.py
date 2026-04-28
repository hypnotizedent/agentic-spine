"""Generated human-intent inventory/readback.

This module is a read model only. It aggregates existing OI/HI records,
blueprint admission, evidence reviews, and contract drains without promoting
any source material or creating a new authority home.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

import yaml


DEFAULT_EXTRA_ROOTS = (
    Path("/Users/ronnyworks/Desktop/Archive"),
    Path("/Users/ronnyworks/Documents/4.16 drop"),
    Path("/Users/ronnyworks/Documents/pre 3.25 notes"),
    Path("/Users/ronnyworks/Documents/spine notes 4.13.2026"),
)


def _load_yaml(path: Path) -> dict[str, Any]:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8", errors="replace"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _iter_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    if root.is_file():
        return [root]
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file() and path.name != ".DS_Store"
    )


def _row(
    *,
    source_id: str,
    source_kind: str,
    source_ref: str,
    title_or_hint: str = "",
    human_intent_id: str = "",
    capture_status: str = "captured",
    review_status: str = "reviewed",
    carrier_kind: str = "none",
    carrier_ref: str = "",
    proof_ref: str = "",
    next_missing_step: str = "",
    operator_visible_summary: str = "",
) -> dict[str, Any]:
    return {
        "source_id": source_id,
        "source_kind": source_kind,
        "source_ref": source_ref,
        "human_intent_id": human_intent_id,
        "title_or_hint": title_or_hint,
        "capture_status": capture_status,
        "review_status": review_status,
        "carrier_kind": carrier_kind,
        "carrier_ref": carrier_ref,
        "proof_ref": proof_ref,
        "next_missing_step": next_missing_step,
        "operator_visible_summary": operator_visible_summary,
    }


def _index_known_files(state_root: Path, evidence_root: Path) -> dict[str, list[str]]:
    index: dict[str, list[str]] = {}
    roots = [
        state_root / "inputs",
        evidence_root / "intake",
    ]
    for root in roots:
        for path in _iter_files(root):
            try:
                digest = _sha256(path)
            except OSError:
                continue
            index.setdefault(digest, []).append(str(path))
    return index


def _collect_oi_rows(state_root: Path, limit: int | None = None) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    ingress_dir = state_root / "inputs" / "operator-ingress"
    paths = sorted(ingress_dir.glob("OI-*.yaml"), reverse=True) if ingress_dir.is_dir() else []
    if limit is not None:
        paths = paths[:limit]
    for path in paths:
        doc = _load_yaml(path)
        if not doc:
            continue
        intent = doc.get("human_intent") if isinstance(doc.get("human_intent"), dict) else {}
        downstream = doc.get("downstream_refs") if isinstance(doc.get("downstream_refs"), list) else []
        carrier_ref = str(doc.get("next_stage") or (downstream[0] if downstream else ""))
        lifecycle = str(doc.get("lifecycle_state") or "submitted")
        disposition = str(doc.get("disposition") or "")
        review_status = lifecycle
        if str(doc.get("human_intent_status") or ""):
            review_status = str(doc.get("human_intent_status"))
        elif disposition in {"deferred", "no_op_preserved"}:
            review_status = "shelved" if disposition == "deferred" else "reference_only"
        rows.append(
            _row(
                source_id=str(doc.get("ingress_id") or path.stem),
                source_kind="operator_ingress",
                source_ref=str(path),
                human_intent_id=str(intent.get("intent_id") or ""),
                title_or_hint=str(doc.get("operator_hint") or intent.get("statement") or ""),
                capture_status="captured",
                review_status=review_status,
                carrier_kind="loop" if carrier_ref.startswith("LOOP-") else ("packet" if carrier_ref.startswith("PACKET-") else ("runtime_route" if carrier_ref else "none")),
                carrier_ref=carrier_ref,
                proof_ref=str(
                    (((doc.get("intent_chain_readback") or {}).get("proof_receipt") or {}).get("ref"))
                    if isinstance(doc.get("intent_chain_readback"), dict)
                    else ""
                ),
                next_missing_step=str(
                    (doc.get("intent_chain_readback") or {}).get("next_missing_seam", "")
                    if isinstance(doc.get("intent_chain_readback"), dict)
                    else ""
                ),
                operator_visible_summary=str(doc.get("disposition_detail") or ""),
            )
        )
    return rows


def _collect_blueprint_rows(repo: Path) -> list[dict[str, Any]]:
    matrix = repo / "ops" / "bindings" / "operator.blueprint.admission.yaml"
    data = _load_yaml(matrix)
    rows: list[dict[str, Any]] = []
    for entry in data.get("entries", []) if isinstance(data.get("entries"), list) else []:
        if not isinstance(entry, dict):
            continue
        materialization = entry.get("materialization_target")
        carrier_kind = "shelf"
        carrier_ref = ""
        proof_ref = ""
        if isinstance(materialization, dict):
            carrier_kind = "binding"
            carrier_ref = str(materialization.get("authority") or "")
            proof_ref = str(materialization.get("proof") or "")
        elif entry.get("decision") == "reference_only":
            carrier_kind = "reference"
        rows.append(
            _row(
                source_id=str(entry.get("id") or ""),
                source_kind="blueprint_admission",
                source_ref=str(entry.get("source_ref") or ""),
                title_or_hint=str(entry.get("title") or ""),
                capture_status="captured",
                review_status=str(entry.get("status") or entry.get("decision") or ""),
                carrier_kind=carrier_kind,
                carrier_ref=carrier_ref,
                proof_ref=proof_ref,
                next_missing_step=str(entry.get("shelf_trigger") or entry.get("materialization_gap") or ""),
                operator_visible_summary=str(entry.get("summary") or ""),
            )
        )
    return rows


def _collect_review_rows(evidence_root: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for meta in sorted((evidence_root / "reviews").glob("*/review-meta.yaml")):
        doc = _load_yaml(meta)
        if not doc:
            continue
        summary = doc.get("claim_summary") if isinstance(doc.get("claim_summary"), dict) else {}
        bits = ", ".join(f"{k}={v}" for k, v in summary.items())
        downstream = doc.get("downstream_refs") if isinstance(doc.get("downstream_refs"), list) else []
        rows.append(
            _row(
                source_id=str(doc.get("review_id") or meta.parent.name),
                source_kind="evidence_review",
                source_ref=str(doc.get("bundle_path") or meta.parent),
                title_or_hint=str(doc.get("bundle_slug") or meta.parent.name),
                capture_status="captured",
                review_status="reviewed",
                carrier_kind="loop" if downstream and str(downstream[0]).startswith("LOOP-") else ("review" if not downstream else "reference"),
                carrier_ref=str(downstream[0]) if downstream else str(doc.get("report_path") or meta),
                proof_ref=str(doc.get("report_path") or meta),
                next_missing_step="none",
                operator_visible_summary=f"{doc.get('bundle_file_count', '?')} files; {bits}",
            )
        )
    return rows


def _find_drains(data: Any, source_path: Path) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(data, dict):
        drains = data.get("operator_blueprint_drains")
        if isinstance(drains, list):
            for drain in drains:
                if isinstance(drain, dict):
                    item = dict(drain)
                    item["_authority_path"] = str(source_path)
                    found.append(item)
        for value in data.values():
            found.extend(_find_drains(value, source_path))
    elif isinstance(data, list):
        for value in data:
            found.extend(_find_drains(value, source_path))
    return found


def _collect_drain_rows(repo: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in sorted((repo / "ops" / "bindings").rglob("*.yaml")):
        doc = _load_yaml(path)
        for drain in _find_drains(doc, path):
            rows.append(
                _row(
                    source_id=str(drain.get("drain_id") or f"drain:{path.name}"),
                    source_kind="contract_drain",
                    source_ref=str(drain.get("source_ref") or ""),
                    title_or_hint=str(drain.get("drain_id") or ""),
                    capture_status="source_linked" if drain.get("source_ref") else "semantic_only",
                    review_status=str(drain.get("status") or "drained"),
                    carrier_kind="contract",
                    carrier_ref=str(drain.get("_authority_path") or path),
                    proof_ref=str(drain.get("_authority_path") or path),
                    next_missing_step="none",
                    operator_visible_summary=str(drain.get("summary") or ""),
                )
            )
    return rows


def _collect_path_rows(
    *,
    extra_roots: list[Path],
    known_hashes: dict[str, list[str]],
    existing_source_refs: set[str],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for root in extra_roots:
        for path in _iter_files(root):
            try:
                digest = _sha256(path)
            except OSError:
                continue
            matches = [m for m in known_hashes.get(digest, []) if m != str(path)]
            source_ref_known = str(path) in existing_source_refs
            if matches:
                capture_status = "captured"
                review_status = "duplicate_captured"
                carrier_kind = "source"
                carrier_ref = matches[0]
                next_missing = "none"
            elif source_ref_known:
                capture_status = "source_linked"
                review_status = "drained_or_referenced"
                carrier_kind = "source_ref"
                carrier_ref = str(path)
                next_missing = "none"
            else:
                capture_status = "semantic_only"
                review_status = "source_not_linked"
                carrier_kind = "none"
                carrier_ref = ""
                next_missing = "create admission/review/drain link or mark out_of_scope"
            rows.append(
                _row(
                    source_id=f"path:{path}",
                    source_kind="path_drop_source",
                    source_ref=str(path),
                    title_or_hint=path.name,
                    capture_status=capture_status,
                    review_status=review_status,
                    carrier_kind=carrier_kind,
                    carrier_ref=carrier_ref,
                    proof_ref=carrier_ref if matches or source_ref_known else "",
                    next_missing_step=next_missing,
                    operator_visible_summary=f"sha256={digest[:16]} matches={len(matches)}",
                )
            )
    return rows


def build_inventory(
    *,
    repo: Path,
    state_root: Path,
    evidence_root: Path,
    extra_roots: list[Path] | None = None,
    oi_limit: int | None = None,
) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    rows.extend(_collect_oi_rows(state_root, limit=oi_limit))
    rows.extend(_collect_blueprint_rows(repo))
    rows.extend(_collect_review_rows(evidence_root))
    rows.extend(_collect_drain_rows(repo))

    known_hashes = _index_known_files(state_root, evidence_root)
    existing_refs = {str(row.get("source_ref") or "") for row in rows}
    path_rows = _collect_path_rows(
        extra_roots=extra_roots if extra_roots is not None else [p for p in DEFAULT_EXTRA_ROOTS if p.exists()],
        known_hashes=known_hashes,
        existing_source_refs=existing_refs,
    )
    rows.extend(path_rows)

    by_capture: dict[str, int] = {}
    by_review: dict[str, int] = {}
    by_kind: dict[str, int] = {}
    for row in rows:
        by_capture[row["capture_status"]] = by_capture.get(row["capture_status"], 0) + 1
        by_review[row["review_status"]] = by_review.get(row["review_status"], 0) + 1
        by_kind[row["source_kind"]] = by_kind.get(row["source_kind"], 0) + 1

    return {
        "version": 1,
        "authority": "generated_read_model",
        "mutation_permitted": False,
        "sources": {
            "operator_ingress": str(state_root / "inputs" / "operator-ingress"),
            "blueprint_admission": str(repo / "ops" / "bindings" / "operator.blueprint.admission.yaml"),
            "evidence_reviews": str(evidence_root / "reviews"),
            "contract_drains": str(repo / "ops" / "bindings"),
            "path_drop_roots": [str(p) for p in (extra_roots if extra_roots is not None else DEFAULT_EXTRA_ROOTS) if p.exists()],
        },
        "summary": {
            "total_rows": len(rows),
            "by_source_kind": by_kind,
            "by_capture_status": by_capture,
            "by_review_status": by_review,
            "source_not_linked": sum(1 for r in rows if r["review_status"] == "source_not_linked"),
            "semantic_only": sum(1 for r in rows if r["capture_status"] == "semantic_only"),
        },
        "items": rows,
    }

