---
status: authoritative
owner: "@ronny"
created: 2026-02-07
last_verified: 2026-02-13
scope: infra-relocation-phase4
prerequisite: Phase 2 (Vaultwarden) promoted to migrated
---

# Phase 4: Observability VM (205) — Execute Runbook

> Strict command-order runbook for provisioning VM 205 and deploying
> Prometheus, Grafana, Loki, and Uptime Kuma.
>
> **Gate-first**: every mutating step is preceded by a dry-run and
> followed by a verification gate. Stop on any failure.

---

## Prerequisites (must be true before starting)

```bash
# All must pass
./bin/ops cap run infra.relocation.promote --service vaultwarden \
  --tunnel-url https://vault.ronny.works \
  --health-url http://100.92.91.128:8081/alive \
  --rollback-host 100.93.142.63 --rollback-port 8080 \
  --execute
# ^ Vaultwarden must be migrated before Phase 4 execute
```

| Check | Expected |
|-------|----------|
| Vaultwarden status | `migrated` |
| D35 parity | PASS |
| D37 placement lock | PASS |
| All drift gates | PASS |
| DHCP DNS task | Open (independent, not a blocker) |

---

## Step 1: Provision VM 205

```bash
cd /Users/ronnyworks/code/agentic-spine

# Dry-run first
echo "yes" | ./bin/ops cap run infra.vm.provision \
  --target observability --profile spine-ready-v1 --vm-id 205 --dry-run
```

**STOP if dry-run shows errors.** Expected output: clone from template 9000,
4 cores, 8GB RAM, 50GB disk.

```bash
# Execute
echo "yes" | ./bin/ops cap run infra.vm.provision \
  --target observability --profile spine-ready-v1 --vm-id 205 --execute
```

**Wait for VM to boot** (~60-90s). Verify it's running:

```bash
ssh root@pve 'qm status 205'
# Expected: status: running
```

---

## Step 2: Get Tailscale IP + Add SSH target

After provisioning, the VM needs Tailscale. Bootstrap handles this, but
we need the Tailscale IP first for SSH targets.

```bash
# Get the VM's DHCP IP from Proxmox (guest agent)
ssh root@pve 'qm guest cmd 205 network-get-interfaces' | python3 -c "
import sys, json
data = json.load(sys.stdin)
for iface in data:
    if iface['name'] != 'lo':
        for addr in iface.get('ip-addresses', []):
            if addr['ip-address-type'] == 'ipv4':
                print(f\"{iface['name']}: {addr['ip-address']}\")
"
```

**Add SSH target to `ops/bindings/ssh.targets.yaml`:**

```yaml
    - id: "observability"
      host: "<TAILSCALE_IP>"  # Fill after tailscale up
      user: "ubuntu"
      notes: "Observability VM (VM 205)"
      tags: ["monitoring", "observability", "shop"]
```

Also add to `ops/bindings/backup.inventory.yaml`:

```yaml
  - name: vm-205-observability-primary
    enabled: true
    kind: file_glob
    host: pve
    base_path: "/tank/backups/vzdump/dump"
    glob: "vzdump-qemu-205-*.vma.zst"
    stale_after_hours: 26
    classification: important
```

---

## Step 3: Bootstrap VM 205

```bash
# Dry-run
echo "yes" | ./bin/ops cap run infra.vm.bootstrap \
  --target observability --profile spine-ready-v1 --vm-id 205 --dry-run

# Execute
echo "yes" | ./bin/ops cap run infra.vm.bootstrap \
  --target observability --profile spine-ready-v1 --vm-id 205 --execute
```

**STOP if bootstrap fails.** Common issues:
- Docker apt repo not found → bootstrap adds it
- Tailscale not connected → run `tailscale up` on the VM
- Port 53 conflict with systemd-resolved → add no-stub config (see infra-core pattern)

---

## Step 4: Readiness check

```bash
./bin/ops cap run infra.vm.ready.status --target observability
```

**All checks must be OK:**

| Check | Required |
|-------|----------|
| vm_running | OK |
| ssh_target_binding | OK |
| ssh_reachability | OK |
| tailscale_connected | OK |
| qemu_agent_running | OK |
| cron_running | OK |
| backup_binding | OK |

**STOP if any check fails.** Fix before proceeding.

---

