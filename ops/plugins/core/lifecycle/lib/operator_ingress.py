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

import copy
import json
import os
import re
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

TRANSLATOR_CONCERN_CLASSES = {
    "platform_architecture_or_governance",
    "platform_workload",
    "domain_workload",
    "external_membrane_or_operator_rail",
}

PENDING_LIFECYCLE_STATES = {
    "submitted",
    "preserved",
}

_LOOP_REF_RE = re.compile(r"\bLOOP-[A-Z0-9-]+\b")
_PACKET_REF_RE = re.compile(r"\bPACKET-[A-Z0-9-]+\b")
_GAP_REF_RE = re.compile(r"\bGAP-[A-Z0-9-]+\b")
_CAPABILITY_REF_RE = re.compile(r"\b[a-z][a-z0-9_]*(?:\.[a-z0-9_]+){1,5}\b")
_URL_RE = re.compile(r"https?://\S+", re.IGNORECASE)
_REVIEW_PREFIX_RE = re.compile(
    r"^\s*(please\s+)?(review|audit|verify|reconcile|inspect|assess|check|explain|status)\b",
    re.IGNORECASE,
)
_DIRECT_COMMAND_PREFIX_RE = re.compile(
    r"^\s*(please\s+)?(resume|create|fix|implement|open|close|route|dispatch|attach|submit|update|run|stop|start|build|write|promote|widen)\b",
    re.IGNORECASE,
)

_PLATFORM_KEYWORDS = (
    "spine",
    "governance",
    "aperture",
    "contract",
    "binding",
    "loop",
    "packet",
    "wave",
    "verify",
    "gate",
    "translator",
    "operator ingress",
    "control plane",
    "controller",
    "runtime",
    "authority",
    "receipt",
    "closeout",
)
_REVIEW_KEYWORDS = (
    "review",
    "audit",
    "verify",
    "reconcile",
    "inspect",
    "assess",
    "status",
    "readback",
    "explain",
    "check",
)
_ADJACENT_EVIDENCE_KEYWORDS = (
    "adjacent evidence",
    "supporting context",
    "supporting evidence",
    "background context",
    "sharpen",
    "context only",
)
_OUT_OF_SPINE_KEYWORDS = (
    "out of spine",
    "outside the spine",
    "not for spine",
    "external only",
)
_DOMAIN_KEYWORDS: dict[str, tuple[str, ...]] = {
    "communications": ("communications", "email", "mailbox", "smtp", "alerts", "stalwart"),
    "finance": ("finance", "simplefin", "firefly", "paperless", "transactions"),
    "homeassistant": ("home assistant", "homeassistant", "zigbee", "z2m"),
    "immich": ("immich", "photos", "ingest watch"),
    "infra": ("proxmox", "tailscale", "cloudflare", "docker", "vm", "ssh", "backup", "recovery"),
    "media": ("media", "plex", "sonarr", "radarr", "lidarr"),
    "mint": ("mint", "shopify", "order", "prints"),
    "stewardship": ("stewardship", "operator posture", "operator surfaces"),
}


