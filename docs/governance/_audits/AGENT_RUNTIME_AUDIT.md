# Agent Runtime Audit

> **⚠️ Historical Capture (2026-01-26)**
>
> This document is a point-in-time audit snapshot. Paths and commands reference the
> legacy `ronny-ops` repository layout and `~/agent/` runtime structure.
>
> **Do not execute commands or act on paths in this document.**
>
> **Current authority:** See [SESSION_PROTOCOL.md](../SESSION_PROTOCOL.md) and
> [GOVERNANCE_INDEX.md](../GOVERNANCE_INDEX.md) for live governance.

- Generated: 2026-01-26T22:24:24-05:00
- Auditor: Terminal Operator
- Purpose: Verify agent runtime layout matches desired state
- **Status: historical** — Read-only reference; do not execute

---

## 1) WHAT EXISTS (Filesystem + Launchd + Repo)

### A) Filesystem Truth

**HOME:** `/Users/ronnyworks`

**~/agent/ structure:**
```
total 0
drwxr-xr-x@  6 ronnyworks  staff   192 Jan 26 22:18 .
drwxr-x---+ 76 ronnyworks  staff  2432 Jan 26 22:18 ..
drwxr-xr-x@ 12 ronnyworks  staff   384 Jan 26 22:20 inbox
drwxr-xr-x@  4 ronnyworks  staff   128 Jan 26 22:18 logs
drwxr-xr-x@ 11 ronnyworks  staff   352 Jan 26 22:20 outbox
drwxr-xr-x@  5 ronnyworks  staff   160 Jan 26 22:18 state
```

**~/agent/inbox contents:**
```
total 72
drwxr-xr-x@ 12 ronnyworks  staff   384 Jan 26 22:20 .
drwxr-xr-x@  6 ronnyworks  staff   192 Jan 26 22:18 ..
drwxr-xr-x@ 18 ronnyworks  staff   576 Jan 26 22:20 .processed
-rw-r--r--@  1 ronnyworks  staff  2925 Jan 26 20:35 AGENT_01_AUTOMATION_GAPS_AUDIT.md
-rw-r--r--@  1 ronnyworks  staff   483 Jan 26 11:48 REQ_001_repo-clean-proof.md
-rw-r--r--@  1 ronnyworks  staff   421 Jan 26 11:47 REQ_002_gh-clean-proof.md
-rw-r--r--@  1 ronnyworks  staff   483 Jan 26 11:52 REQ_003_repo-clean.md
-rw-r--r--@  1 ronnyworks  staff    76 Jan 26 11:50 REQ_TEST_1769446216.md
-rw-r--r--@  1 ronnyworks  staff    48 Jan 26 11:18 TEST_001.md
-rw-r--r--@  1 ronnyworks  staff    39 Jan 26 14:48 TEST_639_E2E_20260126_144810.md
-rw-r--r--@  1 ronnyworks  staff    64 Jan 26 11:35 TEST_OK.md
-rw-r--r--@  1 ronnyworks  staff    41 Jan 25 22:29 test-1769398143.md
```

**~/agent/outbox contents:**
```
total 72
drwxr-xr-x@ 11 ronnyworks  staff   352 Jan 26 22:20 .
drwxr-xr-x@  6 ronnyworks  staff   192 Jan 26 22:18 ..
-rw-r--r--@  1 ronnyworks  staff  1091 Jan 26 11:35 response-20260126-113526.md
-rw-r--r--@  1 ronnyworks  staff  1009 Jan 26 11:50 response-20260126-115017.md
-rw-r--r--@  1 ronnyworks  staff   105 Jan 26 11:57 response-20260126-115722.md
-rw-r--r--@  1 ronnyworks  staff   112 Jan 26 12:00 response-20260126-120045.md
-rw-r--r--@  1 ronnyworks  staff   109 Jan 26 12:07 response-20260126-120714.md
-rw-r--r--@  1 ronnyworks  staff   110 Jan 26 14:48 response-20260126-144800.md
-rw-r--r--@  1 ronnyworks  staff   110 Jan 26 14:48 response-20260126-144801.md
-rw-r--r--@  1 ronnyworks  staff  1006 Jan 26 14:49 response-20260126-144909.md
-rw-r--r--@  1 ronnyworks  staff  1703 Jan 26 22:20 response-20260126-221949.md
```

**Desktop agent links (should be none):**
```
(none - GOOD)
```

**Legacy folders (should not be used):**
```
EXISTS: /Users/ronnyworks/agent-inbox
drwxr-xr-x@ 11 ronnyworks  staff  352 Jan 26 14:49 /Users/ronnyworks/agent-inbox
EXISTS: /Users/ronnyworks/agent-outbox
drwxr-xr-x@ 10 ronnyworks  staff  320 Jan 26 14:49 /Users/ronnyworks/agent-outbox
EXISTS: /Users/ronnyworks/ronnyworks
drwxr-xr-x@ 3 ronnyworks  staff  96 Jan 26 19:27 /Users/ronnyworks/ronnyworks
EXISTS: /Users/ronnyworks/RONNYWORKS
drwxr-xr-x@ 3 ronnyworks  staff  96 Jan 26 19:27 /Users/ronnyworks/RONNYWORKS
EXISTS: /Users/ronnyworks/ronny-ops/state/agent
drwxr-xr-x@ 6 ronnyworks  staff  192 Jan 26 22:13 /Users/ronnyworks/ronny-ops/state/agent
```

