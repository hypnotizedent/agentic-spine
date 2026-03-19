#!/usr/bin/env bash
# TRIAGE: Block impossible lifecycle retention claims and missing expiry windows.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REGISTRY="$ROOT/ops/bindings/service.data.lifecycle.registry.yaml"
GEN="$ROOT/ops/plugins/core/authority/bin/service-data-lifecycle-projection-build"

fail() {
  echo "D407 FAIL: $*" >&2
  exit 1
}

[[ -f "$REGISTRY" ]] || fail "missing lifecycle registry: $REGISTRY"
[[ -x "$GEN" ]] || fail "missing executable generator: $GEN"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 "$GEN" --check --verify

python3 - "$REGISTRY" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

registry_path = Path(sys.argv[1]).resolve()


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        doc = yaml.safe_load(handle) or {}
    if not isinstance(doc, dict):
        raise ValueError("registry YAML root must be a mapping")
    return doc


def as_dict(value) -> dict:
    return value if isinstance(value, dict) else {}


def as_list(value) -> list:
    return value if isinstance(value, list) else []


registry = load_yaml(registry_path)
services = as_dict(registry.get("services"))
violations: list[str] = []

for service_id, raw_service in sorted(services.items()):
    service = as_dict(raw_service)

    for group_name in ("staging_roots", "quarantine_roots"):
        for row in as_list(service.get(group_name)):
            item = as_dict(row)
            expiry = as_dict(item.get("expiry_policy"))
            if not expiry or expiry.get("max_age_days") in {None, ""}:
                violations.append(
                    f"{service_id}: {group_name} root {item.get('host') or '?'}:{item.get('path') or '?'} missing expiry_policy.max_age_days"
                )

    retention = as_dict(service.get("retention_policy"))
    capacity = as_dict(service.get("capacity_model"))
    if str(capacity.get("mode") or "") != "enforce":
        continue
    if str(capacity.get("type") or "") != "rolling_retention_bytes":
        continue

    try:
        claim_days = float(retention.get("claim_days"))
        usable_capacity_gib = float(capacity.get("usable_capacity_gib"))
        observed_used_gib = float(capacity.get("observed_used_gib"))
        reserved_headroom_gib = float(capacity.get("reserved_headroom_gib"))
        observed_daily_growth_gib = float(capacity.get("observed_daily_growth_gib"))
    except Exception:
        violations.append(f"{service_id}: enforce-mode rolling_retention_bytes model is missing numeric fields")
        continue

    if observed_daily_growth_gib <= 0:
        violations.append(f"{service_id}: observed_daily_growth_gib must be > 0 for enforce-mode claim_days")
        continue

    safe_free_gib = usable_capacity_gib - observed_used_gib - reserved_headroom_gib
    achievable_days = max(0.0, safe_free_gib) / observed_daily_growth_gib
    if claim_days > achievable_days + 0.01:
        violations.append(
            f"{service_id}: claim_days={claim_days:g} exceeds achievable_days={achievable_days:.2f} "
            f"(usable_capacity_gib={usable_capacity_gib:g} observed_used_gib={observed_used_gib:g} "
            f"reserved_headroom_gib={reserved_headroom_gib:g} observed_daily_growth_gib={observed_daily_growth_gib:g})"
        )

if violations:
    for violation in violations:
        print(f"D407 FAIL: {violation}", file=sys.stderr)
    print(
        f"D407 FAIL: lifecycle retention/capacity honesty violations ({len(violations)} finding(s))",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(f"D407 PASS: lifecycle retention/capacity honesty enforced (services={len(services)})")
PY
