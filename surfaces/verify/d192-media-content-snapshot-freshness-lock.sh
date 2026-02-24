#!/usr/bin/env bash
# TRIAGE: regenerate media.content.snapshot.yaml via media-content-snapshot-refresh so schema + freshness are valid before hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SNAPSHOT="$ROOT/ops/bindings/media.content.snapshot.yaml"

fail() {
  echo "D192 FAIL: $*" >&2
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


REQUIRED_TOP_KEYS = [
    "status",
    "owner",
    "last_verified",
    "scope",
    "version",
    "updated_at",
    "generated_at",
    "freshness_policy",
    "source_capability",
    "movies",
    "tv",
    "music",
]

REQUIRED_ITEM_KEYS = [
    "id",
    "title",
    "source_id",
    "year_or_release",
    "first_seen_at",
    "last_seen_at",
    "status",
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
    print(f"D192 FAIL: expected mapping at YAML root: {snapshot_path}", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []
now = datetime.now(timezone.utc)

for key in REQUIRED_TOP_KEYS:
    if key not in data:
        violations.append(f"missing top-level key: {key}")

freshness = data.get("freshness_policy")
if not isinstance(freshness, dict):
    violations.append("freshness_policy must be a mapping")
    max_age_hours = 24
else:
    raw_max_age = freshness.get("max_age_hours", 24)
    try:
        max_age_hours = int(raw_max_age)
    except Exception:
        max_age_hours = 24
        violations.append(f"freshness_policy.max_age_hours invalid: {raw_max_age}")

generated_at = parse_dt(str(data.get("generated_at", "")))
if generated_at is None:
    violations.append("generated_at missing or invalid")
else:
    age_hours = (now - generated_at).total_seconds() / 3600.0
    if age_hours > max_age_hours:
        violations.append(f"snapshot stale ({age_hours:.1f}h > {max_age_hours}h)")

section_counts: dict[str, int] = {}
for section in ("movies", "tv", "music"):
    values = data.get(section)
    if not isinstance(values, list):
        violations.append(f"{section} must be a list")
        continue
    section_counts[section] = len(values)
    for index, row in enumerate(values, start=1):
        if not isinstance(row, dict):
            violations.append(f"{section}[{index}] must be a mapping")
            continue
        for key in REQUIRED_ITEM_KEYS:
            if key not in row:
                violations.append(f"{section}[{index}] missing required field: {key}")
        for key in ("id", "title", "source_id", "first_seen_at", "last_seen_at", "status"):
            if key in row and not str(row.get(key, "")).strip():
                violations.append(f"{section}[{index}] field '{key}' must be non-empty")

if violations:
    for msg in violations:
        print(f"D192 FAIL: {msg}", file=sys.stderr)
    print(f"D192 FAIL: media snapshot contract violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(
    "D192 PASS: media snapshot freshness/schema valid "
    f"(movies={section_counts.get('movies', 0)} tv={section_counts.get('tv', 0)} music={section_counts.get('music', 0)})"
)
PY
