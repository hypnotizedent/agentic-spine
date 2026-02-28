# W61 Consolidated Baseline

Date: 2026-02-28 (UTC)
Wave: `LOOP-SPINE-W61-AGENT-FRICTION-CONSOLIDATION-20260228-20260303`

## Phase 0 Run Keys

- `session.start`: `CAP-20260227-212824__session.start__Rortc21449`
- `loops.status`: `CAP-20260227-212849__loops.status__Rd87g28987`
- `gaps.status`: `CAP-20260227-212849__gaps.status__Rqui828994`

## Repo Baseline Parity

| repo | branch | head | origin/main | github/main | share/main |
|---|---|---|---|---|---|
| `agentic-spine` | `codex/w61-entry-projection-verify-unification-20260228` | `20ef0b4beede60891a1ec8f1b45ecce4c8955a84` | `5c2454f5b74ab91d111355233aed108736d73df0` | `5c2454f5b74ab91d111355233aed108736d73df0` | `5c2454f5b74ab91d111355233aed108736d73df0` |
| `workbench` | `codex/w61-entry-projection-verify-unification-20260228` | `e1d97b7318b3415e8cafef30c7c494a585e7aec6` | `e1d97b7318b3415e8cafef30c7c494a585e7aec6` | `e1d97b7318b3415e8cafef30c7c494a585e7aec6` | n/a |
| `mint-modules` | `codex/w61-entry-projection-verify-unification-20260228` | `b98bf32126ad931842a2bb8983c3b8194286a4fd` | `b98bf32126ad931842a2bb8983c3b8194286a4fd` | `b98bf32126ad931842a2bb8983c3b8194286a4fd` | n/a |

## Open Gap Data-Quality Snapshot

- Open gaps missing `parent_loop`: **33**
- Open gaps missing `title`: **80**
- Open gaps missing `classification`: **80**

### Open Gaps With Missing parent_loop