### B) Launchd Truth

**Launchd list (agent-related):**
```
54955	0	com.ronny.agent-inbox
```

**Launchd job details:**
```
gui/501/com.ronny.agent-inbox = {
	active count = 1
	path = /Users/ronnyworks/Library/LaunchAgents/com.ronny.agent-inbox.plist
	type = LaunchAgent
	state = running

	program = /bin/bash
	arguments = {
		/bin/bash
		-lc
		/Users/ronnyworks/ronny-ops/scripts/agents/hot-folder-watcher.sh
	}

	working directory = /Users/ronnyworks/ronny-ops

	stdout path = /Users/ronnyworks/agent/logs/agent-inbox.out
	stderr path = /Users/ronnyworks/agent/logs/agent-inbox.err
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.RIlzSsNsen/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		AGENT_INBOX => /Users/ronnyworks/agent/inbox
		PATH => /usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
		AGENT_STATE => /Users/ronnyworks/agent/state
		AGENT_OUTBOX => /Users/ronnyworks/agent/outbox
		RONNY_OPS_REPO => /Users/ronnyworks/ronny-ops
		HOME => /Users/ronnyworks
		XPC_SERVICE_NAME => com.ronny.agent-inbox
	}

	domain = gui/501 [100012]
	asid = 100012
	minimum runtime = 30
	exit timeout = 5
	runs = 1
```

**Plist environment variables:**
```
    "AGENT_INBOX" => "/Users/ronnyworks/agent/inbox"
    "AGENT_OUTBOX" => "/Users/ronnyworks/agent/outbox"
    "AGENT_STATE" => "/Users/ronnyworks/agent/state"
  "StandardErrorPath" => "/Users/ronnyworks/agent/logs/agent-inbox.err"
  "StandardOutPath" => "/Users/ronnyworks/agent/logs/agent-inbox.out"
```

### C) Repo Status

**Git status:**
```
 M docs/runbooks/AGENT_DISPATCH_PIPELINE.md
 M infrastructure/dotfiles/macbook/launchd/com.ronny.agent-inbox.plist
 M scripts/agents/hot-folder-watcher.sh
?? docs/audits/AGENT_RUNTIME_AUDIT.md
?? docs/audits/DISCONNECT_AUDIT_2026-01-27.md
?? scripts/purge_outbox.sh
?? state/
```

**Repo state/ folder (should be gitignored or absent):**
```
total 0
drwxr-xr-x@  4 ronnyworks  staff   128 Jan 26 22:11 .
drwxr-xr-x  37 ronnyworks  staff  1184 Jan 26 22:10 ..
drwxr-xr-x@  6 ronnyworks  staff   192 Jan 26 22:13 agent
drwxr-xr-x@  5 ronnyworks  staff   160 Jan 26 22:11 backups
```

## 2) WHAT DOCUMENTATION SAYS

### AGENT_DISPATCH_PIPELINE.md canonical claims:

```
> **SSOT**: This runbook governs the hot-folder prompt dispatch system.
~/agent/inbox/*.md       ← Canonical SSOT
~/agent/outbox/response-YYYYMMDD-HHMMSS.md
### Canonical Paths (SSOT)
| `~/agent/inbox/` | Prompt files (.md or .txt) |
| `~/agent/outbox/` | Response files |
| `~/agent/logs/` | Watcher logs |
| `~/agent/state/` | Lock files, PID, queue state |
| `~/agent/inbox/.processed/` | Processed prompts |
For drag-and-drop convenience, Desktop folders symlink to canonical:
~/Desktop/agent-inbox  → ~/agent/inbox
~/Desktop/agent-outbox → ~/agent/outbox
**Rule**: Desktop is convenience, not truth. Canonical paths are the SSOT.
# Via canonical path
echo "Explain the SOLID principles" > ~/agent/inbox/solid.md
ls ~/agent/outbox/
cat ~/agent/outbox/response-*.md | tail -50
tail -f ~/agent/logs/agent-inbox.out
| `~/agent/inbox/` | Drop prompts here (.md or .txt) |
| `~/agent/inbox/.processed/` | Processed prompts move here |
```

### All agent path references in docs/:
```
(none)
```

## 3) WHAT SCRIPTS EXIST

