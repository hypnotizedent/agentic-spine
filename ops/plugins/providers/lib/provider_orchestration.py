#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

import yaml


def detect_root() -> Path:
    here = Path(__file__).resolve()
    for candidate in [here.parent] + list(here.parents):
        if (candidate / "ops/bindings").is_dir() and (candidate / "ops").is_dir():
            return candidate
    raise SystemExit(f"FAIL: unable to resolve repo root from {here}")


ROOT = detect_root()
DEFAULT_CONTRACT = ROOT / "ops/bindings/provider.orchestration.bundle.yaml"
INF_AGENT = ROOT / "ops/tools/infisical-agent.sh"


def shutil_which(name: str) -> str | None:
    for base in os.environ.get("PATH", "").split(os.pathsep):
        if not base:
            continue
        candidate = Path(base) / name
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def router_available() -> bool:
    return shutil_which("ccr") is not None


def codex_login_probe() -> dict[str, Any]:
    codex_bin = shutil_which("codex")
    if codex_bin is None:
        return {
            "installed": False,
            "logged_in": False,
            "detail": "codex cli not installed",
        }

    try:
        proc = subprocess.run(
            [codex_bin, "login", "status"],
            capture_output=True,
            text=True,
            check=False,
        )
    except Exception as exc:
        return {
            "installed": True,
            "logged_in": False,
            "detail": str(exc),
        }

    detail = ((proc.stdout or "") + (proc.stderr or "")).strip()
    return {
        "installed": True,
        "logged_in": proc.returncode == 0,
        "detail": detail,
    }


def load_contract(path: Path | None = None) -> dict[str, Any]:
    contract_path = path or DEFAULT_CONTRACT
    data = yaml.safe_load(contract_path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"FAIL: invalid provider contract: {contract_path}")
    return data


def env_value(
    keys: list[str],
    *,
    allow_cached: bool = True,
    project: str = "infrastructure",
    environment: str = "prod",
) -> tuple[str, str | None]:
    for key in keys:
        val = os.environ.get(key, "").strip()
        if val:
            return key, val
    if allow_cached and INF_AGENT.exists() and os.access(INF_AGENT, os.X_OK):
        for key in keys:
            try:
                out = subprocess.run(
                    [str(INF_AGENT), "get-cached", project, environment, key],
                    capture_output=True,
                    text=True,
                    check=False,
                )
            except Exception:
                continue
            value = (out.stdout or "").strip()
            if out.returncode == 0 and value:
                return key, value
    return "", None


def surface_from_tool(tool: str) -> str:
    surface_map = {
        "claude": "claude_code",
        "codex": "codex",
        "opencode": "opencode",
        "spine_engine": "spine_engine",
        "claude_desktop": "claude_desktop",
    }
    return surface_map.get(tool, tool)


def surface_block(contract: dict[str, Any], surface: str) -> dict[str, Any]:
    surfaces = contract.get("surfaces", {}) if isinstance(contract.get("surfaces"), dict) else {}
    block = surfaces.get(surface)
    if not isinstance(block, dict):
        raise SystemExit(f"FAIL: unknown surface: {surface}")
    return block


def local_endpoint_status(base_url: str, models_path: str | None = None) -> dict[str, Any]:
    models_url = f"{base_url.rstrip('/')}{models_path or '/models'}"
    req = urllib.request.Request(models_url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=1.5) as resp:
            payload = resp.read(4096).decode("utf-8", errors="replace")
            return {
                "reachable": True,
                "http_status": getattr(resp, "status", 200),
                "sample": payload[:200],
            }
    except urllib.error.HTTPError as exc:
        return {"reachable": True, "http_status": exc.code, "sample": ""}
    except Exception as exc:
        return {"reachable": False, "error": str(exc)}


def provider_status(contract: dict[str, Any], provider_id: str) -> dict[str, Any]:
    defaults = contract.get("defaults", {}) if isinstance(contract.get("defaults"), dict) else {}
    project = str(defaults.get("infisical_project", "infrastructure"))
    environment = str(defaults.get("infisical_environment", "prod"))
    providers = contract.get("providers", {}) if isinstance(contract.get("providers"), dict) else {}
    provider = providers.get(provider_id)
    if not isinstance(provider, dict):
        raise KeyError(provider_id)

    env_keys = [str(x) for x in provider.get("env_keys", []) if str(x).strip()]
    auth_required = bool(provider.get("auth_required", True))
    matched_key, value = env_value(env_keys, allow_cached=True, project=project, environment=environment)
    ready = (not auth_required) or bool(value)
    missing_env = [] if ready else env_keys

    endpoint = provider.get("endpoint", {}) if isinstance(provider.get("endpoint"), dict) else {}
    local_probe = None
    if provider_id == "codex_native":
        local_probe = codex_login_probe()
        ready = bool(local_probe.get("installed", False))
        missing_env = []
    elif provider_id == "local_lmstudio":
        local_probe = local_endpoint_status(
            str(endpoint.get("base_url", "http://127.0.0.1:1234/v1")),
            str(endpoint.get("models_path", "/models")),
        )
        ready = bool(local_probe.get("reachable", False))
        missing_env = []

    return {
        "id": provider_id,
        "display_name": provider.get("display_name", provider_id),
        "engine_backend": provider.get("engine_backend", "unknown"),
        "ready": ready,
        "matched_env_key": matched_key or None,
        "missing_env": missing_env,
        "endpoint_base_url": endpoint.get("base_url"),
        "surface_support": provider.get("surface_support", []),
        "local_probe": local_probe,
    }


