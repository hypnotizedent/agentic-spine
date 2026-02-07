# Secrets Namespace Migration Map (GAP-OP-013)

| Field | Value |
|---|---|
| Generated | `2026-02-07T20:37:21Z` |
| Scope | `infrastructure/prod` (project `01ddd93a-e0f8-4c7c-ad9f-903d76ef94d9`) |
| Legacy debt | `49` keys still at root path `/` |
| New namespace baseline | `/spine/*` |
| Guardrail | `./bin/ops cap run secrets.namespace.status` |

## Objective

Migrate legacy root-path keys (`/`) into canonical `/spine/*` namespaces without service outage.

- Freeze regression first (already done via policy + namespace status checks).
- Migrate by key cohorts.
- Verify each cohort before deleting root copies.

## Execution Snapshot (2026-02-07)

- P1 `/spine/platform/security`: complete (9 keys copied + root copies deleted).
- P2 `/spine/network/edge`: complete (10 keys copied + root copies deleted).
- Namespace status: `OK_WITH_LEGACY_DEBT`
  - Baseline root keys: `49`
  - Current root keys: `30`
  - Removed from root: `19`

## Migration Rules

1. Never move all keys at once.
2. For each cohort: copy -> validate consumer -> delete old root key.
3. Keep rollback path simple: re-create root key from namespaced value.
4. Run `secrets.namespace.status` before and after each cohort.

## Cohorts

### P1: Platform Security
Target path: `/spine/platform/security`

Keys:
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_TENANT_ID`
- `GITHUB_PERSONAL_ACCESS_TOKEN`
- `INFISICAL_AUTH_SECRET`
- `INFISICAL_ENCRYPTION_KEY`
- `INFISICAL_MCP_CLIENT_ID`
- `INFISICAL_MCP_CLIENT_SECRET`
- `INFISICAL_POSTGRES_PASSWORD`

### P2: Edge And Networking
Target path: `/spine/network/edge`

Keys:
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_AUTH_EMAIL`
- `CLOUDFLARE_GLOBAL_API_KEY`
- `CLOUDFLARE_TUNNEL_ID`
- `CLOUDFLARE_TUNNEL_TOKEN`
- `PIHOLE_HOME_PASSWORD`
- `XB8_GATEWAY_PASSWORD`
- `XB8_GATEWAY_URL`
- `XB8_GATEWAY_USER`

### P3: Storage And NAS
Target path: `/spine/storage/nas`

Keys:
- `DOCKER_HOST_SMB_PASS`
- `DOCKER_HOST_SMB_USER`
- `SMB_PASSWORD`
- `SYNOLOGY_HOST`
- `SYNOLOGY_SSH_PASSWORD`
- `SYNOLOGY_SSH_USER`

### P4: Commerce And Mail
Target path: `/spine/integrations/commerce-mail`

Keys:
- `APPLE_APP_PASSWORD`
- `APPLE_ID_EMAIL`
- `FROM_EMAIL`
- `SHOPIFY_CLIENT_ID`
- `SHOPIFY_CLIENT_SECRET`
- `SHOPIFY_CLI_TOKEN`
- `SHOPIFY_PARTNER_API_KEY`
- `SHOPIFY_PARTNER_ID`
- `SHOPIFY_STORE_DOMAIN`

### P5: Service Workloads
Target paths:
- `/spine/services/immich`
- `/spine/services/mail-archiver`
- `/spine/services/finance`
- `/spine/services/paperless`
- `/spine/services/mcpjungle`

Keys:
- `IMMICH_API_KEY`
- `IMMICH_HYPNO_API_KEY`
- `IMMICH_HYPNO_PASSWORD`
- `IMMICH_HYPNO_USER_ID`
- `IMMICH_MINT_API_KEY`
- `IMMICH_SUDO_PASSWORD`
- `MAIL_ARCHIVER_ADMIN_PASS`
- `MAIL_ARCHIVER_DB_PASS`
- `FIREFLY_PAT`
- `PAPERLESS_API_TOKEN`
- `MCPJUNGLE_ADMIN_TOKEN`

### P6: AI Keys (Preferred Project Split)
Preferred target: move to `ai-services` project first, then path `/spine/ai/providers`.

Keys:
- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`
- `Z_AI_API_KEY`
- `ANYTHINGLLM_API_KEY`

## Safe Copy Pattern (One Key)

```bash
# Inputs
PROJ="01ddd93a-e0f8-4c7c-ad9f-903d76ef94d9"
ENV="prod"
KEY="EXAMPLE_KEY"
SRC_PATH="/"
DST_PATH="/spine/example"

# Copy without printing value
val="$(infisical secrets get "$KEY" --projectId "$PROJ" --env "$ENV" --path "$SRC_PATH" --plain --silent)"
infisical secrets set "$KEY=$val" --projectId "$PROJ" --env "$ENV" --path "$DST_PATH" --silent

# Verify destination key exists (value length > 0)
[[ "$(infisical secrets get "$KEY" --projectId "$PROJ" --env "$ENV" --path "$DST_PATH" --plain --silent | wc -c | tr -d ' ')" -gt 0 ]]
```

## Rollback Pattern (Per Key)

```bash
# Recreate root key from namespaced copy
val="$(infisical secrets get "$KEY" --projectId "$PROJ" --env "$ENV" --path "$DST_PATH" --plain --silent)"
infisical secrets set "$KEY=$val" --projectId "$PROJ" --env "$ENV" --path "/" --silent
```

## Acceptance Per Cohort

1. `./bin/ops cap run secrets.namespace.status` remains `OK_WITH_LEGACY_DEBT` or `OK`.
2. No new root-path keys are introduced.
3. Consumer services for the cohort remain healthy after path switch.
4. Root-path key count decreases after cleanup.

## Final Exit Criteria

1. Root-path key count = `0`.
2. `./bin/ops cap run secrets.namespace.status` returns `status: OK`.
3. GAP-OP-013 can be marked fixed.
