# Barudan DFS Architecture Report

**Loop**: LOOP-MINT-PRODUCTION-MACHINE-NETWORK-20260325
**Date**: 2026-03-25
**Machine**: BEKY-S1506CII (6 Head, 15 Needle, Serial: 3130544J20)
**Status**: Research complete — awaiting architecture decision

---

## 1. Can DFS Run on Linux?

**No. Windows VM required.**

- DFS (DesignFileServer.exe) officially supports Windows Vista/7/8/10 only. No macOS/Linux build exists.
- No evidence of anyone running DFS under Wine (WineHQ AppDB, forums, GitHub — all empty).
- DFS is a GUI-only application with watched-folder functionality. No headless/CLI mode.
- DFS uses COM/serial port access (for up to 8 machines) and TCP port 8000 (for LAN mode).
- DFS installer is not publicly downloadable — requires networking software request form from Barudan.

**Realistic Linux path**: Run DFS inside a lightweight Windows 10 VM on mint-apps with bridged NIC on the shop VLAN.

## 2. Is the DFS Protocol Documented?

**Setup documented. Wire format is not.**

### What IS documented (from DFS Protocol Setup Guide v1.53.01):
- **Port**: TCP 8000 (default, fixed for DFS). Alternate range: 49152-65535.
- **LAN mode**: Only **1 machine** per DFS LAN connection. Machine IP set via MSU1 Automat settings.
- **COM mode**: Up to 8 machines via null-modem serial (9-pin, 9600 baud).
- **Two operational modes**:
  - "Protocol Mode" — bidirectional: machine requests designs from DFS
  - "Free Download Mode" / "CF Drive Mode" — DFS pushes designs to machine CF card space
- **Machine firmware**: DS/DY/DX >= 3.20R00, DT >= 2.20R00

### What is NOT documented:
- Wire-level TCP byte format (handshake, framing, checksums, ACKs)
- No public packet captures, Wireshark dissectors, or protocol analyses
- No open-source implementations anywhere (GitHub exhaustively searched)

### Serial protocol details (from MakerFX Wiki):
- Baud: 9600 or 38400, 8N1
- Proprietary "Embroidery Machine" handshake

## 3. Alternative Protocols

### Does the BEKY-S1506CII support standard protocols?

| Protocol | Supported? |
|----------|-----------|
| SMB/CIFS | No |
| FTP | No |
| HTTP | No |
| NFS | No |
| USB mass storage | Yes (.TFD folder structure) |
| CompactFlash | Yes |
| DFS (TCP:8000) | Yes (proprietary) |
| Serial COM | Yes (proprietary) |

**The machine speaks Barudan's proprietary protocol only.** No standard network file sharing.

### DFS vs B-NET Pro vs LEM

| Feature | DFS | B-NET Pro | LEM Workgroup 10 |
|---------|-----|-----------|-------------------|
| Max machines | 9 (8 COM + 1 LAN) | 100+ (all LAN) | ~10 (LAN) |
| Monitoring | None | Real-time dashboards | Basic |
| API | None | API integration | Unknown |
| D-series support | Yes | Not listed | Unknown |
| Cost | Included/free | Enterprise pricing | Mid-tier |

### Third-party options
- **Wilcom EmbroideryConnect**: WiFi USB dongle + hub PC. Third-party hardware, not a software protocol.
- **No open-source DFS server exists anywhere.**

## 4. Packet Capture Feasibility

**Yes — straightforward with tcpdump.**

### Approach:
1. Run DFS on a Windows VM with bridged NIC on shop VLAN
2. `tcpdump -i br0 -w dfs-capture.pcap port 8000` on the VM host
3. Trigger transfers in both "Protocol Mode" (pull) and "Free Download Mode" (push)
4. Analyze TCP conversation for handshake, framing, file data boundaries

