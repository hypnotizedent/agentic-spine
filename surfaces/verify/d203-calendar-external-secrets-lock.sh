#!/usr/bin/env bash
# TRIAGE: enforce required external calendar provider secret refs (Infisical paths only).
# D203: calendar external secrets lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/calendar.external.providers.contract.yaml"

fail() {
  echo "D203 FAIL: $*" >&2
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
    print(f"D203 FAIL: unable to parse contract: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(doc, dict):
    print("D203 FAIL: contract root must be mapping", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

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

    if block.get("mode") != "read-only":
        violations.append(f"providers.{provider}.mode must be read-only")

provider_mode = doc.get("provider_mode") if isinstance(doc.get("provider_mode"), dict) else {}
if provider_mode.get("external_ingest_mode") != "read-only":
    violations.append("provider_mode.external_ingest_mode must be read-only")
if provider_mode.get("writeback_enabled") is not False:
    violations.append("provider_mode.writeback_enabled must be false")

if violations:
    for item in violations:
        print(f"D203 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D203 PASS: calendar external provider secret refs present and locked to Infisical")
PY