class OperatorIngressError(Exception):
    """Raised for validation or write failures."""


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _iso_utc(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def _ingress_dir(state_root: str) -> Path:
    return Path(state_root) / "inputs" / "operator-ingress"


def _auto_metabolizer_runtime_paths(state_root: str) -> dict[str, Path]:
    ingress_dir = _ingress_dir(state_root)
    return {
        "pid": ingress_dir / ".auto-metabolizer.pid",
        "heartbeat": ingress_dir / ".auto-metabolizer-heartbeat.json",
    }


def _ingress_lifecycle_journal_path(state_root: str) -> Path:
    return _ingress_dir(state_root) / "lifecycle.ndjson"


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


def _append_ingress_lifecycle_event(
    *,
    state_root: str,
    event: str,
    ingress_id: str,
    path: Path,
    before: dict[str, Any] | None = None,
    after: dict[str, Any] | None = None,
) -> str:
    journal_path = _ingress_lifecycle_journal_path(state_root)
    journal_path.parent.mkdir(parents=True, exist_ok=True)

    payload: dict[str, Any] = {
        "recorded_at": _iso_utc(_utcnow()),
        "event": event,
        "ingress_id": ingress_id,
        "path": str(path),
    }
    if before is not None:
        payload["before"] = before
    if after is not None:
        payload["after"] = after

    line = json.dumps(payload, ensure_ascii=False, sort_keys=False) + "\n"
    try:
        with journal_path.open("a", encoding="utf-8") as handle:
            handle.write(line)
    except OSError as exc:
        raise OperatorIngressError(f"lifecycle journal write failed: {exc}") from exc

    return str(journal_path)


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
    journal_path = _append_ingress_lifecycle_event(
        state_root=state_root,
        event="submitted",
        ingress_id=ingress_id,
        path=target,
        after=copy.deepcopy(doc),
    )

    return {
        "status": "ok",
        "ingress_id": ingress_id,
        "path": str(target),
        "journal_path": journal_path,
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
        translator_workload = doc.get("translator_workload")
        if isinstance(translator_workload, dict):
            w1 = translator_workload.get("W1")
            if isinstance(w1, dict):
                if "concern_class" in w1:
                    item["concern_class"] = str(w1["concern_class"])
                if "confidence" in w1:
                    item["confidence"] = w1["confidence"]
            w2 = translator_workload.get("W2")
            if isinstance(w2, dict) and "routing_target" in w2:
                item["routing_target"] = str(w2["routing_target"])
            w3 = translator_workload.get("W3")
            if isinstance(w3, dict) and "execution_dispatched" in w3:
                item["execution_dispatched"] = bool(w3["execution_dispatched"])
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


def _unique_preserve_order(values: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for value in values:
        cleaned = str(value).strip()
        if not cleaned or cleaned in seen:
            continue
        seen.add(cleaned)
        out.append(cleaned)
    return out


def _token_hits(text: str, keywords: tuple[str, ...]) -> bool:
    return any(keyword in text for keyword in keywords)


def _infer_likely_domains(text: str) -> list[str]:
    matches: list[str] = []
    for domain_id, keywords in _DOMAIN_KEYWORDS.items():
        if _token_hits(text, keywords):
            matches.append(domain_id)
    if _token_hits(text, _PLATFORM_KEYWORDS) and "spine" not in matches:
        matches.append("spine")
    return matches


def _extract_refs(text: str) -> dict[str, list[str]]:
    capabilities = []
    for match in _CAPABILITY_REF_RE.findall(text):
        if match.startswith("http.") or match.startswith("https."):
            continue
        if match.endswith(".com") or match.endswith(".works"):
            continue
        capabilities.append(match)
    return {
        "loops": _unique_preserve_order(_LOOP_REF_RE.findall(text)),
        "packets": _unique_preserve_order(_PACKET_REF_RE.findall(text)),
        "gaps": _unique_preserve_order(_GAP_REF_RE.findall(text)),
        "capabilities": _unique_preserve_order(capabilities),
        "urls": _unique_preserve_order(_URL_RE.findall(text)),
    }


def _looks_like_review_request(text: str) -> bool:
    if _token_hits(text, _REVIEW_KEYWORDS):
        return True
    return any(_REVIEW_PREFIX_RE.search(line) for line in text.splitlines() if line.strip())


def _looks_like_direct_command(text: str) -> bool:
    if any(_DIRECT_COMMAND_PREFIX_RE.search(line) for line in text.splitlines() if line.strip()):
        return True
    return any(
        marker in text
        for marker in (
            "explicit command",
            "need two outputs",
            "please ",
            "execute this",
            "make sure",
            "route this",
            "attach this",
        )
    )


def _classify_auto_route(
    *,
    text: str,
    refs: dict[str, list[str]],
    likely_domains: list[str],
) -> str:
    if _token_hits(text, _OUT_OF_SPINE_KEYWORDS):
        return "out_of_spine"
    if refs["urls"] and not likely_domains and not _token_hits(text, _PLATFORM_KEYWORDS):
        return "out_of_spine"
    if refs["loops"] or refs["packets"] or refs["gaps"]:
        if _token_hits(text, _ADJACENT_EVIDENCE_KEYWORDS):
            return "adjacent_evidence"
        return "bind_to_existing_seam"
    if _looks_like_review_request(text):
        return "review_request"
    if _looks_like_direct_command(text):
        return "direct_command"
    if likely_domains and any(domain != "spine" for domain in likely_domains):
        if _token_hits(text, _ADJACENT_EVIDENCE_KEYWORDS):
            return "adjacent_evidence"
        return "bind_adjacent_to_existing_seam"
    if _token_hits(text, _ADJACENT_EVIDENCE_KEYWORDS):
        return "adjacent_evidence"
    return "staged_only_runtime_input"


def _infer_concern_class(
    *,
    classification: str,
    likely_domains: list[str],
    refs: dict[str, list[str]],
    text: str,
) -> str:
    if classification == "out_of_spine":
        return "external_membrane_or_operator_rail"
    if likely_domains and any(domain != "spine" for domain in likely_domains):
        return "domain_workload"
    if classification in {"bind_to_existing_seam", "adjacent_evidence"}:
        return "platform_architecture_or_governance"
    if classification == "staged_only_runtime_input" and not refs["loops"] and not refs["packets"]:
        if not _token_hits(text, _PLATFORM_KEYWORDS):
            return "external_membrane_or_operator_rail"
    if classification in {"direct_command", "review_request"}:
        if _token_hits(text, _PLATFORM_KEYWORDS):
            return "platform_architecture_or_governance"
        return "platform_workload"
    return "platform_workload"


def _confidence_for_classification(
    *,
    classification: str,
    refs: dict[str, list[str]],
    likely_domains: list[str],
    text: str,
) -> float:
    score = 0.58
    if refs["loops"] or refs["packets"] or refs["gaps"]:
        score += 0.26
    if likely_domains:
        score += 0.12
    if classification in {"review_request", "direct_command"}:
        score += 0.1
    if _token_hits(text, _PLATFORM_KEYWORDS):
        score += 0.08
    return round(min(score, 0.97), 2)


def _routing_target_for_plan(
    *,
    classification: str,
    concern_class: str,
    likely_domains: list[str],
    refs: dict[str, list[str]],
) -> str:
    if refs["loops"]:
        return refs["loops"][0]
    if refs["packets"]:
        return refs["packets"][0]
    if classification == "review_request":
        if concern_class == "domain_workload" and likely_domains:
            return f"domain_agent:{likely_domains[0]}:review"
        return "control_plane.review"
    if concern_class == "domain_workload" and likely_domains:
        return f"domain_agent:{likely_domains[0]}"
    if concern_class == "external_membrane_or_operator_rail":
        return "runtime_parking"
    return "control_plane"


def _suggested_capability_id(
    *,
    classification: str,
    concern_class: str,
    text: str,
) -> str:
    if classification == "review_request":
        if "verify" in text or "gate" in text or "honesty" in text:
            return "spine.verify"
        if "status" in text or "what is running" in text:
            return "spine.status"
        return "surface.operator.overview.payload"
    if classification == "direct_command":
        if concern_class == "platform_architecture_or_governance":
            return "controller_prompt.create"
        if concern_class == "platform_workload":
            return "mailroom.task.enqueue"
    if classification in {"bind_adjacent_to_existing_seam", "staged_only_runtime_input"}:
        return "bundle.review"
    return ""


def _build_auto_metabolize_plan(doc: dict[str, Any]) -> dict[str, Any]:
    ingress_id = str(doc.get("ingress_id", "")).strip()
    operator_hint = str(doc.get("operator_hint", "")).strip()
    raw_content = str(doc.get("raw_content", "")).strip()
    content_type = str(doc.get("content_type", "")).strip()
    text = "\n".join(part for part in (operator_hint, raw_content, content_type) if part).lower()

    refs = _extract_refs(f"{operator_hint}\n{raw_content}")
    likely_domains = _infer_likely_domains(text)
    classification = _classify_auto_route(text=text, refs=refs, likely_domains=likely_domains)
    concern_class = _infer_concern_class(
        classification=classification,
        likely_domains=likely_domains,
        refs=refs,
        text=text,
    )
    confidence = _confidence_for_classification(
        classification=classification,
        refs=refs,
        likely_domains=likely_domains,
        text=text,
    )
    routing_target = _routing_target_for_plan(
        classification=classification,
        concern_class=concern_class,
        likely_domains=likely_domains,
        refs=refs,
    )
    suggested_capability_id = _suggested_capability_id(
        classification=classification,
        concern_class=concern_class,
        text=text,
    )
    downstream_refs = _unique_preserve_order(
        refs["packets"] + refs["gaps"] + refs["capabilities"]
    )
    next_stage = ""
    activation_conditions = ""

    if classification == "bind_to_existing_seam":
        disposition = "attached"
        next_stage = routing_target
        disposition_detail = f"Auto-metabolized against existing seam {next_stage}."
    elif classification == "adjacent_evidence":
        disposition = "attached"
        next_stage = routing_target
        disposition_detail = (
            f"Auto-metabolized as adjacent evidence for {next_stage}."
        )
    elif classification == "bind_adjacent_to_existing_seam":
        disposition = "deferred"
        activation_conditions = (
            "Attach when the adjacent seam is explicitly reopened or named."
        )
        disposition_detail = (
            "Auto-metabolized as adjacent seam pressure; deferred pending a named seam."
        )
    elif classification == "staged_only_runtime_input":
        disposition = "deferred"
        activation_conditions = operator_hint or "Await explicit seam naming or operator promotion."
        disposition_detail = "Auto-metabolized into runtime parking without a current seam."
    elif classification == "out_of_spine":
        disposition = "no_op_preserved"
        disposition_detail = "Auto-metabolized as out-of-spine material; preserved without routing."
    elif classification == "review_request":
        disposition = "packet_candidate"
        next_stage = routing_target
        disposition_detail = "Auto-metabolized as a bounded review request candidate."
    else:
        disposition = "packet_candidate"
        next_stage = routing_target
        disposition_detail = "Auto-metabolized as an explicit command candidate without execution."

    envelope_payload = {
        "ingress_id": ingress_id,
        "operator_hint": operator_hint,
        "content_type": content_type,
        "classification": classification,
        "disposition": disposition,
        "likely_domains": likely_domains,
        "explicit_refs": {
            "loops": refs["loops"],
            "packets": refs["packets"],
            "gaps": refs["gaps"],
            "capabilities": refs["capabilities"],
        },
    }
    if next_stage:
        envelope_payload["next_stage"] = next_stage
    if activation_conditions:
        envelope_payload["activation_conditions"] = activation_conditions

    translator_workload = {
        "implementation": "operator.ingress.auto_metabolizer",
        "captured_at": _iso_utc(_utcnow()),
        "W1": {
            "request_id": ingress_id,
            "concern_class": concern_class,
            "confidence": confidence,
        },
        "W2": {
            "request_id": ingress_id,
            "concern_class": concern_class,
            "routing_target": routing_target,
            "extracted_params": {
                "classification": classification,
                "disposition": disposition,
                "likely_domains": likely_domains,
                "next_stage": next_stage,
                "downstream_refs": downstream_refs,
                "activation_conditions": activation_conditions,
            },
        },
        "W3": {
            "request_id": ingress_id,
            "routing_target": routing_target,
            "suggested_capability_id": suggested_capability_id,
            "envelope_payload": envelope_payload,
            "execution_dispatched": False,
        },
    }

    return {
        "classification": classification,
        "concern_class": concern_class,
        "confidence": confidence,
        "disposition": disposition,
        "disposition_detail": disposition_detail,
        "next_stage": next_stage,
        "downstream_refs": downstream_refs,
        "activation_conditions": activation_conditions,
        "likely_domains": likely_domains,
        "routing_target": routing_target,
        "suggested_capability_id": suggested_capability_id,
        "translator_workload": translator_workload,
    }


def pending_operator_ingress(state_root: str) -> list[dict[str, Any]]:
    ingress_dir = _ingress_dir(state_root)
    if not ingress_dir.is_dir():
        return []

    pending: list[dict[str, Any]] = []
    for path in sorted(ingress_dir.glob("OI-*.yaml")):
        try:
            doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(doc, dict):
            continue
        lifecycle_state = str(doc.get("lifecycle_state", "submitted"))
        disposition = str(doc.get("disposition", "awaiting_classification"))
        if lifecycle_state in PENDING_LIFECYCLE_STATES or disposition == "awaiting_classification":
            pending.append({
                "path": str(path),
                "ingress_id": str(doc.get("ingress_id", path.stem)),
                "submitted_at": str(doc.get("submitted_at", "")),
            })
    return pending


def auto_metabolize_operator_ingress(
    *,
    state_root: str,
    ingress_id: str,
) -> dict[str, Any]:
    path = _find_ingress_file(state_root, ingress_id)
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise OperatorIngressError(f"failed to read ingress object: {exc}") from exc
    if not isinstance(doc, dict):
        raise OperatorIngressError(f"ingress object is not a valid YAML dict: {path}")

    lifecycle_state = str(doc.get("lifecycle_state", "submitted"))
    disposition = str(doc.get("disposition", "awaiting_classification"))
    if lifecycle_state not in PENDING_LIFECYCLE_STATES and disposition != "awaiting_classification":
        return {
            "status": "skipped",
            "ingress_id": str(doc.get("ingress_id", path.stem)),
            "reason": "ingress already metabolized",
            "lifecycle_state": lifecycle_state,
            "disposition": disposition,
            "path": str(path),
        }

    plan = _build_auto_metabolize_plan(doc)
    result = metabolize_operator_ingress(
        state_root=state_root,
        ingress_id=ingress_id,
        classification=plan["classification"],
        disposition=plan["disposition"],
        disposition_detail=plan["disposition_detail"],
        next_stage=plan["next_stage"],
        downstream_refs=plan["downstream_refs"],
        activation_conditions=plan["activation_conditions"],
        likely_domains=plan["likely_domains"],
        translator_workload=plan["translator_workload"],
    )
    result["concern_class"] = plan["concern_class"]
    result["confidence"] = plan["confidence"]
    result["routing_target"] = plan["routing_target"]
    result["suggested_capability_id"] = plan["suggested_capability_id"]
    return result


def process_pending_operator_ingress(
    *,
    state_root: str,
    batch_limit: int = 10,
) -> dict[str, Any]:
    pending = pending_operator_ingress(state_root)
    processed: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []

    for item in pending[: max(batch_limit, 0)]:
        result = auto_metabolize_operator_ingress(
            state_root=state_root,
            ingress_id=item["ingress_id"],
        )
        if result.get("status") == "skipped":
            skipped.append(result)
        else:
            processed.append(result)

    return {
        "status": "ok",
        "pending_count": len(pending),
        "processed_count": len(processed),
        "skipped_count": len(skipped),
        "processed": processed,
        "skipped": skipped,
    }


def write_operator_ingress_auto_metabolizer_heartbeat(
    *,
    state_root: str,
    worker_id: str,
    mode: str,
    poll_seconds: int,
    batch_limit: int,
    last_result: dict[str, Any],
) -> dict[str, Any]:
    if not state_root or not os.path.isdir(state_root):
        raise OperatorIngressError(f"state_root not found: {state_root}")
    paths = _auto_metabolizer_runtime_paths(state_root)
    now = _iso_utc(_utcnow())
    payload = {
        "worker_id": worker_id,
        "mode": mode,
        "pid": os.getpid(),
        "heartbeat_at": now,
        "poll_seconds": poll_seconds,
        "batch_limit": batch_limit,
        "processed_count": int(last_result.get("processed_count", 0) or 0),
        "pending_count": int(last_result.get("pending_count", 0) or 0),
        "last_ingress_ids": [
            str(item.get("ingress_id", ""))
            for item in last_result.get("processed", [])
            if str(item.get("ingress_id", "")).strip()
        ],
    }
    paths["pid"].parent.mkdir(parents=True, exist_ok=True)
    paths["pid"].write_text(str(os.getpid()) + "\n", encoding="utf-8")
    _atomic_write(paths["heartbeat"], json.dumps(payload, indent=2) + "\n")
    return payload


def clear_operator_ingress_auto_metabolizer_runtime(state_root: str) -> None:
    paths = _auto_metabolizer_runtime_paths(state_root)
    try:
        if paths["pid"].exists():
            paths["pid"].unlink()
    except OSError:
        pass


def operator_ingress_auto_metabolizer_status(state_root: str) -> dict[str, Any]:
    if not state_root or not os.path.isdir(state_root):
        raise OperatorIngressError(f"state_root not found: {state_root}")

    paths = _auto_metabolizer_runtime_paths(state_root)
    queue = {
        "pending": 0,
        "classified": 0,
        "routed": 0,
        "total": 0,
    }
    ingress_dir = _ingress_dir(state_root)
    if ingress_dir.is_dir():
        for path in ingress_dir.glob("OI-*.yaml"):
            try:
                doc = yaml.safe_load(path.read_text(encoding="utf-8"))
            except Exception:
                continue
            if not isinstance(doc, dict):
                continue
            queue["total"] += 1
            lifecycle_state = str(doc.get("lifecycle_state", "submitted"))
            disposition = str(doc.get("disposition", "awaiting_classification"))
            if lifecycle_state in PENDING_LIFECYCLE_STATES or disposition == "awaiting_classification":
                queue["pending"] += 1
            elif lifecycle_state == "classified":
                queue["classified"] += 1
            elif lifecycle_state == "routed":
                queue["routed"] += 1

    heartbeat: dict[str, Any] = {}
    if paths["heartbeat"].is_file():
        try:
            heartbeat = json.loads(paths["heartbeat"].read_text(encoding="utf-8"))
        except Exception:
            heartbeat = {}

    pid = 0
    pid_alive = False
    if paths["pid"].is_file():
        try:
            pid = int(paths["pid"].read_text(encoding="utf-8").strip() or "0")
        except ValueError:
            pid = 0
    if pid > 0:
        try:
            os.kill(pid, 0)
            pid_alive = True
        except OSError:
            pid_alive = False

    heartbeat_at = str(heartbeat.get("heartbeat_at", ""))
    heartbeat_age_seconds = None
    if heartbeat_at:
        try:
            parsed = datetime.fromisoformat(heartbeat_at.replace("Z", "+00:00"))
            heartbeat_age_seconds = int((_utcnow() - parsed).total_seconds())
        except ValueError:
            heartbeat_age_seconds = None

    # Stale threshold: 3x the default 60s poll interval.
    _STALE_HEARTBEAT_SECONDS = 180

    heartbeat_stale = False
    if heartbeat_age_seconds is not None and heartbeat_age_seconds > _STALE_HEARTBEAT_SECONDS:
        heartbeat_stale = True

    status = "idle"
    if pid_alive:
        status = "running"
    elif heartbeat_at:
        status = "recent" if not heartbeat_stale else "stale"

    return {
        "status": status,
        "queue": queue,
        "worker": {
            "pid_file": str(paths["pid"]),
            "heartbeat_file": str(paths["heartbeat"]),
            "pid": pid,
            "pid_alive": pid_alive,
            "heartbeat_at": heartbeat_at,
            "heartbeat_age_seconds": heartbeat_age_seconds,
            "heartbeat_stale": heartbeat_stale,
            "heartbeat_stale_threshold_seconds": _STALE_HEARTBEAT_SECONDS,
            "worker_id": str(heartbeat.get("worker_id", "")),
            "mode": str(heartbeat.get("mode", "")),
            "poll_seconds": heartbeat.get("poll_seconds"),
            "batch_limit": heartbeat.get("batch_limit"),
            "last_ingress_ids": heartbeat.get("last_ingress_ids", []),
        },
        "oneliner": (
            f"OperatorIngressAutoMetabolizer: {status} "
            f"(pending={queue['pending']} classified={queue['classified']} routed={queue['routed']})"
        ),
    }


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
    translator_workload: dict[str, Any] | None = None,
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
    before_doc = copy.deepcopy(doc)

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
    if translator_workload:
        doc["translator_workload"] = translator_workload

    content = yaml.safe_dump(
        doc,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
    )
    _atomic_write(path, content)
    journal_path = _append_ingress_lifecycle_event(
        state_root=state_root,
        event="metabolized",
        ingress_id=str(doc.get("ingress_id", path.stem)),
        path=path,
        before=before_doc,
        after=copy.deepcopy(doc),
    )

    return {
        "status": "ok",
        "ingress_id": str(doc.get("ingress_id", path.stem)),
        "path": str(path),
        "journal_path": journal_path,
        "lifecycle_state": doc["lifecycle_state"],
        "classification": classification,
        "disposition": disposition,
        "disposition_detail": disposition_detail,
        "next_stage": next_stage,
        "downstream_refs": downstream_refs or [],
        "activation_conditions": activation_conditions,
        "metabolized_at": doc.get("classified_at", ""),
        "translator_workload": translator_workload or {},
    }


# ---------------------------------------------------------------------------
# Promotion consumer: check activation_conditions on classified/deferred OIs
# ---------------------------------------------------------------------------

# Dispositions eligible for promotion evaluation
_PROMOTABLE_DISPOSITIONS = {"deferred", "packet_candidate"}

# Classifications that could promote (have a named seam or actionable content)
_PROMOTABLE_CLASSIFICATIONS = {
    "bind_to_existing_seam",
    "bind_adjacent_to_existing_seam",
    "direct_command",
    "review_request",
}


def _list_open_loops(state_root: str) -> list[str]:
    """Return IDs of loops that have no closed.yaml."""
    orch_dir = Path(state_root) / "orchestration"
    if not orch_dir.is_dir():
        return []
    open_loops = []
    for d in orch_dir.iterdir():
        if d.is_dir() and d.name.startswith("LOOP-"):
            if not (d / "closed.yaml").exists():
                open_loops.append(d.name)
    return sorted(open_loops)


def _find_covering_loop(concern_text: str, open_loops: list[str]) -> str | None:
    """Check if any open loop already covers the OI concern.

    Uses simple keyword overlap between the OI content and loop IDs.
    Returns the first matching loop ID, or None.
    """
    if not concern_text or not open_loops:
        return None
    # Normalize: extract significant words from the concern
    words = set(
        w.lower()
        for w in re.split(r"[\s\-_./]+", concern_text)
        if len(w) > 3
    )
    for loop_id in open_loops:
        loop_words = set(
            w.lower()
            for w in re.split(r"[\s\-_]+", loop_id.replace("LOOP-", ""))
            if len(w) > 3
        )
        # Require at least 2 significant word overlaps to count as covering
        if len(words & loop_words) >= 2:
            return loop_id
    return None


def _oi_has_concrete_deliverable(doc: dict[str, Any]) -> bool:
    """Check if the OI names a concrete deliverable (not just aspirational)."""
    hint = str(doc.get("operator_hint", "")).lower()
    raw = str(doc.get("raw_content", "")).lower()
    text = hint + " " + raw
    # Aspirational signals — these suggest no concrete deliverable
    aspirational = [
        "someday", "keep an eye", "it would be nice",
        "think about", "maybe we should", "consider",
    ]
    for phrase in aspirational:
        if phrase in text:
            return False
    # Must have some actionable content
    return bool(hint.strip() or len(raw.strip()) > 20)


def _oi_is_bounded(doc: dict[str, Any]) -> bool:
    """Check if the OI implies bounded work (not open-ended)."""
    raw = str(doc.get("raw_content", "")).lower()
    unbounded = [
        "continuously", "always monitor", "permanent",
        "indefinite", "ongoing maintenance", "keep running",
    ]
    for phrase in unbounded:
        if phrase in raw:
            return False
    return True


def evaluate_oi_promotion(
    doc: dict[str, Any],
    open_loops: list[str],
) -> dict[str, Any]:
    """Evaluate whether a classified OI qualifies for promotion.

    Returns a dict with:
      eligible: bool
      action: "attach" | "open_loop" | "stay_deferred"
      reason: str
      covering_loop: str | None (if attaching)
    """
    ingress_id = str(doc.get("ingress_id", ""))
    classification = str(doc.get("classification", ""))
    disposition = str(doc.get("disposition", ""))
    activation_conditions = str(doc.get("activation_conditions", ""))

    # Already promoted
    if disposition not in _PROMOTABLE_DISPOSITIONS:
        return {
            "eligible": False,
            "action": "stay_deferred",
            "reason": f"disposition '{disposition}' is not promotable",
            "covering_loop": None,
        }

    # packet_candidate items are always eligible for evaluation even without
    # activation_conditions — they already have a routing target and were
    # classified as actionable by the metabolizer.
    if disposition != "packet_candidate" and not activation_conditions.strip():
        return {
            "eligible": False,
            "action": "stay_deferred",
            "reason": "no activation_conditions set",
            "covering_loop": None,
        }

    # Criterion 1: classification must be promotable (has a named seam)
    if classification not in _PROMOTABLE_CLASSIFICATIONS:
        return {
            "eligible": False,
            "action": "stay_deferred",
            "reason": f"classification '{classification}' is not promotable",
            "covering_loop": None,
        }

    # Criterion 3: concrete deliverable
    if not _oi_has_concrete_deliverable(doc):
        return {
            "eligible": False,
            "action": "stay_deferred",
            "reason": "no concrete deliverable identified",
            "covering_loop": None,
        }

    # Criterion 5: bounded work
    if not _oi_is_bounded(doc):
        return {
            "eligible": False,
            "action": "stay_deferred",
            "reason": "work appears unbounded",
            "covering_loop": None,
        }

    # Criterion 4: check for existing covering loop
    concern = str(doc.get("operator_hint", "")) + " " + str(doc.get("raw_content", ""))
    covering = _find_covering_loop(concern, open_loops)
    if covering:
        return {
            "eligible": True,
            "action": "attach",
            "reason": f"existing loop covers this concern: {covering}",
            "covering_loop": covering,
        }

    # All criteria met, no covering loop — open a new one
    return {
        "eligible": True,
        "action": "open_loop",
        "reason": "all promotion criteria satisfied; no covering loop found",
        "covering_loop": None,
    }


def promote_operator_ingress(
    *,
    state_root: str,
    ingress_id: str,
    action: str,
    covering_loop: str | None = None,
    reason: str = "",
) -> dict[str, Any]:
    """Execute promotion for a qualifying OI object.

    action must be "attach" or "open_loop".
    For "attach", covering_loop must be provided.
    For "open_loop", a new loop ID is derived from the OI.
    """
    path = _find_ingress_file(state_root, ingress_id)
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise OperatorIngressError(f"failed to read ingress object: {exc}") from exc
    if not isinstance(doc, dict):
        raise OperatorIngressError(f"ingress object is not a valid YAML dict: {path}")

    before_doc = copy.deepcopy(doc)
    now = _utcnow()
    now_str = _iso_utc(now)

    if action == "attach":
        if not covering_loop:
            raise OperatorIngressError("attach action requires covering_loop")
        doc["lifecycle_state"] = "routed"
        doc["disposition"] = "attached"
        doc["disposition_detail"] = f"Promoted by activation consumer: attached to {covering_loop}."
        doc["next_stage"] = covering_loop
        doc["routed_at"] = now_str
        refs = doc.get("downstream_refs", [])
        if covering_loop not in refs:
            refs.append(covering_loop)
        doc["downstream_refs"] = refs
        doc.pop("activation_conditions", None)
        doc["promoted_at"] = now_str
        doc["promoted_by"] = "activation_consumer"
        doc["promotion_reason"] = reason

    elif action == "open_loop":
        # Derive a loop ID from the OI hint or content
        hint = str(doc.get("operator_hint", "")).strip()
        if hint:
            slug = re.sub(r"[^a-zA-Z0-9]+", "-", hint).strip("-").upper()[:40]
        else:
            slug = ingress_id.replace("OI-", "").upper()[:20]
        date_part = now.strftime("%Y%m%d")
        loop_id = f"LOOP-OI-PROMOTED-{slug}-{date_part}"

        doc["lifecycle_state"] = "routed"
        doc["disposition"] = "attached"
        doc["disposition_detail"] = f"Promoted by activation consumer: opened {loop_id}."
        doc["next_stage"] = loop_id
        doc["routed_at"] = now_str
        refs = doc.get("downstream_refs", [])
        if loop_id not in refs:
            refs.append(loop_id)
        doc["downstream_refs"] = refs
        doc.pop("activation_conditions", None)
        doc["promoted_at"] = now_str
        doc["promoted_by"] = "activation_consumer"
        doc["promotion_reason"] = reason

    else:
        raise OperatorIngressError(f"unknown promotion action: {action}")

    content = yaml.safe_dump(
        doc, default_flow_style=False, sort_keys=False, allow_unicode=True
    )
    _atomic_write(path, content)
    _append_ingress_lifecycle_event(
        state_root=state_root,
        event="promoted",
        ingress_id=ingress_id,
        path=path,
        before=before_doc,
        after=copy.deepcopy(doc),
    )

    return {
        "status": "ok",
        "ingress_id": ingress_id,
        "action": action,
        "lifecycle_state": doc["lifecycle_state"],
        "disposition": doc["disposition"],
        "disposition_detail": doc["disposition_detail"],
        "next_stage": doc.get("next_stage", ""),
        "downstream_refs": doc.get("downstream_refs", []),
        "promoted_at": now_str,
        "path": str(path),
        "covering_loop": covering_loop or "",
    }


def process_promotable_operator_ingress(
    *,
    state_root: str,
    batch_limit: int = 10,
    dry_run: bool = False,
) -> dict[str, Any]:
    """Scan classified OI objects and promote qualifying ones.

    Idempotent: already-promoted objects are skipped.
    """
    ingress_dir = _ingress_dir(state_root)
    if not ingress_dir.is_dir():
        return {"status": "ok", "evaluated": 0, "promoted": 0, "deferred": 0, "results": []}

    open_loops = _list_open_loops(state_root)
    results: list[dict[str, Any]] = []
    promoted_count = 0
    deferred_count = 0
    evaluated_count = 0

    for path in sorted(ingress_dir.glob("OI-*.yaml")):
        if evaluated_count >= batch_limit:
            break
        try:
            doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(doc, dict):
            continue

        disposition = str(doc.get("disposition", ""))
        if disposition not in _PROMOTABLE_DISPOSITIONS:
            continue

        activation_conditions = str(doc.get("activation_conditions", ""))
        if disposition != "packet_candidate" and not activation_conditions.strip():
            continue

        evaluated_count += 1
        ingress_id = str(doc.get("ingress_id", path.stem))
        evaluation = evaluate_oi_promotion(doc, open_loops)

        if not evaluation["eligible"]:
            deferred_count += 1
            results.append({
                "ingress_id": ingress_id,
                "action": "stay_deferred",
                "reason": evaluation["reason"],
                "promoted": False,
            })
            continue

        if dry_run:
            promoted_count += 1
            results.append({
                "ingress_id": ingress_id,
                "action": evaluation["action"],
                "reason": evaluation["reason"],
                "covering_loop": evaluation["covering_loop"],
                "promoted": False,
                "dry_run": True,
            })
            continue

        result = promote_operator_ingress(
            state_root=state_root,
            ingress_id=ingress_id,
            action=evaluation["action"],
            covering_loop=evaluation["covering_loop"],
            reason=evaluation["reason"],
        )
        promoted_count += 1
        # If we opened a loop, add it to open_loops for subsequent items
        if evaluation["action"] == "open_loop" and result.get("next_stage"):
            open_loops.append(result["next_stage"])
        results.append({
            "ingress_id": ingress_id,
            "action": evaluation["action"],
            "reason": evaluation["reason"],
            "covering_loop": evaluation.get("covering_loop", ""),
            "next_stage": result.get("next_stage", ""),
            "promoted": True,
        })

    return {
        "status": "ok",
        "evaluated": evaluated_count,
        "promoted": promoted_count,
        "deferred": deferred_count,
        "open_loops_checked": len(open_loops),
        "results": results,
    }
