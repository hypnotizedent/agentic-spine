#!/usr/bin/env bash
# D153: project attach parity lock
# Validates materialized .spine-link.yaml files against the current attach
# contract/policy surfaces and live gate pack authorities.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WORKBENCH_ATTACH_CONTRACT="$ROOT/ops/bindings/workbench.ssh.attach.contract.yaml"
PROJECT_ATTACH_POLICY="$ROOT/ops/bindings/project.attach.link.policy.yaml"
DOMAIN_PROFILES="$ROOT/ops/bindings/gate.domain.profiles.yaml"
AGENT_PROFILES="$ROOT/ops/bindings/gate.agent.profiles.yaml"

fail() {
  echo "D153 FAIL: $*" >&2
  exit 1
}

for file in "$WORKBENCH_ATTACH_CONTRACT" "$PROJECT_ATTACH_POLICY" "$DOMAIN_PROFILES" "$AGENT_PROFILES"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$ROOT" "$WORKBENCH_ATTACH_CONTRACT" "$PROJECT_ATTACH_POLICY" "$DOMAIN_PROFILES" "$AGENT_PROFILES" <<'PY'
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import yaml

root = Path(sys.argv[1])
contract_path = Path(sys.argv[2])
policy_path = Path(sys.argv[3])
domain_profiles_path = Path(sys.argv[4])
agent_profiles_path = Path(sys.argv[5])


def fail(msg: str) -> None:
    print(f"D153 FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path):
    try:
        with path.open("r", encoding="utf-8") as handle:
            return yaml.safe_load(handle) or {}
    except Exception as exc:
        fail(f"{path}: invalid YAML ({exc})")


def resolve_git_root(path: Path) -> Path | None:
    proc = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--show-toplevel"],
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        return None
    out = (proc.stdout or "").strip()
    return Path(out).resolve() if out else None


contract = load_yaml(contract_path)
policy_doc = load_yaml(policy_path)
domain_profiles = load_yaml(domain_profiles_path)
agent_profiles = load_yaml(agent_profiles_path)

workbench_root_raw = str(contract.get("workbench_root") or "").strip()
if not workbench_root_raw:
    fail("workbench.ssh.attach.contract workbench_root is required")
workbench_root = Path(workbench_root_raw).expanduser()
if not workbench_root.is_dir():
    fail(f"workbench root not found: {workbench_root}")

generator_rel = str(contract.get("generator_script") or "").strip()
if not generator_rel:
    fail("workbench.ssh.attach.contract generator_script is required")
generator_path = root / generator_rel
if not generator_path.is_file():
    fail(f"missing generator script: {generator_path}")
if not os.access(generator_path, os.X_OK):
    fail(f"generator script is not executable: {generator_path}")

generator_proc = subprocess.run(
    [str(generator_path), "--check"],
    text=True,
    capture_output=True,
    check=False,
    cwd=str(root),
)
if generator_proc.returncode != 0:
    detail = (generator_proc.stderr or generator_proc.stdout or "").strip()
    fail(f"workbench ssh projection drift detected: {detail or 'generator check failed'}")

attach_filename = str(contract.get("attach_file") or "").strip()
policy_attach_filename = str(((policy_doc.get("policy") or {}).get("attach_filename")) or "").strip()
if not attach_filename:
    fail("workbench.ssh.attach.contract attach_file is required")
if attach_filename != policy_attach_filename:
    fail(f"attach filename mismatch between contract and policy: {attach_filename} vs {policy_attach_filename}")

expected_source_registry = ""
for check in (contract.get("checks") or []):
    if isinstance(check, dict) and check.get("id") == "attach_source_registry_match":
        expected_source_registry = str(check.get("expected_source_registry") or "").strip()
        break
if not expected_source_registry:
    fail("workbench.ssh.attach.contract missing expected_source_registry for attach_source_registry_match")

domain_ids = set((domain_profiles.get("domains") or {}).keys())
agent_ids = {str(item.get("agent_id")) for item in (agent_profiles.get("profiles") or []) if isinstance(item, dict)}

search_root = Path("/Users/ronnyworks/code")
attach_paths = sorted(search_root.glob(f"*/{attach_filename}"))
if not attach_paths:
    fail(f"no attach files found under {search_root}")

required_fields = [
    "status",
    "owner",
    "source_registry",
    "managed_by",
    "spine_link_version",
    "project_id",
    "repo_path",
    "domain",
    "agent_id",
    "gate_pack",
    "verify_command",
    "governance_bundle",
]

checked = 0
for attach_path in attach_paths:
    checked += 1
    doc = load_yaml(attach_path)
    if not isinstance(doc, dict):
        fail(f"{attach_path}: attach file must be a mapping")

    missing = [field for field in required_fields if field not in doc]
    if missing:
        fail(f"{attach_path}: missing required fields: {', '.join(missing)}")

    if str(doc.get("status")).strip() != "generated":
        fail(f"{attach_path}: status must be generated")
    if str(doc.get("owner")).strip() != "@ronny":
        fail(f"{attach_path}: owner must be @ronny")
    if str(doc.get("source_registry")).strip() != expected_source_registry:
        fail(f"{attach_path}: source_registry must be {expected_source_registry}")

    repo_path = Path(str(doc.get("repo_path")).strip()).resolve()
    if repo_path.parent != search_root:
        fail(f"{attach_path}: repo_path must live directly under {search_root}")
    if attach_path.parent.resolve() != repo_path:
        fail(f"{attach_path}: attach file must live at repo root declared by repo_path")
    git_root = resolve_git_root(repo_path)
    if git_root is None or git_root != repo_path:
        fail(f"{attach_path}: repo_path is not a git worktree root")

    domain = str(doc.get("domain")).strip()
    if domain not in domain_ids:
        fail(f"{attach_path}: unknown domain '{domain}'")

    gate_pack = str(doc.get("gate_pack")).strip()
    if gate_pack not in domain_ids and gate_pack not in agent_ids:
      fail(f"{attach_path}: gate_pack '{gate_pack}' does not resolve to domain or agent profile")

    governance_bundle = doc.get("governance_bundle")
    if not isinstance(governance_bundle, list) or not governance_bundle:
        fail(f"{attach_path}: governance_bundle must be a non-empty list")

    verify_command = str(doc.get("verify_command")).strip()
    if not verify_command.startswith("./bin/ops cap run verify.pack.run "):
        fail(f"{attach_path}: verify_command must use verify.pack.run")

print(f"D153 PASS: project attach parity valid for {checked} attach file(s); workbench ssh projection in sync")
PY
