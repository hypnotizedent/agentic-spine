---
status: authoritative
owner: "@ronny"
created: 2026-02-12
last_verified: 2026-02-13
scope: mint-fresh-slate-infra-bootstrap
authority: LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-PLAN-20260212
adr_alignment:
  - mint-modules/docs/DECISIONS/ADR-001-RUNTIME-BOUNDARY-FRESH-SLATE.md
  - mint-modules/docs/DECISIONS/ADR-002-DATA-PLANE-AND-INTEGRATION.md
  - mint-modules/docs/DECISIONS/ADR-003-SECRETS-PROJECT-MODEL.md
---

# Mint Fresh-Slate Infrastructure Bootstrap Runbook

> Executable plan for provisioning and deploying mint-modules on two new VMs with zero legacy runtime dependency.
> Follows VM Creation Contract (`docs/core/VM_CREATION_CONTRACT.md`) and spine-ready-v1 profile.
> All placeholder values marked with `PLACEHOLDER:` must be resolved during execution.

---

## 1. Target Model (Locked)

### VM Topology

| VM | VMID | Hostname | Role | LAN IP | Profile | Resources |
|----|------|----------|------|--------|---------|-----------|
| mint-data | 212 | mint-data | data-plane | 192.168.1.212 | spine-ready-v1 | 4c / 8GB / 50GB |
| mint-apps | 213 | mint-apps | app-plane | 192.168.1.213 | spine-ready-v1 | 4c / 8GB / 50GB |

> **Resource note:** pve has 192GB RAM, currently ~216GB allocated across 9 VMs (overcommitted with balloon/KSM). Adding 16GB total for these two VMs brings allocation to ~232GB. This is within the overcommit tolerance given docker-host (96GB) will shed artwork-module + quote-page workloads post-cutover. If needed, docker-host can be downsized to 64GB after legacy detach, reclaiming 32GB.

### Services Placement

**mint-data (VM 212):**

| Service | Container Name | Port | Image | Purpose |
|---------|---------------|------|-------|---------|
| PostgreSQL 16 | mint-modules-postgres | 5432 | postgres:16-alpine | New `mint_modules` database (empty start, ADR-002) |
| MinIO | mint-modules-minio | 9000 (API), 9001 (console) | minio/minio:latest | Object storage for artwork-intake bucket |
| Redis | mint-modules-redis | 6379 | redis:7-alpine | Session/cache store (if needed by modules) |

**mint-apps (VM 213):**

| Service | Container Name | Port | Image | Purpose |
|---------|---------------|------|-------|---------|
| Artwork (files-api) | files-api | 3500 | mint-modules/artwork:latest | Seeds intake, asset management, presigned URLs |
| Quote Page | quote-page | 3341 | mint-modules/quote-page:latest | Customer intake form |
| Order Intake | order-intake | 3400 | mint-modules/order-intake:latest | Order processing API |

### Network Model

| Network | Location | Purpose | Members |
|---------|----------|---------|---------|
| `mint-data-network` | mint-data VM | Internal DB+storage access | mint-modules-postgres, mint-modules-minio, mint-modules-redis |
| `mint-apps-network` | mint-apps VM | Inter-module communication | files-api, quote-page, order-intake |

> **Cross-VM connectivity:** App containers on mint-apps connect to data services on mint-data via Tailscale IP (`PLACEHOLDER:MINT_DATA_TS_IP`) or LAN IP (192.168.1.212). No Docker network spans VMs. Environment variables point to mint-data's IP, not Docker DNS names.

### Database Schema

| Schema Owner | Tables (v1) | Access |
|-------------|-------------|--------|
| artwork | job_files, customer_artwork, pending_jobs | artwork writes; quote-page, order-intake read via API |
| order-intake | (TBD per module sprint) | order-intake writes only |

> **Start empty (ADR-002).** No legacy data migration. Legacy `mint_os` DB on docker-host remains available for historical reference. Modules get a fresh `mint_modules` database.