def provider_surface_status(contract: dict[str, Any], provider_id: str, surface: str) -> dict[str, Any]:
    base = provider_status(contract, provider_id)
    provider = contract["providers"][provider_id]
    supported_surfaces = provider.get("surface_support", []) if isinstance(provider.get("surface_support"), list) else []
    supported = surface in {str(x) for x in supported_surfaces}
    router_required_surfaces = {
        str(x) for x in provider.get("router_required_surfaces", [])
        if isinstance(provider.get("router_required_surfaces"), list)
    }
    router_needed = surface in router_required_surfaces
    router_ok = (not router_needed) or router_available()

    mode = str(surface_block(contract, surface).get("mode", "dynamic"))
    fixed_upstream = mode == "fixed_upstream"
    if fixed_upstream and provider_id != "anthropic":
        supported = False

    ready = bool(base["ready"]) and supported and router_ok
    status = dict(base)
    status.update(
        {
            "surface": surface,
            "supported": supported,
            "ready": ready,
            "router_required": router_needed,
            "router_available": router_ok,
            "fixed_upstream": fixed_upstream,
        }
    )
    if router_needed and not router_ok:
        status["reason"] = "claude-code-router not installed"
    elif not supported:
        status["reason"] = f"provider not supported on surface={surface}"
    elif not base["ready"]:
        if provider_id == "codex_native":
            status["reason"] = "codex cli unavailable"
        else:
            status["reason"] = "credentials or endpoint unavailable"
    return status


_ALIAS_MAP = {
    "local": "local_echo",
    "claude": "anthropic",
    "zai": "zai",
    "openai": "openai",
    "auto": "auto",
}


def normalize_provider_id(requested: str | None) -> str | None:
    if not requested:
        return None
    return _ALIAS_MAP.get(requested, requested)


def candidate_ids_for_surface(contract: dict[str, Any], surface: str, requested: str | None = None) -> list[str]:
    requested = normalize_provider_id(requested)
    if requested and requested != "auto":
        return [requested]

    block = surface_block(contract, surface)
    candidates: list[str] = []
    if surface == "claude_code":
        candidates.extend(str(x) for x in block.get("direct_chain", []) if str(x).strip())
        if router_available():
            candidates.extend(str(x) for x in block.get("router_chain", []) if str(x).strip())
    else:
        candidates.extend(str(x) for x in block.get("default_chain", []) if str(x).strip())

    deduped: list[str] = []
    for candidate in candidates:
        if candidate not in deduped:
            deduped.append(candidate)
    return deduped


def surface_status(contract: dict[str, Any], surface: str, requested: str | None = None) -> dict[str, Any]:
    block = surface_block(contract, surface)
    candidates = [provider_surface_status(contract, provider_id, surface) for provider_id in candidate_ids_for_surface(contract, surface, requested)]
    selected = next((status["id"] for status in candidates if status["ready"]), None)
    return {
        "surface": surface,
        "mode": str(block.get("mode", "dynamic")),
        "description": str(block.get("description", "")),
        "requested": normalize_provider_id(requested) or "auto",
        "selected": selected,
        "router_available": router_available(),
        "candidates": candidates,
    }


def choose_provider(contract: dict[str, Any], surface: str, requested: str | None = None) -> tuple[str, dict[str, Any], list[dict[str, Any]]]:
    status = surface_status(contract, surface, requested)
    statuses = status["candidates"]
    for candidate in statuses:
        if candidate["ready"]:
            return str(candidate["id"]), candidate, statuses
    checked = ",".join(str(candidate["id"]) for candidate in statuses) or "<none>"
    raise SystemExit(f"FAIL: no ready providers for surface={surface}; checked={checked}")


def provider_model(contract: dict[str, Any], provider_id: str, surface: str) -> str:
    defaults = contract.get("defaults", {}) if isinstance(contract.get("defaults"), dict) else {}
    local_default = str(defaults.get("local_lmstudio_model_default", "qwen3-coder-30b-a3b-instruct"))
    provider = contract["providers"][provider_id]
    if provider_id == "local_echo":
        return "local-echo"
    if provider_id == "local_lmstudio":
        env_key = str(
            provider.get(surface, {}).get(
                "model_env",
                defaults.get("local_lmstudio_model_env", "SPINE_LOCAL_LMSTUDIO_MODEL"),
            )
        )
        return os.environ.get(env_key, local_default)
    block = provider.get(surface, {}) if isinstance(provider.get(surface), dict) else {}
    model = block.get("model")
    if isinstance(model, str) and model.strip():
        return model.strip()
    models = provider.get("models", {}) if isinstance(provider.get("models"), dict) else {}
    model = models.get(surface)
    if isinstance(model, str) and model.strip():
        return model.strip()
    raise SystemExit(f"FAIL: no model configured for provider={provider_id} surface={surface}")


