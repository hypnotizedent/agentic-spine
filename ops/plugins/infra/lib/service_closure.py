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
DEFAULT_SSH_TARGETS = ROOT / "ops/bindings/ssh.targets.yaml"
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

    for backup in ensure_list(ensure_dict(closure.get("backups")).get("jobs")):
        backup_row = ensure_dict(backup)
        job_id = str(backup_row.get("job_id") or "").strip()
        expected_host = str(backup_row.get("expected_host") or active_host).strip()
        expected_script_ref = str(backup_row.get("expected_script_ref") or "").strip()
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

    route_registry_path = resolve_env_path("SPINE_SERVICE_CLOSURE_ROUTE_REGISTRY", DEFAULT_ROUTE_REGISTRY)
    ingress_projection_path = resolve_env_path("SPINE_SERVICE_CLOSURE_INGRESS_PROJECTION", DEFAULT_INGRESS_PROJECTION)
    services_health_path = resolve_env_path("SPINE_SERVICE_CLOSURE_SERVICES_HEALTH", DEFAULT_SERVICES_HEALTH)
    backup_schedule_path = resolve_env_path("SPINE_SERVICE_CLOSURE_BACKUP_SCHEDULE", DEFAULT_BACKUP_SCHEDULE)
    ssh_targets_path = resolve_env_path("SPINE_SERVICE_CLOSURE_SSH_TARGETS", DEFAULT_SSH_TARGETS)

    route_registry_rows = flatten_route_registry(load_yaml(route_registry_path))
    ingress_projection_rows = flatten_ingress_projection(load_yaml(ingress_projection_path))
    services_health_rows = load_services_health(load_yaml(services_health_path))
    backup_job_rows = load_backup_jobs(load_yaml(backup_schedule_path))
    live_cloudflare_rows, live_cloudflare_error = load_live_cloudflare_routes(defaults)
    ssh_probe = SSHProbe(ssh_targets_path)

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
            route_registry_rows=route_registry_rows,
            ingress_projection_rows=ingress_projection_rows,
            live_cloudflare_rows=live_cloudflare_rows,
            live_cloudflare_error=live_cloudflare_error,
            services_health_rows=services_health_rows,
            backup_job_rows=backup_job_rows,
            ssh_probe=ssh_probe,
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
