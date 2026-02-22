# AOF Alignment Audit: /infra

> **Audit Date:** 2026-02-16
> **Target Folder:** `/Users/ronnyworks/code/agentic-spine/infra`
> **Auditor:** Sisyphus (agentic-spine)
> **Status:** READ-ONLY AUDIT (no edits made)

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Total Items | 10 (1 directory + 9 files) |
| KEEP_SPINE | 0 |
| MOVE_WORKBENCH | 9 files |
| RUNTIME_ONLY | 0 |
| UNKNOWN | 1 (broken doc reference) |

**Verdict:** The `infra/` folder in agentic-spine contains Home Assistant Lovelace dashboard configurations that belong in the workbench tooling surface or the home-assistant pillar, NOT in the spine runtime environment.

---

## Classification Rationale

### Governance Sources Consulted

1. **STACK_AUTHORITY.md**: Spine VM-infra stacks live in `ops/staged/**` — these are canonical, sanitized compose configs
2. **RUNWAY_TOOLING_PRODUCT_OPERATING_CONTRACT_V1.md**: 
   - Spine = runway/governance (loops, gaps, capabilities, receipts, SSOT bindings)
   - Workbench = tooling surface (compose/script/tooling assets)
3. **REPO_STRUCTURE_AUTHORITY.md** (workbench-scoped): `infra/` in workbench contains `compose/`, `cloudflare/`, `data/`, etc.
4. **AGENTS.md / GOVERNANCE_BRIEF**: Spine is the runtime environment; workbench is compose/script/MCP configs

### Key Principle

Home Assistant dashboards are **application-level UI configurations** consumed by an external service (Home Assistant). They are NOT:
- Spine runtime infrastructure (no capabilities, no receipts, no governance)
- VM-infra compose stacks (those live in `ops/staged/`)
- Part of the governed spine surface

They ARE:
- Tooling/supporting configurations for a smart home application
- Appropriate for workbench `infra/` or a dedicated `home-assistant` pillar

---

## KEEP_SPINE (0 items)

None. The spine's infrastructure authority is `ops/staged/**` for VM-infra compose configs.

---

## MOVE_WORKBENCH (9 files)

All files in `infra/ha-dashboards/` should move to workbench.

| # | Absolute Path | Size | Risk | Notes |
|---|---------------|------|------|-------|
| 1 | `/Users/ronnyworks/code/agentic-spine/infra/ha-dashboards/command-center.yaml` | 139,703 bytes | MEDIUM | Main Command Center dashboard — largest file |
| 2 | `/Users/ronnyworks/code/agentic-spine/infra/ha-dashboards/home-dashboard.yaml` | 30,009 bytes | LOW | Central 7-tab Home dashboard |
| 3 | `/Users/ronnyworks/code/agentic-spine/infra/ha-dashboards/master-bedroom.yaml` | 15,468 bytes | LOW | Master Bedroom dashboard |
| 4 | `/Users/ronnyworks/code/agentic-spine/infra/ha-dashboards/ronny-phone.yaml` | 9,831 bytes | LOW | Ronny mobile dashboard |
| 5 | `/Users/ronnyworks/code/agentic-spine/infra/ha-dashboards/empress-phone.yaml` | 8,523 bytes | LOW | Empress phone dashboard |
| 6 | `/Users/ronnyworks/code/agentic-spine/infra/ha-dashboards/kitchen-hub.yaml` | 8,126 bytes | LOW | Kitchen Hub dashboard |
| 7 | `/Users/ronnyworks/code/agentic-spine/infra/ha-dashboards/guest-room.yaml` | 5,460 bytes | LOW | Guest Room dashboard |
| 8 | `/Users/ronnyworks/code/agentic-spine/infra/ha-dashboards/command-center-v2-test.yaml` | 6,145 bytes | LOW | Test/v2 Command Center variant |
| 9 | `/Users/ronnyworks/code/agentic-spine/infra/ha-dashboards/tier1-dashboard.yaml` | 3,543 bytes | LOW | Tier 1 priority dashboard |

**Recommended Target Location:**
```
/Users/ronnyworks/code/workbench/infra/ha-dashboards/
```

Or if home-assistant is a separate pillar:
```
/Users/ronnyworks/code/workbench/home-assistant/dashboards/
```

---

## RUNTIME_ONLY (0 items)

None. These are configuration files, not runtime processes.

---

## UNKNOWN (1 item)

| # | Item | Description | Action Needed |
|---|------|-------------|---------------|
| 1 | Broken doc reference | `master-bedroom.yaml` references `../../../HA_INFRASTRUCTURE.md` which does not exist at repo root | Create the missing doc or remove the reference |

**Evidence:** The file `/Users/ronnyworks/code/agentic-spine/HA_INFRASTRUCTURE.md` does not exist.

---

## Top 10 Highest-Risk Mismatches

| Rank | File | Risk | Reason |
|------|------|------|--------|
| 1 | `command-center.yaml` | MEDIUM | Largest file (139KB) — if actively used, migration requires verification of HA integration |
| 2 | `master-bedroom.yaml` | LOW | Contains broken doc reference to `HA_INFRASTRUCTURE.md` |
| 3-9 | Other dashboard YAMLs | LOW | Standard UI configs, low complexity |

---

## Content Analysis

### File Types Found

| Type | Count | Location |
|------|-------|----------|
| YAML (Lovelace dashboard) | 9 | `infra/ha-dashboards/` |

### Sample Content (home-dashboard.yaml)

```yaml
# Home Dashboard - 7-Tab Structure
# Purpose: Single source of truth for all devices
# Last Updated: Jan 2, 2026
# Structure: Home | Devices | Automations | Media | Climate | Security | System

title: Home
views:
  - title: Home
    path: home
    icon: mdi:home
    # ... (Lovelace dashboard configuration)
```

### Purpose

These files define Home Assistant Lovelace dashboard UIs for:
- Light controls (bedroom lamps, bulbs)
- Media players (TVs, speakers)
- Climate controls (air purifiers)
- Security (Ring doorbell, Yale lock, sensors)
- Prayer times display
- Device inventory by type
- Automation status

---

## Git Status

| Status | Count | Items |
|--------|-------|-------|
| Tracked | 9 | All `infra/ha-dashboards/*.yaml` files |
| Ignored | 0 | None detected |
| Untracked | 0 | None |

---

## Recommendations

### Immediate Actions

1. **Move all 9 YAML files** from `agentic-spine/infra/ha-dashboards/` to `workbench/infra/ha-dashboards/`
2. **Remove the empty `infra/` directory** from spine after migration
3. **Create or remove** the missing `HA_INFRASTRUCTURE.md` reference

### Drift Gate Impact

After migration, verify:
- `spine.verify` passes without the infra folder
- No capabilities reference `infra/ha-dashboards/`

### Future Prevention

Add a drift gate check that `infra/` in spine should be empty or not exist (spine infra is `ops/staged/`).

---

## Audit Trail

| Step | Tool | Result |
|------|------|--------|
| Glob infra/** | glob | Found 9 files in ha-dashboards/ |
| Read governance docs | read | STACK_AUTHORITY, REPO_STRUCTURE_AUTHORITY, RUNWAY_TOOLING_CONTRACT |
| Sample file contents | read | home-dashboard.yaml (768 lines) |
| Git tracking check | bash | All 9 files tracked |
| Background explore | task | Confirmed inventory |

---

## Sign-off

- **Audit Complete:** 2026-02-16
- **Classification:** MOVE_WORKBENCH (all 9 files)
- **Blocking Issues:** None (safe to migrate)
- **Next Step:** Create GAP-OP entry for migration if proceeding