### Secrets Model (ADR-003)

| Infisical Project | Scope | Key Examples |
|-------------------|-------|--------------|
| `mint-shared-infra` | Data plane creds | POSTGRES_PASSWORD, MINIO_ROOT_USER, MINIO_ROOT_PASSWORD |
| `mint-artwork` | Module-specific | DATABASE_URL, API_KEY, PRESIGNED_UPLOAD_EXPIRY |
| `mint-quote-page` | Module-specific | MINIO_ACCESS_KEY, FILES_API_URL |
| `mint-order-intake` | Module-specific | API_KEY, FILES_API_URL |

> **Implementation:** Create four new Infisical projects during execution. Populate keys before first deployment. No new keys in legacy `mint-os-api` project.

---

## 2. Preflight Checklist

Run before any execution begins:

- [ ] **1.** `./bin/ops cap run spine.verify` — ALL PASS
- [ ] **2.** `./bin/ops cap run gaps.status` — No fresh-slate related gaps open
- [ ] **3.** Confirm template VM 9000 exists: `qm config 9000` on pve
- [ ] **4.** Confirm VMID 212 and 213 are free: `qm status 212` and `qm status 213` (should fail/not found)
- [ ] **5.** Confirm LAN IPs .212 and .213 are unassigned: `ping -c1 192.168.1.212` and `.213` (should fail)
- [ ] **6.** Confirm SSH key available: `~/.ssh/id_ed25519.pub` exists
- [ ] **7.** Confirm Tailscale auth key available: `infisical secrets get TAILSCALE_AUTH_KEY --path /spine/vm-infra/provisioning`
- [ ] **8.** Confirm pve has disk space: `pvesm status` (local-lvm needs ~100GB free for both VMs)
- [ ] **9.** Confirm fresh-slate ADRs are accepted: `cat ~/code/mint-modules/docs/DECISIONS/ADR-001*.md | head -3` (status: accepted)
- [ ] **10.** Open execution loop: `LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-<DATE>`

---

## 3. Phase 1: PLAN — Reserve VMIDs and Register Intent

### 3.1 Create execution loop scope

```bash
# In agentic-spine
cat > mailroom/state/loop-scopes/LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-<DATE>.scope.md <<'EOF'
---
loop_id: LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-<DATE>
status: open
owner: "@ronny"
created: <DATE>
---
# Mint Fresh-Slate Infra Bootstrap
Provision mint-data (VM 212) and mint-apps (VM 213) per this runbook.
EOF
```

### 3.2 Reserve VMIDs in vm.lifecycle.yaml

Add two entries with `status: planning`:

```yaml
# mint-data (data plane)
- vmid: 212
  hostname: mint-data
  proxmox_host: pve
  role: mint-data-plane
  owner: "@ronny"
  status: planning
  created_at: "<DATE>"
  profile: spine-ready-v1
  lan_ip: 192.168.1.212
  tailscale_ip: null  # assigned during bootstrap
  ssh_target: mint-data
  ssh_user: ubuntu
  os: ubuntu-24.04
  resources:
    cpu_cores: 4
    memory_mb: 8192
    boot_disk_gb: 50
  stacks:
    - mint-data
  services:
    - mint-modules-postgres
    - mint-modules-minio
    - mint-modules-redis
  backup_target: vm-212-mint-data-primary
  health_probe_policy: full
  decommission_policy: requires_final_backup
  notes: "Mint fresh-slate data plane. PostgreSQL 16 + MinIO + Redis."

# mint-apps (app plane)
- vmid: 213
  hostname: mint-apps
  proxmox_host: pve
  role: mint-app-plane
  owner: "@ronny"
  status: planning
  created_at: "<DATE>"
  profile: spine-ready-v1
  lan_ip: 192.168.1.213
  tailscale_ip: null  # assigned during bootstrap
  ssh_target: mint-apps
  ssh_user: ubuntu
  os: ubuntu-24.04
  resources:
    cpu_cores: 4
    memory_mb: 8192
    boot_disk_gb: 50
  stacks:
    - mint-apps
  services:
    - files-api
    - quote-page
    - order-intake
  backup_target: vm-213-mint-apps-primary
  health_probe_policy: full
  decommission_policy: requires_migration_first
  notes: "Mint fresh-slate app plane. Artwork + quote-page + order-intake."
```

