---
checklist_id: EXEC-SURVEILLANCE-RUNTIME-20260304
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
status: ready
owner: "@ronny"
created: "2026-03-04"
authority: ops/bindings/surveillance.topology.contract.yaml
prerequisite_commit: ed821d8
verify_baseline: "20/20 fast, 35/35 loop_gap"
---

# Surveillance Runtime Execution Checklist

> Operator-driven. Each phase has exact commands, expected output, and a proof gate.
> Phases are sequential — do not skip ahead. If a phase fails, stop and record why.

---

## Phase 0 — Camera Outage Triage (physical, on-site)

**Clears:** STUB-camera-outage, LOOP-CAMERA-OUTAGE-20260209

### 0.1 PoE switch inspection

- [ ] Go to shop upstairs 9U rack
- [ ] Locate Netgear PoE switch (uplink to NVR PoE ports)
- [ ] Check power LED on switch — is it powered?
- [ ] Check per-port link/activity LEDs — how many ports show link?
- [ ] If switch is dead or unplugged, restore power and wait 2 minutes

### 0.2 NVR web UI check

- [ ] From a shop LAN workstation, open `http://192.168.1.216` in browser
- [ ] Log in with NVR credentials (Infisical: `infrastructure/prod:/spine/shop/nvr/*`)
- [ ] Check live view — how many channels show video?
- [ ] If browser says "plugin required", try Chrome or install the Hikvision web plugin

### 0.3 ISAPI re-query (can run remotely if PVE is reachable)

```bash
# From any machine on shop LAN or via SSH to PVE:
NVR_USER="<from infisical>"
NVR_PASS="<from infisical>"

# Channel detect — shows online/offline per channel
for ch in $(seq 1 12); do
  echo -n "ch${ch}: "
  curl -s --digest -u "${NVR_USER}:${NVR_PASS}" \
    "http://192.168.1.216/ISAPI/ContentMgmt/InputProxy/channels/${ch}/detect" \
    | grep -oP '<detectResult>\K[^<]+'
done
```

**Expected:** At least 8 channels show `connect`. Channels 2-4 may remain `notExist` (physical issue).

### 0.4 Proof gate

- [ ] Record count of online channels
- [ ] Update `docs/governance/CAMERA_SSOT.md` channel registry with new status
- [ ] If >= 4 channels online: **Phase 0 PASS** — proceed to Phase 1
- [ ] If 0 channels online: **STOP** — escalate to NVR hardware diagnosis

---

## Phase 1 — VM Provision on PVE

**Clears:** STUB-vm-provision

### 1.1 SSH to PVE

```bash
ssh root@100.96.211.33   # pve via Tailscale
```

If Tailscale is down, use shop LAN if physically present.

### 1.2 Clone template and configure

```bash
# Clone from ubuntu-2404-cloudinit-template
qm clone 9000 215 --name surveillance-stack --full

# Set resources (4 cores, 8GB RAM)
qm set 215 --cores 4 --memory 8192

# Verify boot disk is 50GB (template default)
qm config 215 | grep scsi0
```

### 1.3 Create and attach data disk

```bash
# Allocate 100GB ZFS zvol on tank
pvesm alloc tank vm-215-disk-1 100G

# Attach as virtio1
qm set 215 --virtio1 tank:vm-215-disk-1
```

### 1.4 Set network (static IP)

```bash
# Cloud-init IP config
qm set 215 --ipconfig0 ip=192.168.1.215/24,gw=192.168.1.1
qm set 215 --nameserver 192.168.1.1
```

### 1.5 Start VM

```bash
qm start 215

# Wait for cloud-init to complete (~60s), then test SSH
sleep 60
ssh ubuntu@192.168.1.215 'hostname && uptime'
```

**Expected:** `surveillance-stack` hostname, uptime shows seconds.

### 1.6 Proof gate

```bash
# From PVE:
qm status 215           # Expected: status: running
qm config 215 | grep -E 'cores|memory|scsi0|virtio1|ipconfig0'

# From your machine:
ssh ubuntu@192.168.1.215 'cat /etc/hostname && df -h / && lsblk'
```

- [ ] VM 215 is running
- [ ] SSH works at 192.168.1.215
- [ ] Boot disk ~ 50GB, data disk ~ 100GB visible in `lsblk`
- [ ] **Phase 1 PASS**

---

## Phase 2 — Storage Mount (non-boot proof)

**Clears:** STUB-storage-evidence

### 2.1 Format and mount data disk

```bash
ssh ubuntu@192.168.1.215 << 'REMOTE'
# Identify the data disk (should be /dev/vdb or similar)
lsblk

# Format (ONLY if not already formatted — check first!)
sudo mkfs.ext4 /dev/vdb

# Create mount point
sudo mkdir -p /mnt/data

# Mount
sudo mount /dev/vdb /mnt/data

# Add to fstab for persistence
echo '/dev/vdb /mnt/data ext4 defaults 0 2' | sudo tee -a /etc/fstab

# Create Frigate directory structure
sudo mkdir -p /mnt/data/frigate/{recordings,clips,snapshots}
sudo chown -R 1000:1000 /mnt/data/frigate
REMOTE
```

