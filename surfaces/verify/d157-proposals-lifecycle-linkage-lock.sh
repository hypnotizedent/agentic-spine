#!/usr/bin/env bash
# TRIAGE: Reconcile proposal manifest lifecycle metadata with loop linkage contract.
# D157: proposals lifecycle linkage lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
PROPOSALS_DIR="$ROOT/mailroom/outbox/proposals"
LOOP_SCOPES_DIR="$ROOT/mailroom/state/loop-scopes"

fail() {
  echo "D157 FAIL: $*" >&2
  exit 1
}

[[ -d "$PROPOSALS_DIR" ]] || fail "missing proposals directory: $PROPOSALS_DIR"
[[ -d "$LOOP_SCOPES_DIR" ]] || fail "missing loop scopes directory: $LOOP_SCOPES_DIR"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$PROPOSALS_DIR" "$LOOP_SCOPES_DIR" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

proposals_dir = Path(sys.argv[1])
loop_scopes_dir = Path(sys.argv[2])

ACTIVE_LOOP_STATUSES = {"active", "planned", "open", "draft"}
errors: list[str] = []


def clean_scalar(value) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    if text.lower() in {"null", "none"}:
        return ""
    return text


def parse_manifest(path: Path):
    try:
        raw = path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"{path}: unreadable manifest ({exc})")
        return None

    try:
        parsed = yaml.safe_load(raw)
    except Exception as exc:
        errors.append(f"{path}: manifest parse error ({exc})")
        return None

    if parsed is None:
        return {}
    if not isinstance(parsed, dict):
        errors.append(f"{path}: manifest top-level must be a map")
        return None
    return parsed


def parse_scope_status(loop_id: str) -> tuple[str, str]:
    scope_path = loop_scopes_dir / f"{loop_id}.scope.md"
    if not scope_path.exists():
        return "missing", ""

    try:
        raw = scope_path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return "invalid", "unreadable"

    status = ""
    if raw.startswith("---\n"):
        end_idx = raw.find("\n---", 4)
        if end_idx != -1:
            fm = raw[4:end_idx + 1]
            try:
                parsed = yaml.safe_load(fm) or {}
                status = clean_scalar(parsed.get("status"))
            except Exception:
                status = ""

    if not status:
        match = re.search(r"^status:\s*([^\n#]+)", raw, flags=re.MULTILINE)
        if match:
            status = clean_scalar(match.group(1).strip().strip('"').strip("'"))

    lowered = status.lower()
    if lowered in ACTIVE_LOOP_STATUSES:
        return "active", lowered
    if lowered == "closed":
        return "closed", lowered
    return "invalid", lowered or "unknown"


checked = 0
pending_checked = 0
draft_hold_checked = 0

for proposal_dir in sorted(proposals_dir.glob("CP-*")):
    if not proposal_dir.is_dir():
        continue

    checked += 1
    proposal_id = proposal_dir.name
    manifest_path = proposal_dir / "manifest.yaml"
    applied_marker = (proposal_dir / ".applied").exists()

    if not manifest_path.exists():
        errors.append(f"{proposal_id}: missing manifest.yaml")
        continue

    manifest = parse_manifest(manifest_path)
    if manifest is None:
        continue

    status = clean_scalar(manifest.get("status"))
    loop_id = clean_scalar(manifest.get("loop_id"))

    # 2) .applied marker implies manifest status=applied
    if applied_marker and status != "applied":
        errors.append(f"{proposal_id}: .applied marker requires status=applied (got '{status or 'missing'}')")

    # 3) pending requires non-null loop_id
    if status == "pending":
        pending_checked += 1
        if not loop_id:
            errors.append(f"{proposal_id}: pending status requires non-null loop_id")
            continue

        # 4) pending loop_id must reference existing active loop scope
        state, detail = parse_scope_status(loop_id)
        if state == "missing":
            errors.append(f"{proposal_id}: pending loop_id={loop_id} has no scope file")
        elif state == "closed":
            errors.append(f"{proposal_id}: pending loop_id={loop_id} is closed")
        elif state != "active":
            errors.append(f"{proposal_id}: pending loop_id={loop_id} is not active (status='{detail}')")

    # 5) draft_hold requires owner/review_date/hold_reason
    if status == "draft_hold":
        draft_hold_checked += 1
        owner = clean_scalar(manifest.get("owner"))
        review_date = clean_scalar(manifest.get("review_date"))
        hold_reason = clean_scalar(manifest.get("hold_reason"))

        if not owner:
            errors.append(f"{proposal_id}: draft_hold missing owner")
        if not review_date:
            errors.append(f"{proposal_id}: draft_hold missing review_date")
        if not hold_reason:
            errors.append(f"{proposal_id}: draft_hold missing hold_reason")

if errors:
    for item in errors:
        print(f"  FAIL: {item}", file=sys.stderr)
    print(f"D157 FAIL: proposal lifecycle/linkage violations ({len(errors)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(
    f"D157 PASS: proposal lifecycle/linkage lock valid "
    f"(checked={checked} pending={pending_checked} draft_hold={draft_hold_checked})"
)
PY