### 3.3 Commit PLAN phase

```bash
git add ops/bindings/vm.lifecycle.yaml mailroom/state/loop-scopes/LOOP-*.scope.md
git commit -m "gov(LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-<DATE>): reserve VM 212 (mint-data) + VM 213 (mint-apps)"
```

---

## 4. Phase 2: PROVISION — Create VMs

### 4.1 Provision mint-data (VM 212)

Run on pve (via `ssh root@pve`):

```bash
# Clone from template
qm clone 9000 212 --name mint-data --full --storage local-lvm

# Set resources
qm set 212 --cores 4 --memory 8192 --balloon 0

# Configure cloud-init
qm set 212 --ciuser ubuntu \
  --sshkeys /root/.ssh/authorized_keys \
  --ipconfig0 ip=192.168.1.212/24,gw=192.168.1.1 \
  --nameserver 192.168.1.204 \
  --searchdomain tailnet

# Set boot-on-start
qm set 212 --onboot 1

# Start and wait for cloud-init
qm start 212
# Wait ~60s, then:
qm guest exec 212 --timeout 120 -- cloud-init status --wait
```

### 4.2 Provision mint-apps (VM 213)

```bash
# Clone from template
qm clone 9000 213 --name mint-apps --full --storage local-lvm

# Set resources
qm set 213 --cores 4 --memory 8192 --balloon 0

# Configure cloud-init
qm set 213 --ciuser ubuntu \
  --sshkeys /root/.ssh/authorized_keys \
  --ipconfig0 ip=192.168.1.213/24,gw=192.168.1.1 \
  --nameserver 192.168.1.204 \
  --searchdomain tailnet

# Set boot-on-start
qm set 213 --onboot 1

# Start and wait for cloud-init
qm start 213
qm guest exec 213 --timeout 120 -- cloud-init status --wait
```

### 4.3 Bootstrap packages on each VM

SSH to each VM and run:

```bash
# Add Docker apt repo
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Add Tailscale apt repo
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Install all packages
sudo NEEDRESTART_SUSPEND=1 apt-get update
sudo NEEDRESTART_SUSPEND=1 apt-get install -y qemu-guest-agent tailscale docker-ce docker-ce-cli containerd.io docker-compose-plugin cron

# Enable services
sudo systemctl enable --now qemu-guest-agent
sudo systemctl enable --now docker
sudo systemctl enable --now cron

# Tailscale up (use auth key from Infisical)
sudo tailscale up --auth-key=PLACEHOLDER:TAILSCALE_AUTH_KEY
```

### 4.4 Record Tailscale IPs

After `tailscale up` on each VM:

```bash
tailscale ip -4  # Record this as MINT_DATA_TS_IP / MINT_APPS_TS_IP
```

### 4.5 Provision rollback

If anything fails:

```bash
# On pve:
qm stop 212 && qm destroy 212 --purge
qm stop 213 && qm destroy 213 --purge
# Revert vm.lifecycle.yaml entries to status: abandoned
```

---

## 5. Phase 3: REGISTER — Update All SSOTs

### 5.1 Binding Impact Matrix

Every file below MUST be updated before running spine.verify. Order matters to minimize drift.

