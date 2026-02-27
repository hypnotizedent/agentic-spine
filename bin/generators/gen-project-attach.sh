#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REGISTRY="$ROOT/ops/bindings/agents.registry.yaml"
POLICY="$ROOT/ops/bindings/project.attach.link.policy.yaml"
CHECK_MODE=0

usage() {
  cat <<'EOF'
gen-project-attach.sh

Materialize project attach bindings from ops/bindings/agents.registry.yaml
into /Users/ronnyworks/code/*/.spine-link.yaml.

Usage:
  ./bin/generators/gen-project-attach.sh
  ./bin/generators/gen-project-attach.sh --check
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -f "$REGISTRY" ]] || {
  echo "ERROR: missing registry: $REGISTRY" >&2
  exit 1
}

python3 - "$REGISTRY" "$CHECK_MODE" "$POLICY" <<'PY'
from __future__ import annotations

import sys
import subprocess
from pathlib import Path
from typing import Any

import yaml

REGISTRY = Path(sys.argv[1]).resolve()
CHECK_MODE = sys.argv[2] == "1"
POLICY = Path(sys.argv[3]).resolve()

ROOT = REGISTRY.parents[2]
ROOT_STR = str(ROOT)
REGISTRY_REL = "ops/bindings/agents.registry.yaml"
MANAGED_BY = "bin/generators/gen-project-attach.sh"

REQUIRED_FIELDS = [
    "repo_path",
    "project_id",
    "domain",
    "agent_id",
    "gate_pack",
    "verify_command",
    "governance_bundle",
    "spine_link_version",
]


def fail(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(1)


def dump_yaml(payload: dict[str, Any]) -> str:
    return "---\n" + yaml.safe_dump(payload, sort_keys=False, allow_unicode=False)


with REGISTRY.open("r", encoding="utf-8") as f:
    doc = yaml.safe_load(f) or {}

policy_doc: dict[str, Any] = {}
if POLICY.is_file():
    with POLICY.open("r", encoding="utf-8") as f:
        policy_doc = yaml.safe_load(f) or {}
policy = policy_doc.get("policy") or {}
ATTACH_FILENAME = str(policy.get("attach_filename", ".spine-link.yaml")).strip() or ".spine-link.yaml"
REPO_PATH_MUST_BE_GIT_ROOT = bool(policy.get("repo_path_must_be_git_root", True))

agents = doc.get("agents") or []
if not isinstance(agents, list):
    fail("agents.registry.yaml has invalid agents[] payload")

errors: list[str] = []
updates: list[Path] = []


def resolve_git_root(path: Path) -> Path | None:
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
    implementation_status = str(agent.get("implementation_status", "active")).strip().lower()
    if implementation_status and implementation_status != "active":
        continue

    project_binding = agent.get("project_binding")
    if not isinstance(project_binding, dict):
        continue

    agent_id = str(agent.get("id", "")).strip()
    if not agent_id:
        errors.append("project_binding entry found with missing agent id")
        continue

    missing = [key for key in REQUIRED_FIELDS if key not in project_binding]
    if missing:
        errors.append(f"{agent_id}: missing project_binding fields: {', '.join(missing)}")
        continue

    repo_path = str(project_binding.get("repo_path", "")).strip()
    if not repo_path.startswith("/Users/ronnyworks/code/"):
        errors.append(
            f"{agent_id}: project_binding.repo_path must be absolute under /Users/ronnyworks/code/ (got: {repo_path})"
        )
        continue

    repo_dir = Path(repo_path).resolve()
    if REPO_PATH_MUST_BE_GIT_ROOT:
        git_root = resolve_git_root(repo_dir)
        if git_root is None:
            errors.append(f"{agent_id}: project_binding.repo_path is not a git worktree root (got: {repo_path})")
            continue
        if git_root != repo_dir:
            errors.append(
                f"{agent_id}: project_binding.repo_path must be repository root (got: {repo_path}, root: {git_root})"
            )
            continue

    if str(project_binding.get("agent_id", "")).strip() != agent_id:
        errors.append(
            f"{agent_id}: project_binding.agent_id must match agent id (got: {project_binding.get('agent_id')})"
        )
        continue

    governance_bundle = project_binding.get("governance_bundle")
    if not isinstance(governance_bundle, list) or len(governance_bundle) == 0:
        errors.append(f"{agent_id}: project_binding.governance_bundle must be a non-empty list")
        continue

    link_path = repo_dir / ATTACH_FILENAME

    payload: dict[str, Any] = {
        "status": "generated",
        "owner": "@ronny",
        "source_registry": REGISTRY_REL,
        "managed_by": MANAGED_BY,
        "spine_link_version": str(project_binding.get("spine_link_version", "")).strip(),
        "project_id": str(project_binding.get("project_id", "")).strip(),
        "repo_path": repo_path,
        "domain": str(project_binding.get("domain", "")).strip(),
        "agent_id": agent_id,
        "gate_pack": str(project_binding.get("gate_pack", "")).strip(),
        "verify_command": str(project_binding.get("verify_command", "")).strip(),
        "governance_bundle": [str(item).strip() for item in governance_bundle],
    }

    expected = dump_yaml(payload)
    current = ""
    if link_path.exists():
        current = link_path.read_text(encoding="utf-8")

    if current != expected:
        updates.append(link_path)
        if not CHECK_MODE:
            link_path.parent.mkdir(parents=True, exist_ok=True)
            link_path.write_text(expected, encoding="utf-8")

if errors:
    for msg in errors:
        print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(1)

if CHECK_MODE:
    if updates:
        print("drift detected:", file=sys.stderr)
        for path in updates:
            try:
                rel = path.relative_to(ROOT)
                print(f"- {rel}", file=sys.stderr)
            except ValueError:
                print(f"- {path}", file=sys.stderr)
        raise SystemExit(1)
    print("project attach bindings are in sync")
    raise SystemExit(0)

if updates:
    print("updated project attach bindings:")
    for path in updates:
        try:
            rel = path.relative_to(ROOT)
            print(f"- {rel}")
        except ValueError:
            print(f"- {path}")
else:
    print("no project attach changes")
PY
