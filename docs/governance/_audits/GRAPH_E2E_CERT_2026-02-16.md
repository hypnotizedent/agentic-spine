---
status: authoritative
scope: graph-e2e-certification
date: 2026-02-16
agent: core-operator
result: PASS (mail PASS, calendar PASS)
---

# Microsoft Graph E2E Certification — 2026-02-16

## Summary

| Domain     | Result    | Detail                                    |
|------------|-----------|-------------------------------------------|
| Mail       | **PASS**  | search, send, get all confirmed           |
| Calendar   | **PASS**  | list, create, update, get all confirmed (GAP-OP-560 resolved) |

## Baseline Health

| Check                | Result         | Run Key                                                 |
|----------------------|----------------|---------------------------------------------------------|
| stability.snapshot   | WARN (immich)  | CAP-20260216-112208__stability.control.snapshot__Rrbdn59427 |
| verify.pack core-operator | 14/14 PASS | CAP-20260216-112242__verify.pack.run__Rfbh964734        |

## Capability Argument Discovery

| Capability             | Args Confirmed | Run Key |
|------------------------|----------------|---------|
| graph.mail.search      | --query, --top | CAP-20260216-112343__graph.mail.search__Rf3ly92137 |
| graph.mail.send        | --to, --subject, --body, --cc, --content-type | CAP-20260216-112354__graph.mail.send__R5hsp93036 |
| graph.calendar.create  | --subject, --start, --end, --timezone, --attendees, --body | CAP-20260216-112400__graph.calendar.create__Ryh2393483 |
| graph.calendar.update  | --event-id, --subject, --start, --end, --body | CAP-20260216-112405__graph.calendar.update__R5p7w93893 |

## Auth Discovery

- Azure AD app has application permissions: `Mail.ReadWrite`, `Mail.Send`, `Mail.Read`, `Mail.ReadBasic.All`, `MailboxSettings.ReadWrite`, `User.Read.All`
- **Missing**: `Calendars.ReadWrite` (blocks all calendar operations)
- Token flow: client_credentials → Azure AD v2.0 token endpoint → app-only bearer token
- `/me` endpoints require delegated auth; workaround uses `/users/{upn}` rewrite via `MS_GRAPH_USER` env var
- UPN: `Ronny@mintprints.com`

## E2E Test Results

### Test 1: graph.mail.search (baseline)

| Field    | Value |
|----------|-------|
| Command  | `graph.mail.search --query "spine" --top 3` |
| Run Key  | CAP-20260216-113033__secrets.exec__R9vcl25792 |
| Result   | **PASS** — 200, empty result set (expected) |
| Path     | `/users/Ronny@mintprints.com/messages` |

### Test 2: graph.mail.send

| Field    | Value |
|----------|-------|
| Command  | `graph.mail.send --to Ronny@mintprints.com --subject "Spine Graph E2E Cert 2026-02-16" --body "..."` |
| Run Key  | CAP-20260216-113046__secrets.exec__Rsftk26146 |
| Result   | **PASS** — HTTP 202 Accepted |
| Path     | `/users/Ronny@mintprints.com/sendMail` |

### Test 3: graph.mail.search (readback)

| Field    | Value |
|----------|-------|
| Command  | `graph.mail.search --query "Spine Graph E2E Cert" --top 5` |
| Run Key  | CAP-20260216-113214__secrets.exec__R201d28603 |
| Result   | **PASS** — 2 messages returned (inbox + sent) |
| Message ID (inbox) | `AAMkADhkM2UwZTFmLWI4MTYtNGQ3ZS1iZjg5LWNjNDQ3YmNkNDEzNgBGAAAAAAAunKJP_9FaQokxVhzJDB5MBwCFF7nu3pr7SZn9gFuaEvkhAAAAAAEMAACFF7nu3pr7SZn9gFuaEvkhAAFRHXe0AAA=` |
| Subject  | Spine Graph E2E Cert 2026-02-16 |
| From     | ronny@mintprints.com (Ronny Hantash) |
| Received | 2026-02-16T16:30:53Z |

### Test 4: graph.mail.get (by ID)

| Field    | Value |
|----------|-------|
| Command  | `graph.mail.get --message-id <inbox_id>` |
| Run Key  | CAP-20260216-113227__secrets.exec__R58do28909 |
| Result   | **PASS** — full message body + metadata returned |
| Body     | "Automated certification test from agentic-spine graph lane. Run key: E2E-CERT-20260216." |

### Test 5: graph.calendar.create (BLOCKED)

| Field    | Value |
|----------|-------|
| Command  | `graph.calendar.create --subject "Spine Graph E2E Cert" --start "2026-02-16T20:00:00" --end "2026-02-16T20:30:00"` |
| Run Key  | CAP-20260216-113056__secrets.exec__Rani626500 |
| Result   | **FAIL** — HTTP 403 ErrorAccessDenied |
| Root Cause | Missing `Calendars.ReadWrite` application permission |

