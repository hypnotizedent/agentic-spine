#!/usr/bin/env bash
# TRIAGE: reconcile media.content.ledger.yaml with observed media.services movie/music surfaces before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LEDGER="$ROOT/ops/bindings/media.content.ledger.yaml"
OBSERVED="$ROOT/ops/bindings/media.services.yaml"

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


def parse_ts(value: str) -> datetime | None:
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


def parse_expires(value: str):
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


try:
    ledger = load_yaml(ledger_path)
    observed = load_yaml(observed_path)
except Exception as exc:
    print(f"D191 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

policy = ledger.get("grace_policy") if isinstance(ledger.get("grace_policy"), dict) else {}
warn_under = int(policy.get("warn_under_hours", 24))
fail_at = int(policy.get("fail_at_or_after_hours", 24))

ledger_rows = ledger.get("items") if isinstance(ledger.get("items"), list) else []
ledger_map = {
    str(row.get("id", "")).strip(): row
    for row in ledger_rows
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

media_services = observed.get("services") if isinstance(observed.get("services"), dict) else {}
observed_stamp = parse_ts(str(observed.get("updated_at", ""))) or datetime.now(timezone.utc)

observed_items: dict[str, str] = {}
for service_id, row in media_services.items():
    if not isinstance(row, dict):
        continue
    sid = str(service_id).strip()
    if not sid:
        continue
    desc = str(row.get("description", "")).lower()
    if sid in {"radarr", "jellyfin"} or "movie" in desc:
        observed_items[sid] = "movie"
    elif sid in {"lidarr", "navidrome"} or "music" in desc:
        observed_items[sid] = "music"

if not observed_items:
    print("D191 PASS: no observed media movie/music surfaces found")
    raise SystemExit(0)

allowed = {"approved", "ignored"}
warnings: list[str] = []
violations: list[str] = []
now = datetime.now(timezone.utc)

for item_id, item_class in sorted(observed_items.items()):
    entry = ledger_map.get(item_id)
    if entry:
        status = str(entry.get("status", "")).strip().lower()
        if status not in allowed:
            violations.append(f"{item_id}: status must be approved|ignored (got {status or 'empty'})")
            continue
        if status == "ignored":
            expires = parse_expires(str(entry.get("expires_on", "")))
            if expires is None:
                violations.append(f"{item_id}: ignored items require valid expires_on")
                continue
            if expires < now.date():
                violations.append(f"{item_id}: ignored expires_on is in the past ({expires.isoformat()})")
        entry_class = str(entry.get("class", "")).strip().lower()
        if entry_class and entry_class != item_class:
            violations.append(f"{item_id}: class mismatch (ledger={entry_class}, observed={item_class})")
        continue

    age_hours = (now - observed_stamp).total_seconds() / 3600.0
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

print(
    f"D191 PASS: media content ledger parity valid ({len(observed_items)} observed, {len(ledger_map)} ledgered, warnings={len(warnings)})"
)
PY
