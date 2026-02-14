#!/usr/bin/env bash
# TRIAGE: Keep rag remote reindex runner binding, scripts, and capability wiring in sync. Ensure RAG CLI keeps auth token out of process args.
# D88: RAG remote reindex governance lock
# Enforces:
# 1) rag.remote.runner binding exists and has required fields.
# 2) remote runner scripts exist and are executable.
# 3) capabilities + capability_map + MANIFEST parity for rag.reindex.remote.*.
# 4) remote host in binding matches an SSH target host.
# 5) RAG CLI does not pass Authorization bearer token directly in curl args.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

BINDING="$ROOT/ops/bindings/rag.remote.runner.yaml"
SSH_TARGETS="$ROOT/ops/bindings/ssh.targets.yaml"
CAPS="$ROOT/ops/capabilities.yaml"
CAP_MAP="$ROOT/ops/bindings/capability_map.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
RAG_CLI="$ROOT/ops/plugins/rag/bin/rag"
START_SCRIPT="$ROOT/ops/plugins/rag/bin/rag-reindex-remote-start"
STATUS_SCRIPT="$ROOT/ops/plugins/rag/bin/rag-reindex-remote-status"
STOP_SCRIPT="$ROOT/ops/plugins/rag/bin/rag-reindex-remote-stop"

fail() { echo "D88 FAIL: $*" >&2; exit 1; }

for f in "$BINDING" "$SSH_TARGETS" "$CAPS" "$CAP_MAP" "$MANIFEST" "$RAG_CLI"; do
  [[ -f "$f" ]] || fail "required file missing: $f"
done
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

ERRORS=0
err() { echo "  $*" >&2; ERRORS=$((ERRORS + 1)); }

# 1) Binding required fields
required_fields=(
  ".remote.host"
  ".remote.user"
  ".remote.port"
  ".remote.repo_path"
  ".remote.tmux_session"
  ".remote.log_path"
  ".remote.checkpoint_path"
  ".sync.workspace_slug"
  ".sync.anythingllm_url"
  ".sync.qdrant_url"
  ".sync.ollama_url"
  ".sync.resume_default"
  ".runtime.anythingllm_container_hint"
  ".runtime.status_tail_lines"
)
for key in "${required_fields[@]}"; do
  val="$(yq -r "$key // \"\"" "$BINDING")"
  if [[ -z "$val" || "$val" == "null" ]]; then
    err "binding missing required field: $key"
  fi
done

port="$(yq -r '.remote.port' "$BINDING")"
if ! [[ "$port" =~ ^[0-9]+$ ]]; then
  err "binding .remote.port must be integer (got: $port)"
fi
resume="$(yq -r '.sync.resume_default' "$BINDING")"
if [[ "$resume" != "true" && "$resume" != "false" ]]; then
  err "binding .sync.resume_default must be true|false (got: $resume)"
fi
tail_lines="$(yq -r '.runtime.status_tail_lines' "$BINDING")"
if ! [[ "$tail_lines" =~ ^[0-9]+$ ]]; then
  err "binding .runtime.status_tail_lines must be integer (got: $tail_lines)"
fi

# 2) Script existence/executable
for s in "$START_SCRIPT" "$STATUS_SCRIPT" "$STOP_SCRIPT"; do
  if [[ ! -f "$s" ]]; then
    err "remote runner script missing: ${s#$ROOT/}"
  elif [[ ! -x "$s" ]]; then
    err "remote runner script not executable: ${s#$ROOT/}"
  fi
done

# 3) Capability wiring parity
for cap in rag.reindex.remote.start rag.reindex.remote.status rag.reindex.remote.stop; do
  if ! yq -e ".capabilities.\"$cap\"" "$CAPS" >/dev/null 2>&1; then
    err "capability missing in capabilities.yaml: $cap"
  fi
  if ! yq -e ".capabilities.\"$cap\"" "$CAP_MAP" >/dev/null 2>&1; then
    err "capability missing in capability_map.yaml: $cap"
  fi
done

start_cmd="$(yq -r '.capabilities."rag.reindex.remote.start".command // ""' "$CAPS")"
status_cmd="$(yq -r '.capabilities."rag.reindex.remote.status".command // ""' "$CAPS")"
stop_cmd="$(yq -r '.capabilities."rag.reindex.remote.stop".command // ""' "$CAPS")"
[[ "$start_cmd" == "./ops/plugins/rag/bin/rag-reindex-remote-start" ]] || err "rag.reindex.remote.start command mismatch"
[[ "$status_cmd" == "./ops/plugins/rag/bin/rag-reindex-remote-status" ]] || err "rag.reindex.remote.status command mismatch"
[[ "$stop_cmd" == "./ops/plugins/rag/bin/rag-reindex-remote-stop" ]] || err "rag.reindex.remote.stop command mismatch"

if ! yq -e '.plugins[] | select(.name=="rag")' "$MANIFEST" >/dev/null 2>&1; then
  err "rag plugin missing from MANIFEST.yaml"
else
  for script in bin/rag-reindex-remote-start bin/rag-reindex-remote-status bin/rag-reindex-remote-stop; do
    if ! yq -e ".plugins[] | select(.name==\"rag\") | .scripts[] | select(. == \"$script\")" "$MANIFEST" >/dev/null 2>&1; then
      err "MANIFEST rag plugin missing script: $script"
    fi
  done
  for cap in rag.reindex.remote.start rag.reindex.remote.status rag.reindex.remote.stop; do
    if ! yq -e ".plugins[] | select(.name==\"rag\") | .capabilities[] | select(. == \"$cap\")" "$MANIFEST" >/dev/null 2>&1; then
      err "MANIFEST rag plugin missing capability: $cap"
    fi
  done
fi

# 4) Binding host must be one of ssh.targets hosts
runner_host="$(yq -r '.remote.host // ""' "$BINDING")"
if [[ -n "$runner_host" ]]; then
  if ! grep -qx "$runner_host" < <(yq -r '.ssh.targets[].host' "$SSH_TARGETS"); then
    err "binding .remote.host ($runner_host) not present in ssh.targets.yaml"
  fi
fi

# 5) RAG CLI auth-token hygiene: no raw bearer header in curl args
if grep -Eq -- '-H[[:space:]]+"Authorization:[[:space:]]+Bearer[[:space:]]+\$\{?ANYTHINGLLM_API_KEY\}?"' "$RAG_CLI"; then
  err "RAG CLI still passes bearer token directly in curl args"
fi
if ! grep -q 'make_auth_header_file' "$RAG_CLI"; then
  err "RAG CLI missing make_auth_header_file helper"
fi
if ! grep -q -- '-H "@\${header_file}"' "$RAG_CLI"; then
  err "RAG CLI should use curl header-file pattern (-H \"@\\${header_file}\")"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  fail "$ERRORS governance errors found"
fi

workspace="$(yq -r '.sync.workspace_slug' "$BINDING")"
echo "D88 PASS: RAG remote reindex governance lock enforced (host=$runner_host workspace=$workspace)"
