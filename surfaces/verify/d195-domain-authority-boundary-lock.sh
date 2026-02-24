#!/usr/bin/env bash
# TRIAGE: Restore ops/bindings/domain.authority.boundary.yaml required zone ownership and enforce non-overlap.
# D195: domain authority boundary lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BOUNDARY="$ROOT/ops/bindings/domain.authority.boundary.yaml"

fail() {
  echo "D195 FAIL: $*" >&2
  exit 1
}

[[ -f "$BOUNDARY" ]] || fail "missing boundary binding: $BOUNDARY"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$BOUNDARY" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

path = Path(sys.argv[1]).expanduser().resolve()

expected = {
    "mintprints": {
        "owning_domains": ["mint"],
        "business_data_allowed": True,
        "personal_data_allowed": False,
    },
    "ronny": {
        "owning_domains": ["home", "media", "immich", "n8n", "finance"],
        "business_data_allowed": False,
    },
    "spine-comms": {
        "owning_domains": ["communications", "core", "aof"],
        "mailbox_domain": "spine.ronny.works",
    },
    "microsoft-provider": {
        "owning_domains": ["microsoft"],
        "role": "external_dependency_only",
        "external_dependency_only": True,
        "product_authority": False,
    },
}

try:
    doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
except Exception as exc:  # pragma: no cover - runtime guard
    print(f"D195 FAIL: unable to parse boundary binding: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(doc, dict):
    print("D195 FAIL: boundary binding root must be a mapping", file=sys.stderr)
    raise SystemExit(1)

zones = doc.get("zones")
if not isinstance(zones, dict):
    print("D195 FAIL: zones mapping missing", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

for zone, rules in expected.items():
    if zone not in zones:
        violations.append(f"missing required zone: {zone}")
        continue

    actual = zones.get(zone)
    if not isinstance(actual, dict):
        violations.append(f"zone '{zone}' must be a mapping")
        continue

    actual_domains = actual.get("owning_domains")
    if not isinstance(actual_domains, list):
        violations.append(f"zone '{zone}' owning_domains must be a list")
    elif actual_domains != rules["owning_domains"]:
        violations.append(
            f"zone '{zone}' owning_domains mismatch: expected={rules['owning_domains']} actual={actual_domains}"
        )

    for key, expected_value in rules.items():
        if key == "owning_domains":
            continue
        actual_value = actual.get(key)
        if actual_value != expected_value:
            violations.append(
                f"zone '{zone}' field '{key}' mismatch: expected={expected_value!r} actual={actual_value!r}"
            )

# Non-overlap lock: every owning domain must appear in exactly one zone.
domain_owner: dict[str, str] = {}
for zone, zone_doc in zones.items():
    if not isinstance(zone_doc, dict):
        continue
    domains = zone_doc.get("owning_domains")
    if not isinstance(domains, list):
        violations.append(f"zone '{zone}' owning_domains must be a list")
        continue
    for domain in domains:
        d = str(domain).strip()
        if not d:
            violations.append(f"zone '{zone}' has blank owning_domains entry")
            continue
        previous = domain_owner.get(d)
        if previous and previous != zone:
            violations.append(f"domain overlap: '{d}' owned by both '{previous}' and '{zone}'")
        else:
            domain_owner[d] = zone

if violations:
    for item in violations:
        print(f"D195 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D195 PASS: domain authority boundary lock valid (zones=4, overlaps=0)")
PY
