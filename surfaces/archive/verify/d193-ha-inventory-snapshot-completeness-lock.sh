#!/usr/bin/env bash
# TRIAGE: rebuild ha.inventory.snapshot.yaml with ha-inventory-snapshot-build so required sections and freshness stay complete before hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SNAPSHOT="$ROOT/ops/bindings/ha.inventory.snapshot.yaml"

fail() {
  echo "D193 FAIL: $*" >&2
  exit 1
}

[[ -f "$SNAPSHOT" ]] || fail "missing snapshot binding: $SNAPSHOT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$SNAPSHOT" <<'PY'
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import sys

import yaml

snapshot_path = Path(sys.argv[1]).expanduser().resolve()

REQUIRED_SECTIONS = [
    "devices",
    "entities",
    "scenes",
    "dashboards",
    "automations",
    "addons",
    "integrations",
    "hacs_addons",
]


def parse_dt(value: str):
    text = (value or "").strip()
    if not text:
        return None
    try:
        if len(text) == 10:
            return datetime.strptime(text, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        dt = datetime.fromisoformat(text)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


with snapshot_path.open("r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}

if not isinstance(data, dict):
    print(f"D193 FAIL: expected mapping at YAML root: {snapshot_path}", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []
counts: dict[str, int] = {}

for section in REQUIRED_SECTIONS:
    values = data.get(section)
    if not isinstance(values, list):
        violations.append(f"missing required section list: {section}")
        continue
    counts[section] = len(values)

generated_at = parse_dt(str(data.get("generated_at", "")))
if generated_at is None:
    violations.append("generated_at missing or invalid")
else:
    age_hours = (datetime.now(timezone.utc) - generated_at).total_seconds() / 3600.0
    if age_hours > 24:
        violations.append(f"snapshot stale ({age_hours:.1f}h > 24h)")

if violations:
    for msg in violations:
        print(f"D193 FAIL: {msg}", file=sys.stderr)
    print(f"D193 FAIL: HA inventory snapshot completeness violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

summary = " ".join(f"{section}={counts.get(section, 0)}" for section in REQUIRED_SECTIONS)
print(f"D193 PASS: HA inventory snapshot completeness valid ({summary})")
PY
