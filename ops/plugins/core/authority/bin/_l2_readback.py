#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[5]
POLICY = ROOT / "ops/bindings/secrets.namespace.policy.yaml"
RUNWAY = ROOT / "ops/bindings/secrets.runway.contract.yaml"
INVENTORY = ROOT / "ops/bindings/secrets.inventory.yaml"
ONBOARDING = ROOT / "ops/bindings/service.onboarding.contract.yaml"
SAFE_CONTRACT = ROOT / "ops/bindings/l2.courthouse.safe.contract.yaml"

TOKEN_CLASSES = {
    "API_KEY": ("_API_KEY", "APIKEY"),
    "CLIENT_SECRET": ("_CLIENT_SECRET", "CLIENT_SECRET"),
    "WEBHOOK_SECRET": ("_WEBHOOK_SECRET", "WEBHOOK_SECRET"),
    "RUNNER_TOKEN": ("_RUNNER_TOKEN", "RUNNER_TOKEN"),
    "DEPLOY_KEY": ("_DEPLOY_KEY", "DEPLOY_KEY"),
    "TOKEN": ("_TOKEN", "TOKEN"),
}
UNSANCTIONED_MECHANISMS = {"direct-cli", "hardcoded", "unknown"}


def fail(message: str, code: int = 1) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(code)


def load_yaml(path: Path) -> dict[str, Any]:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except FileNotFoundError:
        return {}
    if not isinstance(data, dict):
        return {}
    return data


