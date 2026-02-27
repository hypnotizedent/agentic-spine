#!/usr/bin/env bash
# TRIAGE: Regenerate project attach bindings via ./bin/generators/gen-project-attach.sh and ensure .spine-link.yaml parity.
# D153: project attach parity lock
# Fast-path check only: file existence + required field parity.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REGISTRY="$ROOT/ops/bindings/agents.registry.yaml"
DOMAIN_PROFILES="$ROOT/ops/bindings/gate.domain.profiles.yaml"
AGENT_PROFILES="$ROOT/ops/bindings/gate.agent.profiles.yaml"

fail() {
  echo "D153 FAIL: $*" >&2
  exit 1
}

[[ -f "$REGISTRY" ]] || fail "missing agents registry: $REGISTRY"
[[ -f "$DOMAIN_PROFILES" ]] || fail "missing domain profiles: $DOMAIN_PROFILES"
[[ -f "$AGENT_PROFILES" ]] || fail "missing agent profiles: $AGENT_PROFILES"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$REGISTRY" "$DOMAIN_PROFILES" "$AGENT_PROFILES" <<'PY'
from __future__ import annotations

import sys
import subprocess
from pathlib import Path

import yaml

registry_path = Path(sys.argv[1])
domain_profiles_path = Path(sys.argv[2])
agent_profiles_path = Path(sys.argv[3])
policy_path = registry_path.parent / "project.attach.link.policy.yaml"


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


registry = load_yaml(registry_path)
domain_profiles = load_yaml(domain_profiles_path)
agent_profiles = load_yaml(agent_profiles_path)
policy_doc = load_yaml(policy_path) if policy_path.is_file() else {}
policy = policy_doc.get("policy") or {}
attach_filename = str(policy.get("attach_filename", ".spine-link.yaml")).strip() or ".spine-link.yaml"
require_git_root = bool(policy.get("repo_path_must_be_git_root", True))

agents = registry.get("agents") or []
if not isinstance(agents, list):
    print("D153 FAIL: agents registry has invalid agents[] payload", file=sys.stderr)
    raise SystemExit(1)

domain_packs = set((domain_profiles.get("domains") or {}).keys())
agent_packs = set()
for profile in (agent_profiles.get("profiles") or []):
    if isinstance(profile, dict) and profile.get("agent_id"):
        agent_packs.add(str(profile.get("agent_id")))

errors: list[str] = []
checked = 0

required = ["repo_path", "project_id", "domain", "agent_id", "gate_pack", "verify_command", "governance_bundle", "spine_link_version"]


def resolve_git_root(path: Path):
    proc = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--show-toplevel"],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        return None
    out = (proc.stdout or "").strip()
    if not out:
        return None
    return Path(out).resolve()

for agent in agents:
    if not isinstance(agent, dict):
        continue

    status = str(agent.get("implementation_status", "active")).strip().lower() or "active"
    if status != "active":
        continue

    binding = agent.get("project_binding")
    if not isinstance(binding, dict):
        continue

    checked += 1
    aid = str(agent.get("id", "")).strip()
    adomain = str(agent.get("domain", "")).strip()

    missing = [field for field in required if field not in binding]
    if missing:
        errors.append(f"{aid}: project_binding missing fields: {', '.join(missing)}")
        continue

    repo_path = str(binding.get("repo_path", "")).strip()
    bdomain = str(binding.get("domain", "")).strip()
    bagent = str(binding.get("agent_id", "")).strip()
    bgate_pack = str(binding.get("gate_pack", "")).strip()

    if not repo_path.startswith("/Users/ronnyworks/code/"):
        errors.append(f"{aid}: repo_path must be absolute under /Users/ronnyworks/code/ (got: {repo_path})")
        continue

    repo_dir = Path(repo_path).resolve()
    if require_git_root:
        git_root = resolve_git_root(repo_dir)
        if git_root is None:
            errors.append(f"{aid}: project_binding.repo_path is not a git worktree root (got: {repo_path})")
            continue
        if git_root != repo_dir:
            errors.append(
                f"{aid}: project_binding.repo_path must be repository root (got: {repo_path}, root: {git_root})"
            )
            continue

    if bdomain != adomain:
        errors.append(f"{aid}: project_binding.domain '{bdomain}' must match agent domain '{adomain}'")

    if bagent != aid:
        errors.append(f"{aid}: project_binding.agent_id '{bagent}' must match agent id '{aid}'")

    if bgate_pack not in domain_packs and bgate_pack not in agent_packs:
        errors.append(
            f"{aid}: project_binding.gate_pack '{bgate_pack}' does not resolve to domain pack or agent pack"
        )

    link_path = repo_dir / attach_filename
    if not link_path.is_file():
        errors.append(f"{aid}: missing attach file: {link_path}")
        continue

    try:
        link_doc = load_yaml(link_path)
    except Exception as exc:
        errors.append(f"{aid}: invalid yaml in {link_path}: {exc}")
        continue

    if str(link_doc.get("domain", "")).strip() != bdomain:
        errors.append(
            f"{aid}: .spine-link.yaml domain mismatch (expected '{bdomain}', got '{link_doc.get('domain')}')"
        )

    if str(link_doc.get("agent_id", "")).strip() != bagent:
        errors.append(
            f"{aid}: .spine-link.yaml agent_id mismatch (expected '{bagent}', got '{link_doc.get('agent_id')}')"
        )

    if str(link_doc.get("gate_pack", "")).strip() != bgate_pack:
        errors.append(
            f"{aid}: .spine-link.yaml gate_pack mismatch (expected '{bgate_pack}', got '{link_doc.get('gate_pack')}')"
        )

if checked == 0:
    errors.append("no active project_binding entries found in agents.registry.yaml")

if errors:
    for err in errors:
        print(f"  FAIL: {err}", file=sys.stderr)
    print(f"D153 FAIL: project attach parity violations ({len(errors)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(f"D153 PASS: project attach parity valid for {checked} active binding(s)")
PY
