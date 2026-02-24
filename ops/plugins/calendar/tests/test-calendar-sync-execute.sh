#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EXEC="$ROOT/ops/plugins/calendar/bin/calendar-sync-execute"

export SPINE_CODE="$ROOT"
export SPINE_ROOT="$ROOT"
export PYTHONDONTWRITEBYTECODE=1

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "calendar-sync-execute tests"
echo "════════════════════════════════════════"

command -v jq >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "MISSING_DEP: python3" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BINDING="$TMP/calendar.global.yaml"
RUNTIME="$TMP/runtime"
STATE="$RUNTIME/mailroom/state/calendar-sync/state.json"
MICROSOFT_DB="$TMP/mock-microsoft-db.json"
MOCK_MICROSOFT="$TMP/mock-microsoft-cap-exec"

cat > "$BINDING" <<'EOF'
version: 1
updated: "2026-02-18"
owner: "@ronny"
calendar:
  id: "test-calendar"
  name: "Test Calendar"
  default_dtstart_date: "2026-02-18"
timezone:
  default: "America/New_York"
layers:
  order:
    - infrastructure
    - automation
    - identity
    - personal
    - spine
    - life
  definitions:
    infrastructure:
      authority: "spine"
      source_contracts:
        - type: "binding"
          ref: "ops/bindings/backup.calendar.yaml"
      events:
        - id: "infra-maintenance"
          summary: "Infra Maintenance"
          description: "Infra window"
          byhour: 2
          byminute: 0
          duration_minutes: 60
    automation:
      authority: "spine"
      source_contracts:
        - type: "capability"
          ref: "n8n.workflows.snapshot.status"
      events:
        - id: "automation-review"
          summary: "Automation Review"
          description: "Automation lane"
          byhour: 9
          byminute: 0
          duration_minutes: 30
    identity:
      authority: "external"
      source_contracts:
        - type: "capability"
          ref: "microsoft.calendar.list"
      events:
        - id: "identity-anchor"
          summary: "Identity Anchor"
          byhour: 8
          byminute: 30
          duration_minutes: 30
    personal:
      authority: "external"
      source_contracts:
        - type: "capability"
          ref: "microsoft.calendar.list"
      events:
        - id: "personal-anchor"
          summary: "Personal Anchor"
          byhour: 18
          byminute: 0
          duration_minutes: 30
    spine:
      authority: "spine"
      source_contracts:
        - type: "capability"
          ref: "verify.core.run"
      events:
        - id: "spine-verify"
          summary: "Spine Verify"
          byhour: 7
          byminute: 30
          duration_minutes: 30
    life:
      authority: "external"
      source_contracts:
        - type: "doc"
          ref: "docs/brain/memory.md"
      events:
        - id: "life-anchor"
          summary: "Life Anchor"
          byhour: 17
          byminute: 0
          duration_minutes: 30
conflict_policy:
  authoritative_layer_owner:
    infrastructure: "spine"
    automation: "spine"
    identity: "external"
    personal: "external"
    spine: "spine"
    life: "external"
sync_contracts:
  pull_read_capabilities:
    - microsoft.calendar.list
    - microsoft.calendar.get
  push_write_capabilities:
    - microsoft.calendar.create
    - microsoft.calendar.update
EOF

cat > "$MOCK_MICROSOFT" <<'PY'
#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

def load_db(path: Path):
    if not path.exists():
        return {"next": 1, "events": {}, "failed_once": {}}
    return json.loads(path.read_text(encoding="utf-8"))

