from __future__ import annotations

import copy
import hashlib
import json
import os
import re
import uuid
from pathlib import Path
from typing import Any

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root as governed_resolve_spine_root
from quote_packet_normalize import dump_yaml, load_structured_file, now_utc


ARTIFACT_NAMESPACE = uuid.uuid5(
    uuid.NAMESPACE_URL,
    "https://spine.ronny.works/mint/artifact-record",
)
ARTIFACT_ROLES = (
    "original",
    "reference_mockup",
    "proof",
    "print_ready",
    "production_asset",
    "superseded",
)
ARTIFACT_STATUSES = (
    "active",
    "needs_review",
    "superseded",
)
ROLE_FOLDER_BY_ROLE = {
    "original": "1. Originals",
    "reference_mockup": "2. Reference Mockups",
    "proof": "2. Proofs",
    "print_ready": "3. Print Ready",
    "production_asset": "4. Production Assets",
    "superseded": "_superseded",
}
ROLE_ORDER = {role: idx for idx, role in enumerate(ARTIFACT_ROLES)}
VECTOR_EXTENSIONS = {"ai", "eps", "svg", "cdr"}
PRODUCTION_EXTENSIONS = {"dst", "u00"}
PRODUCTION_HINT_EXTENSIONS = {"emb", "pxf", "edr"}
IMAGE_EXTENSIONS = {"png", "jpg", "jpeg", "webp"}
VERSION_NOISE_RE = re.compile(
    r"(?i)\b(v\d+|ver\d+|version\d+|rev\d+|rev|revision|updated|latest|final|older|old|bad|wrong|draft|proof)\b"
)


def resolve_spine_root() -> Path:
    return governed_resolve_spine_root(__file__)


def resolve_mint_root(spine_root: Path | None = None) -> Path:
    return resolve_mint_data_root(spine_root=spine_root, current_file=__file__)


def runtime_paths(spine_root: Path | None = None) -> dict[str, Path]:
    mint_root = resolve_mint_root(spine_root)
    return {
        "mint_root": mint_root,
        "artifacts_dir": Path(os.environ.get("MINT_ARTIFACT_DIR") or (mint_root / "artifacts")),
        "artifacts_index_file": Path(os.environ.get("MINT_ARTIFACT_INDEX_FILE") or (mint_root / "artifacts-index.yaml")),
    }


def entity_file(entity_dir: Path, prefix: str, entity_id: str) -> Path:
    return entity_dir / f"{prefix}_{entity_id}.yaml"


def load_yaml_object(path: Path) -> dict[str, Any]:
    payload = load_structured_file(path) if path.exists() else {}
    return payload if isinstance(payload, dict) else {}


def load_index(index_file: Path, list_key: str) -> list[dict[str, Any]]:
    payload = load_structured_file(index_file) if index_file.exists() else {}
    if not isinstance(payload, dict):
        return []
    return [copy.deepcopy(item) for item in (payload.get(list_key) or []) if isinstance(item, dict)]


def update_entity_index(index_file: Path, list_key: str, entity_key: str, entry: dict[str, Any]) -> None:
    payload = load_structured_file(index_file) if index_file.exists() else {list_key: []}
    if not isinstance(payload, dict):
        payload = {list_key: []}
    entries = payload.setdefault(list_key, [])
    existing = next(
        (
            item
            for item in entries
            if isinstance(item, dict) and str(item.get(entity_key) or "") == str(entry.get(entity_key) or "")
        ),
        None,
    )
    if existing:
        existing.update(copy.deepcopy(entry))
    else:
        entries.append(copy.deepcopy(entry))
    dump_yaml(index_file, payload)


def load_artifact(paths: dict[str, Path], artifact_id: str) -> tuple[Path, dict[str, Any]]:
    path = entity_file(paths["artifacts_dir"], "artifact", artifact_id)
    if not path.exists():
        raise FileNotFoundError(f"artifact record not found: {artifact_id}")
    payload = load_yaml_object(path)
    if not payload:
        raise ValueError(f"artifact record is not a valid object: {artifact_id}")
    return path, payload


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def normalize_text(value: Any) -> str:
    return str(value or "").strip()


def normalize_lower(value: Any) -> str:
    return normalize_text(value).lower()


def compact_filename_stem(filename: str) -> str:
    stem = Path(str(filename or "")).stem.lower()
    stem = re.sub(r"[_\-]+", " ", stem)
    stem = VERSION_NOISE_RE.sub(" ", stem)
    stem = re.sub(r"[^a-z0-9]+", "", stem)
    return stem or "artifact"


def canonical_role_folder(role: str) -> str:
    return ROLE_FOLDER_BY_ROLE.get(role, ROLE_FOLDER_BY_ROLE["original"])


def canonical_object_key_from_path(path: str | Path) -> str:
    target = Path(path).expanduser().resolve()
    minio_root = Path(os.environ.get("MINIO_MOUNT_ROOT") or (Path.home() / "MinIO")).expanduser().resolve()
    try:
        return target.relative_to(minio_root).as_posix()
    except ValueError:
        return target.as_posix()


def artifact_id(seed_id: str, sha256: str) -> str:
    signature = json.dumps(
        {
            "seed_id": seed_id,
            "sha256": sha256.lower(),
        },
        sort_keys=True,
    )
    return str(uuid.uuid5(ARTIFACT_NAMESPACE, signature))


def role_sort_value(role: str) -> int:
    return ROLE_ORDER.get(role, 999)


