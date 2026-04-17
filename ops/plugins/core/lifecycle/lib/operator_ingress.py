"""operator_ingress — bounded non-authoritative operator vision intake lifecycle.

Writes raw operator-originated ingress objects into the existing runtime inputs
lane and supports lifecycle transitions (classification + routing) without
inventing new homes or authority surfaces.

Directional boundary:
  - this lane is Ronny/operator -> agents/system only
  - agents must not write return traffic back into operator ingress
  - return traffic belongs to existing handoff, attention, and receipt surfaces

Write target:
  $SPINE_STATE/inputs/operator-ingress/OI-*.yaml

This is a narrow governed write:
  - preserves raw content and provenance
  - does not mutate authority surfaces
  - does not create packets or tasks
  - classification/routing reuses existing operator-vision vocabulary
"""

from __future__ import annotations

import os
import secrets
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


ALLOWED_CONTENT_TYPES = {
    "note",
    "conversation",
    "url",
    "voice_transcript",
}

# Lifecycle states: submitted → classified → routed
# These are the only legal forward transitions.
LIFECYCLE_STATES = ("submitted", "classified", "routed")

# Dispositions reuse existing operator-vision vocabulary from the forensic floor
# and Packet 35 ingress model contract. No new public taxonomy.
ALLOWED_DISPOSITIONS = {
    "awaiting_classification",  # birth state
    "attached",                 # linked to existing loop/packet/design track
    "deferred",                 # parked with review trigger
    "packet_candidate",         # recommended for packetization, needs approval
    "no_op_preserved",          # valuable context, no action needed
}

# Classification categories reuse the existing operator-vision route vocabulary
# from BINDING-OPERATOR-VISION-*.md and forensic floor traces.
ALLOWED_CLASSIFICATIONS = {
    "bind_to_existing_seam",
    "staged_only_runtime_input",
    "adjacent_evidence",
    "bind_adjacent_to_existing_seam",
    "out_of_spine",
    "direct_command",
    "review_request",
}


