from __future__ import annotations

from pathlib import Path
from typing import Any

from ops.plugins.infra.lib.content_family_placement import (
    Issue,
    ensure_dict,
    ensure_list,
    load_yaml,
    rel,
)


REQUIRED_CANDIDATE_PLANES = ["download-stack", "streaming-stack"]
ROOT_SECTION_KEYS = [
    "canonical_live_roots",
    "allowed_secondary_roots",
    "staging_roots",
    "quarantine_roots",
    "export_archive_lanes",
]


def source_paths(root: Path) -> list[Path]:
    return [
        root / "ops/bindings/domains/media/content.family.placement.policy.yaml",
        root / "ops/bindings/service.data.lifecycle.registry.yaml",
        root / "ops/bindings/services.health.yaml",
        root / "ops/bindings/vm.lifecycle.yaml",
        root / "ops/bindings/service.closure.contract.yaml",
        root / "ops/bindings/relocation.closure.contract.yaml",
        root / "ops/bindings/domains/media/media.services.yaml",
    ]


def _unique(items: list[str]) -> list[str]:
    seen: set[str] = set()
    rendered: list[str] = []
    for item in items:
        text = str(item or "").strip()
        if not text or text in seen:
            continue
        seen.add(text)
        rendered.append(text)
    return rendered


def _family_members(policy: dict[str, Any], plane_id: str, *, dep_key: str, authority_key: str | None = None) -> list[str]:
    families = ensure_dict(policy.get("families"))
    hits: list[str] = []
    for family_id, raw_family in families.items():
        family = ensure_dict(raw_family)
        deps = ensure_dict(family.get("decommission_dependencies"))
        authority = ensure_dict(family.get("service_authority"))
        candidates = [
            str(item).strip()
            for item in ensure_list(deps.get(dep_key))
            if str(item).strip()
        ]
        if authority_key:
            candidates.extend(
                [
                    str(item).strip()
                    for item in ensure_list(authority.get(authority_key))
                    if str(item).strip()
                ]
            )
        if plane_id in candidates:
            hits.append(str(family_id))
    return sorted(set(hits))


def _lifecycle_host_refs(lifecycle: dict[str, Any], plane_id: str) -> list[str]:
    refs: list[str] = []
    services = ensure_dict(lifecycle.get("services"))
    for service_id, raw_service in services.items():
        service = ensure_dict(raw_service)
        for section in ROOT_SECTION_KEYS:
            for raw_row in ensure_list(service.get(section)):
                row = ensure_dict(raw_row)
                host = str(row.get("host") or "").strip()
                path = str(row.get("path") or "").strip()
                if host == plane_id and path:
                    refs.append(f"{service_id}:{section}:{host}:{path}")
    return _unique(refs)


def _health_endpoint_refs(services_health: dict[str, Any], plane_id: str) -> list[str]:
    refs: list[str] = []
    for raw_endpoint in ensure_list(services_health.get("endpoints")):
        endpoint = ensure_dict(raw_endpoint)
        host = str(endpoint.get("host") or "").strip()
        enabled = bool(endpoint.get("enabled"))
        if host == plane_id and enabled:
            refs.append(str(endpoint.get("id") or "").strip())
    return _unique(refs)


def _health_lifecycle_bindings(services_health: dict[str, Any], plane_id: str) -> list[str]:
    refs: list[str] = []
    for raw_binding in ensure_list(services_health.get("lifecycle_bindings")):
        binding = ensure_dict(raw_binding)
        if str(binding.get("host") or "").strip() != plane_id:
            continue
        service_ids = [
            str(ensure_dict(raw_service).get("service_id") or "").strip()
            for raw_service in ensure_list(binding.get("services"))
            if str(ensure_dict(raw_service).get("service_id") or "").strip()
        ]
        if service_ids:
            refs.append(",".join(service_ids))
    return _unique(refs)


def _active_media_services(media_services: dict[str, Any], plane_id: str) -> list[str]:
    refs: list[str] = []
    for service_id, raw_service in ensure_dict(media_services.get("services")).items():
        service = ensure_dict(raw_service)
        if str(service.get("vm") or "").strip() != plane_id:
            continue
        if str(service.get("status") or "").strip() == "active":
            refs.append(str(service_id))
    return _unique(refs)


