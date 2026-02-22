---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ronny-ops-proxmox-baseline-cert
---

# Ronny-Ops/Proxmox Baseline Certification (2026-02-17)

Parent context: `LOOP-WORKBENCH-AOF-HARDENING-V2-20260217`.

## Summary

- VM authority parity: `PASS` (spine `vm.lifecycle` matches workbench `CONTAINER_INVENTORY`).
- SSH authority parity: `PASS` on effective `host|user` tuples.
- Legacy runtime authority check: `PASS` (`/Users/ronnyworks/ronny-ops` not referenced as active runtime authority in spine/workbench active surfaces).
- Residual mentions: compatibility/archive references only.

## Check 1: VM Authority Parity

### Command

```bash
python3 - <<'PY'
import yaml
spine='/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.yaml'
wb='/Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml'
with open(spine) as f:
    s=yaml.safe_load(f)
with open(wb) as f:
    w=yaml.safe_load(f)
sp={}
for vm in s.get('vms',[]):
    if vm.get('status')!='active':
        continue
    if vm.get('provider')!='proxmox':
        continue
    sp[int(vm['id'])]=vm.get('name','')
wbm={}
for vm in w.get('vms',[]):
    if vm.get('status')!='active':
        continue
    if vm.get('provider')!='proxmox':
        continue
    wbm[int(vm['id'])]=vm.get('name','')
for vid in sorted(sp):
    print(f"{vid}:{sp[vid]}")
PY
```

### Spine extract

```text
200:docker-host
202:automation-stack
203:immich
204:infra-core
205:observability
206:dev-tools
207:ai-consolidation
209:download-stack
210:streaming-stack
211:finance-stack
212:mint-data
213:mint-apps
```

### Workbench extract

```text
200:docker-host
202:automation-stack
203:immich
204:infra-core
205:observability
206:dev-tools
207:ai-consolidation
209:download-stack
210:streaming-stack
211:finance-stack
212:mint-data
213:mint-apps
```

### Diff

```text
(no diff)
```

## Check 2: SSH Target Parity

### Alias parity note

A raw alias compare showed one non-runtime alias variance (`beelink` alias present in workbench tailscale config while spine tracks the canonical proxmox host aliasing differently).

### Effective authority comparison (host/user)

### Command

```bash
python3 - <<'PY'
import yaml,re
sp='/Users/ronnyworks/code/agentic-spine/ops/bindings/ssh.targets.yaml'
wb='/Users/ronnyworks/code/workbench/dotfiles/ssh/config.d/tailscale.conf'
s=yaml.safe_load(open(sp))
pairs=set()
for t in s.get('targets',[]):
    h=t.get('host')
    u=t.get('user')
    if h and u:
        pairs.add((str(h),str(u)))
for h,u in sorted(pairs):
    print(f"{h}|{u}")
print("---")
hosts=[]; host=user=None
for raw in open(wb):
    line=raw.strip()
    if not line or line.startswith('#'):
        continue
    m=re.match(r'Host\s+(.+)',line,re.I)
    if m:
        if hosts and host and user:
            for alias in hosts:
                print(f"{host}|{user}")
        hosts=m.group(1).split(); host=user=None; continue
    m=re.match(r'HostName\s+(.+)',line,re.I)
    if m:
        host=m.group(1).strip(); continue
    m=re.match(r'User\s+(.+)',line,re.I)
    if m:
        user=m.group(1).strip(); continue
if hosts and host and user:
    for alias in hosts:
        print(f"{host}|{user}")
PY
```

### Spine host|user set

```text
10.0.0.1|root
100.102.199.111|ronadmin
100.103.99.62|root
100.105.148.96|root
100.106.72.25|ubuntu
100.107.36.76|ubuntu
100.114.101.50|ronny
100.120.163.70|ubuntu
100.123.207.64|ubuntu
100.125.138.110|root
100.67.120.1|hassio
100.71.17.29|ubuntu
100.76.153.100|ubuntu
100.79.183.14|ubuntu
100.90.167.39|ubuntu
100.92.156.118|docker-host
100.92.91.128|ubuntu
100.96.211.33|root
100.98.70.70|automation
192.168.1.185|Production
192.168.1.1|root
192.168.1.216|admin
192.168.1.250|root
192.168.1.2|admin
```

### Workbench host|user set

```text
10.0.0.1|root
100.102.199.111|ronadmin
100.103.99.62|root
100.105.148.96|root
100.106.72.25|ubuntu
100.107.36.76|ubuntu
100.114.101.50|ronny
100.120.163.70|ubuntu
100.123.207.64|ubuntu
100.125.138.110|root
100.67.120.1|hassio
100.71.17.29|ubuntu
100.76.153.100|ubuntu
100.79.183.14|ubuntu
100.90.167.39|ubuntu
100.92.156.118|docker-host
100.92.91.128|ubuntu
100.96.211.33|root
100.98.70.70|automation
192.168.1.185|Production
192.168.1.1|root
192.168.1.216|admin
192.168.1.250|root
192.168.1.2|admin
```

### Diff

```text
(no diff)
```

## Check 3: No Active Runtime Authority in Legacy Repo

### Grep checks

```bash
rg -n '/Users/ronnyworks/ronny-ops' /Users/ronnyworks/code/agentic-spine/ops /Users/ronnyworks/code/agentic-spine/docs/governance
rg -n '/Users/ronnyworks/ronny-ops' /Users/ronnyworks/code/workbench/infra /Users/ronnyworks/code/workbench/dotfiles
```

### Active-surface matches

```text
agentic-spine ops/governance: (no matches)
workbench infra/dotfiles active runtime surfaces: (no matches)
```

### Allowed residual mentions (compat/archive docs)

```text
/Users/ronnyworks/code/workbench/dotfiles/macbook/launchd/LAUNCHD_RETIREMENT_2026-02-06.md:3:Purpose: prevent reinfection of legacy `ronny-ops` launchd jobs after spine
/Users/ronnyworks/code/workbench/dotfiles/macbook/launchd/LAUNCHD_RETIREMENT_2026-02-06.md:25:- `dotfiles/macbook/launchd/.archive/2026-02-06-ronny-ops-retired/`
/Users/ronnyworks/code/workbench/dotfiles/macbook/README.md:49:`agentic-spine` is the runtime SSOT. Do not install legacy workbench/ronny-ops
/Users/ronnyworks/code/workbench/dotfiles/README.md:22:├── zsh/ronny-ops-compat.sh # Backward compat exports
/Users/ronnyworks/code/workbench/dotfiles/README.md:50:source ~/code/workbench/dotfiles/zsh/ronny-ops-compat.sh
/Users/ronnyworks/code/workbench/dotfiles/README.md:58:`ronny-ops-compat.sh` is compatibility-only and non-authoritative. It provides
/Users/ronnyworks/code/workbench/dotfiles/README.md:59:legacy alias behavior without requiring `~/ronny-ops` as an active runtime root.
```

## Residuals

- No active runtime-authority residuals in scoped checks.
- One naming alias variance (`beelink`/proxmox alias) exists at alias-level only; effective host/user authority parity is matched and green.
