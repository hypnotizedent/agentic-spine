from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


REQUIRED_FAMILIES = [
    "photos",
    "media.movies",
    "media.tv",
    "media.music",
    "games",
]

PLANE_FIELDS = [
    "active_plane",
    "archive_plane",
    "intake_stage",
    "review_hold",
    "rehydration_target",
    "backup_primary",
    "backup_secondary",
]

NON_CANONICAL_ROOT_PATTERNS = [
    "/md1400/media-cold",
]

RESIDUAL_MEDIA_SERVICE_PLANES = {"download-stack", "streaming-stack"}
ACTIVE_LIKE_SERVICE_STATUSES = {"active", "planned"}


@dataclass
class Issue:
    severity: str
    message: str


def load_yaml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(path)
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise ValueError(f"{path}: YAML root must be a mapping")
    return data


def yaml_dump(data: dict[str, Any]) -> str:
    return yaml.safe_dump(data, sort_keys=False, allow_unicode=False)


def ensure_dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def ensure_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def rel(root: Path, path: Path) -> str:
    return str(path.resolve().relative_to(root.resolve()))


def source_sha(root: Path, paths: list[Path]) -> str:
    digest = hashlib.sha256()
    for path in paths:
        digest.update(rel(root, path).encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def source_stamp(paths: list[Path]) -> str:
    latest = 0.0
    for path in paths:
        if path.exists():
            latest = max(latest, path.stat().st_mtime)
    if latest == 0.0:
        latest = datetime.now(timezone.utc).timestamp()
    return (
        datetime.fromtimestamp(latest, tz=timezone.utc)
        .replace(microsecond=0)
        .strftime("%Y-%m-%dT%H:%M:%SZ")
    )


def flatten_plane_field(value: dict[str, Any]) -> tuple[str, str, str]:
    plane_id = str(value.get("plane_id") or "").strip()
    posture = str(value.get("posture") or "").strip()
    note = str(value.get("note") or "").strip()
    return plane_id, posture, note


def plane_refs_map(storage_planes: dict[str, Any]) -> dict[str, list[str]]:
    rendered: dict[str, list[str]] = {}
    for plane_id, raw in storage_planes.items():
        plane = ensure_dict(raw)
        rendered[str(plane_id)] = [str(item).strip() for item in ensure_list(plane.get("canonical_refs")) if str(item).strip()]
    return rendered


def build_projection(policy: dict[str, Any], *, source_sha256: str, generated_at_utc: str) -> dict[str, Any]:
    storage_planes = ensure_dict(policy.get("storage_planes"))
    service_planes = ensure_dict(policy.get("service_planes"))
    families = ensure_dict(policy.get("families"))
    refs = plane_refs_map(storage_planes)

    family_rows: list[dict[str, Any]] = []
    blockers: dict[str, dict[str, list[str]]] = {}

    for family_id in REQUIRED_FAMILIES:
        family = ensure_dict(families.get(family_id))
        if not family:
            continue

        def field_payload(field_name: str) -> dict[str, Any]:
            row = ensure_dict(family.get(field_name))
            plane_id, posture, note = flatten_plane_field(row)
            return {
                "plane_id": plane_id or None,
                "posture": posture or None,
                "note": note or None,
                "canonical_refs": refs.get(plane_id, []),
            }

        decommission = ensure_dict(family.get("decommission_dependencies"))
        required_storage = [str(item).strip() for item in ensure_list(decommission.get("required_storage_planes")) if str(item).strip()]
        required_services = [str(item).strip() for item in ensure_list(decommission.get("required_service_planes")) if str(item).strip()]
        planned_services = [str(item).strip() for item in ensure_list(decommission.get("planned_service_planes")) if str(item).strip()]

        for plane_id in required_storage:
            blockers.setdefault(plane_id, {"families": [], "kind": "storage"})
            blockers[plane_id]["families"].append(family_id)
        for plane_id in required_services:
            blockers.setdefault(plane_id, {"families": [], "kind": "service"})
            blockers[plane_id]["families"].append(family_id)

        family_rows.append(
            {
                "family_id": family_id,
                "active_plane": field_payload("active_plane"),
                "archive_plane": field_payload("archive_plane"),
                "intake_stage": field_payload("intake_stage"),
                "review_hold": field_payload("review_hold"),
                "rehydration_target": field_payload("rehydration_target"),
                "backup_primary": field_payload("backup_primary"),
                "backup_secondary": field_payload("backup_secondary"),
                "retention_policy": str(family.get("retention_policy") or "").strip(),
                "lifecycle_policy": str(family.get("lifecycle_policy") or "").strip(),
                "service_authority": ensure_dict(family.get("service_authority")),
                "decommission_dependencies": {
                    "required_storage_planes": required_storage,
                    "optional_storage_planes": [
                        str(item).strip()
                        for item in ensure_list(decommission.get("optional_storage_planes"))
                        if str(item).strip()
                    ],
                    "required_service_planes": required_services,
                    "optional_service_planes": [
                        str(item).strip()
                        for item in ensure_list(decommission.get("optional_service_planes"))
                        if str(item).strip()
                    ],
                    "planned_service_planes": planned_services,
                    "prohibited_future_placeholders": [
                        str(item).strip()
                        for item in ensure_list(decommission.get("prohibited_future_placeholders"))
                        if str(item).strip()
                    ],
                },
                "blocking_dependencies": {
                    "required_storage_planes": required_storage,
                    "required_service_planes": required_services,
                    "planned_service_planes": planned_services,
                },
                "description": str(family.get("description") or "").strip(),
            }
        )

    blocker_rows = [
        {
            "plane_id": plane_id,
            "plane_kind": payload["kind"],
            "blocking_families": sorted(set(payload["families"])),
        }
        for plane_id, payload in sorted(blockers.items())
    ]

    return {
        "version": 1,
        "status": "projection",
        "authority_state": "projection",
        "projection_of": "ops/bindings/content.family.placement.policy.yaml",
        "source_capability": "content.family.placement.projection.build",
        "source_sha256": source_sha256,
        "generated_at_utc": generated_at_utc,
        "storage_planes": storage_planes,
        "service_planes": service_planes,
        "family_matrix": family_rows,
        "decommission_blockers": blocker_rows,
    }


def render_markdown(projection: dict[str, Any]) -> str:
    rows = ensure_list(projection.get("family_matrix"))
    lines = [
        "---",
        "status: generated",
        "owner: \"@ronny\"",
        "scope: content-family-placement",
        "---",
        "",
        "# Content Family Placement Matrix",
        "",
        "Generated from `ops/bindings/content.family.placement.policy.yaml`.",
        "",
        "| Family | Hot / Active | Stage | Hold | Archive | Rehydrate | Backup Primary | Backup Secondary | Blocking Dependencies |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for row in rows:
        family = ensure_dict(row)
        deps = ensure_dict(family.get("blocking_dependencies"))
        dep_bits = deps.get("required_storage_planes", []) + deps.get("required_service_planes", [])
        dep_rendered = ", ".join(str(item) for item in dep_bits) if dep_bits else "none"

        def field_name(name: str) -> str:
            payload = ensure_dict(family.get(name))
            plane_id = str(payload.get("plane_id") or "").strip()
            posture = str(payload.get("posture") or "").strip()
            if not plane_id:
                return posture or "none"
            if posture:
                return f"`{plane_id}` ({posture})"
            return f"`{plane_id}`"

        lines.append(
            "| {family_id} | {active} | {stage} | {hold} | {archive} | {rehydrate} | {backup_primary} | {backup_secondary} | {deps} |".format(
                family_id=str(family.get("family_id") or ""),
                active=field_name("active_plane"),
                stage=field_name("intake_stage"),
                hold=field_name("review_hold"),
                archive=field_name("archive_plane"),
                rehydrate=field_name("rehydration_target"),
                backup_primary=field_name("backup_primary"),
                backup_secondary=field_name("backup_secondary"),
                deps=dep_rendered,
            )
        )
    lines.append("")
    return "\n".join(lines)


def validate_policy(policy: dict[str, Any], projection_on_disk: dict[str, Any] | None = None, expected_projection: dict[str, Any] | None = None) -> list[Issue]:
    issues: list[Issue] = []
    storage_planes = ensure_dict(policy.get("storage_planes"))
    service_planes = ensure_dict(policy.get("service_planes"))
    families = ensure_dict(policy.get("families"))

    for family_id in REQUIRED_FAMILIES:
        family = ensure_dict(families.get(family_id))
        if not family:
            issues.append(Issue("error", f"{family_id}: missing required family declaration"))
            continue
        for field_name in PLANE_FIELDS:
            field = ensure_dict(family.get(field_name))
            if not field:
                issues.append(Issue("error", f"{family_id}: missing {field_name} declaration"))
                continue
            plane_id, posture, _note = flatten_plane_field(field)
            if field_name == "active_plane":
                if not plane_id:
                    issues.append(Issue("error", f"{family_id}: active_plane must reference a declared storage plane"))
                    continue
                if plane_id not in storage_planes:
                    issues.append(Issue("error", f"{family_id}: active_plane references unknown storage plane '{plane_id}'"))
                    continue
            if plane_id:
                if plane_id not in storage_planes:
                    issues.append(Issue("error", f"{family_id}: {field_name} references unknown storage plane '{plane_id}'"))
                    continue
                plane = ensure_dict(storage_planes.get(plane_id))
                plane_status = str(plane.get("status") or "").strip()
                refs = [str(item).strip() for item in ensure_list(plane.get("canonical_refs")) if str(item).strip()]
                if field_name in {"active_plane", "archive_plane", "intake_stage", "rehydration_target", "backup_primary"}:
                    if plane_status in {"residual", "decommissioned"}:
                        issues.append(Issue("error", f"{family_id}: {field_name} cannot target {plane_status} plane '{plane_id}'"))
                if plane_status == "planned" and field_name not in {"archive_plane", "intake_stage", "review_hold", "backup_primary", "backup_secondary", "rehydration_target", "active_plane"}:
                    issues.append(Issue("warning", f"{family_id}: {field_name} uses planned plane '{plane_id}'"))
                if plane_status != "planned" and not refs and field_name != "backup_secondary":
                    issues.append(Issue("error", f"{family_id}: {field_name} plane '{plane_id}' has no canonical_refs"))
                for ref in refs:
                    if any(token in ref for token in NON_CANONICAL_ROOT_PATTERNS):
                        issues.append(Issue("error", f"{family_id}: {field_name} plane '{plane_id}' references non-canonical root '{ref}'"))
            elif posture not in {"undeclared"}:
                issues.append(Issue("error", f"{family_id}: {field_name} must reference a plane or declare posture=undeclared"))

        authority = ensure_dict(family.get("service_authority"))
        primary_service_planes = [str(item).strip() for item in ensure_list(authority.get("primary_service_planes")) if str(item).strip()]
        residual_service_planes = [str(item).strip() for item in ensure_list(authority.get("residual_compatibility_planes")) if str(item).strip()]
        planned_service_planes = [str(item).strip() for item in ensure_list(authority.get("planned_service_planes")) if str(item).strip()]
        if family_id != "games" and not primary_service_planes:
            issues.append(Issue("error", f"{family_id}: missing primary_service_planes"))
        if family_id == "games" and "games-stack" not in planned_service_planes:
            issues.append(Issue("error", "games: planned_service_planes must declare games-stack"))

        for plane_id in primary_service_planes:
            if plane_id not in service_planes:
                issues.append(Issue("error", f"{family_id}: primary service plane '{plane_id}' is undefined"))
                continue
            status = str(ensure_dict(service_planes.get(plane_id)).get("status") or "").strip()
            if status not in ACTIVE_LIKE_SERVICE_STATUSES:
                issues.append(Issue("error", f"{family_id}: primary service plane '{plane_id}' cannot be status '{status}'"))

        for plane_id in residual_service_planes:
            if plane_id not in service_planes:
                issues.append(Issue("error", f"{family_id}: residual service plane '{plane_id}' is undefined"))
                continue
            status = str(ensure_dict(service_planes.get(plane_id)).get("status") or "").strip()
            if status != "residual":
                issues.append(Issue("error", f"{family_id}: residual compatibility plane '{plane_id}' must be status residual"))

        deps = ensure_dict(family.get("decommission_dependencies"))
        required_service_planes = [str(item).strip() for item in ensure_list(deps.get("required_service_planes")) if str(item).strip()]
        required_storage_planes = [str(item).strip() for item in ensure_list(deps.get("required_storage_planes")) if str(item).strip()]
        for plane_id in required_storage_planes:
            if plane_id not in storage_planes:
                issues.append(Issue("error", f"{family_id}: required storage dependency '{plane_id}' is undefined"))
        for plane_id in required_service_planes:
            if plane_id not in service_planes:
                issues.append(Issue("error", f"{family_id}: required service dependency '{plane_id}' is undefined"))
                continue
            status = str(ensure_dict(service_planes.get(plane_id)).get("status") or "").strip()
            if status not in ACTIVE_LIKE_SERVICE_STATUSES:
                issues.append(Issue("error", f"{family_id}: required service dependency '{plane_id}' cannot be status '{status}'"))

        prohibited = {str(item).strip() for item in ensure_list(deps.get("prohibited_future_placeholders")) if str(item).strip()}
        if family_id == "games":
            if not RESIDUAL_MEDIA_SERVICE_PLANES.issubset(prohibited):
                issues.append(Issue("error", "games: prohibited_future_placeholders must explicitly block download-stack and streaming-stack reuse"))
            if any(plane_id in RESIDUAL_MEDIA_SERVICE_PLANES for plane_id in primary_service_planes + required_service_planes + planned_service_planes):
                issues.append(Issue("error", "games: residual media service planes must not define games family authority"))

    if expected_projection is not None and projection_on_disk is not None and expected_projection != projection_on_disk:
        issues.append(Issue("error", "content.family.placement.projected.yaml drifted from authoritative policy"))

    return issues