| # | File | Action | What to Add/Change |
|---|------|--------|-------------------|
| 1 | `ops/bindings/vm.lifecycle.yaml` | modify | Update both entries: `status: registered`, set `tailscale_ip` |
| 2 | `ops/bindings/ssh.targets.yaml` | modify | Add two targets: `mint-data` and `mint-apps` |
| 3 | `ops/bindings/docker.compose.targets.yaml` | modify | Add two targets with stack paths |
| 4 | `docs/governance/DEVICE_IDENTITY_SSOT.md` | modify | Add two device rows |
| 5 | `docs/governance/SHOP_SERVER_SSOT.md` | modify | Add two VM inventory rows |
| 6 | `docs/governance/SERVICE_REGISTRY.yaml` | modify | Add section with 6 service entries (3 data + 3 app) |
| 7 | `docs/governance/STACK_REGISTRY.yaml` | modify | Add two stack entries (mint-data, mint-apps) |
| 8 | `ops/bindings/services.health.yaml` | modify | Add 5 health probes (postgres excluded — TCP-only) |
| 9 | `ops/bindings/backup.inventory.yaml` | modify | Add two backup targets |
| 10 | `ops/bindings/secrets.namespace.policy.yaml` | modify | Add shared-infra namespace path |

### 5.2 SSH Targets

```yaml
# In ssh.targets.yaml — add:
- id: mint-data
  host: "PLACEHOLDER:MINT_DATA_TS_IP"
  user: ubuntu
  notes: "Mint fresh-slate data plane VM 212 (PostgreSQL + MinIO + Redis)"
  tags: [mint, data, docker, shop]

- id: mint-apps
  host: "PLACEHOLDER:MINT_APPS_TS_IP"
  user: ubuntu
  notes: "Mint fresh-slate app plane VM 213 (artwork, quote-page, order-intake)"
  tags: [mint, apps, docker, shop]
```

### 5.3 Docker Compose Targets

```yaml
# In docker.compose.targets.yaml — add:
mint-data:
  ssh_target: mint-data
  connect_timeout_sec: 5
  enabled: true
  notes: "Mint data plane VM 212 (fresh-slate). PostgreSQL 16 + MinIO + Redis."
  stacks:
    - name: mint-data
      path: /opt/stacks/mint-data

mint-apps:
  ssh_target: mint-apps
  connect_timeout_sec: 5
  enabled: true
  notes: "Mint app plane VM 213 (fresh-slate). Artwork + quote-page + order-intake."
  stacks:
    - name: mint-apps
      path: /opt/stacks/mint-apps
```

### 5.4 Service Registry Entries

```yaml
# In SERVICE_REGISTRY.yaml — add section:

# ─── Mint Fresh-Slate: Data Plane (VM 212) ──────────────────────────
mint-modules-postgres:
  host: mint-data
  port: 5432
  health: null  # TCP-only, Docker HEALTHCHECK authoritative
  compose: /opt/stacks/mint-data/docker-compose.yml
  container: mint-modules-postgres
  status: active
  notes: "PostgreSQL 16 for mint_modules DB. Fresh-slate (ADR-002)."

mint-modules-minio:
  host: mint-data
  port: 9000
  health: /minio/health/live
  compose: /opt/stacks/mint-data/docker-compose.yml
  container: mint-modules-minio
  status: active
  notes: "MinIO for mint-modules object storage. Fresh-slate (ADR-001)."

mint-modules-redis:
  host: mint-data
  port: 6379
  health: null  # TCP-only
  compose: /opt/stacks/mint-data/docker-compose.yml
  container: mint-modules-redis
  status: active
  notes: "Redis for mint-modules session/cache. Fresh-slate."

# ─── Mint Fresh-Slate: App Plane (VM 213) ───────────────────────────
# Note: files-api, quote-page entries already exist under docker-host.
# After cutover validation, UPDATE existing entries to point to mint-apps.
# Until then, both sets can coexist (old=disabled, new=active).
files-api-v2:
  host: mint-apps
  port: 3500
  health: /health
  source: mint-modules/artwork
  compose: /opt/stacks/mint-apps/docker-compose.yml
  container: files-api
  status: active
  notes: "Artwork API on fresh-slate mint-apps VM 213 (ADR-001)."

quote-page-v2:
  host: mint-apps
  port: 3341
  health: /health
  source: mint-modules/quote-page
  compose: /opt/stacks/mint-apps/docker-compose.yml
  container: quote-page
  status: active
  public_url: https://customer.mintprints.co
  notes: "Quote intake on fresh-slate mint-apps VM 213 (ADR-001)."

order-intake-v2:
  host: mint-apps
  port: 3400
  health: /health
  source: mint-modules/order-intake
  compose: /opt/stacks/mint-apps/docker-compose.yml
  container: order-intake
  status: active
  notes: "Order intake API on fresh-slate mint-apps VM 213 (ADR-001)."
```

