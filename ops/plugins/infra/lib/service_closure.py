#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
import re
import shlex
import subprocess
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[4]
DEFAULT_CONTRACT_PATH = ROOT / "ops/bindings/service.closure.contract.yaml"
DEFAULT_ROUTE_REGISTRY = ROOT / "ops/bindings/domain.routing.registry.yaml"
DEFAULT_INGRESS_PROJECTION = ROOT / "ops/bindings/shop.ingress.map.yaml"
DEFAULT_SERVICES_HEALTH = ROOT / "ops/bindings/services.health.yaml"
DEFAULT_BACKUP_SCHEDULE = ROOT / "ops/bindings/backup.schedule.yaml"
DEFAULT_BACKUP_INVENTORY = ROOT / "ops/bindings/backup.inventory.yaml"
DEFAULT_SERVICE_DATA_LIFECYCLE = ROOT / "ops/bindings/service.data.lifecycle.registry.yaml"
DEFAULT_SSH_TARGETS = ROOT / "ops/bindings/ssh.targets.yaml"
DEFAULT_AGENTS_REGISTRY = ROOT / "ops/bindings/agents.registry.yaml"
DEFAULT_WORKER_CATALOG = ROOT / "ops/bindings/terminal.worker.catalog.yaml"
DEFAULT_SECRETS_BUNDLE_CONTRACT = ROOT / "ops/bindings/secrets.bundle.contract.yaml"
DEFAULT_RUNTIME_SERVICES = ROOT / "ops/bindings/media.services.yaml"
DEFAULT_CF_INGRESS_SCRIPT = ROOT / "ops/plugins/providers/cloudflare/bin/cloudflare-tunnel-ingress-status"
DEFAULT_SSH_RESOLVE_PATH = ROOT / "ops/lib/ssh-resolve.sh"


