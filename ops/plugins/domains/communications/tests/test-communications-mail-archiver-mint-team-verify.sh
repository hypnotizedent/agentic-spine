#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

VERIFY_BIN="$SPINE_ROOT/ops/plugins/domains/communications/bin/communications-mail-archiver-mint-team-verify"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$VERIFY_BIN" ]] || fail "missing verify bin"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ok_json="$tmp/ok.json"
stale_json="$tmp/stale.json"
starved_json="$tmp/starved.json"

cat >"$ok_json" <<'JSON'
{
  "capability": "communications.mailarchiver.sync.status",
  "schema_version": "1.0",
  "generated_at": "2026-03-12T02:00:00Z",
  "status": "WARN",
  "data": {
    "runtime": {
      "app_status": "running",
      "db_status": "running",
      "total_archived_emails": 358635
    },
    "sync": {
      "live_sync_stale_after_hours": 1,
      "job_runtime_classification": "healthy_but_slow",
      "accounts": [
        {
          "account_contract_id": "microsoft-team",
          "db_account_id": "5",
          "provider_contract": "microsoft-m365",
          "provider_db": "M365",
          "mailbox_contract": "team@mintprints.com",
          "mailbox_db": "team@mintprints.com",
          "account_name_db": "Mint Prints Team",
          "lane_type": "live-sync",
          "last_sync": "2026-03-12T01:24:58.842844",
          "lastsync_canonical": true,
          "last_sync_stale": false,
          "archived_count": 25493,
          "latest_archived_received_at": "2026-03-12 01:19:50.485159",
          "latest_archived_row_id": 360556,
          "latest_job": {
            "job_id": "17347214-2cb9-46ff-ad6b-cbe17713f9d0",
            "status": "completed",
            "started_at": "2026-03-12T01:24:55.303091204Z",
            "completed_at": "2026-03-12T01:24:58.867405128Z",
            "summary": {
              "new": 0,
              "failed": 0,
              "deleted": 0
            }
          },
          "issues": []
        }
      ],
      "recent_jobs": [
        {
          "job_id": "e0948db1-87f0-4304-809b-849d0cc28b95",
          "account_name": "Gmail Primary",
          "db_account_id": "1",
          "status": "running",
          "started_at": "2026-03-12T01:40:39.707491822Z",
          "completed_at": "",
          "cancel_requested_at": "",
          "duration_seconds": 394,
          "summary": null
        },
        {
          "job_id": "17347214-2cb9-46ff-ad6b-cbe17713f9d0",
          "account_name": "Mint Prints Team",
          "db_account_id": "5",
          "status": "completed",
          "started_at": "2026-03-12T01:24:55.303091204Z",
          "completed_at": "2026-03-12T01:24:58.867405128Z",
          "cancel_requested_at": "",
          "duration_seconds": 3,
          "summary": {
            "new": 0,
            "failed": 0,
            "deleted": 0
          }
        }
      ]
    }
  }
}
JSON

cat >"$stale_json" <<'JSON'
{
  "capability": "communications.mailarchiver.sync.status",
  "schema_version": "1.0",
  "generated_at": "2026-03-12T05:00:00Z",
  "status": "WARN",
  "data": {
    "runtime": {
      "app_status": "running",
      "db_status": "running",
      "total_archived_emails": 358635
    },
    "sync": {
      "live_sync_stale_after_hours": 1,
      "job_runtime_classification": "healthy",
      "accounts": [
        {
          "account_contract_id": "microsoft-team",
          "db_account_id": "5",
          "provider_contract": "microsoft-m365",
          "provider_db": "M365",
          "mailbox_contract": "team@mintprints.com",
          "mailbox_db": "team@mintprints.com",
          "account_name_db": "Mint Prints Team",
          "lane_type": "live-sync",
          "last_sync": "2026-03-12T01:24:58.842844",
          "lastsync_canonical": true,
          "last_sync_stale": true,
          "archived_count": 25493,
          "latest_archived_received_at": "2026-03-10 01:19:50.485159",
          "latest_archived_row_id": 360556,
          "latest_job": {
            "job_id": "17347214-2cb9-46ff-ad6b-cbe17713f9d0",
            "status": "completed",
            "started_at": "2026-03-12T01:24:55.303091204Z",
            "completed_at": "2026-03-12T01:24:58.867405128Z",
            "summary": {
              "new": 0,
              "failed": 0,
              "deleted": 0
            }
          },
          "issues": []
        }
      ],
      "recent_jobs": [
        {
          "job_id": "17347214-2cb9-46ff-ad6b-cbe17713f9d0",
          "account_name": "Mint Prints Team",
          "db_account_id": "5",
          "status": "completed",
          "started_at": "2026-03-12T01:24:55.303091204Z",
          "completed_at": "2026-03-12T01:24:58.867405128Z",
          "cancel_requested_at": "",
          "duration_seconds": 3,
          "summary": {
            "new": 0,
            "failed": 0,
            "deleted": 0
          }
        }
      ]
    }
  }
}
JSON