### 5.5 Health Probes

```yaml
# In services.health.yaml — add:

# ─── Mint Fresh-Slate: Data Plane (VM 212) ────────────────────────────
- id: mint-modules-minio
  host: mint-data
  url: "http://PLACEHOLDER:MINT_DATA_TS_IP:9000/minio/health/live"
  expect: 200
  enabled: true
  notes: "MinIO on mint-data VM 212 (fresh-slate)"

# ─── Mint Fresh-Slate: App Plane (VM 213) ─────────────────────────────
- id: files-api-v2
  host: mint-apps
  url: "http://PLACEHOLDER:MINT_APPS_TS_IP:3500/health"
  expect: 200
  enabled: true
  notes: "Artwork files-api on mint-apps VM 213 (fresh-slate)"

- id: quote-page-v2
  host: mint-apps
  url: "http://PLACEHOLDER:MINT_APPS_TS_IP:3341/health"
  expect: 200
  enabled: true
  notes: "Quote page on mint-apps VM 213 (fresh-slate)"

- id: order-intake-v2
  host: mint-apps
  url: "http://PLACEHOLDER:MINT_APPS_TS_IP:3400/health"
  expect: 200
  enabled: true
  notes: "Order intake on mint-apps VM 213 (fresh-slate)"
```

### 5.6 Backup Inventory

```yaml
# In backup.inventory.yaml — add:
- name: vm-212-mint-data-primary
  enabled: true
  kind: file_glob
  host: pve
  base_path: "/tank/backups/vzdump/dump"
  glob: "vzdump-qemu-212-*.vma.zst"
  stale_after_hours: 26
  classification: critical
  notes: "Mint data plane (fresh-slate). PostgreSQL + MinIO."

- name: vm-213-mint-apps-primary
  enabled: true
  kind: file_glob
  host: pve
  base_path: "/tank/backups/vzdump/dump"
  glob: "vzdump-qemu-213-*.vma.zst"
  stale_after_hours: 26
  classification: important
  notes: "Mint app plane (fresh-slate). Stateless modules."
```

### 5.7 Secrets Namespace Update

```yaml
# In secrets.namespace.policy.yaml — add to module_namespaces:
mint-shared-infra: "/spine/services/mint-shared-infra"

# Add to required_key_paths:
MINT_MODULES_POSTGRES_PASSWORD: "/spine/services/mint-shared-infra"
MINT_MODULES_MINIO_ROOT_USER: "/spine/services/mint-shared-infra"
MINT_MODULES_MINIO_ROOT_PASSWORD: "/spine/services/mint-shared-infra"
```

### 5.8 Commit REGISTER phase

Use mailroom proposals or direct commit per governance rules. Submit all SSOT changes as a single proposal.

---

## 6. Phase 4: VALIDATE

### 6.1 Connectivity Checks