def infer_artifact_role(
    *,
    filename: str,
    content_type: str = "",
    context_text: str = "",
    explicit_role: str = "",
) -> tuple[str, str, list[str]]:
    role = normalize_text(explicit_role)
    if role:
        return role, "high", ["explicit_role_override"]

    filename_lower = normalize_lower(filename)
    content_type_lower = normalize_lower(content_type)
    context_lower = normalize_lower(context_text)
    extension = Path(filename_lower).suffix.lower().lstrip(".")
    combined = " ".join(part for part in (filename_lower, content_type_lower, context_lower) if part)
    filename_signals = " ".join(part for part in (filename_lower, content_type_lower) if part)
    reasons: list[str] = []

    if any(token in filename_signals for token in ("superseded", "bad", "wrong", "obsolete", "older", "old version")):
        reasons.append("superseded_filename_marker")
        return "superseded", "high", reasons

    if extension in PRODUCTION_EXTENSIONS:
        reasons.append(f"machine_extension:{extension}")
        return "production_asset", "high", reasons
    if extension in PRODUCTION_HINT_EXTENSIONS and any(token in combined for token in ("production", "barudan", "machine", "embroidery")):
        reasons.append(f"near_machine_extension:{extension}")
        reasons.append("production_context")
        return "production_asset", "high", reasons

    if any(token in combined for token in ("production asset", "production file", "press ready", "barudan", "screenpro")):
        reasons.append("production_keyword")
        return "production_asset", "high", reasons

    if any(token in combined for token in ("print ready", "print-ready", "camera ready", "vector ready", "separated", "seps")):
        reasons.append("print_ready_keyword")
        return "print_ready", "high", reasons
    if extension in VECTOR_EXTENSIONS:
        reasons.append(f"vector_extension:{extension}")
        return "print_ready", "medium", reasons

    if any(token in combined for token in ("reference mockup", "mockup", "render", "preview")):
        reasons.append("mockup_keyword")
        return "reference_mockup", "high", reasons

    if any(token in combined for token in ("proof", "approve", "approval", "approved")):
        reasons.append("proof_keyword")
        return "proof", "high", reasons
    if extension == "pdf" and any(token in combined for token in ("customer", "review", "proofing")):
        reasons.append("proof_pdf_context")
        return "proof", "medium", reasons

    if extension in IMAGE_EXTENSIONS and any(token in combined for token in ("reference", "inspo", "example")):
        reasons.append(f"reference_image_extension:{extension}")
        return "reference_mockup", "medium", reasons

    if extension in {"pdf", *IMAGE_EXTENSIONS}:
        reasons.append(f"default_original_extension:{extension}")
        return "original", "medium", reasons

    reasons.append("fallback_original")
    return "original", "low", reasons


def artifact_index_entry(record: dict[str, Any]) -> dict[str, Any]:
    source_refs = record.get("source_refs") or {}
    customer_binding = record.get("customer_binding") or {}
    job_binding = record.get("job_binding") or {}
    provenance = record.get("provenance") or {}
    role_assignment = provenance.get("role_assignment") or {}
    return {
        "artifact_id": record.get("artifact_id"),
        "seed_id": record.get("seed_id"),
        "customer_id": customer_binding.get("customer_id"),
        "customer_email": customer_binding.get("customer_email"),
        "customer_name": customer_binding.get("customer_name"),
        "job_ref": job_binding.get("job_ref"),
        "order_id": job_binding.get("order_id"),
        "source_message_id": source_refs.get("source_message_id"),
        "source_conversation_id": source_refs.get("source_conversation_id"),
        "source_internet_message_id": source_refs.get("source_internet_message_id"),
        "original_filename": record.get("original_filename"),
        "artifact_family_key": record.get("artifact_family_key"),
        "canonical_object_key": record.get("canonical_object_key"),
        "sha256": record.get("sha256"),
        "artifact_role": record.get("artifact_role"),
        "artifact_status": record.get("artifact_status"),
        "confidence": record.get("confidence"),
        "role_assignment_mode": role_assignment.get("assignment_mode"),
        "superseded_by": record.get("superseded_by"),
        "updated_at": record.get("updated_at"),
        "created_at": record.get("created_at"),
    }


def is_superseded(record: dict[str, Any]) -> bool:
    return normalize_lower(record.get("artifact_status")) == "superseded" or normalize_lower(record.get("artifact_role")) == "superseded"


def artifacts_sort_key(record: dict[str, Any]) -> tuple[str, int, str]:
    return (
        normalize_text(record.get("updated_at") or record.get("created_at")),
        -role_sort_value(normalize_text(record.get("artifact_role"))),
        normalize_lower(record.get("original_filename")),
    )


def sanitize_mapping(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict):
        return {}
    clean: dict[str, Any] = {}
    for key, value in raw.items():
        text_key = normalize_text(key)
        if not text_key:
            continue
        clean[text_key] = value
    return clean


def append_role_history(
    record: dict[str, Any],
    *,
    role: str,
    status: str,
    assignment_mode: str,
    assigned_by: str,
    confidence: str,
    basis: list[str],
    note: str = "",
) -> None:
    history = record.setdefault("role_history", [])
    history.append(
        {
            "recorded_at": now_utc(),
            "artifact_role": role,
            "artifact_status": status,
            "assignment_mode": assignment_mode,
            "assigned_by": assigned_by,
            "confidence": confidence,
            "basis": list(basis),
            "note": normalize_text(note) or None,
        }
    )
