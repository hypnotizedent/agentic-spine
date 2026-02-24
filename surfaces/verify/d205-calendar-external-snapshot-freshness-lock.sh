#!/usr/bin/env bash
# TRIAGE: enforce external calendar snapshot freshness and schema completeness.
# D205: calendar external snapshot freshness lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/calendar.external.providers.contract.yaml"

fail() {
  echo "D205 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CONTRACT" "$ROOT" <<'PY'
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path
import json
import sys

import yaml

contract_path = Path(sys.argv[1]).expanduser().resolve()
root = Path(sys.argv[2]).expanduser().resolve()


def parse_iso(raw: str) -> datetime:
    value = raw.strip()
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


try:
    contract = yaml.safe_load(contract_path.read_text(encoding="utf-8")) or {}
except Exception as exc:
    print(f"D205 FAIL: unable to parse contract: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(contract, dict):
    print("D205 FAIL: contract root must be mapping", file=sys.stderr)
    raise SystemExit(1)

providers = contract.get("providers") if isinstance(contract.get("providers"), dict) else {}
ingest = contract.get("ingest") if isinstance(contract.get("ingest"), dict) else {}
violations: list[str] = []
now = datetime.now(timezone.utc)

required_provider_fields = {"capability", "status", "generated_at", "schema_version", "data"}
required_data_fields = {"provider", "mode", "event_count", "events", "snapshot_path"}

provider_payloads: dict[str, dict] = {}

for provider in ("icloud", "google"):
    block = providers.get(provider)
    if not isinstance(block, dict):
        violations.append(f"providers.{provider} block missing")
        continue

    snapshot = block.get("snapshot") if isinstance(block.get("snapshot"), dict) else {}
    rel = str(snapshot.get("output_path", "")).strip()
    if not rel:
        violations.append(f"providers.{provider}.snapshot.output_path missing")
        continue
    path = (root / rel).resolve()
    if not path.is_file():
        violations.append(f"snapshot file missing for {provider}: {path}")
        continue

    try:
        payload = load_json(path)
    except Exception as exc:
        violations.append(f"invalid JSON for {provider} snapshot: {exc}")
        continue
    if not isinstance(payload, dict):
        violations.append(f"{provider} snapshot root must be mapping")
        continue

    missing = sorted(required_provider_fields - set(payload.keys()))
    if missing:
        violations.append(f"{provider} snapshot missing required fields: {missing}")

    generated_at = str(payload.get("generated_at", "")).strip()
    if not generated_at:
        violations.append(f"{provider} snapshot generated_at missing")
    else:
        try:
            dt = parse_iso(generated_at)
            max_age_hours = int(snapshot.get("max_snapshot_age_hours", 24))
            age = now - dt
            if age > timedelta(hours=max_age_hours):
                violations.append(
                    f"{provider} snapshot stale: age={age} exceeds {max_age_hours}h (generated_at={generated_at})"
                )
        except Exception as exc:
            violations.append(f"{provider} generated_at parse failed: {exc}")

    data = payload.get("data")
    if not isinstance(data, dict):
        violations.append(f"{provider} snapshot data block missing")
    else:
        missing_data = sorted(required_data_fields - set(data.keys()))
        if missing_data:
            violations.append(f"{provider} snapshot data missing fields: {missing_data}")
        events = data.get("events")
        if not isinstance(events, list):
            violations.append(f"{provider} snapshot data.events must be list")
        if str(data.get("mode", "")).strip() != "read-only":
            violations.append(f"{provider} snapshot data.mode must be read-only")

    provider_payloads[provider] = payload

index_rel = str(ingest.get("external_index_path", "")).strip()
if not index_rel:
    violations.append("ingest.external_index_path missing")
else:
    index_path = (root / index_rel).resolve()
    if not index_path.is_file():
        violations.append(f"external index file missing: {index_path}")
    else:
        try:
            index_payload = load_json(index_path)
        except Exception as exc:
            violations.append(f"external index invalid JSON: {exc}")
        else:
            if not isinstance(index_payload, dict):
                violations.append("external index root must be mapping")
            else:
                for field in ("capability", "status", "generated_at", "schema_version", "data"):
                    if field not in index_payload:
                        violations.append(f"external index missing field: {field}")
                data = index_payload.get("data")
                if not isinstance(data, dict):
                    violations.append("external index data block missing")
                else:
                    providers_data = data.get("providers")
                    if not isinstance(providers_data, dict):
                        violations.append("external index data.providers missing")
                    else:
                        for provider in ("icloud", "google"):
                            if provider not in providers_data:
                                violations.append(f"external index providers missing {provider}")
                    layers = data.get("layers")
                    if not isinstance(layers, dict):
                        violations.append("external index data.layers missing")
                    else:
                        for layer in ("external_icloud", "external_google"):
                            if layer not in layers:
                                violations.append(f"external index layers missing {layer}")

if violations:
    for item in violations:
        print(f"D205 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D205 PASS: external calendar snapshots fresh (<24h) and schema/index complete")
PY