def _closure_refs(service_closure: dict[str, Any], plane_id: str) -> tuple[list[str], list[str]]:
    residual: list[str] = []
    retired: list[str] = []
    for raw_closure in ensure_list(service_closure.get("closures")):
        closure = ensure_dict(raw_closure)
        closure_id = str(closure.get("id") or "").strip() or "unknown"
        policy = ensure_dict(closure.get("residual_source_policy"))
        residual_hosts = [str(item).strip() for item in ensure_list(policy.get("residual_hosts")) if str(item).strip()]
        retired_hosts = [str(item).strip() for item in ensure_list(policy.get("retired_hosts")) if str(item).strip()]
        if plane_id in residual_hosts:
            residual.append(f"{closure_id}:residual_source_policy.residual_hosts")
        if plane_id in retired_hosts:
            retired.append(f"{closure_id}:residual_source_policy.retired_hosts")
    return _unique(residual), _unique(retired)


def _vm_preconditions(vm_lifecycle: dict[str, Any], plane_id: str) -> list[str]:
    for raw_vm in ensure_list(vm_lifecycle.get("vms")):
        vm = ensure_dict(raw_vm)
        if str(vm.get("hostname") or "").strip() != plane_id:
            continue
        return _unique([str(item).strip() for item in ensure_list(vm.get("decommission_blocked_by")) if str(item).strip()])
    return []


def _active_relocation_preconditions(relocation_contract: dict[str, Any], plane_id: str) -> list[str]:
    refs: list[str] = []
    for raw_relocation in ensure_list(relocation_contract.get("relocations")):
        relocation = ensure_dict(raw_relocation)
        if str(relocation.get("status") or "").strip() != "active":
            continue
        relocation_id = str(relocation.get("id") or "").strip() or "unknown"
        source_vm = str(relocation.get("source_vm") or "").strip()
        target_vms = [str(item).strip() for item in ensure_list(relocation.get("target_vms")) if str(item).strip()]
        note = str(relocation.get("note") or "")
        if plane_id != source_vm and plane_id not in target_vms and plane_id not in note:
            continue
        gaps = [str(item).strip() for item in ensure_list(relocation.get("open_closure_gaps")) if str(item).strip()]
        if gaps:
            refs.extend([f"{relocation_id}: {gap}" for gap in gaps])
        else:
            refs.append(f"{relocation_id}: active relocation remains open")
    return _unique(refs)


