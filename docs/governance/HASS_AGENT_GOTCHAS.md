---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
scope: ha-agent-gotchas
---

# Home Assistant Agent Gotchas

> Every friction point agents encounter when working with Home Assistant in this spine.
> Discovered during real activation sessions on 2026-02-15.
> If you are an agent entering a session cold, read this top-to-bottom before touching HA.

---

## 1. `ha apps` vs `ha addons` CLI Deprecation

The HA CLI deprecated `ha addons` in favor of `ha apps`. Using the old form will fail silently or error.

**Wrong:**
```bash
ssh hassio@ha "bash -l -c 'ha addons start core_zwave_js'"
```

**Right:**
```bash
ssh hassio@ha "bash -l -c 'ha apps start core_zwave_js'"
```

Available subcommands: `start`, `stop`, `restart`, `info`, `logs`, `update` -- all via `ha apps`.

**Critical:** `ha apps options` does NOT exist. To change add-on options you must use the Supervisor REST API directly (see gotcha #3).

---

## 2. SUPERVISOR_TOKEN Access Pattern

`$SUPERVISOR_TOKEN` is NOT available in a plain SSH session. You must use `bash -l -c '...'` to load the login environment where the token is injected.

**Wrong:**
```bash
ssh hassio@ha 'curl -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/api/config'
```

**Right:**
```bash
ssh hassio@ha 'bash -l -c '"'"'curl -s -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/api/config'"'"''
```

The `docker exec homeassistant bash -c "..."` pattern also works but only from inside an already-established SSH session.

**Prerequisite:** Protection Mode must be OFF on the SSH add-on for Supervisor API access. If you get connection refused to `http://supervisor`, this is the first thing to check.

---

## 3. Supervisor REST API Behavior

The Supervisor API `/addons/<slug>/options` endpoint **REPLACES** all options -- it does not merge. You must send the COMPLETE option set every time.

**Pattern:** GET current options first via `/addons/<slug>/info` (read `.data.options`), then POST the full set back with your changes.

**Wrong:**
```bash
# Sending only the field you want to change -- all other options get wiped
POST {"options": {"network_device": "10.0.0.52:6638"}}
# Error: "Missing option 'firewall'"
```

**Right:**
```bash
# Send the complete option set with your change included
POST {"options": {"device": "/dev/ttyS0", "baudrate": "460800", "flow_control": true, "otbr_log_level": "notice", "firewall": true, "nat64": false, "beta": false, "network_device": "10.0.0.52:6638"}}
```

**Full API call pattern:**
```bash
ssh hassio@ha 'bash -l -c '"'"'curl -s -X POST \
  -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"options\": {... full options ...}}" \
  http://supervisor/addons/<slug>/options'"'"''
```

---

## 4. Add-on Slug Formats

Slug prefixes vary by source repository:

| Source | Prefix | Examples |
|--------|--------|----------|
| Core add-ons | `core_*` | `core_zwave_js`, `core_matter_server`, `core_openthread_border_router`, `core_mosquitto`, `core_configurator`, `core_git_pull`, `core_whisper` |
| Community (a0d7b954 repo) | `a0d7b954_*` | `a0d7b954_ssh`, `a0d7b954_tailscale` |
| Z2M community repo | `45df7312_*` | `45df7312_zigbee2mqtt` |
| Local builds | `local_*` | `local_tubeszb` |

Docker container names prepend `addon_` to the slug: `addon_45df7312_zigbee2mqtt`, `addon_core_zwave_js`.

**When scripting:** always use `ha apps info <slug>` to verify the slug exists before operating on it. Do not guess slugs.

---

## 5. OTBR network_device Format

The OpenThread Border Router add-on `network_device` option uses bare `host:port` format. The add-on internally wraps it with socat's `tcp:` prefix.

**Wrong:**
```bash
"network_device": "tcp://10.0.0.52:6638"
# socat error: "tcp: wrong number of parameters (3 instead of 2)"
```

**Right:**
```bash
"network_device": "10.0.0.52:6638"
```

**Also:** the `device` field is REQUIRED by the schema even when `network_device` is set. Use `/dev/ttyS0` as a placeholder value.

---

## 6. Entity Naming Patterns

HA entity IDs are not guessable. Here are the real names discovered during activation:

| Purpose | Entity ID |
|---------|-----------|
| Z2M bridge connection | `binary_sensor.zigbee2mqtt_bridge_connection_state` (NOT `sensor.zigbee2mqtt_bridge_state`) |
| SLZB-06MU radio type | `sensor.slzb_06mu_zigbee_type` (reports "thread" when in RCP mode) |
| TubesZB serial connected | `binary_sensor.tubeszb_2026_zw_tubeszb_zw_serial_connected` (on/off) |
| TubesZB IP address | `sensor.tubeszb_2026_zw_esp_ip_address` |
| SLZB core firmware update | `update.slzb_06mu_core_firmware` |
| SLZB Zigbee firmware update | `update.slzb_06mu_zigbee_firmware` |

**Rule:** always query the HA API (`/api/states`) to discover entity IDs. Never guess.

---

## 7. SSH Quoting for Supervisor API Calls

The triple-nested quoting for SSH -> bash -l -> curl with JSON is the single most error-prone pattern in HA scripting.

**Template:**
```bash
ssh hassio@ha 'bash -l -c '"'"'curl -s -X POST \
  -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"key\": \"value\"}" \
  http://supervisor/addons/<slug>/<action>'"'"''
```

**How the quoting works:**
- `'bash -l -c '` -- opens and closes the outer single-quote
- `"'"` -- adds a literal single quote via double-quoting
- `"'curl -s ...'"` -- opens a new single-quoted segment for the inner command
- `"'"` -- adds the closing literal single quote
- `''` -- empty string, closes the SSH argument

The `'"'"'` construct: end single quote, add literal single quote (double-quoted), reopen single quote.

**Alternative:** for complex JSON payloads, use a heredoc or write to a temporary file on the remote host instead of inline quoting.

---

## 8. Capability Preconditions for HA Operations

All `touches_api: true` capabilities require secrets preconditions to be satisfied before execution: `secrets.binding` + `secrets.auth.status`.

The cap runner checks these automatically. But if running scripts manually outside the cap runner, you need:

1. **Infisical agent available:** `${SPINE_ROOT}/ops/tools/infisical-agent.sh`
2. **Token retrieval:** `infisical-agent.sh get home-assistant prod HA_API_TOKEN`
3. **HA reachable at Tailscale IP:** `http://100.67.120.1:8123/api`

**Common failure:** HA is reachable at local IP (10.0.0.100) but NOT at the Tailscale IP. If API calls time out, check that Tailscale is running on the HA host first.

---

## Related Documents

- [HASS_OPERATIONAL_RUNBOOK.md](HASS_OPERATIONAL_RUNBOOK.md) -- step-by-step procedures for HA operations
- [HASS_MCP_INTEGRATION.md](HASS_MCP_INTEGRATION.md) -- MCP bridge integration policy and constraints
- [HASS_LEGACY_EXTRACTION_MATRIX.md](HASS_LEGACY_EXTRACTION_MATRIX.md) -- extraction coverage and gap tracking