### 2.2 Proof gate

```bash
ssh ubuntu@192.168.1.215 'df -h /mnt/data && ls -la /mnt/data/frigate/'
```

**Expected output:**

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/vdb         98G   24K   93G   1% /mnt/data

total 20
drwxr-xr-x 5 1000 1000 4096 ... .
drwxr-xr-x 3 root root 4096 ... ..
drwxr-xr-x 2 1000 1000 4096 ... clips
drwxr-xr-x 2 1000 1000 4096 ... recordings
drwxr-xr-x 2 1000 1000 4096 ... snapshots
```

- [ ] `/mnt/data` is mounted on `/dev/vdb` (NOT `/dev/vda` / boot)
- [ ] `recordings/`, `clips/`, `snapshots/` directories exist
- [ ] Capacity >= 90GB available
- [ ] **Phase 2 PASS**

---

## Phase 3 — Tailscale Enrollment

### 3.1 Get auth key from Infisical

```bash
# From spine:
./bin/ops cap run secrets.get -- --project-id spine --env prod \
  --path /spine/vm-infra/provisioning --secret-name TAILSCALE_AUTH_KEY
```

### 3.2 Install and enroll

```bash
ssh ubuntu@192.168.1.215 << 'REMOTE'
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --auth-key="<AUTH_KEY>" --hostname=surveillance-stack
tailscale ip -4
REMOTE
```

### 3.3 Proof gate

```bash
# From your machine:
tailscale ping surveillance-stack
ssh ubuntu@<tailscale-ip> 'hostname'
```

- [ ] Tailscale IP assigned
- [ ] Ping succeeds from home network
- [ ] Update `ops/bindings/ssh.targets.yaml` with `tailscale_ip`
- [ ] Update `ops/bindings/vm.lifecycle.yaml` with `tailscale_ip`
- [ ] **Phase 3 PASS**

---

## Phase 4 — Docker + Frigate/go2rtc Bootstrap

### 4.1 Install Docker

```bash
ssh ubuntu@192.168.1.215 << 'REMOTE'
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
REMOTE

# Re-login to pick up docker group
ssh ubuntu@192.168.1.215 'docker --version && docker compose version'
```

### 4.2 Deploy surveillance stack

```bash
# Copy compose files from workbench to VM
scp -r ~/code/workbench/infra/compose/surveillance/ ubuntu@192.168.1.215:~/surveillance/

# Create .env with real credentials
ssh ubuntu@192.168.1.215 << 'REMOTE'
cd ~/surveillance

# Get NVR credentials from Infisical and create .env
# (substitute actual values from Infisical /spine/shop/nvr/*)
cat > .env << 'ENV'
NVR_ADMIN_USER=admin
NVR_ADMIN_PASSWORD=<FROM_INFISICAL>
ENV

docker compose up -d
REMOTE
```

### 4.3 Wait for startup and verify

```bash
# Wait 60s for Frigate to initialize
sleep 60

# Check containers
ssh ubuntu@192.168.1.215 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Check Frigate API
curl -s http://192.168.1.215:5000/api/version

# Check go2rtc API
curl -s http://192.168.1.215:1984/api/streams | python3 -m json.tool
```

### 4.4 Verify camera ingest

```bash
# Check Frigate stats — cameras should show fps > 0 for online channels
curl -s http://192.168.1.215:5000/api/stats | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Detector:', d.get('detectors', {}))
for cam, stats in d.get('cameras', {}).items():
    fps = stats.get('camera_fps', 0)
    det = stats.get('detection_fps', 0)
    pid = stats.get('pid', 0)
    print(f'  {cam}: camera_fps={fps} detection_fps={det} pid={pid}')
"
```

**Expected:** At least some cameras showing `camera_fps > 0`. Cameras on offline NVR channels will show 0.

### 4.5 Proof gate

- [ ] `frigate` container is `Up` and healthy
- [ ] `go2rtc` container is `Up` and healthy
- [ ] Frigate web UI accessible at `http://192.168.1.215:5000`
- [ ] At least 1 camera shows live feed in UI
- [ ] Detector type shows `cpu` (not GPU)
- [ ] Recordings are writing to `/mnt/data/frigate/recordings/` (check after ~5 min)
- [ ] **Phase 4 PASS**

---

## Phase 5 — Home HA Integration

**Clears:** STUB-ha-integration

### 5.1 Mosquitto broker

```bash
# Check if Mosquitto add-on is already installed in HA
curl -s -H "Authorization: Bearer ${HA_TOKEN}" \
  http://10.0.0.100:8123/api/hassio/addons | python3 -c "
import json, sys
addons = json.load(sys.stdin).get('data', {}).get('addons', [])
mqtt = [a for a in addons if 'mosquitto' in a.get('slug', '').lower()]
print('Mosquitto:', mqtt[0]['state'] if mqtt else 'NOT INSTALLED')
"
```

