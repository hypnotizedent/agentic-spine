#!/usr/bin/env bash
# TRIAGE: reconcile media.content.snapshot.yaml item IDs against media.content.ledger.yaml before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LEDGER="$ROOT/ops/bindings/media.content.ledger.yaml"
OBSERVED="$ROOT/ops/bindings/media.content.snapshot.yaml"

fail() {
  echo "D191 FAIL: $*" >&2
  exit 1
}

[[ -f "$LEDGER" ]] || fail "missing ledger binding: $LEDGER"
[[ -f "$OBSERVED" ]] || fail "missing observed binding: $OBSERVED"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$LEDGER" "$OBSERVED" <<'PY'
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import sys

import yaml

ledger_path = Path(sys.argv[1]).expanduser().resolve()
observed_path = Path(sys.argv[2]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


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


def parse_date(value: str):
    text = (value or "").strip()
    if not text:
        return None
    try:
        if len(text) == 10:
            return datetime.strptime(text, "%Y-%m-%d").date()
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        return datetime.fromisoformat(text).date()
    except Exception:
        return None


def normalize_items(values, default_class: str):
    out = []
    if not isinstance(values, list):
        return out
    for row in values:
        if isinstance(row, str):
            item_id = row.strip()
        elif isinstance(row, dict):
            item_id = str(row.get("id", "")).strip()
        else:
            continue
        if not item_id:
            continue
        out.append((item_id, default_class))
    return out


try:
    ledger = load_yaml(ledger_path)
    observed = load_yaml(observed_path)
except Exception as exc:
    print(f"D191 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []
warnings: list[str] = []
now = datetime.now(timezone.utc)

freshness = observed.get("freshness_policy") if isinstance(observed.get("freshness_policy"), dict) else {}
max_age_hours = int(freshness.get("max_age_hours", 24))
generated_at = parse_dt(str(observed.get("generated_at", "")))
if generated_at is None:
    violations.append("media.content.snapshot generated_at missing or invalid")
else:
    observed_age_hours = (now - generated_at).total_seconds() / 3600.0
    if observed_age_hours > max_age_hours:
        violations.append(
            f"media.content.snapshot stale ({observed_age_hours:.1f}h > {max_age_hours}h)"
        )

policy = ledger.get("grace_policy") if isinstance(ledger.get("grace_policy"), dict) else {}
warn_under = int(policy.get("warn_under_hours", 24))
fail_at = int(policy.get("fail_at_or_after_hours", 24))

ledger_rows = ledger.get("items") if isinstance(ledger.get("items"), list) else []
ledger_map = {
    str(row.get("id", "")).strip(): row
    for row in ledger_rows
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

observed_items = []
observed_items.extend(normalize_items(observed.get("movies"), "movie"))
observed_items.extend(normalize_items(observed.get("music"), "music"))

allowed_ledger_status = {"approved", "ignored"}

for item_id, item_class in observed_items:
    entry = ledger_map.get(item_id)
    if entry:
        status = str(entry.get("status", "")).strip().lower()
        if status not in allowed_ledger_status:
            violations.append(f"{item_id}: status must be approved|ignored (got {status or 'empty'})")
            continue

        entry_class = str(entry.get("class", "")).strip().lower()
        if entry_class and entry_class != item_class:
            violations.append(f"{item_id}: class mismatch observed={item_class} ledger={entry_class}")

        if status == "ignored":
            expires_on = parse_date(str(entry.get("expires_on", "")))
            if expires_on is None:
                violations.append(f"{item_id}: ignored entries require valid expires_on")
                continue
            if expires_on < now.date():
                violations.append(f"{item_id}: ignored expires_on is in the past ({expires_on.isoformat()})")
        continue

    age_hours = 0.0
    if generated_at is not None:
        age_hours = (now - generated_at).total_seconds() / 3600.0

    if age_hours >= fail_at:
        violations.append(
            f"unledgered media {item_class} item {item_id} observed age={age_hours:.1f}h (fail threshold {fail_at}h)"
        )
    elif age_hours < warn_under:
        warnings.append(
            f"unledgered media {item_class} item {item_id} observed age={age_hours:.1f}h (warning threshold {warn_under}h)"
        )

for msg in warnings:
    print(f"D191 WARN: {msg}", file=sys.stderr)

if violations:
    for msg in violations:
        print(f"D191 FAIL: {msg}", file=sys.stderr)
    print(f"D191 FAIL: media content ledger parity violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(f"D191 PASS: media item ledger parity valid (observed={len(observed_items)} ledger={len(ledger_map)} warnings={len(warnings)})")
PY
