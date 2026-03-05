#!/usr/bin/env bash
# TRIAGE: reconcile network.unifi.{home,shop}.clients.observed.yaml against network.devices.ledger.yaml before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LEDGER="$ROOT/ops/bindings/network.devices.ledger.yaml"
OBS_HOME="$ROOT/ops/bindings/network.unifi.home.clients.observed.yaml"
OBS_SHOP="$ROOT/ops/bindings/network.unifi.shop.clients.observed.yaml"

fail() {
  echo "D188 FAIL: $*" >&2
  exit 1
}

[[ -f "$LEDGER" ]] || fail "missing ledger binding: $LEDGER"
[[ -f "$OBS_HOME" ]] || fail "missing observed binding: $OBS_HOME"
[[ -f "$OBS_SHOP" ]] || fail "missing observed binding: $OBS_SHOP"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$LEDGER" "$OBS_HOME" "$OBS_SHOP" <<'PY'
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import sys

import yaml

ledger_path = Path(sys.argv[1]).expanduser().resolve()
home_path = Path(sys.argv[2]).expanduser().resolve()
shop_path = Path(sys.argv[3]).expanduser().resolve()


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


try:
    ledger = load_yaml(ledger_path)
    home = load_yaml(home_path)
    shop = load_yaml(shop_path)
except Exception as exc:
    print(f"D188 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

now = datetime.now(timezone.utc)
violations: list[str] = []

for source_name, source_doc, source_path in (
    ("home", home, home_path),
    ("shop", shop, shop_path),
):
    freshness = source_doc.get("freshness_policy") if isinstance(source_doc.get("freshness_policy"), dict) else {}
    max_age_hours = int(freshness.get("max_age_hours", 24))
    generated_at = parse_dt(str(source_doc.get("generated_at", "")))
    if generated_at is None:
        violations.append(f"{source_name}: missing or invalid generated_at in {source_path}")
        continue
    age_hours = (now - generated_at).total_seconds() / 3600.0
    if age_hours > max_age_hours:
        violations.append(
            f"{source_name}: observed feed stale ({age_hours:.1f}h > {max_age_hours}h) in {source_path.name}"
        )

ledger_rows = ledger.get("items") if isinstance(ledger.get("items"), list) else []
ledger_map = {
    str(row.get("id", "")).strip(): row
    for row in ledger_rows
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

allowed_observed_status = {"active", "online", "present"}
allowed_ledger_status = {"approved", "ignored"}

observed_rows = []
for source_doc in (home, shop):
    devices = source_doc.get("devices") if isinstance(source_doc.get("devices"), list) else []
    for row in devices:
        if isinstance(row, dict):
            observed_rows.append(row)

for row in observed_rows:
    item_id = str(row.get("id", "")).strip()
    site = str(row.get("site", "")).strip()
    observed_status = str(row.get("status", "active")).strip().lower()

    if not item_id:
        violations.append("observed device entry missing id")
        continue
    if observed_status not in allowed_observed_status:
        continue

    entry = ledger_map.get(item_id)
    if not entry:
        violations.append(f"unmanaged observed network device: {item_id}")
        continue

    ledger_status = str(entry.get("status", "")).strip().lower()
    if ledger_status not in allowed_ledger_status:
        violations.append(f"{item_id}: ledger status must be approved|ignored (got {ledger_status or 'empty'})")
        continue

    ledger_site = str(entry.get("location_or_site", "")).strip()
    if site and ledger_site and site != ledger_site:
        violations.append(f"{item_id}: site mismatch observed={site} ledger={ledger_site}")

    if ledger_status == "ignored":
        expires_on = parse_date(str(entry.get("expires_on", "")))
        if expires_on is None:
            violations.append(f"{item_id}: ignored entries require valid expires_on")
            continue
        if expires_on < now.date():
            violations.append(f"{item_id}: ignored expires_on is in the past ({expires_on.isoformat()})")

if violations:
    for msg in violations:
        print(f"D188 FAIL: {msg}", file=sys.stderr)
    print(f"D188 FAIL: network device ledger parity violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(f"D188 PASS: network ledger parity valid (observed={len(observed_rows)} ledger={len(ledger_map)})")
PY