If not installed:
- [ ] In HA UI: Settings > Add-ons > Mosquitto broker > Install > Start

### 5.2 Configure Frigate MQTT

```bash
ssh ubuntu@192.168.1.215 << 'REMOTE'
cd ~/surveillance

# Edit frigate config to enable MQTT
# Uncomment the mqtt section in config/frigate.yml:
#   mqtt:
#     enabled: true
#     host: 10.0.0.100
#     port: 1883
#     topic_prefix: frigate
#     client_id: frigate-shop

# Then restart Frigate
docker compose restart frigate
REMOTE
```

### 5.3 Install Frigate integration in HA

- [ ] In HA: HACS > Integrations > search "Frigate" > Download
- [ ] Restart HA
- [ ] Settings > Devices & Services > Add Integration > Frigate
- [ ] Enter Frigate URL: `http://192.168.1.215:5000`

### 5.4 Verify events flow

```bash
# Check for Frigate entities in HA
curl -s -H "Authorization: Bearer ${HA_TOKEN}" \
  http://10.0.0.100:8123/api/states | python3 -c "
import json, sys
states = json.load(sys.stdin)
frigate = [s for s in states if 'frigate' in s['entity_id'].lower()]
print(f'Frigate entities: {len(frigate)}')
for e in frigate[:10]:
    print(f'  {e[\"entity_id\"]}: {e[\"state\"]}')
"
```

### 5.5 Baseline automation (optional, can defer)

Create a simple person-detection notification automation in HA:
- Trigger: `frigate.event` with `label: person`
- Condition: `time_after: 22:00` AND `time_before: 06:00`
- Action: Send notification via preferred channel

### 5.6 Proof gate

- [ ] Frigate integration shows as "Connected" in HA
- [ ] Camera entities appear in HA (e.g. `camera.front_drive`)
- [ ] At least one Frigate event visible in HA developer tools
- [ ] `ha.surveillance.status` capability reports `PASS` for `frigate_integration`
- [ ] **Phase 5 PASS**

---

## Phase 6 — Spine Governance Closure

### 6.1 Update lifecycle bindings

```bash
# Update vm.lifecycle.yaml: status planning -> active
# Update surveillance.topology.contract.yaml: vm_id, lan_ip, tailscale_ip, channels_online
# Update ssh.targets.yaml: tailscale_ip
# Update backup.inventory.yaml: enable backup target
```

### 6.2 Run capability checks

```bash
./bin/ops cap run surveillance.stack.status
./bin/ops cap run surveillance.event.query -- --limit 5
./bin/ops cap run ha.surveillance.status
```

All three should return real data (not BLOCKED/PENDING_SETUP).

### 6.3 Close stubs

For each cleared stub, update the frontmatter:

```yaml
status: cleared
cleared_at: "2026-XX-XX"
cleared_by: "@ronny"
```

### 6.4 Run verify

```bash
./bin/ops cap run verify.run -- fast
./bin/ops cap run verify.run -- domain loop_gap
./bin/ops cap run verify.run -- domain surveillance
```

### 6.5 Commit and update loop status

```bash
# Commit all binding updates
git add ops/bindings/ mailroom/state/orchestration/ docs/governance/CAMERA_SSOT.md
git commit -m "feat(surveillance): runtime closure — VM active, Frigate live, HA integrated"

# Update loop from planned -> closed (if all acceptance criteria met)
# T0-A: cameras live, T1-A: VM provisioned, T1-B: Frigate stable,
# T2-A: HA events, T2-C: capabilities callable, T3-A/B/C: docs committed
```

### 6.6 Final proof gate

- [ ] verify.run fast: 20/20 PASS
- [ ] verify.run domain loop_gap: 35/35 PASS
- [ ] D351: 10/10 PASS
- [ ] surveillance.stack.status: HEALTHY
- [ ] ha.surveillance.status: HEALTHY (not PENDING_SETUP)
- [ ] All 4 stubs marked `cleared`
- [ ] Loop status updated to `closed`
- [ ] **ALL PHASES COMPLETE**

---

## Quick Reference

| Item | Value |
|------|-------|
| **VM** | 215 / surveillance-stack / 192.168.1.215 |
| **NVR** | 192.168.1.216 (Hikvision ERI-K216-P16) |
| **Frigate UI** | http://192.168.1.215:5000 |
| **go2rtc UI** | http://192.168.1.215:1984 |
| **Home HA** | http://10.0.0.100:8123 |
| **NVR creds** | Infisical `infrastructure/prod:/spine/shop/nvr/*` |
| **TS auth key** | Infisical `/spine/vm-infra/provisioning/TAILSCALE_AUTH_KEY` |
| **Contract** | `ops/bindings/surveillance.topology.contract.yaml` |
| **Gate** | D351 surveillance-canonical-parity-lock |
| **Loop** | LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302 |
| **Workbench** | `workbench/infra/compose/surveillance/` |
