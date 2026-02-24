#!/usr/bin/env bash
# TRIAGE: enforce external snapshot normalization into calendar home union ingest surface.
# D205: calendar-home-union-ingest-lock
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

from pathlib import Path
import json
import sys

import yaml

contract_path = Path(sys.argv[1]).expanduser().resolve()
root = Path(sys.argv[2]).expanduser().resolve()


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
merge = ingest.get("merge") if isinstance(ingest.get("merge"), dict) else {}
layers = merge.get("local_layers") if isinstance(merge.get("local_layers"), dict) else {}
violations: list[str] = []

required_event_fields = {"source", "source_calendar_id", "source_event_id", "title", "start", "end", "read_only", "immutable_by_source"}

snapshot_paths: dict[str, Path] = {}
for provider in ("icloud", "google"):
    block = providers.get(provider)
    if not isinstance(block, dict):
        violations.append(f"providers.{provider} block missing")
        continue
    snap = block.get("snapshot") if isinstance(block.get("snapshot"), dict) else {}
    rel = str(snap.get("output_path", "")).strip()
    if not rel:
        violations.append(f"providers.{provider}.snapshot.output_path missing")
        continue
    path = (root / rel).resolve()
    snapshot_paths[provider] = path
    if not path.is_file():
        violations.append(f"snapshot missing for {provider}: {path}")
        continue
    try:
        payload = load_json(path)
    except Exception as exc:
        violations.append(f"invalid {provider} snapshot JSON: {exc}")
        continue
    if not isinstance(payload, dict):
        violations.append(f"{provider} snapshot root must be mapping")
        continue
    data = payload.get("data")
    if not isinstance(data, dict):
        violations.append(f"{provider} snapshot data block missing")
        continue
    events = data.get("events")
    if not isinstance(events, list):
        violations.append(f"{provider} snapshot data.events must be list")
        continue
    for idx, event in enumerate(events):
        if not isinstance(event, dict):
            violations.append(f"{provider} snapshot event[{idx}] must be mapping")
            continue
        missing = sorted(required_event_fields - set(event.keys()))
        if missing:
            violations.append(f"{provider} snapshot event[{idx}] missing fields: {missing}")

index_rel = str(ingest.get("external_index_path", "")).strip()
if not index_rel:
    violations.append("ingest.external_index_path missing")
    index_path = None
else:
    index_path = (root / index_rel).resolve()
    if not index_path.is_file():
        violations.append(f"external index missing: {index_path}")

if index_path and index_path.is_file():
    try:
        index_payload = load_json(index_path)
    except Exception as exc:
        violations.append(f"invalid external index JSON: {exc}")
        index_payload = {}
    if isinstance(index_payload, dict):
        data = index_payload.get("data") if isinstance(index_payload.get("data"), dict) else {}
        idx_layers = data.get("layers") if isinstance(data.get("layers"), dict) else {}
        store_path = str(data.get("local_layer_store_path", "")).strip()
        if not store_path:
            violations.append("external index data.local_layer_store_path missing")
        for layer_id, provider in (("external_icloud", "icloud"), ("external_google", "google")):
            layer = idx_layers.get(layer_id) if isinstance(idx_layers.get(layer_id), dict) else {}
            if not layer:
                violations.append(f"external index data.layers.{layer_id} missing")
                continue
            if layer.get("provider") != provider:
                violations.append(f"external index data.layers.{layer_id}.provider must be {provider}")
            if layer.get("read_only") is not True:
                violations.append(f"external index data.layers.{layer_id}.read_only must be true")
            if layer.get("immutable_by_source") is not True:
                violations.append(f"external index data.layers.{layer_id}.immutable_by_source must be true")

            layer_dir = Path(str(layer.get("path", ""))).expanduser()
            if not layer_dir.is_dir():
                violations.append(f"local union layer directory missing: {layer_dir}")
                continue
            manifest_path = layer_dir / "manifest.json"
            if not manifest_path.is_file():
                violations.append(f"local union layer manifest missing: {manifest_path}")
                continue
            try:
                manifest = load_json(manifest_path)
            except Exception as exc:
                violations.append(f"invalid manifest JSON ({manifest_path}): {exc}")
                continue
            if manifest.get("read_only") is not True:
                violations.append(f"manifest read_only must be true: {manifest_path}")
            if manifest.get("immutable_by_source") is not True:
                violations.append(f"manifest immutable_by_source must be true: {manifest_path}")
            expected_snapshot = str(snapshot_paths.get(provider, Path("")))
            source_snapshot = str(manifest.get("source_snapshot", "")).strip()
            if expected_snapshot and source_snapshot and source_snapshot != expected_snapshot:
                violations.append(
                    f"manifest source snapshot mismatch for {layer_id}: expected={expected_snapshot} actual={source_snapshot}"
                )

if violations:
    for item in violations:
        print(f"D205 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D205 PASS: external snapshots normalize into calendar-home union ingest schema/location")
PY