```bash
# SSH reachability
ssh mint-data hostname     # expect: mint-data
ssh mint-apps hostname     # expect: mint-apps

# Tailscale
ssh mint-data tailscale status --self  # expect: connected
ssh mint-apps tailscale status --self  # expect: connected

# QEMU agent
qm agent 212 ping   # on pve
qm agent 213 ping   # on pve

# Docker
ssh mint-data docker ps    # expect: postgres, minio, redis running
ssh mint-apps docker ps    # expect: files-api, quote-page, order-intake running
```

### 6.2 Service Health

```bash
# Data plane
curl -f http://PLACEHOLDER:MINT_DATA_TS_IP:9000/minio/health/live   # 200
ssh mint-data 'docker exec mint-modules-postgres pg_isready'          # accepting connections

# App plane
curl -f http://PLACEHOLDER:MINT_APPS_TS_IP:3500/health   # 200 { status: "ok" }
curl -f http://PLACEHOLDER:MINT_APPS_TS_IP:3341/health   # 200 { status: "ok" }
curl -f http://PLACEHOLDER:MINT_APPS_TS_IP:3400/health   # 200 { status: "ok" }
```

### 6.3 Spine Verification

```bash
./bin/ops cap run spine.verify            # ALL PASS (D69 must pass)
./bin/ops cap run services.health.status  # All new endpoints green
./bin/ops cap run docker.compose.status   # New stacks show ok
./bin/ops cap run backup.status           # New targets present
```

### 6.4 Transition to Active

Update `vm.lifecycle.yaml`: set `status: active` for both VMs.

---

## 7. Phase 5: DEPLOY — Compose Setup

### 7.1 mint-data Docker Compose

Deploy to `/opt/stacks/mint-data/docker-compose.yml` on VM 212:

```yaml
version: "3.8"

services:
  mint-modules-postgres:
    image: postgres:16-alpine
    container_name: mint-modules-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: mint_modules
      POSTGRES_USER: mint
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - mint-data-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mint -d mint_modules"]
      interval: 30s
      timeout: 10s
      start_period: 10s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  mint-modules-minio:
    image: minio/minio:latest
    container_name: mint-modules-minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - mint-data-network
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 30s
      timeout: 10s
      start_period: 10s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  mint-modules-redis:
    image: redis:7-alpine
    container_name: mint-modules-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    networks:
      - mint-data-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 5s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  postgres_data:
  minio_data:

networks:
  mint-data-network:
    driver: bridge
```

### 7.2 mint-apps Docker Compose

Deploy to `/opt/stacks/mint-apps/docker-compose.yml` on VM 213:

