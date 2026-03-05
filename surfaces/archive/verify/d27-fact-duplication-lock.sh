#!/usr/bin/env bash
# TRIAGE: Remove raw IPs/ports from no-fact docs. Reference SSOT docs instead of duplicating facts.
set -euo pipefail

# D27: Fact Duplication Lock
# Prevents host/IP/service fact drift in agent startup/governance read surfaces.
# Mutable infrastructure facts must live in canonical fact docs only.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$ROOT/ops/bindings/agent.fact.lock.yaml"

fail() { echo "D27 FAIL: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool yq
require_tool rg
require_tool sort

[[ -f "$BINDING" ]] || fail "binding not found: $BINDING"
yq e '.' "$BINDING" >/dev/null 2>&1 || fail "binding is not valid YAML"

mapfile -t CANONICAL < <(yq e '.canonical_fact_docs[]' "$BINDING")
mapfile -t NO_FACT < <(yq e '.no_fact_docs[]' "$BINDING")
SERVICE_REG="$(yq e '.service_registry' "$BINDING")"

(( ${#CANONICAL[@]} > 0 )) || fail "canonical_fact_docs empty"
(( ${#NO_FACT[@]} > 0 )) || fail "no_fact_docs empty"
[[ -n "${SERVICE_REG:-}" && "${SERVICE_REG:-}" != "null" ]] || fail "service_registry missing"

for rel in "${CANONICAL[@]}"; do
  [[ -f "$ROOT/$rel" ]] || fail "canonical fact doc missing: $rel"
done
for rel in "${NO_FACT[@]}"; do
  [[ -f "$ROOT/$rel" ]] || fail "no-fact doc missing: $rel"
done
[[ -f "$ROOT/$SERVICE_REG" ]] || fail "service registry missing: $SERVICE_REG"

# Patterns for mutable infrastructure facts
IP_RE='\b(100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})\b'
PORT_TEXT_RE='\bport[[:space:]]+[0-9]{2,5}\b'

# 1) no_fact docs must not include raw LAN/Tailscale IPs or literal "port ####" claims.
for rel in "${NO_FACT[@]}"; do
  file="$ROOT/$rel"
  if rg -n "$IP_RE" "$file" >/dev/null 2>&1; then
    fail "raw IP fact found in no-fact doc: $rel"
  fi
  if rg -n "$PORT_TEXT_RE" "$file" >/dev/null 2>&1; then
    fail "literal port claim found in no-fact doc: $rel"
  fi
done

# 2) Extract service ports from canonical registry.
mapfile -t PORTS < <(
  {
    yq e '.services[] | .port // ""' "$ROOT/$SERVICE_REG"
    yq e '.services[] | .console_port // ""' "$ROOT/$SERVICE_REG"
  } | sed '/^$/d' | sort -u
)

# 3) no_fact docs must not contain those service port values.
for p in "${PORTS[@]:-}"; do
  [[ -n "${p:-}" ]] || continue
  for rel in "${NO_FACT[@]}"; do
    file="$ROOT/$rel"
    if rg -n --pcre2 "(?<![0-9])${p}(?![0-9])" "$file" >/dev/null 2>&1; then
      fail "service port ${p} duplicated in no-fact doc: $rel"
    fi
  done
done

# 4) Extract canonical IP facts and ensure they are absent from no_fact docs.
mapfile -t CANON_IPS < <(
  rg -o --pcre2 "$IP_RE" "${CANONICAL[@]/#/$ROOT/}" 2>/dev/null | sort -u
)

for ip in "${CANON_IPS[@]:-}"; do
  [[ -n "${ip:-}" ]] || continue
  for rel in "${NO_FACT[@]}"; do
    file="$ROOT/$rel"
    if rg -n --fixed-strings "$ip" "$file" >/dev/null 2>&1; then
      fail "canonical IP ${ip} duplicated in no-fact doc: $rel"
    fi
  done
done

echo "D27 PASS: fact duplication lock enforced"
