#!/usr/bin/env bash
# TRIAGE: repair extension transaction transition_history/evidence or rebuild stale/missing index before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LIFECYCLE_CONTRACT="$ROOT/ops/bindings/platform.extension.lifecycle.contract.yaml"
INDEX_CONTRACT="$ROOT/ops/bindings/platform.extension.index.contract.yaml"
TX_DIR="$ROOT/mailroom/state/extension-transactions"

fail() {
  echo "D178 FAIL: $*" >&2
  exit 1
}

[[ -f "$LIFECYCLE_CONTRACT" ]] || fail "missing lifecycle contract: $LIFECYCLE_CONTRACT"
[[ -f "$INDEX_CONTRACT" ]] || fail "missing index contract: $INDEX_CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$LIFECYCLE_CONTRACT" "$INDEX_CONTRACT" "$TX_DIR" <<'PY'
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import json
import sys

import yaml

lifecycle_path = Path(sys.argv[1]).expanduser().resolve()
index_contract_path = Path(sys.argv[2]).expanduser().resolve()
tx_dir = Path(sys.argv[3]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


def parse_iso(ts: str):
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))


errors: list[str] = []
violations: list[tuple[str, str]] = []

try:
    lifecycle = load_yaml(lifecycle_path)
    index_contract = load_yaml(index_contract_path)
except Exception as exc:
    print(f"D178 FAIL: unable to parse contracts: {exc}", file=sys.stderr)
    raise SystemExit(1)

statuses = [str(x).strip() for x in (lifecycle.get("statuses") or []) if str(x).strip()]
allowed = lifecycle.get("allowed_transitions") if isinstance(lifecycle.get("allowed_transitions"), dict) else {}
required_evidence = lifecycle.get("required_evidence") if isinstance(lifecycle.get("required_evidence"), dict) else {}

if not statuses:
    errors.append("lifecycle contract statuses[] is empty")
if not isinstance(allowed, dict) or not allowed:
    errors.append("lifecycle contract allowed_transitions is missing/empty")

if errors:
    for err in errors:
        print(f"D178 FAIL: contract :: {err}", file=sys.stderr)
    raise SystemExit(1)

transaction_files = sorted(tx_dir.glob("TXN-*.yaml")) if tx_dir.is_dir() else []
if not transaction_files:
    print("D178 PASS: no extension transactions found")
    raise SystemExit(0)

for tx_path in transaction_files:
    try:
        tx = load_yaml(tx_path)
    except Exception as exc:
        violations.append((str(tx_path), f"invalid YAML: {exc}"))
        continue

    status = str(tx.get("status", "")).strip()
    if status not in statuses:
        violations.append((str(tx_path), f"invalid status: {status}"))

    history = tx.get("transition_history") if isinstance(tx.get("transition_history"), list) else []
    if history:
        prev_to = None
        for idx, row in enumerate(history):
            if not isinstance(row, dict):
                violations.append((str(tx_path), f"transition_history[{idx}] must be an object"))
                continue
            frm = str(row.get("from", "")).strip()
            to = str(row.get("to", "")).strip()
            at = str(row.get("at", "")).strip()
            if frm not in statuses or to not in statuses:
                violations.append((str(tx_path), f"transition_history[{idx}] has invalid from/to status"))
                continue
            allowed_to = [str(x).strip() for x in (allowed.get(frm) or []) if str(x).strip()]
            if to not in allowed_to:
                violations.append((str(tx_path), f"illegal transition in history: {frm} -> {to}"))
            if prev_to is not None and frm != prev_to:
                violations.append((str(tx_path), f"transition_history chain break at index {idx} (expected from={prev_to}, got {frm})"))
            prev_to = to
            if not at:
                violations.append((str(tx_path), f"transition_history[{idx}] missing at timestamp"))
        if prev_to and status and prev_to != status:
            violations.append((str(tx_path), f"current status '{status}' does not match last transition_history to '{prev_to}'"))
    else:
        if status != "planned":
            violations.append((str(tx_path), "non-planned transaction must include transition_history"))

    # Evidence validation for current status.
    policy = required_evidence.get(status) if isinstance(required_evidence.get(status), dict) else {}
    required_fields = [str(x).strip() for x in (policy.get("required_fields") or []) if str(x).strip()]
    for field in required_fields:
        value = tx.get(field)
        if isinstance(value, list):
            if len(value) == 0:
                violations.append((str(tx_path), f"required evidence field empty list: {field}"))
            continue
        if not str(value or "").strip():
            violations.append((str(tx_path), f"required evidence field missing: {field}"))

    if bool(policy.get("required_homes_all_ready", False)):
        required_homes = tx.get("required_homes") if isinstance(tx.get("required_homes"), dict) else {}
        if not required_homes:
            violations.append((str(tx_path), "required_homes missing for status requiring homes ready"))
        for key, row in required_homes.items():
            if not isinstance(row, dict):
                violations.append((str(tx_path), f"required_homes.{key} must be object"))
                continue
            home_status = str(row.get("status", "")).strip().lower()
            if home_status != "ready":
                violations.append((str(tx_path), f"required_homes.{key}.status must be ready for status={status}"))

# Index requirements when transactions exist.
index_rel = str(index_contract.get("index_path", "")).strip()
required_index_fields = [str(x).strip() for x in (index_contract.get("required_fields") or []) if str(x).strip()]
max_age_hours = int(index_contract.get("freshness_policy", {}).get("max_age_hours", 24))

if not index_rel:
    violations.append((str(index_contract_path), "index_path missing in platform.extension.index.contract"))
else:
    index_path = (index_contract_path.parents[2] / index_rel).resolve()
    if not index_path.is_file():
        violations.append((str(index_path), "index file missing while transactions exist"))
    else:
        try:
            with index_path.open("r", encoding="utf-8") as handle:
                index_doc = json.load(handle)
        except Exception as exc:
            violations.append((str(index_path), f"invalid JSON index: {exc}"))
            index_doc = {}

        if isinstance(index_doc, dict):
            for field in required_index_fields:
                if field not in index_doc:
                    violations.append((str(index_path), f"index missing required field: {field}"))

            generated_at = str(index_doc.get("generated_at", "")).strip()
            if not generated_at:
                violations.append((str(index_path), "index generated_at missing"))
            else:
                try:
                    age_hours = (datetime.now(timezone.utc) - parse_iso(generated_at)).total_seconds() / 3600.0
                    if age_hours > max_age_hours:
                        violations.append((str(index_path), f"index stale beyond freshness policy ({age_hours:.2f}h > {max_age_hours}h)"))
                except Exception as exc:
                    violations.append((str(index_path), f"index generated_at invalid timestamp: {exc}"))

if violations:
    for path, msg in violations:
        print(f"D178 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D178 FAIL: extension lifecycle/index violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D178 PASS: extension lifecycle and index parity valid")
PY
