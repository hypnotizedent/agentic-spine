# LOOP-MD1400-SAS-RECOVERY-20260208

> **Status:** open (Phase 1 complete — module config persisted)
> **Blocked By:** cold boot required + **OOB guard not satisfied** (today `pve` is the sole Tailscale subnet router advertising `192.168.1.0/24`, so powering off `pve` strands remote iDRAC unless on-site or a second subnet router is added).
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** critical

---

## Problem Statement

The Dell MD1400 DAS shelf is physically cabled to the R730XD (`pve`) via a Dell SAS cable (DP/N 0GYK61, Mini-SAS HD SFF-8644) but **no drives from the MD1400 are visible to the OS**. The entire shelf's storage is inaccessible.

Two root causes identified:

1. **PCI vendor ID mismatch (GAP-OP-029):** The PM8072 SAS controller reports vendor ID `11f8` (Microchip Technology, post-acquisition) but the Linux `pm80xx` kernel module only recognizes vendor `117C` (PMC-Sierra, pre-acquisition). The driver does not auto-bind at boot.

2. **Firmware initialization failure on hot-load:** When the driver is manually bound via `new_id`, the PM8072 chip firmware does not respond to the MPI handshake. The chip has been sitting uninitialized since power-on because no driver claimed it. A cold boot with the driver loaded at boot time is required for proper firmware init.

---

## Evidence

### Hardware (verified 2026-02-08)

| Component | Value |
|-----------|-------|
| SAS Controller | Microchip PM8072 Tachyon SPCv 12G 16-port (PCIe 82:00.0) |
| PCI ID | `11f8:8072` (rev 06) |
| PCIe Link | UP — 8GT/s, Width x8 (full speed) |
| SAS Cable | Dell DP/N 0GYK61 (Mini-SAS HD SFF-8644, both ends) |
| Cable Status | Connected (physically verified by owner) |
| Internal HBA | Dell HBA330 Mini (LSI SAS3008) — working, drives 12 internal bays |
| MD1400 Power | Confirmed on (owner verified) |

### Driver probe failure (dmesg)

```
pm80xx 0000:82:00.0: pm80xx: driver version 0.1.40
pm8001_alloc: PHY:8                              ← 8 external PHYs detected
pm8001_setup_msix: request ret:1                 ← only 1 MSI-X vector (of 64)
init_pci_device_addresses: Scratchpad 0 Offset: 2000
mpi_uninit_check 735: TIMEOUT:IBDB value/=0x2   ← firmware doorbell timeout
soft_reset_ready_check 768: MPI state is not ready
pm8001_chip_soft_rst 829: FW is not ready        ← chip firmware unresponsive
pm8001_chip_init 664: Firmware is not ready!
pm8001_pci_probe 1173: chip_init failed [ret: -16]  ← -EBUSY
pm80xx 0000:82:00.0: probe with driver pm80xx failed with error -16
```

### PCI details

```
82:00.0 Serial Attached SCSI controller: Microchip Technology PM8072 (rev 06)
  Control: I/O+ Mem+ BusMaster- ...   ← BusMaster never enabled (probe failed before DMA setup)
  LnkSta: Speed 8GT/s, Width x8       ← PCIe link is healthy
  Kernel driver in use: (none)         ← no driver bound
```

### Driver alias mismatch

```
Actual device:    11f8:8072
Driver expects:   117C:8072 (various subsystem IDs)
                  9005:8074/8076/8077 (Adaptec variants)
```

---

## Fix Plan

### Phase 1: Persist driver config (safe — no downtime) — COMPLETE

Executed 2026-02-08. Files written to pve:

- `/etc/modules-load.d/pm80xx.conf` — loads pm80xx at boot
- `/etc/modprobe.d/pm80xx.conf` — install hook injects Microchip PCI ID (`11f8 8072`)

```bash
# /etc/modules-load.d/pm80xx.conf
pm80xx

# /etc/modprobe.d/pm80xx.conf
install pm80xx /sbin/modprobe --ignore-install pm80xx; echo "11f8 8072" > /sys/bus/pci/drivers/pm80xx/new_id 2>/dev/null; true
```

**2026-02-09 correction (no downtime):** `/etc/modprobe.d/pm80xx.conf` was found to be incorrectly set to
`options pm80xx new_id=0x11f8,0x8072` (unsupported; ignored by the driver). It was replaced with the
install-hook form above via the governed capability `network.md1400.pm8072.stage`.

Evidence:
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260209-151027__network.md1400.pm8072.stage__Rf84u3431/receipt.md` (dry-run)
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260209-151114__network.md1400.pm8072.stage__R7rtq4016/receipt.md` (execute)