def evaluate_readiness(root: Path, policy: dict[str, Any]) -> dict[str, Any]:
    lifecycle = load_yaml(root / "ops/bindings/service.data.lifecycle.registry.yaml")
    services_health = load_yaml(root / "ops/bindings/services.health.yaml")
    vm_lifecycle = load_yaml(root / "ops/bindings/vm.lifecycle.yaml")
    service_closure = load_yaml(root / "ops/bindings/service.closure.contract.yaml")
    relocation_contract = load_yaml(root / "ops/bindings/relocation.closure.contract.yaml")
    media_services = load_yaml(root / "ops/bindings/domains/media/media.services.yaml")

    service_planes = ensure_dict(policy.get("service_planes"))
    rows: list[dict[str, Any]] = []

    for plane_id in REQUIRED_CANDIDATE_PLANES:
        service_plane = ensure_dict(service_planes.get(plane_id))
        plane_status = str(service_plane.get("status") or "").strip()
        required_by = _family_members(policy, plane_id, dep_key="required_service_planes")
        optional_only = _family_members(
            policy,
            plane_id,
            dep_key="optional_service_planes",
            authority_key="residual_compatibility_planes",
        )
        planned_only = _family_members(
            policy,
            plane_id,
            dep_key="planned_service_planes",
            authority_key="planned_service_planes",
        )

        blocking_dependencies: list[str] = []
        observations: list[str] = []

        if required_by:
            blocking_dependencies.append(
                "required by families: " + ", ".join(required_by)
            )

        lifecycle_refs = _lifecycle_host_refs(lifecycle, plane_id)
        if lifecycle_refs:
            blocking_dependencies.append(
                "service.data.lifecycle.registry still references plane: " + "; ".join(lifecycle_refs)
            )

        health_endpoints = _health_endpoint_refs(services_health, plane_id)
        if health_endpoints:
            blocking_dependencies.append(
                "services.health still enables probes on plane: " + ", ".join(health_endpoints)
            )

        lifecycle_bindings = _health_lifecycle_bindings(services_health, plane_id)
        if lifecycle_bindings:
            blocking_dependencies.append(
                "services.health lifecycle bindings still resolve to plane: " + ", ".join(lifecycle_bindings)
            )

        active_media = _active_media_services(media_services, plane_id)
        if active_media:
            blocking_dependencies.append(
                "media.services still marks plane active for: " + ", ".join(active_media)
            )

        closure_residual, closure_retired = _closure_refs(service_closure, plane_id)
        if closure_residual:
            blocking_dependencies.append(
                "service.closure.contract still lists plane as residual source: " + ", ".join(closure_residual)
            )
        if closure_retired:
            observations.append(
                "service.closure.contract already classifies plane as retired host: " + ", ".join(closure_retired)
            )

        if planned_only:
            blocking_dependencies.append(
                "planned families still reference residual media plane: " + ", ".join(planned_only)
            )

        required_preconditions = _unique(
            _vm_preconditions(vm_lifecycle, plane_id) + _active_relocation_preconditions(relocation_contract, plane_id)
        )

        residual_only = plane_status == "residual" and not required_by
        safe_to_retire = residual_only and not blocking_dependencies and not required_preconditions

        if safe_to_retire:
            status = "ready_to_retire"
        elif blocking_dependencies:
            status = "blocked_by_governed_dependencies"
        elif required_preconditions:
            status = "preconditions_pending"
        else:
            status = "not_ready"

        rows.append(
            {
                "plane_id": plane_id,
                "plane_type": "service_plane",
                "readiness_status": status,
                "required_by_families": required_by,
                "optional_only_families": [family for family in optional_only if family not in required_by],
                "planned_only_families": planned_only,
                "residual_only": residual_only,
                "safe_to_retire": safe_to_retire,
                "blocking_dependencies": _unique(blocking_dependencies),
                "required_preconditions": required_preconditions,
                "description": str(service_plane.get("description") or "").strip(),
                "observations": _unique(observations),
            }
        )

    return {
        "candidate_planes": rows,
        "summary": {
            "candidate_count": len(rows),
            "ready_count": len([row for row in rows if row.get("safe_to_retire")]),
            "blocked_count": len(
                [row for row in rows if str(row.get("readiness_status")) == "blocked_by_governed_dependencies"]
            ),
            "precondition_blocked_count": len(
                [row for row in rows if str(row.get("readiness_status")) == "preconditions_pending"]
            ),
        },
    }


def build_projection(
    root: Path,
    policy: dict[str, Any],
    *,
    source_sha256: str,
    generated_at_utc: str,
) -> dict[str, Any]:
    snapshot = evaluate_readiness(root, policy)
    return {
        "version": 1,
        "status": "projection",
        "authority_state": "projection",
        "projection_of": "ops/bindings/domains/media/content.family.placement.policy.yaml",
        "source_capability": "content.family.decommission.readiness.build",
        "supporting_sources": [
            rel(root, path)
            for path in source_paths(root)
        ],
        "source_sha256": source_sha256,
        "generated_at_utc": generated_at_utc,
        "candidate_planes": snapshot["candidate_planes"],
        "summary": snapshot["summary"],
    }