## Step 5: Update relocation manifest

Update `ops/bindings/infra.relocation.plan.yaml`:

```bash
# Set observability VM target to ready with Tailscale IP
echo "yes" | ./bin/ops cap run infra.relocation.state.transition \
  --target observability --status ready --tailscale-ip <TAILSCALE_IP> --execute
```

---

## Step 6: Deploy observability stacks

Config files should already be staged at `/opt/stacks/` on observability.
See `ops/staged/observability/` for pre-built configs.

### 6a: Create stack directories

```bash
ssh ubuntu@observability 'sudo mkdir -p /opt/stacks/{prometheus,grafana,loki,uptime-kuma} && sudo chown -R ubuntu:ubuntu /opt/stacks'
```

### 6b: Transfer staged configs

```bash
scp -r ops/staged/observability/prometheus/* ubuntu@observability:/opt/stacks/prometheus/
scp -r ops/staged/observability/grafana/* ubuntu@observability:/opt/stacks/grafana/
scp -r ops/staged/observability/loki/* ubuntu@observability:/opt/stacks/loki/
scp -r ops/staged/observability/uptime-kuma/* ubuntu@observability:/opt/stacks/uptime-kuma/
```

### 6c: Start stacks (one at a time, verify each)

```bash
# Prometheus
ssh ubuntu@observability 'cd /opt/stacks/prometheus && sudo docker compose up -d'
curl -fsS http://<OBSERVABILITY_IP>:9090/-/healthy
# Expected: Prometheus Server is Healthy.

# Grafana
ssh ubuntu@observability 'cd /opt/stacks/grafana && sudo docker compose up -d'
curl -fsS -o /dev/null -w "%{http_code}" http://<OBSERVABILITY_IP>:3000/api/health
# Expected: 200

# Loki
ssh ubuntu@observability 'cd /opt/stacks/loki && sudo docker compose up -d'
curl -fsS http://<OBSERVABILITY_IP>:3100/ready
# Expected: ready

# Uptime Kuma (Phase 5 - can be deferred)
ssh ubuntu@observability 'cd /opt/stacks/uptime-kuma && sudo docker compose up -d'
curl -fsS -o /dev/null -w "%{http_code}" http://<OBSERVABILITY_IP>:3001
# Expected: 200
```

---

## Step 7: Update SSOTs

For each deployed service, update:

1. **`docs/governance/SERVICE_REGISTRY.yaml`** — add service entries with host: observability
2. **`ops/bindings/services.health.yaml`** — add health probe endpoints
3. **`ops/bindings/docker.compose.targets.yaml`** — add observability target with stack paths
4. **`docs/governance/DEVICE_IDENTITY_SSOT.md`** — add VM 205 to Tailscale device table

### Service transition (per service):

```bash
echo "yes" | ./bin/ops cap run infra.relocation.service.transition \
  --service prometheus --status shadow --execute
# Repeat for grafana, loki, uptime-kuma
```

After validation:

```bash
echo "yes" | ./bin/ops cap run infra.relocation.service.transition \
  --service prometheus --status cutover --execute
echo "yes" | ./bin/ops cap run infra.relocation.service.transition \
  --service prometheus --status migrated --execute
# Repeat for grafana, loki, uptime-kuma
```

---

## Step 8: Final gates

```bash
./bin/ops cap run infra.relocation.preflight
./bin/ops cap run infra.relocation.parity
./bin/ops cap run infra.placement.policy
./bin/ops cap run spine.verify
```

**All must pass.** If parity fails, check which SSOT is missing the new service entries.

---

## Rollback

Phase 4 services are new deployments (no `from_host`), so rollback = stop and remove:

```bash
ssh ubuntu@observability 'cd /opt/stacks/<service> && sudo docker compose down'
```

Then revert service status:

```bash
echo "yes" | ./bin/ops cap run infra.relocation.service.transition \
  --service <service> --status rolled-back --execute
```

---

## Stop conditions

Stop the runbook and investigate if:
- Any dry-run shows unexpected output
- VM 205 fails to boot or get Tailscale IP
- Bootstrap fails (package install, service start)
- Any readiness check fails
- Any health endpoint returns non-200
- D35 parity fails after SSOT updates
- Any drift gate fails

Do not proceed past a failure. Fix the issue, re-verify, then continue.
