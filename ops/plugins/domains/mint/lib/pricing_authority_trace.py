#!/usr/bin/env python3
"""Fetch the canonical Mint pricing authority trace through a governed Spine capability."""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any
from urllib import error as urlerror
from urllib import request as urlrequest

from mint_runtime_paths import resolve_spine_root
from quote_packet_normalize import fail
from quote_packet_price import canonical_pricing_base_url, resolve_pricing_api_key


VALID_METHODS = {"screen_print", "embroidery", "engraving", "transfers", "extras"}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="pricing-authority-trace",
        description="Read the generated Mint pricing authority trace through Spine-governed pricing auth/runtime.",
    )
    parser.add_argument(
        "--method",
        choices=sorted(VALID_METHODS),
        help="Optional method section to focus on (screen_print, embroidery, engraving, transfers, extras).",
    )
    parser.add_argument("--timeout-seconds", type=int, default=30, help="HTTP timeout for pricing requests")
    parser.add_argument("--json", action="store_true", help="Emit structured JSON instead of summary text")
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_PRICING_CAPABILITY_NAME") or "mint.pricing.authority_trace"


def fetch_authority_trace(base_url: str, api_key: str, timeout_seconds: int) -> dict[str, Any]:
    url = f"{base_url.rstrip('/')}/api/v1/pricing/authority-trace"
    request = urlrequest.Request(
        url,
        method="GET",
        headers={
            "Accept": "application/json",
            "X-API-Key": api_key,
        },
    )
    with urlrequest.urlopen(request, timeout=timeout_seconds) as response:
        raw = response.read().decode("utf-8")
    parsed = json.loads(raw or "{}")
    if not isinstance(parsed, dict):
        fail("authority-trace response must be a JSON object")
    return parsed


def filtered_trace(trace: dict[str, Any], method: str | None) -> dict[str, Any]:
    if not method:
        return trace
    methods = trace.get("methods")
    if not isinstance(methods, dict):
        return trace
    section = methods.get(method)
    if not isinstance(section, dict):
        fail(f"authority trace is missing method section: {method}")
    return {
        "generated_at_utc": trace.get("generated_at_utc"),
        "pricing_authority_version": trace.get("pricing_authority_version"),
        "workbook": trace.get("workbook"),
        "runtime_surfaces": trace.get("runtime_surfaces"),
        "global_value_domains": trace.get("global_value_domains"),
        "selected_method": method,
        "method": section,
        "boringness_blockers": trace.get("boringness_blockers"),
    }


def summarize(trace: dict[str, Any], base_url: str, method: str | None) -> str:
    lines = [
        f"capability: {current_capability_name()}",
        "service_state: completed",
        f"pricing_base_url: {base_url}",
        f"generated_at_utc: {trace.get('generated_at_utc')}",
    ]

    workbook = trace.get("workbook")
    if isinstance(workbook, dict):
        lines.append(f"workbook_sha256: {workbook.get('sha256')}")
        lines.append(f"workbook_source_generation_mode: {workbook.get('source_generation_mode')}")

    blockers = trace.get("boringness_blockers")
    if isinstance(blockers, list):
        lines.append(f"boringness_blocker_count: {len(blockers)}")

    if method:
        method_section = trace.get("method")
        if isinstance(method_section, dict):
            authority_mode = method_section.get("authority_mode")
            if isinstance(authority_mode, dict):
                lines.append(f"selected_method: {method}")
                lines.append(f"authority_exact: {authority_mode.get('exact')}")
                if authority_mode.get("overlay") is not None:
                    lines.append(f"authority_overlay: {authority_mode.get('overlay')}")
                if authority_mode.get("fallback") is not None:
                    lines.append(f"authority_fallback: {authority_mode.get('fallback')}")
            disconnects = method_section.get("disconnects")
            if isinstance(disconnects, list):
                lines.append(f"disconnect_count: {len(disconnects)}")
                for entry in disconnects[:12]:
                    lines.append(f"disconnect: {entry}")
    else:
        methods = trace.get("methods")
        if isinstance(methods, dict):
            lines.append(f"method_count: {len(methods)}")
            for name in sorted(methods.keys()):
                section = methods.get(name)
                disconnect_count = 0
                if isinstance(section, dict):
                    disconnects = section.get("disconnects")
                    if isinstance(disconnects, list):
                        disconnect_count = len(disconnects)
                lines.append(f"method: {name} disconnect_count={disconnect_count}")

    return "\n".join(lines)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    spine_root = resolve_spine_root()
    api_key = resolve_pricing_api_key(spine_root)
    if not api_key:
        fail("PRICING_API_KEY is unavailable for mint.pricing.authority_trace")

    base_url = canonical_pricing_base_url(spine_root)

    try:
        trace = fetch_authority_trace(base_url, api_key, args.timeout_seconds)
    except urlerror.HTTPError as exc:
        raw = exc.read().decode("utf-8") if exc.fp else ""
        message = f"pricing authority-trace service returned HTTP {exc.code}"
        if raw:
            message = f"{message}: {raw}"
        fail(message)
    except urlerror.URLError as exc:
        fail(f"pricing authority-trace service unavailable: {exc.reason}")

    selected = filtered_trace(trace, args.method)
    envelope = {
        "capability": current_capability_name(),
        "service_state": "completed",
        "pricing_base_url": base_url,
        "data": selected,
    }
    if args.json:
        print(json.dumps(envelope, indent=2, sort_keys=True))
    else:
        print(summarize(selected, base_url, args.method))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