**2026-02-09 hot-bind test (expected fail):** Manual bind attempt confirmed the PM8072 firmware cannot init without a cold power-on reset.

Evidence:
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260209-152358__network.md1400.bind_test__Rbind5001/receipt.md`

### Phase 2: Cold boot (requires physical presence)

1. Notify: all 10 running VMs will go down
2. `poweroff` pve (NOT reboot — full power cycle needed for PM8072 firmware init)
3. Wait 10 seconds
4. Power on via iDRAC or physical button
5. After boot: verify `lspci -k -s 82:00.0` shows `Kernel driver in use: pm80xx`
6. Verify new drives appear in `lsblk`
7. Assess MD1400 drive inventory (models, serials, health)
8. Decide: create new ZFS pool, add to existing pool, or leave unmanaged

**2026-02-09 Phase 2 execution (FAIL):** Full shutdown + cold boot with AC drain was performed on-site. The controller still fails the same MPI handshake
(`FW is not ready`, `chip_init failed [ret: -16]`) and **no new block devices** appear.

Evidence:
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260209-153006__infra.proxmox.maintenance.shutdown__R061o19880/receipt.md` (VM shutdown + poweroff)
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260209-152948__infra.proxmox.maintenance.precheck__Rnqr119796/receipt.md` (pre-cold-boot baseline + pm80xx probe failure)
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260209-154702__infra.proxmox.maintenance.precheck__R2eyv21104/receipt.md` (post-cold-boot state)
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260209-152358__network.md1400.bind_test__Rbind5001/receipt.md` (bind test evidence)

**Implication:** treat PM8072 as hardware/firmware defective (reflash/replace); proceed to “replace controller with known-good external SAS HBA” path.

### Phase 3: Post-boot validation

- [ ] `lspci -k -s 82:00.0` → `Kernel driver in use: pm80xx`
- [ ] `dmesg | grep pm80xx` → no errors, PHYs and expander enumerated
- [ ] `lsblk` → new drives visible (sdX devices beyond current 14)
- [ ] `smartctl -a /dev/sdX` on each new drive → health assessment
- [ ] All 10 VMs come back online (onboot=1)
- [ ] `spine.verify` → all drift gates pass

---

## Impact Assessment

| Factor | Value |
|--------|-------|
| **Storage at risk** | Unknown capacity — MD1400 is 12-bay 3.5" LFF, unknown drive population |
| **Current impact** | MD1400 storage is completely inaccessible — zero usable capacity from the shelf |
| **Downtime required** | Full cold boot of pve (all VMs, estimated 5-10 min total) |
| **Risk of fix** | Low — module config is additive, cold boot is standard procedure |
| **Risk of inaction** | Medium — purchased hardware sitting unused, unknown drive health degradation without monitoring |

---

## Upstream Bug

The PCI ID mismatch (`11f8` vs `117C`) is a known gap in the upstream Linux `pm80xx` driver. Microchip acquired PMC-Sierra and began shipping the same chip under their own vendor ID, but the kernel driver's PCI device table was never updated for all variants. This affects kernel 6.14.8-2-pve (Proxmox 9.1).

Consider reporting upstream or checking if newer kernels (6.15+) have the fix.

---

## Scheduling Note

iDRAC (`192.168.12.250`) is only reachable on the shop LAN. pve is the sole Tailscale node
on that subnet. Powering off pve kills the only remote path to iDRAC — no way to power back
on remotely. The Dell N2024P switch cannot run Tailscale (proprietary DNOS).

**After UDR install:** The Ubiquiti Dream Router runs UniFi OS (Linux-based) and can run
Tailscale as a subnet router. This provides a persistent Tailscale path to the shop LAN
independent of pve, enabling remote iDRAC access and remote cold boots going forward.

**Recommended:** Combine this cold boot with the UDR network cutover in a single on-site
maintenance window. Order of operations:
1. Install UDR, configure Tailscale subnet routing
2. Verify iDRAC reachable via UDR Tailscale path
3. Cold boot pve (now recoverable remotely if anything goes wrong)
4. Validate MD1400 drives, assess ZFS pool options

---

## Related

- **GAP-OP-029**: PM8072 PCI vendor ID mismatch (this loop)
- **GAP-OP-030**: vzdump backup gap (5 VMs not backed up — fix during same window)
- **OL_SHOP_BASELINE_FINISH**: Parent audit that discovered the gap
- **SHOP_SERVER_SSOT.md**: Hardware documentation updated with findings
- **DHCP DNS cutover**: UDR install is a shared dependency

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_

---

## Audit Findings (2026-02-10 certification)

- Source: `mailroom/outbox/audit-export/2026-02-10-full-certification.md`
- Certification noted this loop is still open and remains a prerequisite for a complete shop storage baseline.
