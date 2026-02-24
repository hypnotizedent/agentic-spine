#!/usr/bin/env bash
# TRIAGE: enforce read-only external calendar ingest and immutable local layer policy.
# D204: calendar external ingest readonly lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CAPS="$ROOT/ops/capabilities.yaml"
CONTRACT="$ROOT/ops/bindings/calendar.external.providers.contract.yaml"
SYNC_CONTRACT="$ROOT/ops/bindings/calendar.sync.contract.yaml"

fail() {
  echo "D204 FAIL: $*" >&2
  exit 1
}

for path in "$CAPS" "$CONTRACT" "$SYNC_CONTRACT"; do
  [[ -f "$path" ]] || fail "missing required file: $path"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CAPS" "$CONTRACT" "$SYNC_CONTRACT" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

caps_path = Path(sys.argv[1]).expanduser().resolve()
contract_path = Path(sys.argv[2]).expanduser().resolve()
sync_path = Path(sys.argv[3]).expanduser().resolve()


def load_yaml(path: Path):
    payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(payload, dict):
        raise ValueError(f"YAML root must be mapping: {path}")
    return payload


try:
    caps = load_yaml(caps_path)
    contract = load_yaml(contract_path)
    sync = load_yaml(sync_path)
except Exception as exc:
    print(f"D204 FAIL: parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

provider_mode = contract.get("provider_mode") if isinstance(contract.get("provider_mode"), dict) else {}
if provider_mode.get("external_ingest_mode") != "read-only":
    violations.append("provider_mode.external_ingest_mode must be read-only")
if provider_mode.get("writeback_enabled") is not False:
    violations.append("provider_mode.writeback_enabled must be false")

providers = contract.get("providers") if isinstance(contract.get("providers"), dict) else {}
for provider in ("icloud", "google"):
    block = providers.get(provider)
    if not isinstance(block, dict):
        violations.append(f"providers.{provider} block missing")
        continue
    if block.get("mode") != "read-only":
        violations.append(f"providers.{provider}.mode must be read-only")

merge = (
    ((contract.get("ingest") or {}).get("merge"))
    if isinstance(contract.get("ingest"), dict)
    else {}
)
merge = merge if isinstance(merge, dict) else {}
layers = merge.get("local_layers") if isinstance(merge.get("local_layers"), dict) else {}

for layer_id, provider in (("external_icloud", "icloud"), ("external_google", "google")):
    layer = layers.get(layer_id)
    if not isinstance(layer, dict):
        violations.append(f"ingest.merge.local_layers.{layer_id} missing")
        continue
    if layer.get("provider") != provider:
        violations.append(f"ingest.merge.local_layers.{layer_id}.provider must be {provider}")
    if layer.get("read_only") is not True:
        violations.append(f"ingest.merge.local_layers.{layer_id}.read_only must be true")
    if layer.get("immutable_by_source") is not True:
        violations.append(f"ingest.merge.local_layers.{layer_id}.immutable_by_source must be true")

capabilities = caps.get("capabilities") if isinstance(caps.get("capabilities"), dict) else {}
for cap_id, meta in capabilities.items():
    if not isinstance(meta, dict):
        continue
    cap = str(cap_id)
    if not (
        cap.startswith("calendar.icloud.")
        or cap.startswith("calendar.google.")
        or cap.startswith("calendar.external.")
    ):
        continue
    safety = str(meta.get("safety", "")).strip()
    if safety in {"mutating", "destructive"}:
        violations.append(f"{cap} must be read-only (actual safety={safety!r})")

    # Guard against accidental provider writeback capabilities.
    if any(token in cap for token in (".write", ".create", ".update", ".delete", ".sync.execute")):
        if cap != "calendar.external.ingest.refresh":
            violations.append(f"external provider write capability is not allowed: {cap}")

sync_caps = (
    ((sync.get("sync_contracts") or {}).get("push_write_capabilities", []))
    if isinstance(sync.get("sync_contracts"), dict)
    else []
)
if not isinstance(sync_caps, list):
    violations.append("calendar.sync.contract sync_contracts.push_write_capabilities must be list")
elif sync_caps:
    violations.append("calendar.sync.contract push_write_capabilities must stay empty")

if violations:
    for item in violations:
        print(f"D204 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D204 PASS: external ingest is read-only/immutable and provider writeback routes are blocked")
PY