def as_map(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def as_list(value: Any) -> list[Any]:
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def emit(title: str, payload: dict[str, Any], json_out: bool) -> None:
    if json_out:
        print(json.dumps(payload, indent=2, sort_keys=True))
        return
    print(title)
    print(f"status: {payload.get('status')}")
    for key, value in payload.items():
        if key in {"capability", "status", "rows"}:
            continue
        if isinstance(value, (dict, list)):
            print(f"{key}: {json.dumps(value, sort_keys=True)}")
        else:
            print(f"{key}: {value}")
    for row in payload.get("rows") or []:
        print("")
        print(f"- {row.get('id')}")
        for key, value in row.items():
            if key == "id":
                continue
            if isinstance(value, (dict, list)):
                print(f"  {key}: {json.dumps(value, sort_keys=True)}")
            else:
                print(f"  {key}: {value}")


def path_domain(path: str) -> str:
    parts = [part for part in path.split("/") if part]
    if "services" in parts:
        idx = parts.index("services")
        if idx + 1 < len(parts):
            return parts[idx + 1]
    if "vm-infra" in parts:
        return "forge" if "gitea" in parts else "infra"
    if "platform" in parts:
        return "platform"
    if "network" in parts:
        return "network"
    return "unknown"


def key_routes() -> dict[str, dict[str, Any]]:
    policy = load_yaml(POLICY)
    rules = as_map(policy.get("rules"))
    runway = load_yaml(RUNWAY)
    routes: dict[str, dict[str, Any]] = {}

    for section in ["required_key_paths", "planned_key_paths", "key_path_overrides"]:
        for key, path in as_map(rules.get(section)).items():
            if isinstance(path, str):
                routes[str(key)] = {
                    "key_name": str(key),
                    "project": "unknown",
                    "namespace": path,
                    "declared_consumer": path_domain(path),
                    "source": "ops/bindings/secrets.namespace.policy.yaml",
                }

    for key, data in as_map(runway.get("key_overrides")).items():
        if isinstance(data, dict):
            row = routes.setdefault(str(key), {"key_name": str(key), "source": "ops/bindings/secrets.runway.contract.yaml"})
            row["project"] = data.get("project", row.get("project", "unknown"))
            row["namespace"] = data.get("path", row.get("namespace", ""))
            row["canonical_key"] = data.get("canonical_key")
            row["declared_consumer"] = path_domain(str(row.get("namespace", "")))
            row["source"] = "ops/bindings/secrets.runway.contract.yaml"

    for stack, overrides in as_map(runway.get("stack_key_overrides")).items():
        if not isinstance(overrides, dict):
            continue
        for key, data in overrides.items():
            if isinstance(data, dict):
                row = routes.setdefault(str(key), {"key_name": str(key), "source": "ops/bindings/secrets.runway.contract.yaml"})
                row["project"] = data.get("project", row.get("project", "unknown"))
                row["namespace"] = data.get("path", row.get("namespace", ""))
                row["canonical_key"] = data.get("canonical_key")
                row["declared_consumer"] = str(stack)
                row["source"] = "ops/bindings/secrets.runway.contract.yaml"

    return routes


def project_lifecycle() -> dict[str, dict[str, Any]]:
    inventory = load_yaml(INVENTORY)
    projects = {}
    for item in as_list(inventory.get("projects")):
        if isinstance(item, dict) and item.get("name"):
            projects[str(item["name"])] = {
                "project_health": item.get("project_health", "unknown"),
                "lifecycle": item.get("lifecycle", item.get("project_health", "unknown")),
                "last_synced": as_map(inventory.get("source")).get("last_synced"),
            }
    return projects


def safe_contract() -> dict[str, Any]:
    return load_yaml(SAFE_CONTRACT)


def class_for_key(key: str) -> str | None:
    upper = key.upper()
    for token_class, markers in TOKEN_CLASSES.items():
        if any(marker in upper for marker in markers):
            if token_class == "TOKEN" and any(other in upper for other in ["RUNNER_TOKEN", "API_KEY"]):
                continue
            return token_class
    return None


def domain_matches(row: dict[str, Any], domain: str | None) -> bool:
    if not domain:
        return True
    haystack = " ".join(str(row.get(key, "")) for key in ["id", "key_name", "namespace", "declared_consumer", "project"]).lower()
    return domain.lower() in haystack


def service_matches(row: dict[str, Any], service: str | None) -> bool:
    if not service:
        return True
    return service.lower() in str(row.get("declared_consumer", "")).lower()


def namespace_matches(row: dict[str, Any], namespace: str | None) -> bool:
    if not namespace:
        return True
    return str(row.get("namespace", "")).startswith(namespace)


def reference_rows(domain: str | None = None, service: str | None = None, namespace: str | None = None) -> list[dict[str, Any]]:
    routes = key_routes()
    lifecycles = project_lifecycle()
    rows: list[dict[str, Any]] = []
    for key, data in sorted(routes.items()):
        project = str(data.get("project") or "unknown")
        lifecycle = lifecycles.get(project, {})
        row = {
            "id": key,
            "key_name": key,
            "project": project,
            "namespace": data.get("namespace", ""),
            "lifecycle": lifecycle.get("lifecycle", "unknown"),
            "project_health": lifecycle.get("project_health", "unknown"),
            "declared_consumer": data.get("declared_consumer", "unknown"),
            "last_synced": lifecycle.get("last_synced"),
            "injection_mechanism": "declared_reference_only",
            "sanctioned_by_contract": True,
            "value_read": False,
            "source": data.get("source"),
        }
        if domain_matches(row, domain) and service_matches(row, service) and namespace_matches(row, namespace):
            rows.append(row)

    modules = as_map(as_map(load_yaml(POLICY).get("rules")).get("module_namespaces"))
    for module, path in sorted(modules.items()):
        row = {
            "id": f"module:{module}",
            "key_name": f"module:{module}",
            "project": "module_namespace",
            "namespace": path,
            "lifecycle": "declared",
            "project_health": "declared",
            "declared_consumer": str(module),
            "last_synced": None,
            "injection_mechanism": "declared_reference_only",
            "sanctioned_by_contract": True,
            "value_read": False,
            "source": "ops/bindings/secrets.namespace.policy.yaml",
        }
        if domain_matches(row, domain) and service_matches(row, service) and namespace_matches(row, namespace):
            rows.append(row)
    return rows


def secret_reference_status(args: argparse.Namespace) -> dict[str, Any]:
    rows = reference_rows(args.domain, args.service, args.namespace)
    if args.unsanctioned_only:
        rows = [row for row in rows if row.get("injection_mechanism") in UNSANCTIONED_MECHANISMS or not row.get("sanctioned_by_contract")]
    return {
        "capability": "secret.reference.status",
        "status": "ok",
        "value_disclosure": "none",
        "sources": [
            "ops/bindings/secrets.namespace.policy.yaml",
            "ops/bindings/secrets.runway.contract.yaml",
            "ops/bindings/secrets.inventory.yaml",
            "ops/bindings/service.onboarding.contract.yaml",
        ],
        "rows": rows,
        "summary": {"references": len(rows), "values_read": 0},
    }


def token_custody_status(args: argparse.Namespace) -> dict[str, Any]:
    rows = []
    for row in reference_rows(args.domain, None, None):
        token_class = class_for_key(str(row.get("key_name", "")))
        if not token_class:
            continue
        if args.token_class and token_class != args.token_class:
            continue
        rotation_posture = "not_declared"
        token_row = {
            "id": row["id"],
            "token_class": token_class,
            "custody": "safe",
            "owner_path": row.get("namespace"),
            "declared_consumer": row.get("declared_consumer"),
            "rotation_posture": rotation_posture,
            "last_seen_in_inventory": row.get("last_synced"),
            "value_read": False,
            "source": row.get("source"),
        }
        if args.no_rotation_posture and rotation_posture != "not_declared":
            continue
        rows.append(token_row)
    return {
        "capability": "token.custody.status",
        "status": "ok",
        "custody_boundary": "safe stores values; courthouse/service bindings store references",
        "token_classes": sorted(TOKEN_CLASSES),
        "rows": rows,
        "summary": {"tokens_or_secretlike_refs": len(rows), "values_read": 0},
    }


def secret_injection_status(args: argparse.Namespace) -> dict[str, Any]:
    runway = load_yaml(RUNWAY)
    onboarding = load_yaml(ONBOARDING)
    rows = [
        {
            "id": "consumer_path:bash",
            "consumer": "bash",
            "mechanism": "infisical-agent.sh",
            "sanctioned_by_contract": True,
            "source": "ops/bindings/service.onboarding.contract.yaml",
        },
        {
            "id": "consumer_path:service",
            "consumer": "service",
            "mechanism": "secrets-exec",
            "sanctioned_by_contract": True,
            "source": "ops/bindings/service.onboarding.contract.yaml",
        },
    ]
    for stack, data in sorted(as_map(runway.get("stack_defaults")).items()):
        if args.domain and args.domain not in str(data.get("domain", "")) and args.domain not in stack:
            continue
        rows.append(
            {
                "id": f"stack:{stack}",
                "consumer": stack,
                "mechanism": "declared_namespace_route",
                "project": data.get("project"),
                "namespace": data.get("path"),
                "domain": data.get("domain"),
                "sanctioned_by_contract": True,
                "source": "ops/bindings/secrets.runway.contract.yaml",
            }
        )
    for domain, data in sorted(as_map(runway.get("domain_defaults")).items()):
        if args.domain and args.domain != domain:
            continue
        rows.append(
            {
                "id": f"domain:{domain}",
                "consumer": domain,
                "mechanism": "declared_namespace_route",
                "project": data.get("project"),
                "namespace": data.get("path"),
                "domain": domain,
                "sanctioned_by_contract": True,
                "source": "ops/bindings/secrets.runway.contract.yaml",
            }
        )
    for item in as_list(onboarding.get("boring_onboarding_checklist")):
        if isinstance(item, dict) and item.get("question") == "consumer_path":
            rows.append(
                {
                    "id": "onboarding:consumer_path",
                    "consumer": "new-service",
                    "mechanism": "contract_choice",
                    "allowed": item.get("options", []),
                    "sanctioned_by_contract": True,
                    "source": "ops/bindings/service.onboarding.contract.yaml",
                }
            )
    if args.unsanctioned_only:
        rows = [row for row in rows if row.get("mechanism") in UNSANCTIONED_MECHANISMS or not row.get("sanctioned_by_contract")]
    return {
        "capability": "secret.injection.status",
        "status": "ok",
        "mutation": "none",
        "value_disclosure": "none",
        "rows": rows,
        "summary": {"injection_routes": len(rows), "unsanctioned": sum(1 for row in rows if not row.get("sanctioned_by_contract"))},
    }


def domain_core_status(args: argparse.Namespace) -> dict[str, Any]:
    contract = safe_contract()
    domains = as_map(contract.get("domains"))
    if args.domain:
        selected = {args.domain: domains.get(args.domain)}
        if selected[args.domain] is None:
            pointer = as_map(contract.get("phase_1_pointer")).get("source", "L2 Phase 1 domain fan-out")
            fail(f"unknown Phase 0 domain: {args.domain}; non-forge/safe domains fan out in {pointer}", 2)
    else:
        selected = domains

    rows = []
    for name, data in selected.items():
        if not isinstance(data, dict):
            continue
        row = {
            "id": name,
            "class": data.get("class"),
            "courthouse_class": data.get("courthouse_class"),
            "source_body": data.get("source_body"),
            "runtime_surface": data.get("runtime_surface"),
            "runtime_node_placement": data.get("runtime_node_placement"),
            "canonical_routes": as_list(data.get("canonical_routes")),
            "canonical_source_routes": as_list(data.get("canonical_source_routes")),
            "publication_class": data.get("publication_class"),
            "publication_routes": as_list(data.get("publication_routes")),
            "secret_namespaces": as_list(data.get("secret_namespaces")),
            "token_classes": as_list(data.get("token_classes")),
            "backup_targets": as_list(data.get("backup_targets")),
            "restore_proof_age": data.get("restore_proof_age", "unknown"),
            "observability_probe": data.get("observability_probe", "unknown"),
            "value_disclosure": "none",
            "source": "ops/bindings/l2.courthouse.safe.contract.yaml",
        }
        if args.summary:
            row = {
                "id": name,
                "class": row["class"],
                "courthouse_class": row["courthouse_class"],
                "publication_class": row["publication_class"],
                "source_body": row["source_body"],
                "runtime_node_placement": row["runtime_node_placement"],
                "value_disclosure": "none",
            }
        rows.append(row)
    return {
        "capability": "domain.core.status",
        "status": "ok",
        "phase": "PACKET-518 Phase 0 readback eyes",
        "rows": rows,
        "summary": {"domains": len(rows)},
    }


def courthouse_safe_status(args: argparse.Namespace) -> dict[str, Any]:
    contract = safe_contract()
    boundary = as_map(contract.get("boundary"))
    rows = []
    for name, data in sorted(as_map(contract.get("domains")).items()):
        if not isinstance(data, dict):
            continue
        rows.append(
            {
                "id": name,
                "class": data.get("class"),
                "courthouse_class": data.get("courthouse_class"),
                "publication_class": data.get("publication_class"),
                "courthouse_stores": data.get("courthouse_stores"),
                "safe_stores": data.get("safe_stores"),
                "secret_namespaces": as_list(data.get("secret_namespaces")),
                "token_classes": as_list(data.get("token_classes")),
                "value_disclosure": "none",
            }
        )
    return {
        "capability": "courthouse.safe.status",
        "status": "ok",
        "boundary": boundary,
        "courthouse_classes": safe_contract().get("courthouse_classes", {}),
        "publication_classes": safe_contract().get("publication_classes", {}),
        "rows": rows,
        "summary": {"domains": len(rows), "values_read": 0},
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Read-only L2 courthouse/safe readback helpers")
    parser.add_argument("surface", choices=[
        "secret.reference.status",
        "token.custody.status",
        "secret.injection.status",
        "domain.core.status",
        "courthouse.safe.status",
    ])
    parser.add_argument("--domain")
    parser.add_argument("--service")
    parser.add_argument("--namespace")
    parser.add_argument("--unsanctioned-only", action="store_true")
    parser.add_argument("--class", dest="token_class", choices=sorted(TOKEN_CLASSES))
    parser.add_argument("--no-rotation-posture", action="store_true")
    parser.add_argument("--summary", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()

    required = [POLICY, RUNWAY, INVENTORY, ONBOARDING, SAFE_CONTRACT]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        fail(f"missing required binding(s): {', '.join(missing)}", 2)
    if args.self_check:
        print(f"{args.surface}: self-check ok")
        return

    builders = {
        "secret.reference.status": secret_reference_status,
        "token.custody.status": token_custody_status,
        "secret.injection.status": secret_injection_status,
        "domain.core.status": domain_core_status,
        "courthouse.safe.status": courthouse_safe_status,
    }
    payload = builders[args.surface](args)
    emit(args.surface, payload, args.json)


if __name__ == "__main__":
    main()
