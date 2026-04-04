#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
GAPS_FILE="$ROOT/ops/bindings/operational.gaps.yaml"

python3 - <<'PY' "$GAPS_FILE"
import sys
from pathlib import Path

import yaml

gaps_file = Path(sys.argv[1])
doc = yaml.safe_load(gaps_file.read_text(encoding="utf-8")) or {}
rows = doc.get("gaps", [])
gap = next((row for row in rows if isinstance(row, dict) and row.get("id") == "GAP-OP-1638"), None)
assert gap is not None, "GAP-OP-1638 missing from operational.gaps.yaml"

title = str(gap.get("title") or "")
description = str(gap.get("description") or "")

assert "failing" not in title.lower(), title
assert "monitor" in title.lower(), title
assert "D423 now passes cleanly" in description, description
assert "No active cleanup work remains" in description, description
assert "Closure window opens" in description, description
assert "2026-04-10" in description, description

for stale_fragment in (
    "Gate D423 (runtime path pollution lock) failing due to repo-local .runtime pollution.",
    "Legacy pollution artifacts remain and block D423 gate",
    "Clean up repo-local .runtime pollution",
):
    assert stale_fragment not in description, stale_fragment
PY

echo "PASS: GAP-OP-1638 reflects monitoring-only post-fix truth"
