#!/usr/bin/env bash
# TRIAGE: fail if active source reintroduces repo-local receipts or legacy governance audit write targets.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

fail() {
  echo "D398 FAIL: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "python3 required"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
scan_roots = ("bin", "ops", "surfaces", "docs", "fixtures")
historical_exceptions = {
    "ops/bindings/audits.migration.plan.yaml",
    "ops/bindings/operational.gaps.yaml",
    "docs/reference/brain/memory.md",
    "docs/reference/jd/00.00-index.md",
    "docs/reference/mint/MINT_LEGACY_DATA_HOLD_MANIFEST_20260226.md",
}
compat_exceptions = {
    "ops/lib/runtime-paths.sh",
    "ops/bindings/mailroom.bridge.yaml",
    "ops/plugins/infra/mailroom-bridge/bin/mailroom-bridge-serve",
    "ops/plugins/domains/mint/lib/mint-operator-storage-common.sh",
    "ops/plugins/infra/host/lib/archive-operator-drop-common.sh",
    "surfaces/verify/d19-backup-drift.sh",
    "surfaces/verify/d398-repo-local-evidence-write-target-lock.sh",
}
allowed_contexts = (
    "docs/receipts/",
    "workbench/docs/receipts/",
    "runtime/waves/",
    "/receipts/read",
    "/evidence/read",
    "$receipts/",
)
pattern = re.compile(r"receipts/|docs/governance/_audits")
violations = []

for base in scan_roots:
    for path in sorted((root / base).rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        if rel in historical_exceptions or rel in compat_exceptions:
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except Exception:
            continue
        for lineno, line in enumerate(lines, start=1):
            if not pattern.search(line):
                continue
            if any(token in line for token in allowed_contexts):
                continue
            violations.append(f"{rel}:{lineno}: {line.strip()}")

if violations:
    print("\n".join(violations))
    raise SystemExit(1)
PY

echo "D398 PASS: active source keeps repo-local receipts and legacy governance audit write targets retired"