def save_db(path: Path, obj):
    path.write_text(json.dumps(obj, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def parse_args(argv):
    out = {}
    i = 0
    while i < len(argv):
        token = argv[i]
        if token.startswith("--"):
            key = token[2:]
            if i + 1 < len(argv) and not argv[i + 1].startswith("--"):
                out[key] = argv[i + 1]
                i += 2
            else:
                out[key] = ""
                i += 1
        else:
            i += 1
    return out

def fail_transport(msg):
    print(f"ERROR: Network error: {msg}", file=sys.stderr)
    raise SystemExit(2)

def fail_http(code, msg):
    print(f"ERROR: HTTP {code}: {{\"error\":\"{msg}\"}}", file=sys.stderr)
    raise SystemExit(2)

def maybe_fail(db, op):
    fail_op = os.environ.get("MOCK_TRANSPORT_FAIL_OP", "").strip()
    if fail_op and fail_op != op:
        return
    if os.environ.get("MOCK_TRANSPORT_FAIL_ALWAYS", "") == "1":
        fail_transport("simulated persistent outage")
    if os.environ.get("MOCK_TRANSPORT_FAIL_ONCE", "") == "1":
        if not db["failed_once"].get(op):
            db["failed_once"][op] = True
            fail_transport("simulated one-time outage")

def main():
    if len(sys.argv) < 2:
        raise SystemExit(2)
    op = sys.argv[1]
    params = parse_args(sys.argv[2:])

    db_path = Path(os.environ["MOCK_MICROSOFT_DB"])
    db = load_db(db_path)

    maybe_fail(db, op)

    if op == "calendar_list":
        save_db(db_path, db)
        print(json.dumps({"value": list(db["events"].values())}, sort_keys=True))
        raise SystemExit(0)

    if op == "calendar_get":
        event_id = params.get("event-id", "")
        evt = db["events"].get(event_id)
        if not evt:
            fail_http(404, "not_found")
        save_db(db_path, db)
        print(json.dumps(evt, sort_keys=True))
        raise SystemExit(0)

    if op == "calendar_create":
        event_id = f"evt-{db['next']}"
        db["next"] += 1
        evt = {
            "id": event_id,
            "@odata.etag": f"W/\"{event_id}-1\"",
            "subject": params.get("subject", ""),
            "start": {"dateTime": params.get("start", ""), "timeZone": params.get("timezone", "UTC")},
            "end": {"dateTime": params.get("end", ""), "timeZone": params.get("timezone", "UTC")},
            "body": {"content": params.get("body", "")},
        }
        db["events"][event_id] = evt
        save_db(db_path, db)
        print(json.dumps(evt, sort_keys=True))
        raise SystemExit(0)

    if op == "calendar_update":
        event_id = params.get("event-id", "")
        evt = db["events"].get(event_id)
        if not evt:
            fail_http(404, "not_found")
        rev = 1
        etag = evt.get("@odata.etag", "")
        if "-" in etag:
            try:
                rev = int(etag.rsplit("-", 1)[1].rstrip('"')) + 1
            except Exception:
                rev = 2
        evt["subject"] = params.get("subject", evt.get("subject", ""))
        evt["start"] = {"dateTime": params.get("start", evt.get("start", {}).get("dateTime", "")), "timeZone": params.get("timezone", "UTC")}
        evt["end"] = {"dateTime": params.get("end", evt.get("end", {}).get("dateTime", "")), "timeZone": params.get("timezone", "UTC")}
        evt["body"] = {"content": params.get("body", evt.get("body", {}).get("content", ""))}
        evt["@odata.etag"] = f"W/\"{event_id}-{rev}\""
        db["events"][event_id] = evt
        save_db(db_path, db)
        print(json.dumps(evt, sort_keys=True))
        raise SystemExit(0)

    print(f"ERROR: unsupported op {op}", file=sys.stderr)
    raise SystemExit(2)

if __name__ == "__main__":
    main()
PY
chmod +x "$MOCK_MICROSOFT"

export CALENDAR_SYNC_MICROSOFT_EXEC="$MOCK_MICROSOFT"
export MOCK_MICROSOFT_DB="$MICROSOFT_DB"
export SPINE_REPO="$RUNTIME"

echo ""
echo "T1: dry-run envelope includes summary/actions/conflicts/errors/state_path"
(
  out="$($EXEC --binding "$BINDING" --state-path "$STATE" --json)"
  echo "$out" | jq -e '
    .capability == "calendar.sync.execute" and
    .status == "ok" and
    .data.mode == "dry-run" and
    (.data.summary.planned >= 6) and
    (.data.actions | length >= 6) and
    (.data.conflicts | type == "array") and
    (.data.errors | type == "array") and
    (.data.state_path | contains("mailroom/state/calendar-sync/state.json"))
  ' >/dev/null
) && pass "dry-run output contract" || fail "dry-run output contract"

echo ""
echo "T2: second execute run with unchanged inputs is noop-only for spine-authoritative layers"
(
  out1="$($EXEC --binding "$BINDING" --state-path "$STATE" --execute --json)"
  echo "$out1" | jq -e '.status == "ok" and .data.summary.created >= 3 and .data.summary.errors == 0' >/dev/null

  out2="$($EXEC --binding "$BINDING" --state-path "$STATE" --execute --json)"
  echo "$out2" | jq -e '
    .status == "ok" and
    .data.summary.created == 0 and
    .data.summary.updated == 0 and
    ([.data.actions[] | select(.layer == "infrastructure" or .layer == "automation" or .layer == "spine") | .action] | all(. == "noop"))
  ' >/dev/null
) && pass "idempotent second execute" || fail "idempotent second execute"

echo ""
echo "T3: mapped missing remote event is recreated and remapped"
(
  key="$(jq -r '.mappings | keys[0]' "$STATE")"
  old_id="$(jq -r --arg k "$key" '.mappings[$k].remote_event_id' "$STATE")"
  jq --arg rid "$old_id" 'del(.events[$rid])' "$MICROSOFT_DB" > "$MICROSOFT_DB.tmp"
  mv "$MICROSOFT_DB.tmp" "$MICROSOFT_DB"

  out="$($EXEC --binding "$BINDING" --state-path "$STATE" --execute --json)"
  new_id="$(jq -r --arg k "$key" '.mappings[$k].remote_event_id' "$STATE")"
  echo "$out" | jq -e '.status == "ok" and ([.data.actions[] | .action] | any(. == "recreate"))' >/dev/null
  [[ -n "$new_id" && "$new_id" != "$old_id" ]]
) && pass "recreate + remap on 404" || fail "recreate + remap on 404"

echo ""
echo "T4: external-authoritative layers never emit remote create/update"
(
  out="$($EXEC --binding "$BINDING" --state-path "$STATE" --execute --json)"
  echo "$out" | jq -e '
    ([.data.actions[] | select(.layer == "identity" or .layer == "personal" or .layer == "life") | .action] | all(. != "create" and . != "update" and . != "recreate"))
  ' >/dev/null
) && pass "external layers no remote writes" || fail "external layers no remote writes"

echo ""
echo "T5: partial outage yields partial status and no mapping corruption"
(
  rm -rf "$RUNTIME"
  rm -f "$MICROSOFT_DB"
  export MOCK_TRANSPORT_FAIL_OP="calendar_create"
  export MOCK_TRANSPORT_FAIL_ALWAYS="1"

  set +e
  out="$($EXEC --binding "$BINDING" --state-path "$STATE" --execute --continue-on-error --json 2>/dev/null)"
  rc=$?
  set -e

  [[ $rc -eq 1 ]]
  echo "$out" | jq -e '.status == "partial" and .data.summary.errors > 0 and ([.data.errors[] | .class] | any(. == "transport_error"))' >/dev/null
  jq -e '.mappings | length == 0' "$STATE" >/dev/null
) && pass "partial + retry-classified outage without mapping corruption" || fail "partial + retry-classified outage without mapping corruption"

unset MOCK_TRANSPORT_FAIL_OP
unset MOCK_TRANSPORT_FAIL_ALWAYS

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