### hot-folder-watcher.sh path usage:
```
7:# Purpose: Watch agent inbox for prompt files, wrap with supervisor
27:INBOX="${AGENT_INBOX:-$HOME/~/agent/inbox}"
28:OUTBOX="${AGENT_OUTBOX:-$HOME/~/agent/outbox}"
29:STATE_DIR="${AGENT_STATE:-$HOME/~/agent/state}"
30:PROCESSED="${INBOX}/.processed"
40:LOG_FILE="${STATE_DIR}/hot-folder-watcher.log"
43:LOCK_DIR="${STATE_DIR}/locks/agent-inbox.lock"
44:PID_FILE="${STATE_DIR}/agent-inbox.pid"
126:    mkdir -p "$INBOX" "$OUTBOX" "$PROCESSED" "$STATE_DIR" "${STATE_DIR}/locks"
128:    log "Setup complete: inbox=$INBOX outbox=$OUTBOX state=$STATE_DIR"
130:    echo "   Inbox:     $INBOX"
131:    echo "   Outbox:    $OUTBOX"
133:    echo "   State:     $STATE_DIR"
274:        local outfile="${OUTBOX}/response-${ts}.md"
306:    log "Starting watcher on: $INBOX"
308:    echo "🔄 Watching: $INBOX"
312:    fswatch -0 --event Created --event Updated "$INBOX" | while IFS= read -r -d '' file; do
330:    local test_file="${INBOX}/test-$(date +%s).md"
339:    latest_response=$(ls -t "${OUTBOX}"/response-*.md 2>/dev/null | head -1)
376:            echo "  AGENT_INBOX        Override inbox path (default: ~/agent/inbox)"
```

### purge_outbox.sh path usage:
```
9:OUT="$HOME/agent/outbox"
10:REPO="$HOME/ronny-ops"
14:OUT_REAL="$(python3 -c "import os; print(os.path.realpath('$OUT'))")"
17:count=$(find "$OUT_REAL" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
23:echo "Outbox: $OUT_REAL"
29:  RECEIPT="$REPO/receipts/OUTBOX_PURGE_$(date +%Y%m%d_%H%M%S).md"
30:  mkdir -p "$REPO/receipts"
36:    for f in "$OUT_REAL"/*; do
41:  rm -rf "$OUT_REAL"/*
45:  ARCH="$REPO/state/backups/outbox-archive/$TS"
48:  for f in "$OUT_REAL"/*; do
```

### Launchd plist path usage:
```
        <string>/Users/ronnyworks/ronny-ops/scripts/agents/hot-folder-watcher.sh</string>
    <key>StandardOutPath</key>
    <string>~/agent/logs/agent-inbox.out</string>
    <key>StandardErrorPath</key>
    <string>~/agent/logs/agent-inbox.err</string>
        <key>AGENT_INBOX</key>
        <string>~/agent/inbox</string>
        <key>AGENT_OUTBOX</key>
        <string>~/agent/outbox</string>
        <key>AGENT_STATE</key>
        <string>~/agent/state</string>
```

## 4) PATH TRUTH TABLE

| Path | Filesystem | Docs | Script | Launchd | Verdict |
|------|------------|------|--------|---------|---------|
| inbox | ~/agent/inbox | ~/agent/inbox | $HOME/agent/inbox | /Users/.../agent/inbox | OK |
| outbox | ~/agent/outbox | ~/agent/outbox | $HOME/agent/outbox | /Users/.../agent/outbox | OK |
| logs | ~/agent/logs | ~/agent/logs | $HOME/agent/logs | /Users/.../agent/logs | OK |
| state | ~/agent/state | ~/agent/state | $HOME/agent/state | /Users/.../agent/state | OK |

## 5) RISKS / MISMATCHES

- **Legacy folder exists:** `/Users/ronnyworks/agent-inbox` (should be removed)
- **Legacy folder exists:** `/Users/ronnyworks/agent-outbox` (should be removed)
- **Legacy folder exists:** `/Users/ronnyworks/ronnyworks` (should be removed)
- **Legacy folder exists:** `/Users/ronnyworks/RONNYWORKS` (should be removed)
- **Repo tracks runtime state:** `state/agent/` (should be removed or gitignored)
- **Untracked state/ in repo** (should be gitignored)


## 6) FIX PLAN (No Execution)

### Required steps to reach desired state:

1. **Remove legacy folders:**
   ```bash
   rm -rf ~/agent-inbox ~/agent-outbox ~/ronnyworks ~/RONNYWORKS ~/ronny-ops/state/agent
   ```

2. **Ensure no Desktop links:**
   ```bash
   rm -f ~/Desktop/agent-inbox ~/Desktop/agent-outbox
   ```

3. **Add state/ to .gitignore:**
   ```bash
   echo "state/" >> ~/ronny-ops/.gitignore
   ```

4. **Commit repo changes:**
   - Modified: docs/runbooks/AGENT_DISPATCH_PIPELINE.md
   - Modified: infrastructure/dotfiles/macbook/launchd/com.ronny.agent-inbox.plist
   - Modified: scripts/agents/hot-folder-watcher.sh
   - New: scripts/purge_outbox.sh

5. **Verify launchd uses correct paths** (already done if plist shows ~/agent/...)

---

## Desired End State

| Item | Path | Purpose |
|------|------|---------|
| Inbox | `~/agent/inbox/` | Drop prompts here |
| Outbox | `~/agent/outbox/` | Responses land here |
| Logs | `~/agent/logs/` | Watcher logs |
| State | `~/agent/state/` | Locks + ledger |
| Repo | `~/ronny-ops/` | Code + docs only |

**No Desktop links. No legacy folders. No runtime state in repo.**