class OperatorIngressError(Exception):
    """Raised for validation or write failures."""


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _iso_utc(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def _ingress_dir(state_root: str) -> Path:
    return Path(state_root) / "inputs" / "operator-ingress"


def _derive_ingress_id(now: datetime | None = None) -> str:
    now = now or _utcnow()
    return f"OI-{now.strftime('%Y%m%d-%H%M%S')}-{secrets.token_hex(2)}"


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    try:
        tmp.write_text(content, encoding="utf-8")
        os.replace(tmp, path)
    except OSError as exc:
        try:
            if tmp.exists():
                tmp.unlink()
        except OSError:
            pass
        raise OperatorIngressError(f"filesystem write failed: {exc}") from exc


def _validate_inputs(raw_content: str, content_type: str, state_root: str) -> None:
    if not state_root or not os.path.isdir(state_root):
        raise OperatorIngressError(f"state_root not found: {state_root}")
    if content_type not in ALLOWED_CONTENT_TYPES:
        allowed = ", ".join(sorted(ALLOWED_CONTENT_TYPES))
        raise OperatorIngressError(
            f"content_type invalid: '{content_type}' (allowed: {allowed})"
        )
    if not isinstance(raw_content, str) or not raw_content.strip():
        raise OperatorIngressError("raw_content is required")


def create_operator_ingress(
    *,
    state_root: str,
    raw_content: str,
    content_type: str,
    operator_hint: str = "",
    operator_id: str = "ronny",
    source_device: str = "phone",
    source_app: str = "browser",
    access_identity: str = "",
    source_ip: str = "",
    submitted_via: str = "operator_surface_submit",
) -> dict[str, Any]:
    """Create a non-authoritative operator ingress object.

    Returns a result dict with ingress_id, path, lifecycle_state, and
    disposition.

    This is a one-way operator submission object, not a bidirectional mailbox.
    """
    _validate_inputs(raw_content, content_type, state_root)

    now = _utcnow()
    ingress_id = _derive_ingress_id(now)
    target = _ingress_dir(state_root) / f"{ingress_id}.yaml"
    if target.exists():
        raise OperatorIngressError(f"derived ingress path already exists: {target}")

    doc: dict[str, Any] = {
        "kind": "operator_ingress",
        "authority": "non_authoritative",
        "mutation_permitted": False,
        "ingress_id": ingress_id,
        "operator_id": operator_id,
        "submitted_at": _iso_utc(now),
        "source_device": source_device,
        "source_app": source_app,
        "submitted_via": submitted_via,
        "content_type": content_type,
        "operator_hint": operator_hint.strip(),
        "lifecycle_state": "submitted",
        "disposition": "awaiting_classification",
        "disposition_detail": "Raw input preserved; awaiting membrane classification.",
        "authority_level": "none",
        "raw_content": raw_content,
    }
    if access_identity:
        doc["access_identity"] = access_identity
    if source_ip:
        doc["source_ip"] = source_ip

    content = yaml.safe_dump(
        doc,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
    )
    _atomic_write(target, content)

    return {
        "status": "ok",
        "ingress_id": ingress_id,
        "path": str(target),
        "lifecycle_state": doc["lifecycle_state"],
        "disposition": doc["disposition"],
        "disposition_detail": doc["disposition_detail"],
        "submitted_at": doc["submitted_at"],
        "content_type": content_type,
        "operator_hint": doc["operator_hint"],
    }


def list_operator_ingress(
    *,
    state_root: str,
    limit: int = 20,
) -> dict[str, Any]:
    """List recent operator ingress objects."""
    ingress_dir = _ingress_dir(state_root)
    if not ingress_dir.is_dir():
        return {"count": 0, "items": []}

    items: list[dict[str, Any]] = []
    for path in sorted(ingress_dir.glob("OI-*.yaml"), reverse=True):
        try:
            doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(doc, dict):
            continue
        item: dict[str, Any] = {
            "ingress_id": str(doc.get("ingress_id", "")),
            "submitted_at": str(doc.get("submitted_at", "")),
            "content_type": str(doc.get("content_type", "")),
            "operator_hint": str(doc.get("operator_hint", "")),
            "lifecycle_state": str(doc.get("lifecycle_state", "submitted")),
            "disposition": str(doc.get("disposition", "awaiting_classification")),
            "disposition_detail": str(
                doc.get(
                    "disposition_detail",
                    "Raw input preserved; awaiting membrane classification.",
                )
            ),
            "source_device": str(doc.get("source_device", "")),
            "source_app": str(doc.get("source_app", "")),
            "path": str(path),
        }
        # Include metabolization fields when present
        if "classification" in doc:
            item["classification"] = str(doc["classification"])
        if "next_stage" in doc:
            item["next_stage"] = str(doc["next_stage"])
        if "downstream_refs" in doc:
            item["downstream_refs"] = doc["downstream_refs"]
        if "activation_conditions" in doc:
            item["activation_conditions"] = str(doc["activation_conditions"])
        if "classified_at" in doc:
            item["classified_at"] = str(doc["classified_at"])
        if "routed_at" in doc:
            item["routed_at"] = str(doc["routed_at"])
        items.append(item)
        if len(items) >= limit:
            break

    return {
        "count": len(items),
        "items": items,
    }


def _find_ingress_file(state_root: str, ingress_id: str) -> Path:
    """Resolve an ingress object by ID, constrained to the ingress directory.

    Only files inside $SPINE_STATE/inputs/operator-ingress/ matching OI-*.yaml
    are valid targets. Arbitrary paths are rejected.
    """
    ingress_dir = _ingress_dir(state_root)
    # Strip .yaml suffix if caller included it
    bare_id = ingress_id.removesuffix(".yaml")
    # Only accept bare OI-* identifiers, not arbitrary paths or names
    if os.sep in bare_id or "/" in bare_id:
        raise OperatorIngressError(
            f"ingress_id must be a bare OI identifier, not a path: {ingress_id}"
        )
    if not bare_id.startswith("OI-"):
        raise OperatorIngressError(
            f"ingress_id must start with 'OI-': {ingress_id}"
        )
    candidate = ingress_dir / f"{bare_id}.yaml"
    # Resolve and verify the file is actually inside the ingress directory
    try:
        resolved = candidate.resolve(strict=False)
        expected_parent = ingress_dir.resolve(strict=False)
    except (OSError, ValueError) as exc:
        raise OperatorIngressError(f"path resolution failed: {exc}") from exc
    if not str(resolved).startswith(str(expected_parent) + os.sep):
        raise OperatorIngressError(
            f"resolved path escapes ingress directory: {resolved}"
        )
    if not resolved.is_file():
        raise OperatorIngressError(f"ingress object not found: {ingress_id}")
    return resolved


def metabolize_operator_ingress(
    *,
    state_root: str,
    ingress_id: str,
    classification: str,
    disposition: str,
    disposition_detail: str,
    next_stage: str = "",
    downstream_refs: list[str] | None = None,
    activation_conditions: str = "",
    likely_domains: list[str] | None = None,
) -> dict[str, Any]:
    """Classify and route an existing operator ingress object.

    Moves the object from submitted → classified → routed depending on
    the fields provided. Preserves raw content exactly. Does not create
    packets, promote authority, or mutate anything outside the OI-*.yaml.

    Returns a result dict with the updated lifecycle state.
    """
    if not state_root or not os.path.isdir(state_root):
        raise OperatorIngressError(f"state_root not found: {state_root}")
    if classification not in ALLOWED_CLASSIFICATIONS:
        allowed = ", ".join(sorted(ALLOWED_CLASSIFICATIONS))
        raise OperatorIngressError(
            f"classification invalid: '{classification}' (allowed: {allowed})"
        )
    if disposition not in ALLOWED_DISPOSITIONS:
        allowed = ", ".join(sorted(ALLOWED_DISPOSITIONS))
        raise OperatorIngressError(
            f"disposition invalid: '{disposition}' (allowed: {allowed})"
        )
    # Route-bearing dispositions require route data
    _ROUTED_DISPOSITIONS = {"attached", "packet_candidate"}
    has_route = bool(next_stage or downstream_refs)
    if disposition in _ROUTED_DISPOSITIONS and not has_route:
        raise OperatorIngressError(
            f"disposition '{disposition}' requires --next-stage or --downstream-refs"
        )

    path = _find_ingress_file(state_root, ingress_id)
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise OperatorIngressError(f"failed to read ingress object: {exc}") from exc
    if not isinstance(doc, dict):
        raise OperatorIngressError(f"ingress object is not a valid YAML dict: {path}")

    now = _utcnow()

    # Set classification fields
    doc["classification"] = classification
    doc["classified_at"] = _iso_utc(now)
    doc["disposition"] = disposition
    doc["disposition_detail"] = disposition_detail

    if likely_domains:
        doc["likely_domains"] = likely_domains

    # Determine lifecycle state and clean stale fields
    if next_stage or downstream_refs:
        doc["lifecycle_state"] = "routed"
        doc["routed_at"] = _iso_utc(now)
        if next_stage:
            doc["next_stage"] = next_stage
        else:
            doc.pop("next_stage", None)
        if downstream_refs:
            doc["downstream_refs"] = downstream_refs
        else:
            doc.pop("downstream_refs", None)
    else:
        doc["lifecycle_state"] = "classified"
        # Clear stale route fields from any prior routed state
        doc.pop("routed_at", None)
        doc.pop("next_stage", None)
        doc.pop("downstream_refs", None)

    if activation_conditions:
        doc["activation_conditions"] = activation_conditions
    else:
        doc.pop("activation_conditions", None)

    # Preserve authority posture
    doc["authority"] = "non_authoritative"
    doc["authority_level"] = "none"

    content = yaml.safe_dump(
        doc,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
    )
    _atomic_write(path, content)

    return {
        "status": "ok",
        "ingress_id": str(doc.get("ingress_id", path.stem)),
        "path": str(path),
        "lifecycle_state": doc["lifecycle_state"],
        "classification": classification,
        "disposition": disposition,
        "disposition_detail": disposition_detail,
        "next_stage": next_stage,
        "downstream_refs": downstream_refs or [],
        "activation_conditions": activation_conditions,
        "metabolized_at": doc.get("classified_at", ""),
    }