| gap_id | severity | type | description_head |
|---|---|---|---|
| `GAP-OP-1037` | critical | missing-entry | infra-proxmox-maintenance uses only qm (QEMU) commands for shutdown/startup — no pct (LXC) support. shutdown_vms() calls qm shutdown/qm stop only. LXC containers like pihole-home (105) are invisible to the maintenance orchestrator. |
| `GAP-OP-1038` | critical | missing-entry | LXC 105 (pihole-home) absent from startup.sequencing.yaml. home_vm_lifecycle.active_vm_ids only lists [100]. No active_lxc_ids field exists. Phase 11 reserved but empty. LXC not in shutdown or startup ordering. |
| `GAP-OP-1039` | critical | missing-entry | resolve_vm_order() Python in infra-proxmox-maintenance only reads vm_ids key from startup.sequencing.yaml phases. No lxc_ids extraction. LXC containers cannot be ordered for startup or shutdown even if declared in the binding. |
| `GAP-OP-1040` | high | runtime-bug | assert_qm_exists() and is_qm_running() in infra-proxmox-maintenance use qm status which fails on LXC container IDs. If LXC IDs are added to sequencing without fixing these functions, maintenance will error out. |
| `GAP-OP-1041` | high | missing-entry | infra-post-power-recovery only checks docker ps for container state. No pct list or LXC state inspection. LXC 105 (pihole-home) invisible to recovery status and recovery execution. |
| `GAP-OP-1042` | critical | missing-entry | No nas.shutdown capability exists. Synology NAS (DS918+) requires manual DSM web UI or SSH poweroff. Not part of any maintenance orchestration. Must be last to shut down (Proxmox Home mounts backup storage from it). |
| `GAP-OP-1043` | critical | missing-entry | No nas.startup capability exists. NAS power-on requires physical button or undocumented Wake-on-LAN. No automation for post-power-cycle recovery. Must start before Proxmox Home so backup NFS mount is available. |
| `GAP-OP-1044` | critical | missing-entry | NAS not in startup.sequencing.yaml. No phase entry, no dependency ordering. Correct order: shutdown (VMs -> LXCs -> Proxmox Host -> NAS last) and startup (NAS first -> Proxmox Host -> VMs/LXCs). This ordering is not codified anywhere. |
| `GAP-OP-1045` | high | missing-entry | NAS (synology918 / DS918+) not in SERVICE_REGISTRY.yaml. No SLO, no domain assignment, no terminal role. First-class infrastructure nodes have service-level governance; NAS does not. |
| `GAP-OP-1046` | high | missing-entry | NAS NFS mount dependencies undeclared. Proxmox Home mounts /mnt/pve/synology-backups from NAS (10.0.0.150). Shop VMs 209/210 mount /tank/docker and /media via pve. No dependency graph codified. NFS failure is silent until service degradation. |
| `GAP-OP-1047` | medium | stale-ssot | D139 gate validates NAS presence in device registry and backup inventory only. Does not enforce NAS in startup.sequencing.yaml, SERVICE_REGISTRY, or that shutdown/startup capabilities exist. Gate scope insufficient for first-class infrastructure governance. |
| `GAP-OP-1048` | critical | runtime-bug | Recovery phase in infra-maintenance-window hardcoded to skip home site entirely. Line 493: if SITE==home then return 0. Home site gets no post-power recovery — no NAS check, no LXC verification, no HA supervisor health confirmation. |
| `GAP-OP-1049` | high | missing-entry | REBOOT_HEALTH_GATE.md covers shop site only. No pre-reboot checklist, hard stop conditions, or rollback criteria documented for proxmox-home. Home site operators have no playbook for maintenance or post-power-loss recovery. |
| `GAP-OP-1050` | high | missing-entry | Home site has zero observability capabilities. Shop has 15+ (prometheus, grafana, loki, uptime-kuma, alerting probes). Home has no monitoring dashboards, metric aggregation, or alerting infrastructure. Failures are only discovered reactively. |
| `GAP-OP-1058` | medium | missing-entry | Home backup governance missing: no offsite sync capability (shop has vzdump-offsite-sync.sh), no app-level backup targets (shop has 9), no backup.vzdump.prune equivalent for home. Home relies on VM-level vzdump only. |
| `GAP-OP-1059` | medium | missing-entry | Home site storage policy undeclared. infra.storage.placement.policy.yaml has no entries for VM 100 or LXC 105. No storage tier assignment, no compliance tracking, no boot drive audit coverage for home site assets. |
| `GAP-OP-1060` | medium | stale-ssot | LXC 105 backup is 69h old but REBOOT_HEALTH_GATE.md requires <24h before maintenance. No automated gate enforces backup freshness as a precondition for home site maintenance window. Shop vzdump runs daily; LXC 105 schedule is inconsistent. |
| `GAP-OP-1061` | high | missing-entry | Home site has only 2 health probes (pihole-home + home-assistant) vs shop 30+. No probes for NAS NFS availability, proxmox-home hypervisor health, or LXC 105 DNS resolution functionality. |
| `GAP-OP-1062` | critical | runtime-bug | infra-maintenance-window rejects non-shop/home site names. Line 99: case SITE in shop\|home\|both. A 3rd site name would fail arg validation. Must read valid sites dynamically from infra.maintenance.transaction.contract.yaml. |
| `GAP-OP-1063` | critical | runtime-bug | shutdown_sites() and startup_sites() in infra-maintenance-window use hardcoded case statements (shop/home/both). No dynamic site enumeration from contract. A 3rd site would be silently excluded from shutdown and startup phases. |
| `GAP-OP-1064` | critical | runtime-bug | enforce_shop_oob_policy() checks SITE_ID \!= shop literally instead of reading requires_oob_guard from contract. If a 3rd site needs OOB guard it wont get one. Contract already has the field but the script doesnt use it. |
| `GAP-OP-1065` | high | runtime-bug | OOB guard LAN devices hardcoded in network-oob-guard-status.legacy line 171: lan_ids=(idrac-shop switch-shop nvr-shop). A 3rd site with different infrastructure devices cannot be validated. Device list should come from a binding. |
| `GAP-OP-1066` | high | runtime-bug | Poweroff flags in infra-maintenance-window are site-specific: --poweroff-shop and --poweroff-home with matching POWEROFF_SHOP/POWEROFF_HOME vars. No dynamic --poweroff-<site> pattern. 3rd site would need code change to add --poweroff-site3. |
| `GAP-OP-1067` | medium | stale-ssot | Default host ID pve hardcoded in infra-proxmox-maintenance line 13. Multiple scripts default to shop host. While overridable via --host-id flag, the default creates shop-bias and requires explicit flag for any other site. |
| `GAP-OP-1068` | high | runtime-bug | Recovery decision in infra-maintenance-window is hardcoded: if SITE==home then skip recovery. Should be contract-driven with a requires_recovery field per site. A 3rd site with docker stacks would not get recovery unless code is changed. |
| `GAP-OP-1069` | medium | stale-ssot | network-oob-guard-status.legacy line 41 hardcodes SUBNET=192.168.1.0/24 (shop LAN). While overridable via flag, the default assumes shop. A 3rd site with different LAN CIDR would need to always pass --subnet explicitly. |
| `GAP-OP-1095` | high | agent-behavior | cap show does not display flag documentation or usage examples. Agent called infra.proxmox.maintenance.precheck without --mode precheck and got STOP. Had to read script source to discover required flags. cap show should parse --help or display flags from capability definition. |
| `GAP-OP-1096` | medium | agent-behavior | Capability name implies mode but does not inject it. infra.proxmox.maintenance.precheck and infra.proxmox.maintenance.shutdown are separate capabilities that call the same script but still require explicit --mode flag. The capability definition should auto-inject the mode so agents dont need to discover it. |
| `GAP-OP-1097` | medium | runtime-bug | zsh read-only status variable collision. Bash loops using status as variable name fail silently or error in zsh (macOS default). Agent verification scripts and inline bash hit this. Spine scripts should avoid status as a local variable name or use underscore prefix. |
| `GAP-OP-1098` | medium | agent-behavior | MEMORY.md truncated at 200 lines (currently 268). Agent loses context on recent loops, discoveries, and gotchas. Needs aggressive restructure: move detailed notes into topic files, keep MEMORY.md as a concise index under 150 lines with links. |
| `GAP-OP-1099` | medium | agent-behavior | cap.sh overhead painful for bulk operations. Each gaps.file call takes 3-5s (policy resolution, receipt gen, identity check). Filing 26 gaps took over 3 minutes of wall time. Need lightweight batch mode or reduced overhead path for sequential same-capability calls. |
| `GAP-OP-1100` | low | agent-behavior | Parallel subagents share no context cache. 5 Explore agents launched concurrently each independently read vm.lifecycle.yaml, startup.sequencing.yaml, gate.registry.yaml etc. Total token usage ~400K for one research question split 5 ways. Consider shared context bundles or ctx preload for common infra files. |
| `GAP-OP-1108` | high | missing-entry | Synology NAS (synology918) has no passwordless sudo for shutdown commands. ronadmin user requires interactive password for sudo, blocking automated nas.shutdown capability. Need: either passwordless sudoers entry for synopoweroff/synoshutdown, or NAS admin credentials stored in Infisical for DSM API shutdown. Currently requires manual password input. |