def render_markdown(projection: dict[str, Any]) -> str:
    lines = [
        "---",
        "status: generated",
        "owner: \"@ronny\"",
        "scope: content-family-decommission-readiness",
        "---",
        "",
        "# Content Family Decommission Readiness",
        "",
        "Generated from `ops/bindings/domains/media/content.family.placement.policy.yaml` and the linked lifecycle/closure surfaces.",
        "",
        "| Plane | Type | Required By | Optional Only | Planned Only | Residual Only | Safe Now? | Blocking Dependencies | Required Preconditions |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for raw_row in ensure_list(projection.get("candidate_planes")):
        row = ensure_dict(raw_row)
        required_by = ", ".join(ensure_list(row.get("required_by_families"))) or "none"
        optional_only = ", ".join(ensure_list(row.get("optional_only_families"))) or "none"
        planned_only = ", ".join(ensure_list(row.get("planned_only_families"))) or "none"
        blockers = "<br>".join(ensure_list(row.get("blocking_dependencies"))) or "none"
        preconditions = "<br>".join(ensure_list(row.get("required_preconditions"))) or "none"
        lines.append(
            "| {plane_id} | {plane_type} | {required_by} | {optional_only} | {planned_only} | {residual_only} | {safe_to_retire} | {blockers} | {preconditions} |".format(
                plane_id=str(row.get("plane_id") or ""),
                plane_type=str(row.get("plane_type") or ""),
                required_by=required_by,
                optional_only=optional_only,
                planned_only=planned_only,
                residual_only="yes" if bool(row.get("residual_only")) else "no",
                safe_to_retire="yes" if bool(row.get("safe_to_retire")) else "no",
                blockers=blockers,
                preconditions=preconditions,
            )
        )
    lines.append("")
    return "\n".join(lines)


def validate_projection(
    policy: dict[str, Any],
    projection_on_disk: dict[str, Any] | None,
    expected_projection: dict[str, Any],
) -> list[Issue]:
    issues: list[Issue] = []
    families = ensure_dict(policy.get("families"))
    service_planes = ensure_dict(policy.get("service_planes"))

    expected_rows = {
        str(ensure_dict(row).get("plane_id") or ""): ensure_dict(row)
        for row in ensure_list(expected_projection.get("candidate_planes"))
    }
    projection_rows = {
        str(ensure_dict(row).get("plane_id") or ""): ensure_dict(row)
        for row in ensure_list(ensure_dict(projection_on_disk).get("candidate_planes"))
    }

    for plane_id in REQUIRED_CANDIDATE_PLANES:
        if plane_id not in service_planes:
            issues.append(Issue("error", f"{plane_id}: missing residual service plane declaration in content family policy"))
            continue
        plane = ensure_dict(service_planes.get(plane_id))
        if str(plane.get("status") or "").strip() != "residual":
            issues.append(Issue("error", f"{plane_id}: service plane must stay status residual for decommission readiness tracking"))
        if plane_id not in expected_rows:
            issues.append(Issue("error", f"{plane_id}: readiness snapshot missing from generated projection"))
            continue
        row = expected_rows[plane_id]
        required_by = [str(item).strip() for item in ensure_list(row.get("required_by_families")) if str(item).strip()]
        planned_only = [str(item).strip() for item in ensure_list(row.get("planned_only_families")) if str(item).strip()]
        blockers = [str(item).strip() for item in ensure_list(row.get("blocking_dependencies")) if str(item).strip()]
        preconditions = [str(item).strip() for item in ensure_list(row.get("required_preconditions")) if str(item).strip()]
        safe = bool(row.get("safe_to_retire"))
        if required_by and safe:
            issues.append(Issue("error", f"{plane_id}: cannot be safe_to_retire while still required by {', '.join(required_by)}"))
        if blockers and safe:
            issues.append(Issue("error", f"{plane_id}: cannot be safe_to_retire while governed blockers remain"))
        if preconditions and safe:
            issues.append(Issue("error", f"{plane_id}: cannot be safe_to_retire while decommission preconditions remain"))
        if planned_only:
            issues.append(Issue("error", f"{plane_id}: planned families backdoor residual media plane usage ({', '.join(planned_only)})"))

    games = ensure_dict(families.get("games"))
    games_deps = ensure_dict(games.get("decommission_dependencies"))
    prohibited = {str(item).strip() for item in ensure_list(games_deps.get("prohibited_future_placeholders")) if str(item).strip()}
    for plane_id in REQUIRED_CANDIDATE_PLANES:
        if plane_id not in prohibited:
            issues.append(Issue("error", f"games: prohibited_future_placeholders must include {plane_id}"))

    if projection_on_disk is not None and ensure_dict(projection_on_disk) != expected_projection:
        issues.append(Issue("error", "content.family.decommission.readiness.projected.yaml drifted from authoritative family truth"))

    return issues
