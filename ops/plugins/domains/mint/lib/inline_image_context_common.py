#!/usr/bin/env python3
from __future__ import annotations

import base64
import json
import mimetypes
import os
import subprocess
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from operator_mail_common import first_json_object, run_cap_capture


VISION_PROMPT_VERSION = "inline_image_context_v1"


def normalize_space(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def unique_text(values: list[Any]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for item in values:
        text = normalize_space(item)
        if not text:
            continue
        key = text.lower()
        if key in seen:
            continue
        seen.add(key)
        result.append(text)
    return result


def is_inline_image_attachment(attachment: dict[str, Any], allowed_content_types: set[str]) -> bool:
    content_type = normalize_space(attachment.get("contentType") or "").lower()
    if not bool(attachment.get("isInline")):
        return False
    if content_type in allowed_content_types:
        return True
    guessed, _ = mimetypes.guess_type(str(attachment.get("name") or ""))
    return str(guessed or "").lower() in allowed_content_types


def build_skip_payload(state: str, reason: str, attachments: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    return {
        "state": state,
        "summary": None,
        "visible_products": [],
        "set_context": "unknown",
        "colors": [],
        "decoration_method_guess": None,
        "decoration_confidence": "low",
        "customer_reference_resolution": None,
        "operator_relevance": [],
        "attachments_analyzed": list(attachments or []),
        "provider": None,
        "prompt_version": VISION_PROMPT_VERSION,
        "failure_reason": normalize_space(reason) or None,
    }


def load_fixture_payload(summary_max_chars: int) -> dict[str, Any] | None:
    fixture_json = str(os.environ.get("MINT_INLINE_IMAGE_CONTEXT_FIXTURE_JSON") or "").strip()
    if not fixture_json:
        return None
    try:
        parsed = json.loads(fixture_json)
    except json.JSONDecodeError:
        return {
            "summary": normalize_space(fixture_json)[:summary_max_chars],
        }
    return parsed if isinstance(parsed, dict) else None


def resolve_provider_candidates(spine_root: Path) -> list[str]:
    script = (spine_root / "ops/plugins/providers/bin/providers-status").resolve()
    requested = normalize_space(os.environ.get("SPINE_ENGINE_PROVIDER") or "")
    cmd = [str(script), "--surface", "spine_engine", "--json"]
    if requested:
        cmd.extend(["--provider", requested])
    result = subprocess.run(
        cmd,
        cwd=spine_root,
        capture_output=True,
        text=True,
        check=False,
    )
    combined = (result.stdout or "") + ("\n" + result.stderr if result.stderr else "")
    if result.returncode != 0:
        raise RuntimeError(normalize_space(combined) or "provider status failed")
    payload = json.loads(result.stdout or "{}")
    if not isinstance(payload, dict):
        raise RuntimeError("provider status returned invalid JSON")
    candidates = []
    for item in payload.get("candidates") or []:
        if not isinstance(item, dict):
            continue
        if not bool(item.get("ready")):
            continue
        provider_id = normalize_space(item.get("id") or "")
        if provider_id:
            candidates.append(provider_id)
    if not candidates:
        raise RuntimeError("no ready providers for spine_engine")
    return candidates


def resolve_provider_env(spine_root: Path, provider_id: str) -> tuple[dict[str, str], str]:
    script = (spine_root / "ops/plugins/providers/bin/providers-launch-env").resolve()
    result = subprocess.run(
        [str(script), "--tool", "spine_engine", "--provider", provider_id, "--json"],
        cwd=spine_root,
        capture_output=True,
        text=True,
        check=False,
    )
    combined = (result.stdout or "") + ("\n" + result.stderr if result.stderr else "")
    if result.returncode != 0:
        raise RuntimeError(normalize_space(combined) or "provider launch env failed")
    payload = json.loads(result.stdout or "{}")
    if not isinstance(payload, dict):
        raise RuntimeError("provider launch env returned invalid JSON")
    return {str(key): str(value) for key, value in payload.items()}, normalize_space(combined)


def data_url_for_file(path: Path, content_type: str) -> str:
    raw = path.read_bytes()
    encoded = base64.b64encode(raw).decode("ascii")
    media_type = normalize_space(content_type or "").lower() or mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    return f"data:{media_type};base64,{encoded}"


def http_json(url: str, headers: dict[str, str], payload: dict[str, Any]) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {normalize_space(body)[:240]}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"provider request failed: {exc.reason}") from exc


def openai_compatible_analysis(
    provider_env: dict[str, str],
    prompt: str,
    attachments: list[dict[str, Any]],
) -> str:
    base_url = provider_env.get("OPENAI_BASE_URL") or provider_env.get("SPINE_PROVIDER_BASE_URL") or ""
    chat_path = provider_env.get("SPINE_PROVIDER_CHAT_PATH") or "/chat/completions"
    endpoint = f"{base_url.rstrip('/')}{chat_path}"
    if not base_url:
        raise RuntimeError("missing OpenAI-compatible base URL")
    headers = {"Content-Type": "application/json"}
    api_key = provider_env.get("OPENAI_API_KEY")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    extra_headers = provider_env.get("SPINE_PROVIDER_EXTRA_HEADERS_JSON") or ""
    if extra_headers:
        for key, value in json.loads(extra_headers).items():
            headers[str(key)] = str(value)

    content: list[dict[str, Any]] = [{"type": "text", "text": prompt}]
    for item in attachments:
        content.append(
            {
                "type": "image_url",
                "image_url": {
                    "url": data_url_for_file(Path(str(item["file_path"])), str(item.get("content_type") or "")),
                    "detail": "high",
                },
            }
        )
    payload = {
        "model": provider_env.get("SPINE_PROVIDER_MODEL") or "gpt-4.1-mini",
        "temperature": 0,
        "max_tokens": 500,
        "messages": [
            {
                "role": "system",
                "content": "You are a deterministic apparel image analyst. Return strict JSON only.",
            },
            {
                "role": "user",
                "content": content,
            },
        ],
    }
    response = http_json(endpoint, headers, payload)
    choices = response.get("choices") or []
    if not choices:
        raise RuntimeError("provider returned no choices")
    message = dict((choices[0] or {}).get("message") or {})
    content_value = message.get("content")
    if isinstance(content_value, list):
        return "\n".join(
            normalize_space(item.get("text") or "")
            for item in content_value
            if isinstance(item, dict) and item.get("type") == "text"
        ).strip()
    return normalize_space(content_value)


def anthropic_analysis(
    provider_env: dict[str, str],
    prompt: str,
    attachments: list[dict[str, Any]],
) -> str:
    base_url = provider_env.get("ANTHROPIC_BASE_URL") or provider_env.get("SPINE_PROVIDER_BASE_URL") or ""
    chat_path = provider_env.get("SPINE_PROVIDER_CHAT_PATH") or "/v1/messages"
    endpoint = f"{base_url.rstrip('/')}{chat_path}"
    api_key = provider_env.get("ANTHROPIC_API_KEY") or ""
    if not base_url or not api_key:
        raise RuntimeError("missing Anthropic base URL or API key")
    content: list[dict[str, Any]] = [{"type": "text", "text": prompt}]
    for item in attachments:
        file_path = Path(str(item["file_path"]))
        content.append(
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": normalize_space(item.get("content_type") or "").lower() or mimetypes.guess_type(file_path.name)[0] or "application/octet-stream",
                    "data": base64.b64encode(file_path.read_bytes()).decode("ascii"),
                },
            }
        )
    payload = {
        "model": provider_env.get("SPINE_CLAUDE_MODEL") or provider_env.get("SPINE_PROVIDER_MODEL") or "claude-sonnet-4-5-20250929",
        "max_tokens": 500,
        "temperature": 0,
        "system": "You are a deterministic apparel image analyst. Return strict JSON only.",
        "messages": [{"role": "user", "content": content}],
    }
    response = http_json(
        endpoint,
        {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        payload,
    )
    return "\n".join(
        normalize_space(item.get("text") or "")
        for item in (response.get("content") or [])
        if isinstance(item, dict) and item.get("type") == "text"
    ).strip()


def coerce_analysis_payload(raw_payload: dict[str, Any], summary_max_chars: int) -> dict[str, Any]:
    summary = normalize_space(raw_payload.get("summary") or "")[:summary_max_chars]
    return {
        "summary": summary or None,
        "visible_products": unique_text(list(raw_payload.get("visible_products") or [])),
        "set_context": normalize_space(raw_payload.get("set_context") or "unknown").lower() or "unknown",
        "colors": unique_text(list(raw_payload.get("colors") or [])),
        "decoration_method_guess": normalize_space(raw_payload.get("decoration_method_guess") or "") or None,
        "decoration_confidence": normalize_space(raw_payload.get("decoration_confidence") or "low").lower() or "low",
        "customer_reference_resolution": normalize_space(raw_payload.get("customer_reference_resolution") or "") or None,
        "operator_relevance": unique_text(list(raw_payload.get("operator_relevance") or [])),
    }


def parse_analysis_output(raw_text: str, summary_max_chars: int) -> dict[str, Any]:
    text = str(raw_text or "").strip()
    if not text:
        raise RuntimeError("provider returned empty analysis")
    try:
        parsed = first_json_object(text)
    except ValueError:
        return {
            "summary": normalize_space(text)[:summary_max_chars] or None,
            "visible_products": [],
            "set_context": "unknown",
            "colors": [],
            "decoration_method_guess": None,
            "decoration_confidence": "low",
            "customer_reference_resolution": None,
            "operator_relevance": [],
        }
    return coerce_analysis_payload(parsed, summary_max_chars)


def summarize_inline_image_context(
    *,
    spine_root: Path,
    state_root: Path,
    mailbox: str,
    message_id: str,
    subject: str,
    latest_customer_text: str,
    attachments: list[dict[str, Any]],
    download_capability: str,
    model_config: dict[str, Any],
) -> dict[str, Any]:
    if not bool(model_config.get("enabled", True)):
        return build_skip_payload("disabled", "inline image context disabled by contract")

    allowed_content_types = {
        normalize_space(item).lower()
        for item in (model_config.get("allowed_content_types") or [])
        if normalize_space(item)
    } or {"image/png", "image/jpeg", "image/webp"}
    max_images = max(int(model_config.get("max_images") or 0), 0) or 2
    max_bytes_per_image = max(int(model_config.get("max_bytes_per_image") or 0), 0) or 6 * 1024 * 1024
    summary_max_chars = max(int(model_config.get("summary_max_chars") or 0), 0) or 240

    inline_images = [
        dict(item)
        for item in attachments
        if isinstance(item, dict) and is_inline_image_attachment(item, allowed_content_types)
    ]
    if not inline_images:
        return build_skip_payload("skipped_no_inline_images", "message had no supported inline image attachments")

    selected: list[dict[str, Any]] = []
    for item in inline_images:
        size = int(item.get("size") or 0)
        if size > 0 and size > max_bytes_per_image:
            continue
        selected.append(item)
        if len(selected) >= max_images:
            break
    if not selected:
        return build_skip_payload("skipped_all_too_large", "supported inline images exceeded size limit")

    download_dir = state_root / "mint" / "customer-quote-intakes" / "inline-image-context" / "downloads" / message_id[-8:]
    analyzed_attachments: list[dict[str, Any]] = []
    receipts: list[str] = []
    for item in selected:
        attachment_id = normalize_space(item.get("id") or "")
        if not attachment_id:
            continue
        try:
            payload, receipt = run_cap_capture(
                spine_root,
                download_capability,
                [
                    "--mailbox",
                    mailbox,
                    "--message-id",
                    message_id,
                    "--attachment-id",
                    attachment_id,
                    "--output-dir",
                    str(download_dir),
                ],
            )
        except SystemExit:
            continue
        file_path = normalize_space(payload.get("filePath") or "")
        if not file_path or not Path(file_path).is_file():
            continue
        analyzed_attachments.append(
            {
                "attachment_id": attachment_id,
                "name": normalize_space(item.get("name") or ""),
                "content_type": normalize_space(item.get("contentType") or ""),
                "size": item.get("size"),
                "file_path": file_path,
            }
        )
        if receipt:
            receipts.append(receipt)

    if not analyzed_attachments:
        return build_skip_payload("download_failed", "supported inline images could not be downloaded", selected)

    prompt = "\n".join(
        [
            normalize_space(model_config.get("operator_prompt") or "")
            or "Describe only operator-relevant apparel truth from these inline customer images. Name visible garment or item types, whether they look like a coordinated set, visible logo placement, likely decoration method cues such as puff or embroidery, and what the customer probably means when pointing at these. Do not invent brand names, style codes, quantities, pricing, or unsupported certainty.",
            "",
            "Return strict JSON only with this shape:",
            '{"summary":"","visible_products":[],"set_context":"unknown","colors":[],"decoration_method_guess":"","decoration_confidence":"low","customer_reference_resolution":"","operator_relevance":[]}',
            "",
            f"Email subject: {normalize_space(subject)}",
            f"Latest customer text: {normalize_space(latest_customer_text)}",
        ]
    ).strip()

    fixture = load_fixture_payload(summary_max_chars)
    provider: dict[str, Any] | None = None
    try:
        if fixture is not None:
            analysis = coerce_analysis_payload(fixture, summary_max_chars)
            provider = {"selected": "fixture", "backend": "fixture", "model": "fixture"}
        else:
            last_error = ""
            ready_candidates = resolve_provider_candidates(spine_root)
            analysis = None
            for provider_id in ready_candidates:
                provider_env, provider_receipt = resolve_provider_env(spine_root, provider_id)
                backend = provider_env.get("SPINE_PROVIDER_BACKEND") or "unknown"
                provider = {
                    "selected": provider_env.get("SPINE_PROVIDER_SELECTED") or provider_id,
                    "backend": backend,
                    "model": provider_env.get("SPINE_PROVIDER_MODEL") or None,
                    "launch_receipt": provider_receipt or None,
                }
                try:
                    if backend == "openai_compatible":
                        raw_text = openai_compatible_analysis(provider_env, prompt, analyzed_attachments)
                    elif backend == "anthropic":
                        raw_text = anthropic_analysis(provider_env, prompt, analyzed_attachments)
                    else:
                        last_error = f"{provider_id}: inline image analysis backend not supported: {backend}"
                        continue
                    analysis = parse_analysis_output(raw_text, summary_max_chars)
                    break
                except Exception as exc:
                    last_error = f"{provider_id}: {exc}"
                    continue
            if analysis is None:
                payload = build_skip_payload("analysis_failed", last_error or "no provider succeeded", analyzed_attachments)
                payload["provider"] = provider
                return payload
    except Exception as exc:
        payload = build_skip_payload("analysis_failed", str(exc), analyzed_attachments)
        payload["provider"] = provider
        return payload

    return {
        "state": "captured",
        "summary": analysis.get("summary"),
        "visible_products": list(analysis.get("visible_products") or []),
        "set_context": analysis.get("set_context") or "unknown",
        "colors": list(analysis.get("colors") or []),
        "decoration_method_guess": analysis.get("decoration_method_guess"),
        "decoration_confidence": analysis.get("decoration_confidence") or "low",
        "customer_reference_resolution": analysis.get("customer_reference_resolution"),
        "operator_relevance": list(analysis.get("operator_relevance") or []),
        "attachments_analyzed": analyzed_attachments,
        "provider": provider,
        "download_receipts": receipts or None,
        "prompt_version": VISION_PROMPT_VERSION,
        "failure_reason": None,
    }
