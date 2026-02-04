#!/usr/bin/env bash
# Clerk watcher - detect Infisical, compose, and service drift
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

LIB_DIR="$SCRIPT_DIR/lib"
source "$LIB_DIR/registry.sh"

REGISTRY_FILE="$REPO_ROOT/docs/governance/SERVICE_REGISTRY.yaml"
CACHE_DIR="${HOME}/.cache/ops-clerk"
mkdir -p "$CACHE_DIR"
CHECKSUM_FILE="$CACHE_DIR/checksums"
NEW_CHECKSUM_FILE="$CACHE_DIR/checksums.new"
STATE_FILE="$REPO_ROOT/infrastructure/CURRENT_STATE.md"

INFISICAL_PROJECTS=()
if [[ -f "$REGISTRY_FILE" ]]; then
  while IFS= read -r proj; do
    [[ -n "$proj" ]] && INFISICAL_PROJECTS+=("$proj")
  done < <(yq '.infisical_projects | keys | .[]' "$REGISTRY_FILE" 2>/dev/null)
fi

stack_list=(mint-os finance media-stack)
service_list=(mint-os-api minio anythingllm qdrant)

DRIFT_ALERTS=()
INF_LINES=()
COMPOSE_LINES=()
SERVICE_LINES=()

: > "$NEW_CHECKSUM_FILE"

record_checksum() {
  local key="$1"
  local value="$2"
  echo "${key}:${value}" >> "$NEW_CHECKSUM_FILE"

  if [[ -f "$CHECKSUM_FILE" ]]; then
    local previous_line
    previous_line=$(grep -m1 -F "${key}:" "$CHECKSUM_FILE" || true)
    local previous_value="${previous_line#*:}"
    if [[ -n "$previous_line" && "$previous_value" != "$value" ]]; then
      DRIFT_ALERTS+=("${key} changed from ${previous_value} to ${value}")
    fi
  fi
}

for proj in "${INFISICAL_PROJECTS[@]}"; do
  count="error"
  if [[ -x "$REPO_ROOT/ops/tools/infisical-agent.sh" ]]; then
    set +e
    count=$("$REPO_ROOT/ops/tools/infisical-agent.sh" list "$proj" prod 2>/dev/null | wc -l)
    status=$?
    set -e
    if [[ $status -ne 0 ]]; then
      count="error"
    else
      count="${count//[[:space:]]/}"
    fi
  fi
  INF_LINES+=("${proj}: ${count} secrets")
  record_checksum "infisical_${proj}" "$count"
done

for stack in "${stack_list[@]}"; do
  remote_path="~/stacks/${stack}/docker-compose.yml"
  hash="missing"
  hash=$(ssh docker-host "if [[ -f ${remote_path} ]]; then md5sum ${remote_path} | cut -d' ' -f1; else echo missing; fi" 2>/dev/null || echo "missing")
  COMPOSE_LINES+=("${stack}: ${hash}")
  record_checksum "compose_${stack}" "$hash"
done

for svc in "${service_list[@]}"; do
  status="unknown"
  url=$(get_service_health_url "$svc" 2>/dev/null || true)
  if [[ -n "$url" ]]; then
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "DOWN")
    if [[ "$http_code" =~ ^[0-9]{3}$ ]]; then
      status="$http_code"
    else
      status="DOWN"
    fi
  fi
  SERVICE_LINES+=("${svc}: ${status} (${url:-no-url})")
done

mv "$NEW_CHECKSUM_FILE" "$CHECKSUM_FILE"

cat <<STATE_DOC > "$STATE_FILE"
---
generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
generator: clerk-watcher.sh
---

# Current Infrastructure State

## Infisical Secrets
$(for line in "${INF_LINES[@]}"; do echo "- $line"; done)

## Docker Compose Checksums
$(for line in "${COMPOSE_LINES[@]}"; do echo "- $line"; done)

## Service Health
$(for line in "${SERVICE_LINES[@]}"; do echo "- $line"; done)

## Drift Observations
$(if [[ ${#DRIFT_ALERTS[@]} -eq 0 ]]; then echo "- no drift detected"; else for alert in "${DRIFT_ALERTS[@]}"; do echo "- $alert"; done; fi)
STATE_DOC

echo "Clerk watcher updated $STATE_FILE"
if [[ ${#DRIFT_ALERTS[@]} -gt 0 ]]; then
  for alert in "${DRIFT_ALERTS[@]}"; do
    echo "⚠️  $alert"
  done
fi