def opencode_small_model(contract: dict[str, Any], provider_id: str) -> str:
    provider = contract["providers"][provider_id]
    defaults = contract.get("defaults", {}) if isinstance(contract.get("defaults"), dict) else {}
    local_default = str(defaults.get("local_lmstudio_model_default", "qwen3-coder-30b-a3b-instruct"))
    if provider_id == "local_lmstudio":
        env_key = str(
            provider.get("opencode", {}).get(
                "small_model_env",
                defaults.get("local_lmstudio_model_env", "SPINE_LOCAL_LMSTUDIO_MODEL"),
            )
        )
        return os.environ.get(env_key, local_default)
    block = provider.get("opencode", {}) if isinstance(provider.get("opencode"), dict) else {}
    return str(block.get("small_model") or block.get("model") or provider_model(contract, provider_id, "opencode"))


def openai_headers(contract: dict[str, Any], provider_id: str) -> dict[str, str]:
    provider = contract["providers"][provider_id]
    endpoint = provider.get("endpoint", {}) if isinstance(provider.get("endpoint"), dict) else {}
    headers = endpoint.get("headers", {}) if isinstance(endpoint.get("headers"), dict) else {}
    return {str(k): str(v) for k, v in headers.items() if str(v).strip()}


def launch_env(contract: dict[str, Any], tool: str, requested: str | None = None) -> dict[str, str]:
    surface = surface_from_tool(tool)
    provider_id, status, _ = choose_provider(contract, surface, requested)
    provider = contract["providers"][provider_id]
    endpoint = provider.get("endpoint", {}) if isinstance(provider.get("endpoint"), dict) else {}
    env_keys = [str(x) for x in provider.get("env_keys", []) if str(x).strip()]
    defaults = contract.get("defaults", {}) if isinstance(contract.get("defaults"), dict) else {}
    project = str(defaults.get("infisical_project", "infrastructure"))
    environment = str(defaults.get("infisical_environment", "prod"))
    _, secret = env_value(env_keys, allow_cached=True, project=project, environment=environment)
    model = provider_model(contract, provider_id, surface)

    exports: dict[str, str] = {
        "SPINE_PROVIDER_SURFACE": surface,
        "SPINE_PROVIDER_SELECTED": provider_id,
        "SPINE_PROVIDER_MODEL": model,
        "SPINE_PROVIDER_BACKEND": str(provider.get("engine_backend", "unknown")),
    }

    base_url = str(endpoint.get("base_url", "")).rstrip("/")
    if base_url:
        exports["SPINE_PROVIDER_BASE_URL"] = base_url
    chat_path = str(endpoint.get("chat_path") or endpoint.get("api_path") or "/chat/completions")
    exports["SPINE_PROVIDER_CHAT_PATH"] = chat_path

    if provider.get("engine_backend") == "openai_compatible":
        if base_url:
            exports["OPENAI_BASE_URL"] = base_url
        if secret:
            exports["OPENAI_API_KEY"] = secret
        else:
            exports["SPINE_PROVIDER_ALLOW_ANON"] = "1"
        if tool == "opencode":
            exports["SPINE_OPENCODE_MODEL"] = f"openai/{model}"
            exports["SPINE_OPENCODE_SMALL_MODEL"] = f"openai/{opencode_small_model(contract, provider_id)}"
        if tool == "codex":
            if provider_id == "local_lmstudio":
                exports["CODEX_USE_OSS"] = "1"
                exports["CODEX_LOCAL_PROVIDER"] = str(provider.get("codex", {}).get("local_provider", defaults.get("codex_local_provider", "lmstudio")))
            else:
                exports["CODEX_MODEL_PROVIDER"] = str(provider.get("codex", {}).get("provider_id", defaults.get("codex_default_provider", provider_id)))
        header_map = openai_headers(contract, provider_id)
        if header_map:
            exports["SPINE_PROVIDER_EXTRA_HEADERS_JSON"] = json.dumps(header_map, sort_keys=True)
    elif provider.get("engine_backend") == "anthropic":
        if secret:
            exports["ANTHROPIC_API_KEY"] = secret
        if base_url:
            exports["ANTHROPIC_BASE_URL"] = base_url
        exports["SPINE_CLAUDE_MODEL"] = model
    elif provider.get("engine_backend") == "native_account":
        exports["CODEX_NATIVE_AUTH"] = "1"
    elif provider.get("engine_backend") == "local_echo":
        exports["SPINE_PROVIDER_ALLOW_ANON"] = "1"

    if status.get("router_required"):
        exports["SPINE_PROVIDER_ROUTER_REQUIRED"] = "1"

    return exports
