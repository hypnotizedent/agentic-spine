#!/usr/bin/env python3
"""Call the canonical Mint pricing lane-matrix surface through a governed Spine capability."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any
from urllib import error as urlerror
from urllib import request as urlrequest

from mint_runtime_paths import resolve_spine_root
from quote_packet_normalize import fail, load_structured_file, now_utc
from quote_packet_price import canonical_pricing_base_url, resolve_pricing_api_key


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="pricing-lane-matrix",
        description="Run the canonical Mint pricing lane-matrix advisor through Spine-governed pricing auth/runtime.",
    )
    source_group = parser.add_mutually_exclusive_group(required=True)
    source_group.add_argument("--payload", help="Inline JSON payload for POST /api/v1/pricing/lane-matrix")
    source_group.add_argument("--payload-file", help="Path to a JSON/YAML payload for POST /api/v1/pricing/lane-matrix")
    parser.add_argument("--timeout-seconds", type=int, default=45, help="HTTP timeout for pricing requests")
    parser.add_argument("--json", action="store_true", help="Emit structured JSON instead of summary text")
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_PRICING_CAPABILITY_NAME") or "mint.pricing.lane_matrix"


def load_payload(args: argparse.Namespace) -> dict[str, Any]:
    if args.payload:
        try:
            payload = json.loads(args.payload)
        except json.JSONDecodeError as exc:
            fail(f"--payload must be valid JSON: {exc}")
    else:
        path = Path(str(args.payload_file)).expanduser()
        if not path.is_file():
            fail(f"payload file not found: {path}")
        payload = load_structured_file(path)

    if not isinstance(payload, dict):
        fail("lane-matrix payload must be a JSON/YAML object")

    payload = dict(payload)
    payload.setdefault("request_timestamp_utc", now_utc())
    payload.setdefault("correlation_id", f"{current_capability_name()}:{payload.get('customer_ref') or 'operator'}")
    return payload


def post_lane_matrix_request(base_url: str, api_key: str, payload: dict[str, Any], timeout_seconds: int) -> dict[str, Any]:
    body = json.dumps(payload).encode("utf-8")
    request = urlrequest.Request(
        f"{base_url.rstrip('/')}/api/v1/pricing/lane-matrix",
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-API-Key": api_key,
        },
    )
    with urlrequest.urlopen(request, timeout=timeout_seconds) as response:
        raw = response.read().decode("utf-8")
    parsed = json.loads(raw or "{}")
    if not isinstance(parsed, dict):
        fail("lane-matrix response must be a JSON object")
    return parsed


def summarize(response: dict[str, Any], base_url: str) -> str:
    questions = response.get("questions") or []
    recommendations = response.get("recommendations") or []
    scenarios = response.get("scenarios") or []

    lines = [
        f"capability: {current_capability_name()}",
        "service_state: completed",
        f"pricing_base_url: {base_url}",
        f"question_count: {len(questions) if isinstance(questions, list) else 0}",
        f"recommendation_count: {len(recommendations) if isinstance(recommendations, list) else 0}",
        f"scenario_count: {len(scenarios) if isinstance(scenarios, list) else 0}",
        f"garment_markup_multiplier: {response.get('garment_markup_multiplier')}",
    ]

    if isinstance(questions, list):
        for question in questions[:8]:
            if not isinstance(question, dict):
                continue
            lines.append(
                "question:"
                f" lane_id={question.get('lane_id') or ''}"
                f" code={question.get('code') or ''}"
                f" recommended_answer={question.get('recommended_answer')}"
            )

    if isinstance(scenarios, list):
        for scenario in scenarios[:8]:
            if not isinstance(scenario, dict):
                continue
            lines.append(
                "scenario:"
                f" scenario_id={scenario.get('scenario_id') or ''}"
                f" qty={scenario.get('qty')}"
                f" setup_mode={scenario.get('setup_mode') or ''}"
                f" customer_unit_amount={scenario.get('customer_unit_amount')}"
                f" blank_customer_unit_amount={scenario.get('blank_customer_unit_amount')}"
            )
            for lane in (scenario.get("lanes") or [])[:8]:
                if not isinstance(lane, dict):
                    continue
                lines.append(
                    "lane:"
                    f" scenario_id={scenario.get('scenario_id') or ''}"
                    f" lane_id={lane.get('lane_id') or ''}"
                    f" customer_unit_amount={lane.get('customer_unit_amount')}"
                    f" receipt_id={lane.get('receipt_id') or ''}"
                    f" pricing_key={lane.get('pricing_key') or ''}"
                )
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    spine_root = resolve_spine_root()
    payload = load_payload(args)
    api_key = resolve_pricing_api_key(spine_root)
    if not api_key:
        fail("PRICING_API_KEY is unavailable for mint.pricing.lane_matrix")

    base_url = canonical_pricing_base_url(spine_root)

    try:
        response = post_lane_matrix_request(base_url, api_key, payload, args.timeout_seconds)
    except urlerror.HTTPError as exc:
        raw = exc.read().decode("utf-8") if exc.fp else ""
        message = f"pricing lane-matrix service returned HTTP {exc.code}"
        if raw:
            message = f"{message}: {raw}"
        fail(message)
    except urlerror.URLError as exc:
        fail(f"pricing lane-matrix service unavailable: {exc.reason}")

    envelope = {
        "capability": current_capability_name(),
        "service_state": "completed",
        "pricing_base_url": base_url,
        "data": response,
    }
    if args.json:
        print(json.dumps(envelope, indent=2, sort_keys=True))
    else:
        print(summarize(response, base_url))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