### Test 6: graph.calendar.list (BLOCKED)

| Field    | Value |
|----------|-------|
| Command  | `graph.calendar.list --top 1` |
| Run Key  | CAP-20260216-113235__secrets.exec__R2ujg29216 |
| Result   | **FAIL** — HTTP 403 ErrorAccessDenied |
| Root Cause | Missing `Calendars.ReadWrite` application permission |

## Gaps Filed (both resolved)

| Gap ID     | Type          | Severity | Status | Resolution |
|------------|---------------|----------|--------|------------|
| GAP-OP-559 | missing-entry | medium   | **fixed** | graph-token-exec workaround + governed secrets.exec wrapper |
| GAP-OP-560 | missing-entry | medium   | **fixed** | Calendars.ReadWrite app permission granted in Azure portal (9654e05) |

## Calendar E2E Results (post GAP-OP-560 fix)

### Test 7: graph.calendar.list

| Field    | Value |
|----------|-------|
| Run Key  | CAP-20260216-152001__secrets.exec__R6ep076090 |
| Result   | **PASS** — 200, 3 events returned |

### Test 8: graph.calendar.create

| Field    | Value |
|----------|-------|
| Run Key  | CAP-20260216-152025__secrets.exec__R0laa76419 |
| Result   | **PASS** — 201, event created |
| Event ID | `AAMkADhkM2UwZTFmLWI4MTYtNGQ3ZS1iZjg5LWNjNDQ3YmNkNDEzNgBGAAAAAAAunKJP_9FaQokxVhzJDB5MBwCFF7nu3pr7SZn9gFuaEvkhAAAAAAENAACFF7nu3pr7SZn9gFuaEvkhAAFRHkN6AAA=` |
| Subject  | Spine Graph E2E Cert |

### Test 9: graph.calendar.update

| Field    | Value |
|----------|-------|
| Run Key  | CAP-20260216-152042__secrets.exec__Rbegg76754 |
| Result   | **PASS** — 200, subject updated to "Spine Graph E2E Cert (Updated)" |

### Test 10: graph.calendar.get (readback)

| Field    | Value |
|----------|-------|
| Run Key  | CAP-20260216-152100__secrets.exec (inline) |
| Result   | **PASS** — bodyPreview confirms "Calendar update mutation confirmed." |

## Workarounds Applied

1. **Token acquisition**: Created `ops/plugins/ms-graph/bin/graph-token-exec` — acquires bearer token from Azure AD client credentials via `secrets.exec`
2. **App-only /me rewrite**: Added `MS_GRAPH_USER` env var support to `ms_graph_tools.py` — rewrites `/me` to `/users/{upn}` for client_credentials tokens

## Residual Risks

1. **Token lifecycle** — No refresh/cache mechanism; each capability run acquires a new token (acceptable for governed use, but adds ~1s latency per call)
2. **App-only vs delegated** — Some Graph features (personal settings, shared mailboxes) may behave differently with app-only tokens. No issues observed in certification scope.
3. **graph-token-exec hardcodes UPN default** — `Ronny@mintprints.com`. Multi-user support requires passing `MS_GRAPH_USER` explicitly.

## Created/Updated Object IDs

| Object         | ID / Reference |
|----------------|---------------|
| Email (inbox)  | `AAMkADhkM2UwZTFmLWI4MTYtNGQ3ZS1iZjg5LWNjNDQ3YmNkNDEzNgBGAAAAAAAunKJP_9FaQokxVhzJDB5MBwCFF7nu3pr7SZn9gFuaEvkhAAAAAAEMAACFF7nu3pr7SZn9gFuaEvkhAAFRHXe0AAA=` |
| Email (sent)   | `AAMkADhkM2UwZTFmLWI4MTYtNGQ3ZS1iZjg5LWNjNDQ3YmNkNDEzNgBGAAAAAAAunKJP_9FaQokxVhzJDB5MBwCFF7nu3pr7SZn9gFuaEvkhAAAAAAEJAACFF7nu3pr7SZn9gFuaEvkhAAFRHg5gAAA=` |
| Conversation   | `AAQkADhkM2UwZTFmLWI4MTYtNGQ3ZS1iZjg5LWNjNDQ3YmNkNDEzNgAQAAW2mo8fuwNHskDCdW5-pKU=` |
| Calendar event | `AAMkADhkM2UwZTFmLWI4MTYtNGQ3ZS1iZjg5LWNjNDQ3YmNkNDEzNgBGAAAAAAAunKJP_9FaQokxVhzJDB5MBwCFF7nu3pr7SZn9gFuaEvkhAAAAAAENAACFF7nu3pr7SZn9gFuaEvkhAAFRHkN6AAA=` |
| iCalUId        | `040000008200E00074C5B7101A82E008000000001A2DC4B2819FDC01000000000000000010000000DBB872716F49554B9A5F07E50CD0E5C5` |