```yaml
version: "3.8"

services:
  files-api:
    image: mint-modules/artwork:${ARTWORK_TAG:-latest}
    container_name: files-api
    build:
      context: ./artwork
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - "3500:3500"
    environment:
      PORT: "3500"
      NODE_ENV: production
      DATABASE_URL: postgresql://mint:${POSTGRES_PASSWORD}@PLACEHOLDER:MINT_DATA_IP:5432/mint_modules
      MINIO_ENDPOINT: http://PLACEHOLDER:MINT_DATA_IP:9000
      MINIO_ACCESS_KEY: ${MINIO_ACCESS_KEY}
      MINIO_SECRET_KEY: ${MINIO_SECRET_KEY}
      MINIO_EXTERNAL_URL: https://files.ronny.works
      MINIO_BUCKET: artwork-intake
      API_KEY: ${FILES_API_KEY}
      PRESIGNED_UPLOAD_EXPIRY: "3600"
      PRESIGNED_DOWNLOAD_EXPIRY: "3600"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3500/health"]
      interval: 30s
      timeout: 10s
      start_period: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
    labels:
      com.ronny.module: files-api
      com.ronny.tier: api
      com.ronny.env: production
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  quote-page:
    image: mint-modules/quote-page:${QUOTE_PAGE_TAG:-latest}
    container_name: quote-page
    build:
      context: ./quote-page
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - "3341:3341"
    environment:
      PORT: "3341"
      NODE_ENV: production
      FILES_API_URL: http://files-api:3500
      MINIO_ENDPOINT: http://PLACEHOLDER:MINT_DATA_IP:9000
      MINIO_ACCESS_KEY: ${MINIO_ACCESS_KEY}
      MINIO_SECRET_KEY: ${MINIO_SECRET_KEY}
      MINIO_BUCKET: artwork-intake
    depends_on:
      files-api:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3341/health"]
      interval: 30s
      timeout: 10s
      start_period: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
        reservations:
          cpus: "0.25"
          memory: 128M
    labels:
      com.ronny.module: quote-page
      com.ronny.tier: web
      com.ronny.env: production
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  order-intake:
    image: mint-modules/order-intake:${ORDER_INTAKE_TAG:-latest}
    container_name: order-intake
    build:
      context: ./order-intake
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - "3400:3400"
    environment:
      PORT: "3400"
      NODE_ENV: production
      FILES_API_URL: http://files-api:3500
      API_KEY: ${ORDER_INTAKE_API_KEY}
    depends_on:
      files-api:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3400/health"]
      interval: 30s
      timeout: 10s
      start_period: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
        reservations:
          cpus: "0.25"
          memory: 128M
    labels:
      com.ronny.module: order-intake
      com.ronny.tier: api
      com.ronny.env: production
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

### 7.3 Create MinIO Bucket

After mint-data compose is up:

```bash
ssh mint-data
docker exec -it mint-modules-minio mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
docker exec -it mint-modules-minio mc mb local/artwork-intake
```

### 7.4 Run Database Migrations

After mint-data compose is up, run artwork migrations from mint-apps:

```bash
ssh mint-apps
cd /opt/stacks/mint-apps
# Run migrations (artwork owns job_files, customer_artwork, pending_jobs)
docker exec files-api node dist/migrations/run.js  # or npm run migrate
```

---

## 8. Phase 6: CUTOVER — DNS and Routing

### 8.1 Update Cloudflare Tunnel

In `infra-core:/opt/stacks/cloudflared/config.yml`, update the ingress rule for `customer.mintprints.co`:

```yaml
# Change from:
- hostname: customer.mintprints.co
  service: http://100.92.156.118:3341   # docker-host

# To:
- hostname: customer.mintprints.co
  service: http://PLACEHOLDER:MINT_APPS_TS_IP:3341  # mint-apps VM 213
```

Restart cloudflared: `docker compose restart cloudflared`

### 8.2 Disable Legacy Probes

In `services.health.yaml`, disable the old docker-host entries:

```yaml
# Set enabled: false for:
- id: files-api       # docker-host version
- id: quote-page      # docker-host version
```

### 8.3 Remove from docker-host compose targets

In `docker.compose.targets.yaml`, remove artwork-module and quote-page from docker-host stacks list.

### 8.4 Update SERVICE_REGISTRY

Rename `files-api-v2` → `files-api`, `quote-page-v2` → `quote-page`, `order-intake-v2` → `order-intake`. Remove old docker-host entries.

---

## 9. E2E Smoke Test

After cutover:

- [ ] `POST http://PLACEHOLDER:MINT_APPS_TS_IP:3500/api/v1/seeds` — creates seed
- [ ] `POST http://PLACEHOLDER:MINT_APPS_TS_IP:3500/api/v1/files/upload/prepare` — returns presigned URL
- [ ] `curl <presigned-url> --upload-file test.png` — uploads to MinIO on mint-data
- [ ] `POST http://PLACEHOLDER:MINT_APPS_TS_IP:3500/api/v1/files/upload/confirm` — confirms upload
- [ ] `GET http://PLACEHOLDER:MINT_APPS_TS_IP:3341/health` — quote-page healthy with minio + files-api checks green
- [ ] `https://customer.mintprints.co` — loads through Cloudflare tunnel
- [ ] `./bin/ops cap run spine.verify` — ALL PASS
- [ ] `./bin/ops cap run services.health.status` — all fresh-slate probes green, docker-host probes disabled