cat >"$starved_json" <<'JSON'
{
  "capability": "communications.mailarchiver.sync.status",
  "schema_version": "1.0",
  "generated_at": "2026-03-12T02:00:00Z",
  "status": "WARN",
  "data": {
    "runtime": {
      "app_status": "running",
      "db_status": "running",
      "total_archived_emails": 358635
    },
    "sync": {
      "live_sync_stale_after_hours": 1,
      "job_runtime_classification": "starved_by_long_running_job",
      "accounts": [
        {
          "account_contract_id": "microsoft-team",
          "db_account_id": "5",
          "provider_contract": "microsoft-m365",
          "provider_db": "M365",
          "mailbox_contract": "team@mintprints.com",
          "mailbox_db": "team@mintprints.com",
          "account_name_db": "Mint Prints Team",
          "lane_type": "live-sync",
          "last_sync": "2026-03-12T01:24:58.842844",
          "lastsync_canonical": true,
          "last_sync_stale": false,
          "archived_count": 25493,
          "latest_archived_received_at": "2026-03-12 01:19:50.485159",
          "latest_archived_row_id": 360556,
          "latest_job": {
            "job_id": "17347214-2cb9-46ff-ad6b-cbe17713f9d0",
            "status": "completed",
            "started_at": "2026-03-12T01:24:55.303091204Z",
            "completed_at": "2026-03-12T01:24:58.867405128Z",
            "summary": {
              "new": 0,
              "failed": 0,
              "deleted": 0
            }
          },
          "issues": []
        }
      ],
      "recent_jobs": [
        {
          "job_id": "17347214-2cb9-46ff-ad6b-cbe17713f9d0",
          "account_name": "Mint Prints Team",
          "db_account_id": "5",
          "status": "completed",
          "started_at": "2026-03-12T01:24:55.303091204Z",
          "completed_at": "2026-03-12T01:24:58.867405128Z",
          "cancel_requested_at": "",
          "duration_seconds": 3,
          "summary": {
            "new": 0,
            "failed": 0,
            "deleted": 0
          }
        }
      ]
    }
  }
}
JSON

echo "communications mail-archiver mint team verify tests"

ok_out="$("$VERIFY_BIN" --json --input-json "$ok_json")"
echo "$ok_out" | jq -e '.capability == "communications.mailarchiver.mint.team.verify"' >/dev/null || fail "json envelope capability mismatch"
echo "$ok_out" | jq -e '.status == "WARN"' >/dev/null || fail "healthy but slow queue should warn, not fail"
echo "$ok_out" | jq -e '.data.summary.account_contract_id == "microsoft-team"' >/dev/null || fail "should target microsoft-team"
echo "$ok_out" | jq -e '.data.checks[] | select(.id == "recent_successful_job" and .status == "pass")' >/dev/null || fail "should pass recent successful job check"
echo "$ok_out" | jq -e '.data.checks[] | select(.id == "queue" and .status == "warn")' >/dev/null || fail "should warn on healthy_but_slow queue"
pass "healthy-but-slow queue still proves team lane"

if "$VERIFY_BIN" --json --input-json "$stale_json" >/dev/null 2>&1; then
  fail "stale team evidence should fail"
fi
stale_out="$("$VERIFY_BIN" --json --input-json "$stale_json" 2>/dev/null || true)"
echo "$stale_out" | jq -e '.status == "FAIL"' >/dev/null || fail "stale fixture should report FAIL"
echo "$stale_out" | jq -e '.data.checks[] | select(.id == "recent_successful_job" and .status == "fail")' >/dev/null || fail "stale fixture should fail recent successful job check"
pass "stale team evidence fails"

if "$VERIFY_BIN" --json --input-json "$starved_json" >/dev/null 2>&1; then
  fail "starved queue should fail"
fi
starved_out="$("$VERIFY_BIN" --json --input-json "$starved_json" 2>/dev/null || true)"
echo "$starved_out" | jq -e '.status == "FAIL"' >/dev/null || fail "starved fixture should report FAIL"
echo "$starved_out" | jq -e '.data.checks[] | select(.id == "queue" and .status == "fail")' >/dev/null || fail "starved fixture should fail queue check"
pass "queue starvation fails even with fresh team row"

echo "communications mint team verifier tests"
