#!/usr/bin/env bash
# TRIAGE: Remove hardcoded runtime user@host strings, keep vm.lifecycle ssh_user parity with ssh.targets, enforce secrets runway strict onboarding, ensure deploy.method coverage, and keep calendar operator artifacts fresh.
# D162: operator smoothness lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/operator.smoothness.contract.yaml"

fail() {
  echo "D162 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$ROOT" "$CONTRACT" <<'PY'
from __future__ import annotations

import re
import sys
import time
from pathlib import Path

import yaml


root = Path(sys.argv[1]).expanduser().resolve()
contract_path = Path(sys.argv[2]).expanduser().resolve()


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


errors: list[str] = []

try:
    contract = load_yaml(contract_path)
except Exception as exc:
    print(f"D162 FAIL: unable to parse contract: {exc}", file=sys.stderr)
    raise SystemExit(1)

ssh_identity = contract.get("ssh_identity") if isinstance(contract.get("ssh_identity"), dict) else {}
forbidden = ssh_identity.get("forbidden_runtime_userhost_patterns")
allowlist = ssh_identity.get("allowlist_paths")

if not isinstance(forbidden, list) or not forbidden:
    errors.append("operator.smoothness ssh_identity.forbidden_runtime_userhost_patterns must be a non-empty list")
forbidden = [str(v).strip() for v in (forbidden or []) if str(v).strip()]

if not isinstance(allowlist, list):
    errors.append("operator.smoothness ssh_identity.allowlist_paths must be a list")
allowlist_set = {str(v).strip() for v in (allowlist or []) if str(v).strip()}

ssh_binding_rel = str(ssh_identity.get("authoritative_binding", "")).strip()
vm_binding_rel = str(ssh_identity.get("vm_parity_binding", "")).strip()
if not ssh_binding_rel:
    errors.append("operator.smoothness ssh_identity.authoritative_binding is required")
if not vm_binding_rel:
    errors.append("operator.smoothness ssh_identity.vm_parity_binding is required")

ssh_binding = (root / ssh_binding_rel).resolve() if ssh_binding_rel else None
vm_binding = (root / vm_binding_rel).resolve() if vm_binding_rel else None

# ---------------------------------------------------------------------------
# Check 1: no hardcoded forbidden runtime user@host patterns in governed files
# ---------------------------------------------------------------------------
governed_files: list[Path] = []
for fixed in [root / "ops/capabilities.yaml", root / "ops/bindings/routing.dispatch.yaml"]:
    if fixed.is_file():
        governed_files.append(fixed)

plugins_root = root / "ops/plugins"
if plugins_root.is_dir():
    for path in plugins_root.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        if "/bin/" not in rel:
            continue
        if path.name.endswith(".legacy"):
            continue
        governed_files.append(path)

seen_rel: set[str] = set()
deduped_files: list[Path] = []
for path in governed_files:
    rel = path.relative_to(root).as_posix()
    if rel in seen_rel:
        continue
    seen_rel.add(rel)
    if rel in allowlist_set:
        continue
    deduped_files.append(path)

pattern_hits: list[str] = []
for prefix in forbidden:
    user = prefix[:-1] if prefix.endswith("@") else prefix
    if not user:
        continue
    regex = re.compile(rf"\b{re.escape(user)}@[A-Za-z0-9._:-]+")
    for path in deduped_files:
        rel = path.relative_to(root).as_posix()
        try:
            lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
        except Exception as exc:
            errors.append(f"failed to read governed file {rel}: {exc}")
            continue
        for lineno, line in enumerate(lines, start=1):
            for match in regex.finditer(line):
                token = match.group(0)
                pattern_hits.append(f"{rel}:{lineno}: {token}")

if pattern_hits:
    preview = "; ".join(pattern_hits[:8])
    if len(pattern_hits) > 8:
        preview += f"; ... +{len(pattern_hits) - 8} more"
    errors.append(f"forbidden hardcoded runtime user@host pattern(s) detected: {preview}")

# ---------------------------------------------------------------------------
# Check 2: vm.lifecycle ssh_user parity for active VMs with ssh_target
# ---------------------------------------------------------------------------
if ssh_binding is not None and vm_binding is not None:
    if not ssh_binding.is_file():
        errors.append(f"missing ssh binding: {ssh_binding_rel}")
    if not vm_binding.is_file():
        errors.append(f"missing vm lifecycle binding: {vm_binding_rel}")

if ssh_binding is not None and ssh_binding.is_file() and vm_binding is not None and vm_binding.is_file():
    try:
        ssh_obj = load_yaml(ssh_binding)
        vm_obj = load_yaml(vm_binding)
    except Exception as exc:
        errors.append(f"failed to parse vm/ssh bindings: {exc}")
    else:
        ssh_defaults = ssh_obj.get("ssh", {}).get("defaults", {}) if isinstance(ssh_obj.get("ssh"), dict) else {}
        default_user = str(ssh_defaults.get("user", "root")).strip() or "root"
        ssh_targets = ssh_obj.get("ssh", {}).get("targets", []) if isinstance(ssh_obj.get("ssh"), dict) else []
        target_user: dict[str, str] = {}
        if isinstance(ssh_targets, list):
            for row in ssh_targets:
                if not isinstance(row, dict):
                    continue
                tid = str(row.get("id", "")).strip()
                if not tid:
                    continue
                user = str(row.get("user", "")).strip() or default_user
                target_user[tid] = user

        vms = vm_obj.get("vms", [])
        if not isinstance(vms, list):
            errors.append("vm.lifecycle binding vms must be a list")
        else:
            mismatches: list[str] = []
            for row in vms:
                if not isinstance(row, dict):
                    continue
                status = str(row.get("status", "")).strip().lower()
                if status != "active":
                    continue
                ssh_target = str(row.get("ssh_target", "")).strip()
                if not ssh_target:
                    continue
                vm_user = str(row.get("ssh_user", "")).strip()
                hostname = str(row.get("hostname", row.get("id", "unknown"))).strip() or "unknown"
                expected_user = target_user.get(ssh_target)
                if expected_user is None:
                    mismatches.append(f"{hostname}: ssh_target '{ssh_target}' missing in ssh.targets")
                    continue
                if vm_user != expected_user:
                    mismatches.append(
                        f"{hostname}: ssh_user='{vm_user}' expected='{expected_user}' (ssh_target={ssh_target})"
                    )
            if mismatches:
                errors.append("vm.lifecycle ssh_user parity violations: " + "; ".join(mismatches[:8]))

# ---------------------------------------------------------------------------
# Check 3: strict_unregistered_secret_keys must be true
# ---------------------------------------------------------------------------
runway_path = root / "ops/bindings/secrets.runway.contract.yaml"
if not runway_path.is_file():
    errors.append("missing secrets runway contract: ops/bindings/secrets.runway.contract.yaml")
else:
    try:
        runway_obj = load_yaml(runway_path)
    except Exception as exc:
        errors.append(f"failed to parse secrets runway contract: {exc}")
    else:
        defaults = runway_obj.get("defaults")
        flag = None
        if isinstance(defaults, dict):
            flag = defaults.get("strict_unregistered_secret_keys")
        if flag is not True:
            errors.append(
                "secrets.runway.contract defaults.strict_unregistered_secret_keys must be true"
            )

# ---------------------------------------------------------------------------
# Check 4: deploy.method contract coverage for enabled compose target/stacks
# ---------------------------------------------------------------------------
deploy_section = contract.get("deploy_method") if isinstance(contract.get("deploy_method"), dict) else {}
deploy_contract_rel = str(deploy_section.get("method_contract", "")).strip()
compose_targets_rel = str(deploy_section.get("source_targets", "")).strip()
allowed_methods_raw = deploy_section.get("allowed_methods")
allowed_methods = {str(v).strip() for v in (allowed_methods_raw or []) if str(v).strip()}

if not deploy_contract_rel:
    errors.append("operator.smoothness deploy_method.method_contract is required")
if not compose_targets_rel:
    errors.append("operator.smoothness deploy_method.source_targets is required")
if not allowed_methods:
    errors.append("operator.smoothness deploy_method.allowed_methods must be non-empty")

deploy_contract_path = (root / deploy_contract_rel).resolve() if deploy_contract_rel else None
compose_targets_path = (root / compose_targets_rel).resolve() if compose_targets_rel else None

if deploy_contract_path is not None and not deploy_contract_path.is_file():
    errors.append(f"missing deploy method contract: {deploy_contract_rel}")
if compose_targets_path is not None and not compose_targets_path.is_file():
    errors.append(f"missing compose targets binding: {compose_targets_rel}")

if (
    deploy_contract_path is not None
    and compose_targets_path is not None
    and deploy_contract_path.is_file()
    and compose_targets_path.is_file()
):
    try:
        deploy_obj = load_yaml(deploy_contract_path)
        compose_obj = load_yaml(compose_targets_path)
    except Exception as exc:
        errors.append(f"failed to parse deploy/compose contracts: {exc}")
    else:
        compose_targets = compose_obj.get("targets")
        if not isinstance(compose_targets, dict):
            errors.append("docker.compose.targets.yaml targets must be a map")
            compose_targets = {}

        enabled_pairs: set[tuple[str, str]] = set()
        for target, target_row in compose_targets.items():
            if not isinstance(target_row, dict):
                continue
            enabled = target_row.get("enabled", True)
            if enabled is False:
                continue
            stacks = target_row.get("stacks")
            if not isinstance(stacks, list):
                continue
            for stack in stacks:
                if not isinstance(stack, dict):
                    continue
                name = str(stack.get("name", "")).strip()
                if name:
                    enabled_pairs.add((str(target), name))

        entries = deploy_obj.get("entries")
        if not isinstance(entries, list):
            errors.append("deploy.method.contract entries must be a list")
            entries = []

        covered_pairs: set[tuple[str, str]] = set()
        bad_methods: list[str] = []
        for row in entries:
            if not isinstance(row, dict):
                continue
            target = str(row.get("target", "")).strip()
            stack = str(row.get("stack", "")).strip()
            method = str(row.get("method", "")).strip()
            if target and stack:
                covered_pairs.add((target, stack))
            if method and allowed_methods and method not in allowed_methods:
                bad_methods.append(f"{target}/{stack}:{method}")

        missing_pairs = sorted(enabled_pairs - covered_pairs)
        if missing_pairs:
            preview = ", ".join([f"{t}/{s}" for t, s in missing_pairs[:12]])
            if len(missing_pairs) > 12:
                preview += f", ... +{len(missing_pairs) - 12} more"
            errors.append(f"deploy.method contract missing enabled target/stack coverage: {preview}")
        if bad_methods:
            errors.append(
                "deploy.method contract contains disallowed methods: " + ", ".join(bad_methods[:12])
            )

# ---------------------------------------------------------------------------
# Check 5: calendar operator outputs must exist and be fresh
# ---------------------------------------------------------------------------
calendar_section = (
    contract.get("calendar_operator_surface")
    if isinstance(contract.get("calendar_operator_surface"), dict)
    else {}
)
required_outputs = calendar_section.get("required_outputs")
if not isinstance(required_outputs, list) or not required_outputs:
    errors.append("operator.smoothness calendar_operator_surface.required_outputs must be a non-empty list")
required_outputs = [str(v).strip() for v in (required_outputs or []) if str(v).strip()]

freshness_window = calendar_section.get("freshness_window_minutes", 720)
if not isinstance(freshness_window, int) or freshness_window < 0:
    errors.append("calendar_operator_surface freshness_window_minutes must be a non-negative integer")
    freshness_window = 720

missing_outputs: list[str] = []
stale_outputs: list[str] = []
now = int(time.time())
for rel in required_outputs:
    path = (root / rel).resolve()
    if not path.exists():
        missing_outputs.append(rel)
        continue
    age_minutes = int((now - int(path.stat().st_mtime)) / 60)
    if age_minutes > freshness_window:
        stale_outputs.append(f"{rel} ({age_minutes}m)")

if missing_outputs:
    errors.append("calendar operator outputs missing: " + ", ".join(missing_outputs))
if stale_outputs:
    errors.append(
        "calendar operator outputs stale beyond freshness window "
        f"({freshness_window}m): " + ", ".join(stale_outputs)
    )


if errors:
    for row in errors:
        print(f"  FAIL: {row}", file=sys.stderr)
    print(f"D162 FAIL: operator smoothness lock violations ({len(errors)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D162 PASS: operator smoothness lock valid")
PY
