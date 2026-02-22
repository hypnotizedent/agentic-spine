#!/bin/bash
set -euo pipefail

# Network gate — skip cleanly when Tailscale VPN is disconnected
source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

# Quick health check for infrastructure services

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              INFRASTRUCTURE HEALTH CHECK - $(date '+%Y-%m-%d %H:%M')              ║"
echo "╠══════════════════════════════════════════════════════════════════╣"

# 1. Tailscale
echo ""
echo "║ 🔗 TAILSCALE                                                      ║"
if /Applications/Tailscale.app/Contents/MacOS/Tailscale status &>/dev/null; then
    echo "║   ✅ Connected                                                    ║"
    /Applications/Tailscale.app/Contents/MacOS/Tailscale status 2>/dev/null | head -5
else
    echo "║   ❌ Not connected                                                ║"
fi

# 2. Network connectivity to docker-host
echo ""
echo "║ 🖥️  DOCKER-HOST                                                   ║"
if ping -c 1 -W 2 docker-host &>/dev/null; then
    echo "║   ✅ Reachable via ping                                          ║"
else
    echo "║   ❌ Unreachable via ping                                        ║"
fi

# 3. PostgreSQL via SSH
echo ""
echo "║ 🐘 POSTGRESQL                                                     ║"
if ssh -o ConnectTimeout=5 docker-host "docker exec mint-data-postgres psql -U mint_os_admin -d mint_os -c 'SELECT 1'" &>/dev/null; then
    echo "║   ✅ Database responding via SSH                                 ║"
    ORDER_COUNT=$(ssh docker-host "docker exec mint-data-postgres psql -U mint_os_admin -d mint_os -t -c 'SELECT COUNT(*) FROM orders'" 2>/dev/null | tr -d ' ')
    echo "║   📊 Order count: $ORDER_COUNT                                   ║"
else
    echo "║   ❌ Database not responding                                     ║"
fi

# 4. Direct PostgreSQL (what MCP tries)
echo ""
echo "║ 🐘 POSTGRESQL DIRECT (MCP test)                                   ║"
if nc -z -w 2 docker-host 5433 &>/dev/null; then
    echo "║   ✅ Port 5433 is open                                           ║"
else
    echo "║   ❌ Port 5433 not reachable - THIS IS WHY MCP FAILS            ║"
fi

# 5. API
echo ""
echo "║ 🌐 MINT OS API                                                    ║"
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://mintprints-api.ronny.works/api/orders?limit=1" 2>/dev/null)
if [ "$API_STATUS" = "200" ]; then
    LATEST_ORDER=$(curl -s "https://mintprints-api.ronny.works/api/orders?limit=1" | jq -r '.orders[0].visual_id' 2>/dev/null)
    echo "║   ✅ API responding - Latest order: #$LATEST_ORDER               ║"
else
    echo "║   ⚠️  API status: HTTP $API_STATUS                               ║"
fi

# 6. Infisical
echo ""
echo "║ 🔐 INFISICAL                                                      ║"
INFISICAL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://secrets.ronny.works" 2>/dev/null)
if [ "$INFISICAL_STATUS" = "200" ] || [ "$INFISICAL_STATUS" = "302" ]; then
    echo "║   ✅ Infisical reachable                                         ║"
else
    echo "║   ❌ Infisical unreachable (HTTP $INFISICAL_STATUS)              ║"
fi

# 7. n8n
echo ""
echo "║ ⚡ N8N                                                            ║"
N8N_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://n8n.ronny.works" 2>/dev/null)
if [ "$N8N_STATUS" = "200" ] || [ "$N8N_STATUS" = "302" ]; then
    echo "║   ✅ n8n reachable                                               ║"
else
    echo "║   ⚠️  n8n may be stopped (HTTP $N8N_STATUS)                      ║"
fi

echo ""
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "If PostgreSQL DIRECT shows port not reachable:"
echo "  The database is only accessible via SSH tunnel, not direct connection."
echo ""
echo "FIX: Update pg_hba.conf on docker-host to allow your Tailscale IP:"
echo "  ssh docker-host"
echo "  docker exec -it mint-data-postgres bash"
echo "  echo 'host all all 100.0.0.0/8 md5' >> /var/lib/postgresql/data/pg_hba.conf"
echo "  exit"
echo "  docker restart mint-data-postgres"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
