# ai-consolidation (VM 207)

Purpose: run Qdrant + AnythingLLM on the dedicated AI VM.

## Host

- Host: `ai-consolidation`
- Tailscale IP: `100.71.17.29`
- Stack path (live): `/opt/stacks/ai-consolidation`

## Ports

- AnythingLLM: `3002` (host) → container `3001`
- Qdrant: `6333` (HTTP), `6334` (gRPC)

## Secrets

Required (do not commit):
- `SIG_KEY`
- `SIG_SALT`

Preferred storage: Infisical (project split in P5 of LOOP-AI-CONSOLIDATION).

## Deploy / Update (on VM 207)

```bash
cd /opt/stacks/ai-consolidation
sudo docker compose pull
sudo docker compose up -d
```

## Verify

```bash
curl -sSf http://localhost:6333/healthz
curl -sSf http://localhost:3002/api/ping
```