---

## 10. Legacy Detach Verification

After smoke tests pass, verify zero legacy runtime dependency:

- [ ] `ssh mint-apps 'docker inspect files-api --format={{.NetworkSettings.Networks}}'` — no `mint-os-network`
- [ ] `ssh mint-apps 'docker exec files-api env | grep DATABASE_URL'` — points to mint-data, not mint-os-postgres
- [ ] `ssh mint-apps 'docker exec files-api env | grep MINIO'` — points to mint-data, not docker-host
- [ ] No compose file references `mint-os-network` or `storage-network` (docker-host networks)
- [ ] docker-host artwork-module and quote-page containers can be stopped without affecting fresh-slate

---

## 11. Rollback Procedure

If any phase fails after cutover has begun:

### Quick Rollback (within 1 hour of cutover)

1. Revert Cloudflare tunnel ingress to docker-host IPs
2. Restart cloudflared
3. Re-enable docker-host health probes
4. Verify docker-host modules are still running (`docker ps` on docker-host)

### Full Rollback

1. Quick rollback steps above
2. Revert all SSOT changes (git revert the REGISTER commit)
3. Stop mint-data and mint-apps VMs (`qm stop 212 213`)
4. Destroy VMs if needed (`qm destroy 212 --purge && qm destroy 213 --purge`)
5. Update vm.lifecycle.yaml entries to `abandoned`
6. Run `spine.verify` to confirm clean state

---

## 12. Definition of Done

All of the following must be true for the infra bootstrap execution loop to close:

- [ ] **D1:** VM 212 (mint-data) is `status: active` in vm.lifecycle.yaml
- [ ] **D2:** VM 213 (mint-apps) is `status: active` in vm.lifecycle.yaml
- [ ] **D3:** All 10 SSOT files updated per binding impact matrix (section 5.1)
- [ ] **D4:** `spine.verify` ALL PASS (including D69 VM creation governance)
- [ ] **D5:** `services.health.status` shows all fresh-slate probes green
- [ ] **D6:** `docker.compose.status` shows both mint-data and mint-apps stacks ok
- [ ] **D7:** `backup.status` shows both VM backup targets present
- [ ] **D8:** E2E smoke test passes (section 9, all items checked)
- [ ] **D9:** Legacy detach verified (section 10, all items checked)
- [ ] **D10:** Cloudflare tunnel routes `customer.mintprints.co` to mint-apps VM
- [ ] **D11:** Old docker-host health probes disabled
- [ ] **D12:** All Infisical projects created and populated (ADR-003)
- [ ] **D13:** Execution loop closed with receipt evidence

---

## Appendix A: Execution Loop Sequence

The master plan defines four execution loops (run in order):

1. **LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP** — This runbook (VMs + data services)
2. **LOOP-MINT-FRESH-SLATE-APP-BOOTSTRAP** — Deploy modules to mint-apps
3. **LOOP-MINT-FRESH-SLATE-CUTOVER** — DNS routing + Cloudflare + public traffic
4. **LOOP-MINT-LEGACY-DETACH-VERIFY** — Confirm zero legacy dependency + decommission docker-host module stacks

> Loops 1-3 can be compressed into a single execution session if time permits. Loop 4 must be separate (requires soak period).

## Appendix B: Resource Summary

| Resource | Current (pre-fresh-slate) | After Fresh-Slate | Delta |
|----------|--------------------------|-------------------|-------|
| VMs (shop) | 9 active | 11 active | +2 |
| RAM allocated | ~216 GB | ~232 GB | +16 GB |
| Disk (local-lvm) | varies | +100 GB | +100 GB |
| Health probes | 32 | 36 | +4 |
| Backup targets | 9 | 11 | +2 |
| Infisical projects | existing | +4 new | +4 |
