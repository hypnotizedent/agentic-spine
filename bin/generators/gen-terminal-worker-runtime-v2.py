#!/usr/bin/env python3
"""Generate Terminal Worker Runtime Contract v2 artifacts.

Outputs:
- ops/bindings/terminal.worker.catalog.yaml
- ops/bindings/routing.dispatch.yaml
- ops/bindings/terminal.launcher.view.yaml
- docs/governance/generated/worker-usage/*.md
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[2]

AGENTS_REGISTRY = ROOT / "ops/bindings/agents.registry.yaml"
TERMINAL_ROLE_CONTRACT = ROOT / "ops/bindings/terminal.role.contract.yaml"
GATE_DOMAIN_PROFILES = ROOT / "ops/bindings/gate.domain.profiles.yaml"
GATE_AGENT_PROFILES = ROOT / "ops/bindings/gate.agent.profiles.yaml"
CAPABILITIES_REGISTRY = ROOT / "ops/capabilities.yaml"

WORKER_CATALOG_OUT = ROOT / "ops/bindings/terminal.worker.catalog.yaml"
ROUTING_DISPATCH_OUT = ROOT / "ops/bindings/routing.dispatch.yaml"
LAUNCHER_VIEW_OUT = ROOT / "ops/bindings/terminal.launcher.view.yaml"
WORKER_USAGE_DIR = ROOT / "docs/governance/generated/worker-usage"

GENERATOR_ID = "bin/generators/gen-terminal-worker-runtime-v2.py"

DOMAIN_ALIASES = {
    "home-assistant": "home",
    "home-automation": "home",
    "finance-ops": "finance",
    "identity": "microsoft",
    "photos": "immich",
    "media-library": "immich",
    "commerce": "mint",
    "automation": "n8n",
    "documents": "finance",
}

CORE_CAPABILITY_PREFIXES = (
    "spine.",
    "verify.",
    "stability.",
    "proposals.",
    "loops.",
    "gaps.",
    "docs.",
    "authority.",
    "mailroom.",
    "codex.",
    "agent.",
    "session.",
)

DOMAIN_SCORING_PREFIX_EXCLUSIONS = (
    "mcp.",
    "verify.",
    "secrets.",
    "docs.",
    "authority.",
    "spine.",
    "loops.",
    "gaps.",
    "proposals.",
)


def _today() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _iso_from_epoch(epoch: float) -> str:
    return datetime.fromtimestamp(epoch, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _source_timestamp(paths: list[Path]) -> str:
    latest = 0.0
    for path in paths:
        if path.exists():
            latest = max(latest, path.stat().st_mtime)
    if latest <= 0.0:
        latest = datetime.now(tz=timezone.utc).timestamp()
    return _iso_from_epoch(latest)


def _load_yaml(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"missing required input: {path}")
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def _sorted_unique(values: list[str]) -> list[str]:
    return sorted({str(v) for v in values if v is not None and str(v).strip()})


def _normalize_path(path: str) -> str:
    text = str(path).strip()
    if text.startswith("./"):
        return text[2:]
    return text


def _normalize_domain(domain: str) -> str:
    key = str(domain or "").strip().lower()
    if not key:
        return "core"
    return DOMAIN_ALIASES.get(key, key)


def _humanize_domain(domain: str) -> str:
    text = str(domain).replace("-", " ").replace("_", " ").strip()
    return " ".join(token.capitalize() for token in text.split())


def _infer_lane_profile(terminal_id: str, terminal_type: str) -> str:
    if terminal_id == "SPINE-CONTROL-01":
        return "control"
    if terminal_id == "SPINE-EXECUTION-01":
        return "execution"
    if terminal_id == "SPINE-AUDIT-01":
        return "audit"
    if terminal_id == "SPINE-WATCHER-01":
        return "watcher"
    if terminal_type == "domain-runtime":
        return "execution"
    return "control"


def _infer_domain_from_terminal_id(terminal_id: str) -> str:
    parts = terminal_id.split("-")
    if len(parts) >= 3:
        candidate = "-".join(parts[1:-1]).lower()
        return _normalize_domain(candidate)
    return "core"


def _first_endpoint_url(agent: dict[str, Any] | None) -> str | None:
    if not agent:
        return None
    endpoints = agent.get("endpoints") or {}
    if isinstance(endpoints, dict):
        for key in sorted(endpoints.keys()):
            endpoint = endpoints.get(key) or {}
            url = endpoint.get("url")
            if url:
                return str(url)
    return None


def _extract_command_target(command: str) -> dict[str, Any]:
    command = str(command or "").strip()

    plugin_matches = list(re.finditer(r"\./ops/plugins/([^\s/]+)/bin/([^\s]+)", command))
    if plugin_matches:
        match = plugin_matches[-1]
        plugin = match.group(1)
        script = match.group(2)
        remainder = command[match.end() :].strip()
        subcommand = remainder.split()[0] if remainder else None
        return {
            "type": "plugin",
            "plugin": plugin,
            "script": script,
            "subcommand": subcommand,
            "command": command,
        }

    verify_match = re.search(r"\./surfaces/verify/([^\s]+)", command)
    if verify_match:
        script = verify_match.group(1)
        remainder = command[verify_match.end() :].strip()
        subcommand = remainder.split()[0] if remainder else None
        return {
            "type": "plugin",
            "plugin": "verify",
            "script": script,
            "subcommand": subcommand,
            "command": command,
        }

    inbox_match = re.search(r"\./ops/runtime/inbox/([^\s]+)", command)
    if inbox_match:
        script = inbox_match.group(1)
        remainder = command[inbox_match.end() :].strip()
        subcommand = remainder.split()[0] if remainder else None
        return {
            "type": "plugin",
            "plugin": "inbox",
            "script": script,
            "subcommand": subcommand,
            "command": command,
        }

    command_match = re.search(r"\./ops/commands/([^\s]+)", command)
    if command_match:
        script = command_match.group(1)
        remainder = command[command_match.end() :].strip()
        subcommand = remainder.split()[0] if remainder else None
        return {
            "type": "plugin",
            "plugin": "ops",
            "script": script,
            "subcommand": subcommand,
            "command": command,
        }

    return {
        "type": "builtin",
        "command": command,
    }


def _resolve_agent_for_role(
    role: dict[str, Any],
    agents: list[dict[str, Any]],
    agent_by_contract: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    write_scope = role.get("write_scope") or []
    for path in write_scope:
        normalized = _normalize_path(str(path))
        if normalized in agent_by_contract:
            return agent_by_contract[normalized]

    role_caps = set(role.get("capabilities") or [])
    if not role_caps:
        return None

    def status_rank(agent: dict[str, Any]) -> int:
        status = str(agent.get("implementation_status", "")).lower()
        if status == "active":
            return 0
        if status == "planned":
            return 1
        if status == "superseded":
            return 3
        return 2

    best_agent = None
    best_tuple = (-1, 99, "")
    for agent in agents:
        caps = set(agent.get("capabilities") or [])
        overlap = len(role_caps.intersection(caps))
        if overlap <= 0:
            continue
        candidate = (overlap, -status_rank(agent), str(agent.get("id", "")))
        if candidate > best_tuple:
            best_tuple = candidate
            best_agent = agent
    return best_agent


def _resolve_agent_capabilities(
    agent: dict[str, Any],
    all_capabilities: set[str],
) -> tuple[list[str], list[str]]:
    scope = agent.get("capabilities_scope") or {}
    include_prefixes = scope.get("include_prefixes") or []
    include_keys = scope.get("include_keys") or []
    exclude_keys = set(scope.get("exclude_keys") or [])

    resolved: set[str] = set()
    if include_prefixes or include_keys:
        resolved.update(str(key) for key in include_keys)
        for capability in all_capabilities:
            if any(capability.startswith(prefix) for prefix in include_prefixes):
                resolved.add(capability)
    else:
        resolved.update(str(key) for key in (agent.get("capabilities") or []))

    resolved = {cap for cap in resolved if cap not in exclude_keys}
    unknown = sorted(cap for cap in resolved if cap not in all_capabilities)
    valid = sorted(cap for cap in resolved if cap in all_capabilities)
    return valid, unknown


def _resolve_verify_domain(
    capabilities_scoped: list[str],
    gate_domains: dict[str, Any],
    fallback_domain: str,
) -> str:
    fallback = _normalize_domain(fallback_domain)

    best_domain = fallback if fallback in gate_domains else "core"
    best_score = -1

    for domain, profile in gate_domains.items():
        prefixes = [
            prefix
            for prefix in (profile.get("capability_prefixes") or [])
            if str(prefix) not in DOMAIN_SCORING_PREFIX_EXCLUSIONS
        ]
        score = 0
        for capability in capabilities_scoped:
            if any(str(capability).startswith(str(prefix)) for prefix in prefixes):
                score += 1
        if score > best_score:
            best_score = score
            best_domain = domain

    if best_score <= 0 and fallback in gate_domains:
        return fallback
    return best_domain


def _verify_command_for_domain(domain: str) -> str:
    if domain == "core":
        return "./bin/ops cap run verify.core.run"
    return f"./bin/ops cap run verify.pack.run {domain}"


def _label_for_terminal(terminal_id: str, worker: dict[str, Any]) -> str:
    if terminal_id.startswith("SPINE-"):
        token = terminal_id.split("-")[1].capitalize()
        return f"Spine {token}"

    domain = worker.get("domain")
    if domain:
        return _humanize_domain(str(domain))

    return terminal_id


def _build_worker_catalog(
    roles: list[dict[str, Any]],
    agents: list[dict[str, Any]],
    gate_domains: dict[str, Any],
    agent_profiles: dict[str, dict[str, Any]],
    all_capability_keys: set[str],
    generated_at: str,
) -> dict[str, Any]:
    agent_by_contract: dict[str, dict[str, Any]] = {}
    for agent in agents:
        contract = agent.get("contract")
        if contract:
            agent_by_contract[_normalize_path(str(contract))] = agent

    ordered_roles = sorted(
        roles,
        key=lambda role: (
            int(role.get("sort_order", 9999)),
            str(role.get("id", "")),
        ),
    )

    workers: dict[str, dict[str, Any]] = {}

    for role in ordered_roles:
        terminal_id = str(role.get("id"))
        if not terminal_id:
            continue

        terminal_type = str(role.get("type", "unknown"))
        role_status = str(role.get("status", "planned"))

        agent = None
        if terminal_type == "domain-runtime":
            agent = _resolve_agent_for_role(role, agents, agent_by_contract)

        if terminal_type == "domain-runtime" and agent:
            capabilities_scoped, unknown_capabilities = _resolve_agent_capabilities(agent, all_capability_keys)
            if not capabilities_scoped:
                capabilities_scoped = _sorted_unique(role.get("capabilities") or [])
            domain_raw = str(agent.get("domain") or _infer_domain_from_terminal_id(terminal_id))
        else:
            capabilities_scoped = _sorted_unique(role.get("capabilities") or [])
            unknown_capabilities = []
            domain_raw = "core" if terminal_type != "domain-runtime" else _infer_domain_from_terminal_id(terminal_id)

        fallback_domain = _normalize_domain(domain_raw)
        if terminal_type == "domain-runtime":
            verify_domain = _resolve_verify_domain(capabilities_scoped, gate_domains, fallback_domain)
        else:
            verify_domain = "core"

        gates_scoped: list[str]
        if agent:
            agent_profile = agent_profiles.get(str(agent.get("id", "")))
            if agent_profile and agent_profile.get("gate_ids"):
                gates_scoped = _sorted_unique([str(g) for g in agent_profile.get("gate_ids") or []])
            else:
                gates_scoped = _sorted_unique([str(g) for g in (gate_domains.get(verify_domain, {}) or {}).get("gate_ids", [])])
        else:
            gates_scoped = _sorted_unique([str(g) for g in (gate_domains.get("core", {}) or {}).get("gate_ids", [])])

        open_work_domain_filter = _sorted_unique([domain_raw, verify_domain])
        if terminal_type == "control-plane":
            open_work_domain_filter = ["*"]

        terminal_binding = {}
        if agent:
            terminal_binding = agent.get("terminal_binding") or {}

        worker_entry: dict[str, Any] = {
            "terminal_id": terminal_id,
            "terminal_type": terminal_type,
            "status": role_status,
            "description": role.get("description"),
            "domain": domain_raw,
            "agent_id": agent.get("id") if agent else None,
            "agent_contract": agent.get("contract") if agent else None,
            "capabilities_scoped": capabilities_scoped,
            "gates_scoped": gates_scoped,
            "write_scope": role.get("write_scope") or [],
            "verify_pack": {
                "domain": verify_domain,
                "command": _verify_command_for_domain(verify_domain),
            },
            "open_work_scope": {
                "domain_filter": open_work_domain_filter,
            },
            "usage_surface": f"docs/governance/generated/worker-usage/{terminal_id}.md",
            "launcher_ref": {
                "hotkey": terminal_binding.get("hotkey"),
                "picker_group": role.get("picker_group"),
                "sort_order": role.get("sort_order"),
                "lane_profile": terminal_binding.get("lane_profile") or _infer_lane_profile(terminal_id, terminal_type),
                "verify_domain": terminal_binding.get("verify_domain") or verify_domain,
            },
            "default_tool": role.get("default_tool"),
        }

        if unknown_capabilities:
            worker_entry["capabilities_missing_from_registry"] = unknown_capabilities

        if agent and agent.get("endpoints"):
            worker_entry["endpoints"] = agent.get("endpoints")
        if agent and agent.get("mcp_tools"):
            worker_entry["mcp_tools"] = agent.get("mcp_tools")

        workers[terminal_id] = worker_entry

    return {
        "status": "generated",
        "owner": "@ronny",
        "last_verified": _today(),
        "scope": "terminal-worker-runtime-catalog",
        "version": "2.0",
        "generated_at": generated_at,
        "generated_by": GENERATOR_ID,
        "generated_from": [
            "ops/bindings/agents.registry.yaml",
            "ops/bindings/terminal.role.contract.yaml",
            "ops/bindings/gate.domain.profiles.yaml",
            "ops/bindings/gate.agent.profiles.yaml",
            "ops/capabilities.yaml",
        ],
        "workers": workers,
    }


def _status_rank(agent: dict[str, Any]) -> int:
    status = str(agent.get("implementation_status", "")).lower()
    if status == "active":
        return 0
    if status == "planned":
        return 1
    if status == "superseded":
        return 3
    return 2


def _infer_capability_domain(capability_id: str, declared_domain: str | None) -> str:
    if declared_domain and declared_domain != "none":
        return str(declared_domain)
    if capability_id.startswith(CORE_CAPABILITY_PREFIXES):
        return "core"
    if "." in capability_id:
        return capability_id.split(".", 1)[0]
    return "core"


def _build_routing_dispatch(
    capabilities: dict[str, Any],
    agents: list[dict[str, Any]],
    workers: dict[str, Any],
    generated_at: str,
) -> dict[str, Any]:
    worker_ids = sorted(
        workers.keys(),
        key=lambda terminal_id: (
            int((workers.get(terminal_id) or {}).get("launcher_ref", {}).get("sort_order") or 9999),
            terminal_id,
        ),
    )

    capability_to_agent_candidates: dict[str, list[dict[str, Any]]] = {}
    for agent in agents:
        for capability in agent.get("capabilities") or []:
            capability_to_agent_candidates.setdefault(str(capability), []).append(agent)

    def choose_owner(capability_id: str) -> dict[str, Any] | None:
        candidates = capability_to_agent_candidates.get(capability_id, [])
        if not candidates:
            return None
        ordered = sorted(
            candidates,
            key=lambda agent: (_status_rank(agent), str(agent.get("id", ""))),
        )
        return ordered[0]

    dispatch_map: dict[str, Any] = {}
    for capability_id in sorted(capabilities.keys()):
        cap = capabilities[capability_id] or {}
        command = str(cap.get("command", "")).strip()
        target = _extract_command_target(command)
        owner = choose_owner(capability_id)

        affinity = [
            terminal_id
            for terminal_id in worker_ids
            if capability_id in ((workers.get(terminal_id) or {}).get("capabilities_scoped") or [])
        ]

        execution_target = "builtin"
        if target.get("type") == "plugin":
            execution_target = "plugin"
        if (
            target.get("type") == "plugin"
            and target.get("plugin") == "agent"
            and target.get("script") == "agent-route"
        ):
            execution_target = "agent"

        target_payload: dict[str, Any]
        if execution_target == "plugin":
            target_payload = {
                "plugin": target.get("plugin"),
                "script": target.get("script"),
            }
            if target.get("subcommand"):
                target_payload["subcommand"] = target.get("subcommand")
            target_payload["command"] = target.get("command")
        elif execution_target == "agent":
            target_payload = {
                "router": "ops/plugins/agent/bin/agent-route",
                "command": target.get("command"),
            }
        else:
            target_payload = {
                "command": command,
            }

        dispatch_map[capability_id] = {
            "capability_id": capability_id,
            "domain": _infer_capability_domain(capability_id, cap.get("domain")),
            "execution_target": execution_target,
            "safety": cap.get("safety"),
            "approval": cap.get("approval"),
            "target": target_payload,
            "agent_id": owner.get("id") if owner else None,
            "terminal_affinity": affinity,
            "description": cap.get("description"),
        }

    return {
        "status": "generated",
        "owner": "@ronny",
        "last_verified": _today(),
        "scope": "routing-dispatch",
        "version": "2.0",
        "generated_at": generated_at,
        "generated_by": GENERATOR_ID,
        "generated_from": [
            "ops/capabilities.yaml",
            "ops/bindings/agents.registry.yaml",
            "ops/bindings/terminal.worker.catalog.yaml",
        ],
        "dispatch": dispatch_map,
    }


def _build_launcher_view(workers: dict[str, Any], generated_at: str) -> dict[str, Any]:
    ordered_worker_ids = sorted(
        workers.keys(),
        key=lambda terminal_id: (
            int((workers.get(terminal_id) or {}).get("launcher_ref", {}).get("sort_order") or 9999),
            terminal_id,
        ),
    )

    terminals: dict[str, Any] = {}
    for terminal_id in ordered_worker_ids:
        worker = workers[terminal_id]
        launcher_ref = worker.get("launcher_ref") or {}

        tags = _sorted_unique(
            [
                worker.get("terminal_type") or "",
                str(worker.get("domain") or ""),
                str(worker.get("agent_id") or ""),
                str(launcher_ref.get("lane_profile") or ""),
            ]
        )

        terminals[terminal_id] = {
            "terminal_id": terminal_id,
            "label": _label_for_terminal(terminal_id, worker),
            "description": worker.get("description"),
            "status": worker.get("status"),
            "picker_group": launcher_ref.get("picker_group"),
            "sort_order": launcher_ref.get("sort_order"),
            "hotkey": launcher_ref.get("hotkey"),
            "default_tool": worker.get("default_tool"),
            "domain": worker.get("domain"),
            "agent_id": worker.get("agent_id"),
            "lane_profile": launcher_ref.get("lane_profile"),
            "verify_domain": launcher_ref.get("verify_domain"),
            "capability_count": len(worker.get("capabilities_scoped") or []),
            "gate_count": len(worker.get("gates_scoped") or []),
            "health_url": _first_endpoint_url(worker),
            "usage_doc": worker.get("usage_surface"),
            "tags": tags,
        }

    return {
        "status": "generated",
        "owner": "@ronny",
        "last_verified": _today(),
        "scope": "terminal-launcher-view",
        "version": "2.0",
        "generated_at": generated_at,
        "generated_by": GENERATOR_ID,
        "generated_from": [
            "ops/bindings/terminal.worker.catalog.yaml",
            "ops/bindings/terminal.role.contract.yaml",
        ],
        "terminals": terminals,
    }


def _render_worker_usage_doc(worker: dict[str, Any]) -> str:
    terminal_id = worker.get("terminal_id")
    capabilities = worker.get("capabilities_scoped") or []
    gates = worker.get("gates_scoped") or []
    write_scope = worker.get("write_scope") or []
    verify_pack = worker.get("verify_pack") or {}

    lines: list[str] = [
        "---",
        "status: generated",
        "owner: \"@ronny\"",
        f"last_verified: {_today()}",
        f"scope: worker-usage-{str(terminal_id).lower()}",
        "source_catalog: ops/bindings/terminal.worker.catalog.yaml",
        "---",
        "",
        f"# {terminal_id} Usage Surface",
        "",
        f"- Terminal ID: `{terminal_id}`",
        f"- Terminal Type: `{worker.get('terminal_type')}`",
        f"- Status: `{worker.get('status')}`",
        f"- Domain: `{worker.get('domain')}`",
        f"- Agent ID: `{worker.get('agent_id') or 'none'}`",
        f"- Verify Command: `{verify_pack.get('command', '')}`",
        "",
        "## Write Scope",
    ]

    if write_scope:
        for path in write_scope:
            lines.append(f"- `{path}`")
    else:
        lines.append("- (none)")

    lines.extend([
        "",
        f"## Capabilities ({len(capabilities)})",
    ])

    if capabilities:
        for capability in capabilities:
            lines.append(f"- `{capability}`")
    else:
        lines.append("- (none)")

    lines.extend([
        "",
        f"## Gates ({len(gates)})",
    ])

    if gates:
        for gate in gates:
            lines.append(f"- `{gate}`")
    else:
        lines.append("- (none)")

    lines.extend([
        "",
        "## Boundaries",
        "- Runtime surface is generated from registration and role contracts.",
        "- Do not hand-edit this file; regenerate via the generator script.",
        "",
    ])

    return "\n".join(lines)


def _render_worker_usage_index(worker_ids: list[str]) -> str:
    lines = [
        "---",
        "status: generated",
        "owner: \"@ronny\"",
        f"last_verified: {_today()}",
        "scope: worker-usage-generated-index",
        "source_catalog: ops/bindings/terminal.worker.catalog.yaml",
        "---",
        "",
        "# Worker Usage Surfaces",
        "",
        "This directory is generated by `bin/generators/gen-terminal-worker-runtime-v2.py`.",
        "",
        "## Regenerate",
        "- `./bin/generators/gen-terminal-worker-runtime-v2.py`",
        "",
        "## Files",
    ]
    for terminal_id in worker_ids:
        lines.append(f"- `{terminal_id}.md`")
    lines.append("")
    return "\n".join(lines)


def _dump_yaml(document: dict[str, Any]) -> str:
    payload = yaml.safe_dump(document, sort_keys=False, allow_unicode=False)
    return f"---\n{payload}"


def _write_if_changed(path: Path, content: str, check_only: bool) -> bool:
    current = ""
    if path.exists():
        current = path.read_text(encoding="utf-8")

    if current == content:
        return False

    if not check_only:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    return True


def _collect_existing_usage_docs() -> set[Path]:
    if not WORKER_USAGE_DIR.exists():
        return set()
    return {path for path in WORKER_USAGE_DIR.glob("*.md") if path.is_file()}


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate terminal worker runtime v2 artifacts.")
    parser.add_argument(
        "--target",
        action="append",
        choices=["all", "catalog", "dispatch", "launcher", "usage"],
        help="artifact target to generate (default: all)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="check mode: fail if generated output differs from disk",
    )
    args = parser.parse_args()

    raw_targets = args.target or ["all"]
    targets = set(raw_targets)
    if "all" in targets:
        targets = {"catalog", "dispatch", "launcher", "usage"}

    agents_doc = _load_yaml(AGENTS_REGISTRY)
    roles_doc = _load_yaml(TERMINAL_ROLE_CONTRACT)
    gate_domain_doc = _load_yaml(GATE_DOMAIN_PROFILES)
    gate_agent_doc = _load_yaml(GATE_AGENT_PROFILES)
    capabilities_doc = _load_yaml(CAPABILITIES_REGISTRY)

    agents = agents_doc.get("agents") or []
    roles = roles_doc.get("roles") or []
    gate_domains = gate_domain_doc.get("domains") or {}
    agent_profiles = {
        str(profile.get("agent_id")): profile
        for profile in (gate_agent_doc.get("profiles") or [])
        if profile.get("agent_id")
    }
    capabilities = capabilities_doc.get("capabilities") or {}
    all_capability_keys = set(capabilities.keys())

    generated_at = _source_timestamp(
        [
            AGENTS_REGISTRY,
            TERMINAL_ROLE_CONTRACT,
            GATE_DOMAIN_PROFILES,
            GATE_AGENT_PROFILES,
            CAPABILITIES_REGISTRY,
            Path(__file__),
        ]
    )

    catalog = _build_worker_catalog(
        roles,
        agents,
        gate_domains,
        agent_profiles,
        all_capability_keys,
        generated_at,
    )
    workers = catalog.get("workers") or {}

    dispatch = _build_routing_dispatch(capabilities, agents, workers, generated_at)
    launcher = _build_launcher_view(workers, generated_at)

    changed_paths: list[Path] = []

    if "catalog" in targets:
        content = _dump_yaml(catalog)
        if _write_if_changed(WORKER_CATALOG_OUT, content, args.check):
            changed_paths.append(WORKER_CATALOG_OUT)

    if "dispatch" in targets:
        content = _dump_yaml(dispatch)
        if _write_if_changed(ROUTING_DISPATCH_OUT, content, args.check):
            changed_paths.append(ROUTING_DISPATCH_OUT)

    if "launcher" in targets:
        content = _dump_yaml(launcher)
        if _write_if_changed(LAUNCHER_VIEW_OUT, content, args.check):
            changed_paths.append(LAUNCHER_VIEW_OUT)

    if "usage" in targets:
        expected_paths: set[Path] = set()
        ordered_worker_ids = sorted(
            workers.keys(),
            key=lambda terminal_id: (
                int((workers.get(terminal_id) or {}).get("launcher_ref", {}).get("sort_order") or 9999),
                terminal_id,
            ),
        )

        for terminal_id in ordered_worker_ids:
            worker = workers[terminal_id]
            usage_path = WORKER_USAGE_DIR / f"{terminal_id}.md"
            expected_paths.add(usage_path)
            usage_content = _render_worker_usage_doc(worker)
            if _write_if_changed(usage_path, usage_content, args.check):
                changed_paths.append(usage_path)

        index_path = WORKER_USAGE_DIR / "README.md"
        expected_paths.add(index_path)
        index_content = _render_worker_usage_index(ordered_worker_ids)
        if _write_if_changed(index_path, index_content, args.check):
            changed_paths.append(index_path)

        # Remove stale generated usage docs that no longer map to known terminals.
        for stale_path in sorted(_collect_existing_usage_docs() - expected_paths):
            if args.check:
                changed_paths.append(stale_path)
            else:
                stale_path.unlink(missing_ok=True)
                changed_paths.append(stale_path)

    if args.check:
        if changed_paths:
            print("drift detected in generated artifacts:", file=sys.stderr)
            for path in changed_paths:
                print(f"- {path.relative_to(ROOT)}", file=sys.stderr)
            return 1
        print("generated artifacts are in sync")
        return 0

    if changed_paths:
        print("updated generated artifacts:")
        for path in changed_paths:
            print(f"- {path.relative_to(ROOT)}")
    else:
        print("no generated artifact changes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