### What to look for:
- Connection direction (who initiates?)
- Authentication/identification exchange
- Design request format (how does machine specify which file?)
- File framing (headers, length prefixes, checksums)
- ACK/NACK handling

### Assessment:
Given that the payload is known (DST/U01 stitch data) and the port is fixed (8000), the protocol is likely simple enough to reverse-engineer from a handful of captures.

## 5. File Format Summary

### DST (Data Stitch Tajima)
- De facto universal standard (~85% of commercial machines accept DST)
- 512-byte fixed header (ASCII metadata: label, stitch count, color count, extents)
- Body: 3-byte stitch commands (X/Y movement + control bits)
- Max stitch length: 121 units per command
- Limitation: No thread color info, only color-change markers

### U01 (Barudan Native)
- Part A header: 128 bytes of `0x30` padding
- Part B header: 128+ bytes with boundary coords, stitch count, final position
- Body (offset 0x100): 3-byte triplets — Control, X, Y
- Key advantage: **NEEDLE_SET** commands (explicitly specify needle 1-9) vs DST's abstract color changes
- Maps directly to physical needle bar positions

### Open-source format libraries:
- **pyembroidery** (Python) — reads/writes DST, U01
- **libembroidery** (C) — 45+ formats, zlib license

## 6. Architecture Options Assessment

### Option A: Windows VM + DFS + Watched Folder

```
MinIO (mint-data:212) --> sync/mount --> DFS watched folder (Windows VM on mint-apps:213) --> TCP:8000 --> Barudan
```

**Pros**: Uses official Barudan software. Known to work. No protocol reverse-engineering.
**Cons**: Requires Windows VM. GUI-only software. Single LAN connection limit.
**Complexity**: Medium. Need Windows 10 VM, DFS installer, bridged NIC, MinIO-to-folder sync.

### Option B: Native Protocol Server (Future, requires reverse-engineering)

```
MinIO (mint-data:212) --> native DFS server (mint-apps:213) --> TCP:8000 --> Barudan
```

**Pros**: No Windows dependency. Full control. Can serve from MinIO directly.
**Cons**: Protocol must be reverse-engineered first. Unknown complexity.
**Complexity**: High initially, low ongoing. Requires packet captures + analysis.

### Option C: USB Sneakernet Pipeline (Simplest, no networking)

```
MinIO (mint-data:212) --> export bundle --> operator copies to USB --> physical walk to machine
```

**Pros**: Already partially built (package.export authority). No protocol work needed. Most reliable.
**Cons**: Manual operator step. Not automated last-mile.
**Complexity**: Low. Existing export authority covers this path.

### Option D: Hybrid (Recommended strategy)

1. **Immediate (v1)**: Option C — USB sneakernet. Already governed by existing export authority.
2. **Near-term**: Option A — Windows VM + DFS. Automates last-mile delivery.
3. **Long-term**: Option B — If packet capture reveals a simple protocol, build native server.

## 7. Recommendations

1. **Do not block on DFS.** The existing `mint.production.package.export` authority already supports `shared_folder` export mode. The operator USB path works today.

2. **Request DFS installer** from Barudan via their networking software request form.

3. **When DFS arrives**, install on a Windows 10 VM on mint-apps, capture the TCP:8000 protocol with tcpdump, and evaluate whether a native server is feasible.

4. **Design the delivery binding** to be transport-agnostic: it should define the contract between "staged export bundle" and "machine receives design" without hardcoding DFS, USB, or any specific transport.

---

## Sources

- DFS Protocol Setup Guide v1.53.01 (shopbarudan.com)
- DFS Instruction Manual v1.50.00 (shopbarudan.com)
- Barudan Networking Software Request (barudanamerica.com)
- MakerFX Wiki — Barudan BENT-ZQ-201U
- EduTech Wiki — Embroidery format DST
- EduTech Wiki — Embroidery format U??
- pyembroidery (GitHub EmbroidePy)
- libembroidery (GitHub Embroidermodder)
