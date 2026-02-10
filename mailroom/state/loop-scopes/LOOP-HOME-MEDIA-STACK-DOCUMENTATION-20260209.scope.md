---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-HOME-MEDIA-STACK-DOCUMENTATION-20260209
severity: medium
---

# Loop Scope: LOOP-HOME-MEDIA-STACK-DOCUMENTATION-20260209

## Goal

Document the home download-home LXC (LXC 103) media stack. Services (radarr, sonarr, lidarr, prowlarr, sabnzbd, tdarr) are NOT documented anywhere in spine. Need service discovery, storage documentation, and SERVICE_REGISTRY.yaml entries.

## Problem / Current State (2026-02-09)

- Home media stack completely undocumented in spine
- Unknown storage paths for media files
- No backup procedures for home media stack
- No SERVICE_REGISTRY.yaml entries for home media services
- Cannot verify home media stack health or integrate with shop media stack

## Success Criteria

1. All running services in download-home LXC documented
2. Storage architecture documented (NAS + LXC)
3. All services added to SERVICE_REGISTRY.yaml
4. Backup strategy documented
5. MINILAB_SSOT.md updated with media stack section

## Phases

### P0: Service Discovery — IN PROGRESS
- [x] Document service discovery goal from audit
- [ ] SSH to download-home LXC, list all containers
- [ ] Document each service (ports, volumes, configs)

### P1: Storage Documentation
- Map NAS and LXC storage architecture
- Document media directory structure

### P2: Configuration Documentation
- Document service configurations and env vars
- Document service integrations

### P3: Service Registry Update
- Add home media stack to SERVICE_REGISTRY.yaml
- Create drift gate for home media stack

### P4: Backup and Monitoring Documentation
- Document backup strategy for media stack
- Document monitoring and recovery procedures

## Receipts

- (awaiting execution)
