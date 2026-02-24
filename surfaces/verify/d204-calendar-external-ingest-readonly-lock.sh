#!/usr/bin/env bash
# TRIAGE: enforce external provider secret materialization contract (Infisical refs only).
# D204: external-provider-secrets-materialization-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/calendar.external.providers.contract.yaml"

fail() {
  echo "D204 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CONTRACT" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

contract_path = Path(sys.argv[1]).expanduser().resolve()

try:
    doc = yaml.safe_load(contract_path.read_text(encoding="utf-8")) or {}
except Exception as exc:
    print(f"D204 FAIL: unable to parse contract: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(doc, dict):
    print("D204 FAIL: contract root must be mapping", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

provider_mode = doc.get("provider_mode") if isinstance(doc.get("provider_mode"), dict) else {}
if provider_mode.get("external_ingest_mode") != "read-only":
    violations.append("provider_mode.external_ingest_mode must be read-only")
if provider_mode.get("writeback_enabled") is not False:
    violations.append("provider_mode.writeback_enabled must be false")

providers = doc.get("providers") if isinstance(doc.get("providers"), dict) else {}
if not providers:
    violations.append("providers mapping missing")

required_refs = {
    "icloud": [
        ("endpoint", "caldav_url_ref"),
        ("auth", "username_ref"),
        ("auth", "app_specific_password_ref"),
    ],
    "google": [
        ("oauth", "client_id_ref"),
        ("oauth", "client_secret_ref"),
        ("oauth", "refresh_token_ref"),
        ("allowlist", "calendar_ids_ref"),
    ],
}

for provider, refs in required_refs.items():
    block = providers.get(provider)
    if not isinstance(block, dict):
        violations.append(f"providers.{provider} block missing")
        continue
    if block.get("mode") != "read-only":
        violations.append(f"providers.{provider}.mode must be read-only")
    snap = block.get("snapshot")
    if not isinstance(snap, dict):
        violations.append(f"providers.{provider}.snapshot block missing")
    else:
        if not str(snap.get("output_path", "")).strip():
            violations.append(f"providers.{provider}.snapshot.output_path missing")
        if int(snap.get("max_snapshot_age_hours", 0) or 0) <= 0:
            violations.append(f"providers.{provider}.snapshot.max_snapshot_age_hours must be > 0")

    for section, key in refs:
        sec = block.get(section)
        if not isinstance(sec, dict):
            violations.append(f"providers.{provider}.{section} block missing")
            continue
        value = str(sec.get(key, "")).strip()
        field = f"providers.{provider}.{section}.{key}"
        if not value:
            violations.append(f"{field} missing")
        elif not value.startswith("infisical://"):
            violations.append(f"{field} must use infisical:// ref")

ingest = doc.get("ingest") if isinstance(doc.get("ingest"), dict) else {}
if not str(ingest.get("output_dir", "")).strip():
    violations.append("ingest.output_dir missing")
if not str(ingest.get("external_index_path", "")).strip():
    violations.append("ingest.external_index_path missing")
merge = ingest.get("merge") if isinstance(ingest.get("merge"), dict) else {}
if not str(merge.get("target_local_store_path", "")).strip():
    violations.append("ingest.merge.target_local_store_path missing")
layers = merge.get("local_layers") if isinstance(merge.get("local_layers"), dict) else {}
for layer in ("external_icloud", "external_google"):
    if not isinstance(layers.get(layer), dict):
        violations.append(f"ingest.merge.local_layers.{layer} missing")

if violations:
    for item in violations:
        print(f"D204 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D204 PASS: external provider secrets materialization contract valid (Infisical refs + required fields)")
PY