### Open Gaps With Missing title

| gap_id | severity | parent_loop | type |
|---|---|---|---|
| `GAP-OP-973` | high | LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226 | missing-entry |
| `GAP-OP-1018` | high | LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 | runtime-bug |
| `GAP-OP-1019` | medium | LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 | runtime-bug |
| `GAP-OP-1020` | medium | LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 | missing-entry |
| `GAP-OP-1021` | medium | LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 | missing-entry |
| `GAP-OP-1022` | high | LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 | missing-entry |
| `GAP-OP-1002` | medium | LOOP-MAIL-ARCHIVER-OVERLAP-CLEANUP-20260226 | duplicate-truth |
| `GAP-OP-1036` | high | LOOP-MD1400-CAPACITY-NORMALIZATION-20260227-20260227 | runtime-bug |
| `GAP-OP-1051` | medium | LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1052` | medium | LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1037` | critical | (none) | missing-entry |
| `GAP-OP-1038` | critical | (none) | missing-entry |
| `GAP-OP-1039` | critical | (none) | missing-entry |
| `GAP-OP-1040` | high | (none) | runtime-bug |
| `GAP-OP-1041` | high | (none) | missing-entry |
| `GAP-OP-1042` | critical | (none) | missing-entry |
| `GAP-OP-1043` | critical | (none) | missing-entry |
| `GAP-OP-1044` | critical | (none) | missing-entry |
| `GAP-OP-1045` | high | (none) | missing-entry |
| `GAP-OP-1046` | high | (none) | missing-entry |
| `GAP-OP-1047` | medium | (none) | stale-ssot |
| `GAP-OP-1053` | medium | LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1048` | critical | (none) | runtime-bug |
| `GAP-OP-1054` | medium | LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1049` | high | (none) | missing-entry |
| `GAP-OP-1050` | high | (none) | missing-entry |
| `GAP-OP-1055` | low | LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1056` | medium | LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228 | unclear-doc |
| `GAP-OP-1057` | low | LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228 | stale-ssot |
| `GAP-OP-1058` | medium | (none) | missing-entry |
| `GAP-OP-1059` | medium | (none) | missing-entry |
| `GAP-OP-1060` | medium | (none) | stale-ssot |
| `GAP-OP-1061` | high | (none) | missing-entry |
| `GAP-OP-1062` | critical | (none) | runtime-bug |
| `GAP-OP-1063` | critical | (none) | runtime-bug |
| `GAP-OP-1064` | critical | (none) | runtime-bug |
| `GAP-OP-1065` | high | (none) | runtime-bug |
| `GAP-OP-1066` | high | (none) | runtime-bug |
| `GAP-OP-1067` | medium | (none) | stale-ssot |
| `GAP-OP-1068` | high | (none) | runtime-bug |
| `GAP-OP-1069` | medium | (none) | stale-ssot |
| `GAP-OP-1070` | critical | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | runtime-bug |
| `GAP-OP-1071` | high | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | stale-ssot |
| `GAP-OP-1072` | medium | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | runtime-bug |
| `GAP-OP-1073` | medium | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | runtime-bug |
| `GAP-OP-1074` | medium | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1075` | low | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | runtime-bug |
| `GAP-OP-1076` | medium | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | stale-ssot |
| `GAP-OP-1077` | high | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1078` | critical | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | runtime-bug |
| `GAP-OP-1079` | low | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | stale-ssot |
| `GAP-OP-1080` | medium | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | runtime-bug |
| `GAP-OP-1081` | low | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | stale-ssot |
| `GAP-OP-1082` | low | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1083` | low | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1084` | high | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | runtime-bug |
| `GAP-OP-1085` | high | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | runtime-bug |
| `GAP-OP-1086` | high | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1087` | medium | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | missing-entry |
| `GAP-OP-1088` | high | LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228 | agent-behavior |
| `GAP-OP-1089` | low | LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | stale-ssot |
| `GAP-OP-1090` | high | LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228 | missing-entry |
| `GAP-OP-1091` | medium | LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228 | agent-behavior |
| `GAP-OP-1092` | medium | LOOP-SCOPE-TEMPLATE-VOCABULARY-NORMALIZATION-20260228 | stale-ssot |
| `GAP-OP-1093` | high | LOOP-OPERATIONAL-GAPS-YAML-LINTER-STABILITY-20260228 | runtime-bug |
| `GAP-OP-1094` | medium | LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228 | agent-behavior |
| `GAP-OP-1095` | high | (none) | agent-behavior |
| `GAP-OP-1096` | medium | (none) | agent-behavior |
| `GAP-OP-1097` | medium | (none) | runtime-bug |
| `GAP-OP-1098` | medium | (none) | agent-behavior |
| `GAP-OP-1099` | medium | (none) | agent-behavior |
| `GAP-OP-1100` | low | (none) | agent-behavior |
| `GAP-OP-1101` | high | LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228 | runtime-bug |
| `GAP-OP-1102` | high | LOOP-HA-AGENT-TOOLING-GAPS-20260228 | runtime-bug |
| `GAP-OP-1103` | high | LOOP-HA-AGENT-TOOLING-GAPS-20260228 | missing-entry |
| `GAP-OP-1104` | medium | LOOP-HA-AGENT-TOOLING-GAPS-20260228 | missing-entry |
| `GAP-OP-1105` | medium | LOOP-HA-AGENT-TOOLING-GAPS-20260228 | stale-ssot |
| `GAP-OP-1106` | low | LOOP-HA-AGENT-TOOLING-GAPS-20260228 | missing-entry |
| `GAP-OP-1107` | medium | LOOP-HA-AGENT-TOOLING-GAPS-20260228 | missing-entry |
| `GAP-OP-1108` | high | (none) | missing-entry |