def ensure_dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def ensure_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_yaml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(path)
    with path.open("r", encoding="utf-8") as handle:
        payload = yaml.safe_load(handle) or {}
    if not isinstance(payload, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return payload


def yaml_dump(data: dict[str, Any]) -> str:
    return yaml.safe_dump(data, sort_keys=False, allow_unicode=False)


def json_dump(data: dict[str, Any]) -> str:
    return json.dumps(data, indent=2, sort_keys=False)


def resolve_env_path(env_name: str, default_path: Path) -> Path:
    value = os.environ.get(env_name, "").strip()
    return Path(value).expanduser().resolve() if value else default_path


def resolve_default_source_path(env_name: str, default_path: Path, contract_default: str | None = None) -> Path:
    value = os.environ.get(env_name, "").strip()
    if value:
        return Path(value).expanduser().resolve()
    return resolve_contract_path(contract_default, default_path)


def resolve_contract_path(ref: str | None, default_path: Path) -> Path:
    value = str(ref or "").strip()
    if not value:
        return default_path
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = ROOT / path
    return path.resolve()


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def compile_patterns(patterns: list[str]) -> list[re.Pattern[str]]:
    return [re.compile(pattern) for pattern in patterns if str(pattern).strip()]


def matches_any(patterns: list[re.Pattern[str]], text: str) -> bool:
    if not patterns:
        return True
    return any(pattern.search(text or "") for pattern in patterns)


def add_check(
    checks: list[dict[str, Any]],
    mismatches: list[dict[str, Any]],
    *,
    kind: str,
    status: str,
    code: str,
    message: str,
    severity: str = "high",
    host: str = "",
    path: str = "",
    extra: dict[str, Any] | None = None,
) -> None:
    row = {
        "kind": kind,
        "status": status,
        "code": code,
        "message": message,
    }
    if host:
        row["host"] = host
    if path:
        row["path"] = path
    if extra:
        row.update(extra)
    checks.append(row)
    if status in {"fail", "warn"}:
        mismatch = {
            "domain": "",
            "severity": severity,
            "code": code,
            "host": host,
            "path": path,
            "message": message,
        }
        if extra:
            mismatch.update({k: v for k, v in extra.items() if k not in {"status"}})
        mismatches.append(mismatch)


class SSHProbe:
    def __init__(self, ssh_targets_path: Path) -> None:
        self.ssh_targets_path = ssh_targets_path
        self.ssh_targets = ensure_dict(load_yaml(ssh_targets_path).get("ssh"))
        self.defaults = ensure_dict(self.ssh_targets.get("defaults"))
        self.targets = {
            str(entry.get("id") or "").strip(): entry
            for entry in ensure_list(self.ssh_targets.get("targets"))
            if isinstance(entry, dict) and str(entry.get("id") or "").strip()
        }
        self.ssh_bin = os.environ.get("SPINE_SERVICE_CLOSURE_SSH_BIN", "").strip() or "ssh"
        self.resolve_script = resolve_env_path("SPINE_SERVICE_CLOSURE_SSH_RESOLVE", DEFAULT_SSH_RESOLVE_PATH)

    def target_row(self, target_id: str) -> dict[str, Any]:
        return ensure_dict(self.targets.get(target_id))

    def _local_ssh_opts(self, port: int, timeout: int) -> list[str]:
        return [
            "-n",
            "-o",
            f"ConnectTimeout={timeout}",
            "-o",
            "BatchMode=yes",
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "-o",
            "LogLevel=ERROR",
            "-p",
            str(port),
        ]

    def resolve_target(self, target_id: str, *, timeout: int = 6) -> dict[str, Any]:
        row = self.target_row(target_id)
        if not row:
            return {"target_id": target_id, "error": "unknown_ssh_target"}

        user = str(row.get("user") or self.defaults.get("user") or "root").strip()
        port = int(row.get("port") or self.defaults.get("port") or 22)
        candidates: list[tuple[str, str]] = []
        host = str(row.get("host") or "").strip()
        tailscale_ip = str(row.get("tailscale_ip") or "").strip()
        if host:
            candidates.append((host, "host"))
        if tailscale_ip and tailscale_ip != host:
            candidates.append((tailscale_ip, "tailscale_ip"))

        if self.resolve_script.is_file():
            script = "\n".join(
                [
                    f"source {shlex.quote(str(self.resolve_script))}",
                    f"read -r resolved_host path_used <<< \"$(ssh_resolve_ssh_host_with_fallback {shlex.quote(target_id)} {timeout} || true)\"",
                    'printf "%s\\t%s\\n" "$resolved_host" "$path_used"',
                ]
            )
            run = subprocess.run(
                ["/bin/bash", "-lc", script],
                capture_output=True,
                text=True,
                cwd=ROOT,
            )
            if run.returncode == 0:
                parts = (run.stdout or "").strip().split("\t")
                resolved_host = parts[0].strip() if parts else ""
                path_used = parts[1].strip() if len(parts) > 1 else ""
                if resolved_host and path_used != "unreachable":
                    return {
                        "target_id": target_id,
                        "user": user,
                        "port": port,
                        "host": resolved_host,
                        "path_used": path_used or "resolved",
                        "row": row,
                    }

        if candidates:
            return {
                "target_id": target_id,
                "user": user,
                "port": port,
                "host": candidates[0][0],
                "path_used": candidates[0][1],
                "row": row,
            }
        return {"target_id": target_id, "error": "ssh_target_missing_host", "row": row}

    def ssh_capture(self, target_id: str, remote_script: str, *, timeout: int = 8) -> dict[str, Any]:
        resolved = self.resolve_target(target_id, timeout=timeout)
        if resolved.get("error"):
            return {
                "ok": False,
                "target_id": target_id,
                "returncode": 255,
                "stdout": "",
                "stderr": str(resolved["error"]),
                "path_used": "unresolved",
            }

        cmd = [
            self.ssh_bin,
            *self._local_ssh_opts(int(resolved["port"]), timeout),
            f"{resolved['user']}@{resolved['host']}",
            remote_script,
        ]
        run = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
        return {
            "ok": run.returncode == 0,
            "target_id": target_id,
            "returncode": run.returncode,
            "stdout": run.stdout or "",
            "stderr": run.stderr or "",
            "path_used": str(resolved.get("path_used") or ""),
            "command": " ".join(shlex.quote(part) for part in cmd),
            "target_row": resolved.get("row") or {},
        }


def parse_cloudflare_ingress_output(text: str) -> dict[str, str]:
    routes: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line.startswith("- "):
            continue
        body = line[2:]
        if " -> " not in body:
            continue
        hostname, target = body.split(" -> ", 1)
        hostname = hostname.strip()
        target = target.strip()
        if hostname and hostname != "(catch-all)":
            routes[hostname] = target
    return routes


def load_live_cloudflare_routes(contract_defaults: dict[str, Any]) -> tuple[dict[str, str], str | None]:
    ingress_file = os.environ.get("SPINE_SERVICE_CLOSURE_CF_INGRESS_FILE", "").strip()
    if ingress_file:
        return parse_cloudflare_ingress_output(Path(ingress_file).read_text(encoding="utf-8")), None

    command = os.environ.get("SPINE_SERVICE_CLOSURE_CF_INGRESS_CMD", "").strip()
    if command:
        run = subprocess.run(command, shell=True, capture_output=True, text=True, cwd=ROOT)
    else:
        tunnel_name = str(contract_defaults.get("cloudflare_tunnel_name") or "homelab-tunnel").strip()
        script_path = resolve_env_path("SPINE_SERVICE_CLOSURE_CF_INGRESS_SCRIPT", DEFAULT_CF_INGRESS_SCRIPT)
        run = subprocess.run(
            [str(script_path), "--tunnel", tunnel_name],
            capture_output=True,
            text=True,
            cwd=ROOT,
        )
    if run.returncode != 0:
        message = (run.stderr or run.stdout or "").strip() or "cloudflare_ingress_probe_failed"
        return {}, message
    return parse_cloudflare_ingress_output(run.stdout or ""), None


def flatten_route_registry(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows: dict[str, dict[str, Any]] = {}
    for zone in ensure_list(payload.get("zones")):
        zone_name = str(ensure_dict(zone).get("zone") or "").strip()
        for item in ensure_list(ensure_dict(zone).get("hostnames")):
            row = dict(ensure_dict(item))
            hostname = str(row.get("hostname") or "").strip()
            if not hostname:
                continue
            row["zone"] = zone_name
            rows[hostname] = row
    return rows


def flatten_ingress_projection(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows: dict[str, dict[str, Any]] = {}
    for item in ensure_list(payload.get("public_routes")):
        row = dict(ensure_dict(item))
        hostname = str(row.get("hostname") or "").strip()
        if hostname:
            rows[hostname] = row
    return rows


def load_services_health(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(row.get("id") or "").strip(): row
        for row in ensure_list(payload.get("endpoints"))
        if isinstance(row, dict) and str(row.get("id") or "").strip()
    }


def load_backup_jobs(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(row.get("id") or "").strip(): row
        for row in ensure_list(payload.get("jobs"))
        if isinstance(row, dict) and str(row.get("id") or "").strip()
    }


def load_backup_targets(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(row.get("name") or "").strip(): row
        for row in ensure_list(payload.get("targets"))
        if isinstance(row, dict) and str(row.get("name") or "").strip()
    }


def load_backup_runtime_units(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(row.get("unit_id") or "").strip(): row
        for row in ensure_list(payload.get("runtime_units"))
        if isinstance(row, dict) and str(row.get("unit_id") or "").strip()
    }


def load_lifecycle_services(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(key).strip(): ensure_dict(value)
        for key, value in ensure_dict(payload.get("services")).items()
        if str(key).strip()
    }


def load_agents_registry(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(row.get("id") or "").strip(): row
        for row in ensure_list(payload.get("agents"))
        if isinstance(row, dict) and str(row.get("id") or "").strip()
    }


def load_worker_catalog(payload: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {
        str(key).strip(): ensure_dict(value)
        for key, value in ensure_dict(payload.get("workers")).items()
        if str(key).strip()
    }


def load_secret_bundles(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(key).strip(): ensure_dict(value)
        for key, value in ensure_dict(payload.get("bundles")).items()
        if str(key).strip()
    }


def load_runtime_services(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(key).strip(): ensure_dict(value)
        for key, value in ensure_dict(payload.get("services")).items()
        if str(key).strip()
    }


def closure_posture(mismatches: list[dict[str, Any]]) -> str:
    if any(str(row.get("severity") or "") == "high" for row in mismatches):
        return "fail"
    if mismatches:
        return "warn"
    return "pass"


def audit_closure(
    closure: dict[str, Any],
    *,
    route_registry_rows: dict[str, dict[str, Any]],
    ingress_projection_rows: dict[str, dict[str, Any]],
    live_cloudflare_rows: dict[str, str],
    live_cloudflare_error: str | None,
    services_health_rows: dict[str, dict[str, Any]],
    backup_job_rows: dict[str, dict[str, Any]],
    backup_target_rows: dict[str, dict[str, Any]],
    backup_runtime_unit_rows: dict[str, dict[str, Any]],
    lifecycle_service_rows: dict[str, dict[str, Any]],
    agent_rows: dict[str, dict[str, Any]],
    worker_rows: dict[str, dict[str, Any]],
    secret_bundle_rows: dict[str, dict[str, Any]],
    runtime_service_rows: dict[str, dict[str, Any]],
    ssh_probe: SSHProbe,
) -> dict[str, Any]:
    closure_id = str(closure.get("id") or "").strip()
    domain = str(closure.get("domain") or "").strip()
    checks: list[dict[str, Any]] = []
    mismatches: list[dict[str, Any]] = []
    active_plane = ensure_dict(closure.get("active_plane"))
    active_host = str(active_plane.get("host") or "").strip()

    for route in ensure_list(ensure_dict(closure.get("public_routes")).get("routes")):
        route_row = ensure_dict(route)
        hostname = str(route_row.get("hostname") or "").strip()
        expected_service = str(route_row.get("service") or "").strip()
        expected_stacks = [str(item).strip() for item in ensure_list(route_row.get("expected_stack_aliases")) if str(item).strip()]
        patterns = compile_patterns([str(item).strip() for item in ensure_list(route_row.get("expected_target_patterns")) if str(item).strip()])

        registry_row = ensure_dict(route_registry_rows.get(hostname))
        if not registry_row:
            add_check(
                checks,
                mismatches,
                kind="route_registry",
                status="fail",
                code="route_registry_missing",
                severity="high",
                host=active_host,
                path=hostname,
                message=f"{hostname} missing from route registry",
            )
        else:
            registry_service = str(registry_row.get("service") or "").strip()
            registry_stack = str(registry_row.get("stack") or "").strip()
            registry_target = str(registry_row.get("target_hint") or "").strip()
            if expected_service and registry_service != expected_service:
                add_check(
                    checks,
                    mismatches,
                    kind="route_registry",
                    status="fail",
                    code="route_registry_service_mismatch",
                    severity="high",
                    host=active_host,
                    path=hostname,
                    message=f"{hostname} route registry service={registry_service} expected={expected_service}",
                )
            elif expected_stacks and registry_stack not in expected_stacks:
                add_check(
                    checks,
                    mismatches,
                    kind="route_registry",
                    status="fail",
                    code="route_registry_stack_mismatch",
                    severity="high",
                    host=registry_stack or active_host,
                    path=hostname,
                    message=f"{hostname} route registry stack={registry_stack} does not match active plane {expected_stacks}",
                )
            elif not matches_any(patterns, registry_target):
                add_check(
                    checks,
                    mismatches,
                    kind="route_registry",
                    status="fail",
                    code="route_registry_target_mismatch",
                    severity="high",
                    host=registry_stack or active_host,
                    path=hostname,
                    message=f"{hostname} route registry target_hint={registry_target!r} does not match expected active plane patterns",
                )
            else:
                add_check(
                    checks,
                    mismatches,
                    kind="route_registry",
                    status="pass",
                    code="route_registry_ok",
                    host=active_host,
                    path=hostname,
                    message=f"{hostname} route registry matches active plane",
                )

        projection_row = ensure_dict(ingress_projection_rows.get(hostname))
        if not projection_row:
            add_check(
                checks,
                mismatches,
                kind="ingress_projection",
                status="fail",
                code="ingress_projection_missing",
                severity="high",
                host=active_host,
                path=hostname,
                message=f"{hostname} missing from ingress projection",
            )
        else:
            projection_service = str(projection_row.get("service") or "").strip()
            projection_stack = str(projection_row.get("stack") or "").strip()
            projection_target = str(projection_row.get("target_hint") or "").strip()
            if expected_service and projection_service != expected_service:
                add_check(
                    checks,
                    mismatches,
                    kind="ingress_projection",
                    status="fail",
                    code="ingress_projection_service_mismatch",
                    severity="high",
                    host=active_host,
                    path=hostname,
                    message=f"{hostname} ingress projection service={projection_service} expected={expected_service}",
                )
            elif expected_stacks and projection_stack not in expected_stacks:
                add_check(
                    checks,
                    mismatches,
                    kind="ingress_projection",
                    status="fail",
                    code="ingress_projection_stack_mismatch",
                    severity="high",
                    host=projection_stack or active_host,
                    path=hostname,
                    message=f"{hostname} ingress projection stack={projection_stack} does not match active plane {expected_stacks}",
                )
            elif not matches_any(patterns, projection_target):
                add_check(
                    checks,
                    mismatches,
                    kind="ingress_projection",
                    status="fail",
                    code="ingress_projection_target_mismatch",
                    severity="high",
                    host=projection_stack or active_host,
                    path=hostname,
                    message=f"{hostname} ingress projection target_hint={projection_target!r} does not match expected active plane patterns",
                )
            else:
                add_check(
                    checks,
                    mismatches,
                    kind="ingress_projection",
                    status="pass",
                    code="ingress_projection_ok",
                    host=active_host,
                    path=hostname,
                    message=f"{hostname} ingress projection matches active plane",
                )

        if live_cloudflare_error:
            add_check(
                checks,
                mismatches,
                kind="cloudflare_live",
                status="warn",
                code="cloudflare_live_probe_unavailable",
                severity="warn",
                host=active_host,
                path=hostname,
                message=f"Cloudflare live ingress probe unavailable: {live_cloudflare_error}",
            )
        else:
            live_target = live_cloudflare_rows.get(hostname, "")
            if not live_target:
                add_check(
                    checks,
                    mismatches,
                    kind="cloudflare_live",
                    status="fail",
                    code="cloudflare_live_route_missing",
                    severity="high",
                    host=active_host,
                    path=hostname,
                    message=f"{hostname} missing from live Cloudflare ingress",
                )
            elif not matches_any(patterns, live_target):
                add_check(
                    checks,
                    mismatches,
                    kind="cloudflare_live",
                    status="fail",
                    code="cloudflare_live_target_mismatch",
                    severity="high",
                    host=active_host,
                    path=hostname,
                    message=f"{hostname} live Cloudflare target={live_target!r} does not match expected active plane patterns",
                )
            else:
                add_check(
                    checks,
                    mismatches,
                    kind="cloudflare_live",
                    status="pass",
                    code="cloudflare_live_ok",
                    host=active_host,
                    path=hostname,
                    message=f"{hostname} live Cloudflare target matches active plane",
                )

    for route in ensure_list(ensure_dict(closure.get("public_routes")).get("parked")):
        route_row = ensure_dict(route)
        hostname = str(route_row.get("hostname") or "").strip()
        forbidden_stacks = [str(item).strip() for item in ensure_list(route_row.get("forbidden_stack_aliases")) if str(item).strip()]
        forbidden_patterns = compile_patterns([str(item).strip() for item in ensure_list(route_row.get("forbidden_target_patterns")) if str(item).strip()])

        registry_row = ensure_dict(route_registry_rows.get(hostname))
        registry_stack = str(registry_row.get("stack") or "").strip()
        registry_target = str(registry_row.get("target_hint") or "").strip()
        if registry_row and forbidden_stacks and registry_stack in forbidden_stacks:
            add_check(
                checks,
                mismatches,
                kind="parked_route_registry",
                status="fail",
                code="parked_route_registry_active_stack",
                severity="high",
                host=registry_stack or active_host,
                path=hostname,
                message=f"{hostname} parked route registry still points at active stack {registry_stack}",
            )
        elif registry_row and forbidden_patterns and matches_any(forbidden_patterns, registry_target):
            add_check(
                checks,
                mismatches,
                kind="parked_route_registry",
                status="fail",
                code="parked_route_registry_active_target",
                severity="high",
                host=registry_stack or active_host,
                path=hostname,
                message=f"{hostname} parked route registry target_hint={registry_target!r} still matches active plane",
            )
        else:
            add_check(
                checks,
                mismatches,
                kind="parked_route_registry",
                status="pass",
                code="parked_route_registry_ok",
                host=active_host,
                path=hostname,
                message=f"{hostname} parked route registry is not routed to the active plane",
            )

        if hostname in ingress_projection_rows:
            projection_row = ensure_dict(ingress_projection_rows.get(hostname))
            add_check(
                checks,
                mismatches,
                kind="parked_ingress_projection",
                status="fail",
                code="parked_ingress_projection_present",
                severity="high",
                host=str(projection_row.get("stack") or active_host).strip(),
                path=hostname,
                message=f"{hostname} parked route is still published in ingress projection",
            )
        else:
            add_check(
                checks,
                mismatches,
                kind="parked_ingress_projection",
                status="pass",
                code="parked_ingress_projection_absent",
                host=active_host,
                path=hostname,
                message=f"{hostname} parked route is absent from ingress projection",
            )

        live_target = live_cloudflare_rows.get(hostname, "")
        if live_cloudflare_error:
            add_check(
                checks,
                mismatches,
                kind="parked_cloudflare_live",
                status="warn",
                code="parked_cloudflare_live_probe_unavailable",
                severity="warn",
                host=active_host,
                path=hostname,
                message=f"Cloudflare live ingress probe unavailable: {live_cloudflare_error}",
            )
        elif live_target:
            add_check(
                checks,
                mismatches,
                kind="parked_cloudflare_live",
                status="fail",
                code="parked_cloudflare_live_present",
                severity="high",
                host=active_host,
                path=hostname,
                message=f"{hostname} parked route is still live in Cloudflare ingress: {live_target!r}",
            )
        else:
            add_check(
                checks,
                mismatches,
                kind="parked_cloudflare_live",
                status="pass",
                code="parked_cloudflare_live_absent",
                host=active_host,
                path=hostname,
                message=f"{hostname} parked route is absent from live Cloudflare ingress",
            )

    for endpoint in ensure_list(ensure_dict(closure.get("monitoring")).get("endpoints")):
        endpoint_row = ensure_dict(endpoint)
        endpoint_id = str(endpoint_row.get("endpoint_id") or "").strip()
        expected_host = str(endpoint_row.get("expected_host") or active_host).strip()
        url_patterns = compile_patterns([str(item).strip() for item in ensure_list(endpoint_row.get("expected_url_patterns")) if str(item).strip()])
        health_row = ensure_dict(services_health_rows.get(endpoint_id))
        if not health_row:
            add_check(
                checks,
                mismatches,
                kind="services_health",
                status="fail",
                code="services_health_endpoint_missing",
                severity="high",
                host=expected_host,
                path=endpoint_id,
                message=f"services.health endpoint {endpoint_id} missing",
            )
            continue

        actual_host = str(health_row.get("host") or "").strip()
        actual_url = str(health_row.get("url") or "").strip()
        if expected_host and actual_host != expected_host:
            add_check(
                checks,
                mismatches,
                kind="services_health",
                status="fail",
                code="services_health_host_mismatch",
                severity="high",
                host=actual_host or expected_host,
                path=endpoint_id,
                message=f"services.health endpoint {endpoint_id} host={actual_host} expected={expected_host}",
            )
        elif not matches_any(url_patterns, actual_url):
            add_check(
                checks,
                mismatches,
                kind="services_health",
                status="fail",
                code="services_health_url_mismatch",
                severity="high",
                host=actual_host or expected_host,
                path=endpoint_id,
                message=f"services.health endpoint {endpoint_id} url={actual_url!r} does not match expected active plane patterns",
            )
        else:
            add_check(
                checks,
                mismatches,
                kind="services_health",
                status="pass",
                code="services_health_ok",
                host=expected_host,
                path=endpoint_id,
                message=f"services.health endpoint {endpoint_id} matches active plane",
            )

    for runtime_service in ensure_list(ensure_dict(closure.get("runtime_services")).get("services")):
        runtime_row = ensure_dict(runtime_service)
        service_id = str(runtime_row.get("service_id") or "").strip()
        expected_vm = str(runtime_row.get("expected_vm") or active_host).strip()
        expected_target_vm = str(runtime_row.get("expected_target_vm") or expected_vm).strip()
        expected_status = str(runtime_row.get("expected_status") or "").strip()
        actual = ensure_dict(runtime_service_rows.get(service_id))
        if not actual:
            add_check(
                checks,
                mismatches,
                kind="runtime_services",
                status="fail",
                code="runtime_service_missing",
                severity="high",
                host=expected_vm,
                path=service_id,
                message=f"runtime service {service_id} missing from runtime services source",
            )
            continue
        actual_vm = str(actual.get("vm") or "").strip()
        actual_target_vm = str(actual.get("target_vm") or actual_vm).strip()
        actual_status = str(actual.get("status") or "").strip()
        if expected_vm and actual_vm != expected_vm:
            add_check(
                checks,
                mismatches,
                kind="runtime_services",
                status="fail",
                code="runtime_service_vm_mismatch",
                severity="high",
                host=actual_vm or expected_vm,
                path=service_id,
                message=f"runtime service {service_id} vm={actual_vm} expected={expected_vm}",
            )
        elif expected_target_vm and actual_target_vm != expected_target_vm:
            add_check(
                checks,
                mismatches,
                kind="runtime_services",
                status="fail",
                code="runtime_service_target_vm_mismatch",
                severity="high",
                host=actual_target_vm or expected_target_vm,
                path=service_id,
                message=f"runtime service {service_id} target_vm={actual_target_vm} expected={expected_target_vm}",
            )
        elif expected_status and actual_status != expected_status:
            add_check(
                checks,
                mismatches,
                kind="runtime_services",
                status="fail",
                code="runtime_service_status_mismatch",
                severity="high",
                host=actual_vm or expected_vm,
                path=service_id,
                message=f"runtime service {service_id} status={actual_status} expected={expected_status}",
            )
        else:
            add_check(
                checks,
                mismatches,
                kind="runtime_services",
                status="pass",
                code="runtime_service_ok",
                host=expected_vm,
                path=service_id,
                message=f"runtime service {service_id} matches declared active plane",
            )

    dependents = ensure_dict(closure.get("dependents"))
    for binding in ensure_list(dependents.get("agent_endpoints")):
        binding_row = ensure_dict(binding)
        agent_id = str(binding_row.get("agent_id") or "").strip()
        agent = ensure_dict(agent_rows.get(agent_id))
        if not agent:
            add_check(
                checks,
                mismatches,
                kind="agent_endpoints",
                status="fail",
                code="agent_endpoint_agent_missing",
                severity="high",
                host=active_host,
                path=agent_id,
                message=f"agent registry entry {agent_id} missing",
            )
            continue
        endpoints = ensure_dict(agent.get("endpoints"))
        for endpoint in ensure_list(binding_row.get("endpoints")):
            endpoint_row = ensure_dict(endpoint)
            endpoint_id = str(endpoint_row.get("endpoint_id") or "").strip()
            expected_health_id = str(endpoint_row.get("expected_health_id") or endpoint_id).strip()
            patterns = compile_patterns([str(item).strip() for item in ensure_list(endpoint_row.get("expected_url_patterns")) if str(item).strip()])
            actual = ensure_dict(endpoints.get(endpoint_id))
            if not actual:
                add_check(
                    checks,
                    mismatches,
                    kind="agent_endpoints",
                    status="fail",
                    code="agent_endpoint_missing",
                    severity="high",
                    host=active_host,
                    path=f"{agent_id}:{endpoint_id}",
                    message=f"agent endpoint {agent_id}.{endpoint_id} missing",
                )
                continue
            actual_health_id = str(actual.get("health_id") or "").strip()
            actual_url = str(actual.get("url") or "").strip()
            if expected_health_id and actual_health_id != expected_health_id:
                add_check(
                    checks,
                    mismatches,
                    kind="agent_endpoints",
                    status="fail",
                    code="agent_endpoint_health_mismatch",
                    severity="high",
                    host=active_host,
                    path=f"{agent_id}:{endpoint_id}",
                    message=f"agent endpoint {agent_id}.{endpoint_id} health_id={actual_health_id} expected={expected_health_id}",
                )
            elif not matches_any(patterns, actual_url):
                add_check(
                    checks,
                    mismatches,
                    kind="agent_endpoints",
                    status="fail",
                    code="agent_endpoint_url_mismatch",
                    severity="high",
                    host=active_host,
                    path=f"{agent_id}:{endpoint_id}",
                    message=f"agent endpoint {agent_id}.{endpoint_id} url={actual_url!r} does not match active plane patterns",
                )
            else:
                add_check(
                    checks,
                    mismatches,
                    kind="agent_endpoints",
                    status="pass",
                    code="agent_endpoint_ok",
                    host=active_host,
                    path=f"{agent_id}:{endpoint_id}",
                    message=f"agent endpoint {agent_id}.{endpoint_id} matches active plane",
                )

    for binding in ensure_list(dependents.get("worker_endpoints")):
        binding_row = ensure_dict(binding)
        terminal_id = str(binding_row.get("terminal_id") or "").strip()
        worker = ensure_dict(worker_rows.get(terminal_id))
        if not worker:
            add_check(
                checks,
                mismatches,
                kind="worker_endpoints",
                status="fail",
                code="worker_endpoint_terminal_missing",
                severity="high",
                host=active_host,
                path=terminal_id,
                message=f"worker catalog entry {terminal_id} missing",
            )
            continue
        endpoints = ensure_dict(worker.get("endpoints"))
        for endpoint in ensure_list(binding_row.get("endpoints")):
            endpoint_row = ensure_dict(endpoint)
            endpoint_id = str(endpoint_row.get("endpoint_id") or "").strip()
            expected_health_id = str(endpoint_row.get("expected_health_id") or endpoint_id).strip()
            patterns = compile_patterns([str(item).strip() for item in ensure_list(endpoint_row.get("expected_url_patterns")) if str(item).strip()])
            actual = ensure_dict(endpoints.get(endpoint_id))
            if not actual:
                add_check(
                    checks,
                    mismatches,
                    kind="worker_endpoints",
                    status="fail",
                    code="worker_endpoint_missing",
                    severity="high",
                    host=active_host,
                    path=f"{terminal_id}:{endpoint_id}",
                    message=f"worker endpoint {terminal_id}.{endpoint_id} missing",
                )
                continue
            actual_health_id = str(actual.get("health_id") or "").strip()
            actual_url = str(actual.get("url") or "").strip()
            if expected_health_id and actual_health_id != expected_health_id:
                add_check(
                    checks,
                    mismatches,
                    kind="worker_endpoints",
                    status="fail",
                    code="worker_endpoint_health_mismatch",
                    severity="high",
                    host=active_host,
                    path=f"{terminal_id}:{endpoint_id}",
                    message=f"worker endpoint {terminal_id}.{endpoint_id} health_id={actual_health_id} expected={expected_health_id}",
                )
            elif not matches_any(patterns, actual_url):
                add_check(
                    checks,
                    mismatches,
                    kind="worker_endpoints",
                    status="fail",
                    code="worker_endpoint_url_mismatch",
                    severity="high",
                    host=active_host,
                    path=f"{terminal_id}:{endpoint_id}",
                    message=f"worker endpoint {terminal_id}.{endpoint_id} url={actual_url!r} does not match active plane patterns",
                )
            else:
                add_check(
                    checks,
                    mismatches,
                    kind="worker_endpoints",
                    status="pass",
                    code="worker_endpoint_ok",
                    host=active_host,
                    path=f"{terminal_id}:{endpoint_id}",
                    message=f"worker endpoint {terminal_id}.{endpoint_id} matches active plane",
                )

    for binding in ensure_list(dependents.get("secret_bundles")):
        binding_row = ensure_dict(binding)
        bundle_id = str(binding_row.get("bundle_id") or "").strip()
        bundle = ensure_dict(secret_bundle_rows.get(bundle_id))
        if not bundle:
            add_check(
                checks,
                mismatches,
                kind="secret_bundles",
                status="fail",
                code="secret_bundle_missing",
                severity="high",
                host=active_host,
                path=bundle_id,
                message=f"secret bundle {bundle_id} missing",
            )
            continue
        verify_rows = {
            str(row.get("id") or "").strip(): ensure_dict(row)
            for row in ensure_list(bundle.get("verify"))
            if isinstance(row, dict) and str(row.get("id") or "").strip()
        }
        static_rows = ensure_dict(ensure_dict(bundle.get("local_env")).get("static"))
        for verify in ensure_list(binding_row.get("verify")):
            verify_row = ensure_dict(verify)
            verify_id = str(verify_row.get("verify_id") or "").strip()
            patterns = compile_patterns([str(item).strip() for item in ensure_list(verify_row.get("expected_url_patterns")) if str(item).strip()])
            actual = ensure_dict(verify_rows.get(verify_id))
            if not actual:
                add_check(
                    checks,
                    mismatches,
                    kind="secret_bundles",
                    status="fail",
                    code="secret_bundle_verify_missing",
                    severity="high",
                    host=active_host,
                    path=f"{bundle_id}:{verify_id}",
                    message=f"secret bundle verify {bundle_id}.{verify_id} missing",
                )
                continue
            actual_url = str(actual.get("url") or "").strip()
            if not matches_any(patterns, actual_url):
                add_check(
                    checks,
                    mismatches,
                    kind="secret_bundles",
                    status="fail",
                    code="secret_bundle_verify_url_mismatch",
                    severity="high",
                    host=active_host,
                    path=f"{bundle_id}:{verify_id}",
                    message=f"secret bundle verify {bundle_id}.{verify_id} url={actual_url!r} does not match active plane patterns",
                )
            else:
                add_check(
                    checks,
                    mismatches,
                    kind="secret_bundles",
                    status="pass",
                    code="secret_bundle_verify_ok",
                    host=active_host,
                    path=f"{bundle_id}:{verify_id}",
                    message=f"secret bundle verify {bundle_id}.{verify_id} matches active plane",
                )
        for local_env in ensure_list(binding_row.get("local_env_static")):
            env_row = ensure_dict(local_env)
            env_key = str(env_row.get("key") or "").strip()
            patterns = compile_patterns([str(item).strip() for item in ensure_list(env_row.get("expected_url_patterns")) if str(item).strip()])
            actual_value = str(static_rows.get(env_key) or "").strip()
            if not actual_value:
                add_check(
                    checks,
                    mismatches,
                    kind="secret_bundles",
                    status="fail",
                    code="secret_bundle_local_env_missing",
                    severity="high",
                    host=active_host,
                    path=f"{bundle_id}:{env_key}",
                    message=f"secret bundle local env static {bundle_id}.{env_key} missing",
                )
            elif not matches_any(patterns, actual_value):
                add_check(
                    checks,
                    mismatches,
                    kind="secret_bundles",
                    status="fail",
                    code="secret_bundle_local_env_url_mismatch",
                    severity="high",
                    host=active_host,
                    path=f"{bundle_id}:{env_key}",
                    message=f"secret bundle local env static {bundle_id}.{env_key} value={actual_value!r} does not match active plane patterns",
                )
            else:
                add_check(
                    checks,
                    mismatches,
                    kind="secret_bundles",
                    status="pass",
                    code="secret_bundle_local_env_ok",
                    host=active_host,
                    path=f"{bundle_id}:{env_key}",
                    message=f"secret bundle local env static {bundle_id}.{env_key} matches active plane",
                )

    for backup in ensure_list(ensure_dict(closure.get("backups")).get("jobs")):
        backup_row = ensure_dict(backup)
        job_id = str(backup_row.get("job_id") or "").strip()
        expected_host = str(backup_row.get("expected_host") or active_host).strip()
        expected_script_ref = str(backup_row.get("expected_script_ref") or "").strip()
        expected_capability_ref = str(backup_row.get("expected_capability_ref") or "").strip()
        schedule_row = ensure_dict(backup_job_rows.get(job_id))
        if not schedule_row:
            add_check(
                checks,
                mismatches,
                kind="backup_schedule",
                status="fail",
                code="backup_schedule_job_missing",
                severity="high",
                host=expected_host,
                path=job_id,
                message=f"backup.schedule job {job_id} missing",
            )
        else:
            actual_host = str(schedule_row.get("host") or "").strip()
            script_ref = str(schedule_row.get("script_ref") or "").strip()
            capability_ref = str(schedule_row.get("capability_ref") or "").strip()
            enabled = bool(schedule_row.get("enabled", False))
            if not enabled:
                add_check(
                    checks,
                    mismatches,
                    kind="backup_schedule",
                    status="fail",
                    code="backup_schedule_job_disabled",
                    severity="high",
                    host=actual_host or expected_host,
                    path=job_id,
                    message=f"backup.schedule job {job_id} is disabled",
                )
            elif expected_host and actual_host != expected_host:
                add_check(
                    checks,
                    mismatches,
                    kind="backup_schedule",
                    status="fail",
                    code="backup_schedule_host_mismatch",
                    severity="high",
                    host=actual_host or expected_host,
                    path=job_id,
                    message=f"backup.schedule job {job_id} host={actual_host} expected={expected_host}",
                )
            elif expected_script_ref and script_ref != expected_script_ref:
                add_check(
                    checks,
                    mismatches,
                    kind="backup_schedule",
                    status="fail",
                    code="backup_schedule_script_mismatch",
                    severity="high",
                    host=actual_host or expected_host,
                    path=job_id,
                    message=f"backup.schedule job {job_id} script_ref={script_ref!r} expected={expected_script_ref!r}",
                )
            elif expected_capability_ref and capability_ref != expected_capability_ref:
                add_check(
                    checks,
                    mismatches,
                    kind="backup_schedule",
                    status="fail",
                    code="backup_schedule_capability_mismatch",
                    severity="high",
                    host=actual_host or expected_host,
                    path=job_id,
                    message=f"backup.schedule job {job_id} capability_ref={capability_ref!r} expected={expected_capability_ref!r}",
                )
            else:
                add_check(
                    checks,
                    mismatches,
                    kind="backup_schedule",
                    status="pass",
                    code="backup_schedule_ok",
                    host=expected_host,
                    path=job_id,
                    message=f"backup.schedule job {job_id} matches closure contract",
                )

        for remote_check in ensure_list(backup_row.get("remote_checks")):
            remote_row = ensure_dict(remote_check)
            check_kind = str(remote_row.get("kind") or "").strip()
            target_host = str(remote_row.get("host") or expected_host).strip()
            if check_kind == "remote_file_exists":
                target_path = str(remote_row.get("path") or "").strip()
                probe = ssh_probe.ssh_capture(target_host, f"test -f {shlex.quote(target_path)}", timeout=8)
                if probe["ok"]:
                    add_check(
                        checks,
                        mismatches,
                        kind=check_kind,
                        status="pass",
                        code="remote_file_exists_ok",
                        host=target_host,
                        path=target_path,
                        message=f"{target_host}:{target_path} exists",
                    )
                else:
                    add_check(
                        checks,
                        mismatches,
                        kind=check_kind,
                        status="fail",
                        code="remote_file_missing",
                        severity="high",
                        host=target_host,
                        path=target_path,
                        message=f"{target_host}:{target_path} missing or unreachable ({probe['stderr'].strip() or probe['returncode']})",
                        extra={"probe_path": probe.get("path_used", "")},
                    )
            elif check_kind == "remote_cron_file_line":
                cron_path = str(remote_row.get("path") or "").strip()
                expected_regex = str(remote_row.get("expected_regex") or "").strip()
                probe = ssh_probe.ssh_capture(target_host, f"cat {shlex.quote(cron_path)} 2>/dev/null || true", timeout=8)
                if not probe["ok"]:
                    add_check(
                        checks,
                        mismatches,
                        kind=check_kind,
                        status="fail",
                        code="remote_cron_probe_failed",
                        severity="high",
                        host=target_host,
                        path=cron_path,
                        message=f"{target_host}:{cron_path} unreadable ({probe['stderr'].strip() or probe['returncode']})",
                    )
                elif not re.search(expected_regex, probe["stdout"] or "", flags=re.MULTILINE):
                    add_check(
                        checks,
                        mismatches,
                        kind=check_kind,
                        status="fail",
                        code="remote_cron_line_missing",
                        severity="high",
                        host=target_host,
                        path=cron_path,
                        message=f"{target_host}:{cron_path} does not contain expected scheduler line",
                    )
                else:
                    add_check(
                        checks,
                        mismatches,
                        kind=check_kind,
                        status="pass",
                        code="remote_cron_line_ok",
                        host=target_host,
                        path=cron_path,
                        message=f"{target_host}:{cron_path} contains expected scheduler line",
                    )

        for trust_edge in ensure_list(backup_row.get("trust_edges")):
            edge = ensure_dict(trust_edge)
            if str(edge.get("kind") or "").strip() != "ssh_batch":
                continue
            from_host = str(edge.get("from_host") or expected_host).strip()
            to_target = str(edge.get("to_target") or "").strip()
            to_user = str(edge.get("to_user") or "root").strip()
            to_address_source = str(edge.get("to_address_source") or "host").strip()
            target_row = ssh_probe.target_row(to_target)
            to_address = str(target_row.get(to_address_source) or target_row.get("host") or "").strip()
            if not to_address:
                add_check(
                    checks,
                    mismatches,
                    kind="ssh_batch",
                    status="fail",
                    code="trust_edge_target_unresolved",
                    severity="high",
                    host=from_host,
                    path=to_target,
                    message=f"trust edge target {to_target} missing address source {to_address_source}",
                )
                continue

            remote_cmd = (
                f"ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "
                f"-o UserKnownHostsFile=/dev/null {shlex.quote(to_user)}@{shlex.quote(to_address)} true"
            )
            probe = ssh_probe.ssh_capture(from_host, remote_cmd, timeout=8)
            if probe["ok"]:
                add_check(
                    checks,
                    mismatches,
                    kind="ssh_batch",
                    status="pass",
                    code="trust_edge_ok",
                    host=from_host,
                    path=f"{from_host}->{to_target}",
                    message=f"{from_host} can batch-ssh to {to_target}",
                )
            else:
                add_check(
                    checks,
                    mismatches,
                    kind="ssh_batch",
                    status="fail",
                    code="trust_edge_missing",
                    severity="high",
                    host=from_host,
                    path=f"{from_host}->{to_target}",
                    message=f"{from_host} cannot batch-ssh to {to_target} ({probe['stderr'].strip() or probe['returncode']})",
                    extra={"probe_path": probe.get("path_used", "")},
                )

    backups_section = ensure_dict(closure.get("backups"))
    for target in ensure_list(backups_section.get("inventory_targets")):
        target_row = ensure_dict(target)
        target_id = str(target_row.get("target_id") or "").strip()
        expected_host = str(target_row.get("expected_host") or "").strip()
        patterns = compile_patterns([str(item).strip() for item in ensure_list(target_row.get("expected_base_path_patterns")) if str(item).strip()])
        actual = ensure_dict(backup_target_rows.get(target_id))
        if not actual:
            add_check(
                checks,
                mismatches,
                kind="backup_inventory",
                status="fail",
                code="backup_inventory_target_missing",
                severity="high",
                host=expected_host,
                path=target_id,
                message=f"backup.inventory target {target_id} missing",
            )
            continue
        actual_host = str(actual.get("host") or "").strip()
        actual_base_path = str(actual.get("base_path") or "").strip()
        if expected_host and actual_host != expected_host:
            add_check(
                checks,
                mismatches,
                kind="backup_inventory",
                status="fail",
                code="backup_inventory_target_host_mismatch",
                severity="high",
                host=actual_host or expected_host,
                path=target_id,
                message=f"backup.inventory target {target_id} host={actual_host} expected={expected_host}",
            )
        elif not matches_any(patterns, actual_base_path):
            add_check(
                checks,
                mismatches,
                kind="backup_inventory",
                status="fail",
                code="backup_inventory_target_base_path_mismatch",
                severity="high",
                host=actual_host or expected_host,
                path=target_id,
                message=f"backup.inventory target {target_id} base_path={actual_base_path!r} does not match expected locality patterns",
            )
        else:
            add_check(
                checks,
                mismatches,
                kind="backup_inventory",
                status="pass",
                code="backup_inventory_target_ok",
                host=expected_host,
                path=target_id,
                message=f"backup.inventory target {target_id} matches declared locality role",
            )

    for unit in ensure_list(backups_section.get("runtime_units")):
        unit_row = ensure_dict(unit)
        unit_id = str(unit_row.get("unit_id") or "").strip()
        expected_hostname = str(unit_row.get("expected_hostname") or "").strip()
        expected_destination_lane = str(unit_row.get("expected_destination_lane") or "").strip()
        expected_restore_class = str(unit_row.get("expected_restore_class") or "").strip()
        expected_inventory_targets = [str(item).strip() for item in ensure_list(unit_row.get("expected_inventory_targets")) if str(item).strip()]
        actual = ensure_dict(backup_runtime_unit_rows.get(unit_id))
        if not actual:
            add_check(
                checks,
                mismatches,
                kind="backup_runtime_units",
                status="fail",
                code="backup_runtime_unit_missing",
                severity="high",
                host=expected_hostname,
                path=unit_id,
                message=f"backup.inventory runtime unit {unit_id} missing",
            )
            continue
        actual_hostname = str(actual.get("hostname") or "").strip()
        actual_destination_lane = str(actual.get("destination_lane") or "").strip()
        actual_restore_class = str(actual.get("restore_class") or "").strip()
        actual_targets = [str(item).strip() for item in ensure_list(actual.get("inventory_targets")) if str(item).strip()]
        if expected_hostname and actual_hostname != expected_hostname:
            add_check(
                checks,
                mismatches,
                kind="backup_runtime_units",
                status="fail",
                code="backup_runtime_unit_hostname_mismatch",
                severity="high",
                host=actual_hostname or expected_hostname,
                path=unit_id,
                message=f"backup runtime unit {unit_id} hostname={actual_hostname} expected={expected_hostname}",
            )
        elif expected_destination_lane and actual_destination_lane != expected_destination_lane:
            add_check(
                checks,
                mismatches,
                kind="backup_runtime_units",
                status="fail",
                code="backup_runtime_unit_destination_lane_mismatch",
                severity="high",
                host=actual_hostname or expected_hostname,
                path=unit_id,
                message=f"backup runtime unit {unit_id} destination_lane={actual_destination_lane} expected={expected_destination_lane}",
            )
        elif expected_restore_class and actual_restore_class != expected_restore_class:
            add_check(
                checks,
                mismatches,
                kind="backup_runtime_units",
                status="fail",
                code="backup_runtime_unit_restore_class_mismatch",
                severity="high",
                host=actual_hostname or expected_hostname,
                path=unit_id,
                message=f"backup runtime unit {unit_id} restore_class={actual_restore_class} expected={expected_restore_class}",
            )
        elif any(target_id not in actual_targets for target_id in expected_inventory_targets):
            add_check(
                checks,
                mismatches,
                kind="backup_runtime_units",
                status="fail",
                code="backup_runtime_unit_inventory_target_mismatch",
                severity="high",
                host=actual_hostname or expected_hostname,
                path=unit_id,
                message=f"backup runtime unit {unit_id} inventory_targets={actual_targets} missing expected targets {expected_inventory_targets}",
            )
        else:
            add_check(
                checks,
                mismatches,
                kind="backup_runtime_units",
                status="pass",
                code="backup_runtime_unit_ok",
                host=expected_hostname,
                path=unit_id,
                message=f"backup runtime unit {unit_id} matches declared locality role",
            )

    lifecycle_binding = ensure_dict(backups_section.get("lifecycle_binding"))
    lifecycle_service_id = str(lifecycle_binding.get("service_id") or "").strip()
    if lifecycle_service_id:
        actual = ensure_dict(lifecycle_service_rows.get(lifecycle_service_id))
        if not actual:
            add_check(
                checks,
                mismatches,
                kind="service_data_lifecycle",
                status="fail",
                code="lifecycle_service_missing",
                severity="high",
                host=active_host,
                path=lifecycle_service_id,
                message=f"service.data.lifecycle entry {lifecycle_service_id} missing",
            )
        else:
            declared_actions = {
                str(row.get("action_id") or "").strip()
                for row in ensure_list(ensure_dict(actual.get("background_actions")).get("declared"))
                if isinstance(row, dict) and str(row.get("action_id") or "").strip()
            }
            expected_actions = [str(item).strip() for item in ensure_list(lifecycle_binding.get("expected_background_action_ids")) if str(item).strip()]
            binding_refs = ensure_dict(actual.get("binding_refs"))
            actual_backup_targets = [str(item).strip() for item in ensure_list(binding_refs.get("backup_targets")) if str(item).strip()]
            actual_backup_runtime_units = [str(item).strip() for item in ensure_list(binding_refs.get("backup_runtime_units")) if str(item).strip()]
            expected_backup_targets = [str(item).strip() for item in ensure_list(lifecycle_binding.get("expected_backup_targets")) if str(item).strip()]
            expected_backup_runtime_units = [str(item).strip() for item in ensure_list(lifecycle_binding.get("expected_backup_runtime_units")) if str(item).strip()]
            if any(action_id not in declared_actions for action_id in expected_actions):
                add_check(
                    checks,
                    mismatches,
                    kind="service_data_lifecycle",
                    status="fail",
                    code="lifecycle_background_action_missing",
                    severity="high",
                    host=active_host,
                    path=lifecycle_service_id,
                    message=f"service.data.lifecycle {lifecycle_service_id} missing expected background actions {expected_actions}",
                )
            elif any(target_id not in actual_backup_targets for target_id in expected_backup_targets):
                add_check(
                    checks,
                    mismatches,
                    kind="service_data_lifecycle",
                    status="fail",
                    code="lifecycle_backup_target_missing",
                    severity="high",
                    host=active_host,
                    path=lifecycle_service_id,
                    message=f"service.data.lifecycle {lifecycle_service_id} backup_targets={actual_backup_targets} missing expected targets {expected_backup_targets}",
                )
            elif any(unit_id not in actual_backup_runtime_units for unit_id in expected_backup_runtime_units):
                add_check(
                    checks,
                    mismatches,
                    kind="service_data_lifecycle",
                    status="fail",
                    code="lifecycle_backup_runtime_unit_missing",
                    severity="high",
                    host=active_host,
                    path=lifecycle_service_id,
                    message=f"service.data.lifecycle {lifecycle_service_id} backup_runtime_units={actual_backup_runtime_units} missing expected units {expected_backup_runtime_units}",
                )
            else:
                add_check(
                    checks,
                    mismatches,
                    kind="service_data_lifecycle",
                    status="pass",
                    code="lifecycle_binding_ok",
                    host=active_host,
                    path=lifecycle_service_id,
                    message=f"service.data.lifecycle {lifecycle_service_id} matches relocation backup locality policy",
                )

    for mismatch in mismatches:
        mismatch["domain"] = domain
    posture = closure_posture(mismatches)
    return {
        "id": closure_id,
        "domain": domain,
        "description": str(closure.get("description") or ""),
        "active_plane": active_plane,
        "checks": checks,
        "mismatches": mismatches,
        "posture": posture,
    }


def run_service_closure_audit(*, closure_id: str | None = None, domain: str | None = None) -> dict[str, Any]:
    contract_path = resolve_env_path("SPINE_SERVICE_CLOSURE_CONTRACT", DEFAULT_CONTRACT_PATH)
    contract = load_yaml(contract_path)
    defaults = ensure_dict(contract.get("defaults"))

    route_registry_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_ROUTE_REGISTRY", DEFAULT_ROUTE_REGISTRY, str(defaults.get("route_registry") or ""))
    ingress_projection_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_INGRESS_PROJECTION", DEFAULT_INGRESS_PROJECTION, str(defaults.get("ingress_projection") or ""))
    services_health_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_SERVICES_HEALTH", DEFAULT_SERVICES_HEALTH, str(defaults.get("services_health") or ""))
    backup_schedule_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_BACKUP_SCHEDULE", DEFAULT_BACKUP_SCHEDULE, str(defaults.get("backup_schedule") or ""))
    backup_inventory_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_BACKUP_INVENTORY", DEFAULT_BACKUP_INVENTORY, str(defaults.get("backup_inventory") or ""))
    service_data_lifecycle_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_SERVICE_DATA_LIFECYCLE", DEFAULT_SERVICE_DATA_LIFECYCLE, str(defaults.get("service_data_lifecycle") or ""))
    ssh_targets_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_SSH_TARGETS", DEFAULT_SSH_TARGETS, str(defaults.get("ssh_targets") or ""))
    agents_registry_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_AGENTS_REGISTRY", DEFAULT_AGENTS_REGISTRY, str(defaults.get("agents_registry") or ""))
    worker_catalog_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_WORKER_CATALOG", DEFAULT_WORKER_CATALOG, str(defaults.get("worker_catalog") or ""))
    secrets_bundle_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_SECRETS_BUNDLE_CONTRACT", DEFAULT_SECRETS_BUNDLE_CONTRACT, str(defaults.get("secrets_bundle_contract") or ""))
    runtime_services_path = resolve_default_source_path("SPINE_SERVICE_CLOSURE_RUNTIME_SERVICES", DEFAULT_RUNTIME_SERVICES, str(defaults.get("runtime_services") or ""))

    live_cloudflare_rows, live_cloudflare_error = load_live_cloudflare_routes(defaults)
    ssh_probe = SSHProbe(ssh_targets_path)
    yaml_cache: dict[Path, dict[str, Any]] = {}

    def yaml_payload(path: Path) -> dict[str, Any]:
        resolved = path.resolve()
        if resolved not in yaml_cache:
            yaml_cache[resolved] = load_yaml(resolved)
        return yaml_cache[resolved]

    def rows_for_closure(closure: dict[str, Any]) -> dict[str, Any]:
        refs = ensure_dict(closure.get("refs"))
        resolved_route_registry_path = resolve_contract_path(str(refs.get("route_registry") or ""), route_registry_path)
        resolved_ingress_projection_path = resolve_contract_path(str(refs.get("ingress_projection") or ""), ingress_projection_path)
        resolved_services_health_path = resolve_contract_path(str(refs.get("services_health") or ""), services_health_path)
        resolved_backup_schedule_path = resolve_contract_path(str(refs.get("backup_schedule") or ""), backup_schedule_path)
        resolved_backup_inventory_path = resolve_contract_path(str(refs.get("backup_inventory") or ""), backup_inventory_path)
        resolved_lifecycle_path = resolve_contract_path(str(refs.get("service_data_lifecycle") or ""), service_data_lifecycle_path)
        resolved_agents_registry_path = resolve_contract_path(str(refs.get("agents_registry") or ""), agents_registry_path)
        resolved_worker_catalog_path = resolve_contract_path(str(refs.get("worker_catalog") or ""), worker_catalog_path)
        resolved_secrets_bundle_path = resolve_contract_path(str(refs.get("secrets_bundle_contract") or ""), secrets_bundle_path)
        resolved_runtime_services_path = resolve_contract_path(str(refs.get("runtime_services") or ""), runtime_services_path)
        return {
            "route_registry_rows": flatten_route_registry(yaml_payload(resolved_route_registry_path)),
            "ingress_projection_rows": flatten_ingress_projection(yaml_payload(resolved_ingress_projection_path)),
            "services_health_rows": load_services_health(yaml_payload(resolved_services_health_path)),
            "backup_job_rows": load_backup_jobs(yaml_payload(resolved_backup_schedule_path)),
            "backup_target_rows": load_backup_targets(yaml_payload(resolved_backup_inventory_path)),
            "backup_runtime_unit_rows": load_backup_runtime_units(yaml_payload(resolved_backup_inventory_path)),
            "lifecycle_service_rows": load_lifecycle_services(yaml_payload(resolved_lifecycle_path)),
            "agent_rows": load_agents_registry(yaml_payload(resolved_agents_registry_path)),
            "worker_rows": load_worker_catalog(yaml_payload(resolved_worker_catalog_path)),
            "secret_bundle_rows": load_secret_bundles(yaml_payload(resolved_secrets_bundle_path)),
            "runtime_service_rows": load_runtime_services(yaml_payload(resolved_runtime_services_path)),
        }

    filtered_closures = []
    for item in ensure_list(contract.get("closures")):
        row = ensure_dict(item)
        item_id = str(row.get("id") or "").strip()
        item_domain = str(row.get("domain") or "").strip()
        if closure_id and item_id != closure_id:
            continue
        if domain and item_domain != domain:
            continue
        filtered_closures.append(row)

    results = [
        audit_closure(
            row,
            live_cloudflare_rows=live_cloudflare_rows,
            live_cloudflare_error=live_cloudflare_error,
            ssh_probe=ssh_probe,
            **rows_for_closure(row),
        )
        for row in filtered_closures
    ]

    summary = {
        "closure_count": len(results),
        "closure_posture_pass": len([row for row in results if row.get("posture") == "pass"]),
        "closure_posture_warn": len([row for row in results if row.get("posture") == "warn"]),
        "closure_posture_fail": len([row for row in results if row.get("posture") == "fail"]),
        "check_total": sum(len(ensure_list(row.get("checks"))) for row in results),
        "mismatch_total": sum(len(ensure_list(row.get("mismatches"))) for row in results),
    }
    return {
        "version": 1,
        "status": "audit",
        "generated_at_utc": now_utc_iso(),
        "source_contract": display_path(contract_path),
        "source_capability": "service.closure.audit",
        "summary": summary,
        "closures": results,
    }


def render_text(snapshot: dict[str, Any]) -> str:
    lines = [
        "service.closure.audit",
        f"contract: {snapshot.get('source_contract')}",
        f"closures: {ensure_dict(snapshot.get('summary')).get('closure_count', 0)}",
        f"checks: {ensure_dict(snapshot.get('summary')).get('check_total', 0)}",
        "",
    ]
    for closure in ensure_list(snapshot.get("closures")):
        lines.append(f"[{str(closure.get('posture') or '').upper()}] {closure.get('id')} ({closure.get('domain')})")
        for mismatch in ensure_list(closure.get("mismatches")):
            lines.append(f"  - [{mismatch.get('severity')}] {mismatch.get('code')}: {mismatch.get('message')}")
        if not ensure_list(closure.get("mismatches")):
            lines.append("  - OK: all closure checks passed")
        lines.append("")
    return "\n".join(lines).strip()
