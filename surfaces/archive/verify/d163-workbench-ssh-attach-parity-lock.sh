#!/usr/bin/env bash
# TRIAGE: Align workbench SSH host aliases with spine ssh.targets + project attach metadata.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/workbench.ssh.attach.contract.yaml"

fail() {
  echo "D163 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$ROOT" "$CONTRACT" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml


root = Path(sys.argv[1]).expanduser().resolve()
contract_path = Path(sys.argv[2]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


errors: list[str] = []
violations: list[tuple[str, str]] = []

try:
    contract = load_yaml(contract_path)
except Exception as exc:
    print(f"D163 FAIL: unable to parse contract: {exc}", file=sys.stderr)
    raise SystemExit(1)

for required in ("status", "owner", "last_verified", "scope", "checks", "exceptions"):
    if required not in contract:
        errors.append(f"contract missing required field: {required}")

checks = contract.get("checks") if isinstance(contract.get("checks"), list) else []
exceptions = contract.get("exceptions") if isinstance(contract.get("exceptions"), list) else []

exception_paths: set[str] = set()
for row in exceptions:
    if not isinstance(row, dict):
        errors.append("contract exceptions[] entries must be mappings")
        continue
    for field in ("path", "reason", "owner", "expires_on", "ticket_id"):
        value = str(row.get(field, "")).strip()
        if not value:
            errors.append(f"contract exception missing required field: {field}")
    path = str(row.get("path", "")).strip()
    if path:
        exception_paths.add(path)

workbench_root = Path(str(contract.get("workbench_root", "")).strip()).expanduser()
if not workbench_root.is_dir():
    errors.append(f"workbench_root does not exist: {workbench_root}")

spine_binding_rel = str(contract.get("spine_binding", "")).strip()
ssh_config_rel = str(contract.get("workbench_ssh_config", "")).strip()
attach_rel = str(contract.get("attach_file", "")).strip()

if not spine_binding_rel:
    errors.append("contract missing spine_binding")
if not ssh_config_rel:
    errors.append("contract missing workbench_ssh_config")
if not attach_rel:
    errors.append("contract missing attach_file")

spine_binding = (root / spine_binding_rel).resolve() if spine_binding_rel else None
ssh_config = (workbench_root / ssh_config_rel).resolve() if ssh_config_rel else None
attach_file = (workbench_root / attach_rel).resolve() if attach_rel else None

if spine_binding is not None and not spine_binding.is_file():
    errors.append(f"missing spine binding: {spine_binding_rel}")
if ssh_config is not None and not ssh_config.is_file():
    errors.append(f"missing workbench ssh config: {ssh_config_rel}")


def is_excepted(path: str) -> bool:
    return path in exception_paths


check_ids = {str(row.get("id", "")).strip(): row for row in checks if isinstance(row, dict)}

if (
    "attach_file_present" in check_ids
    and bool(check_ids["attach_file_present"].get("enforce", True))
    and attach_file is not None
):
    violation_path = f"{attach_rel}::attach_file_present"
    if not attach_file.is_file() and not is_excepted(violation_path):
        violations.append((violation_path, "attach file missing"))

attach_doc = {}
if attach_file is not None and attach_file.is_file():
    try:
        attach_doc = load_yaml(attach_file)
    except Exception as exc:
        violations.append((f"{attach_rel}::attach_source_registry_match", f"invalid attach YAML: {exc}"))

if "attach_source_registry_match" in check_ids and bool(check_ids["attach_source_registry_match"].get("enforce", True)):
    expected = str(check_ids["attach_source_registry_match"].get("expected_source_registry", "")).strip()
    actual = str(attach_doc.get("source_registry", "")).strip()
    path = f"{attach_rel}::attach_source_registry_match"
    if expected and actual != expected and not is_excepted(path):
        violations.append((path, f"source_registry mismatch (expected '{expected}', got '{actual}')"))

spine_targets: dict[str, tuple[str, str]] = {}
if spine_binding is not None and spine_binding.is_file():
    try:
        spine_obj = load_yaml(spine_binding)
    except Exception as exc:
        errors.append(f"failed to parse {spine_binding_rel}: {exc}")
    else:
        ssh_obj = spine_obj.get("ssh") if isinstance(spine_obj.get("ssh"), dict) else {}
        defaults = ssh_obj.get("defaults") if isinstance(ssh_obj.get("defaults"), dict) else {}
        default_user = str(defaults.get("user", "root")).strip() or "root"
        targets = ssh_obj.get("targets") if isinstance(ssh_obj.get("targets"), list) else []
        for row in targets:
            if not isinstance(row, dict):
                continue
            sid = str(row.get("id", "")).strip()
            if not sid:
                continue
            host = str(row.get("host", "")).strip()
            user = str(row.get("user", "")).strip() or default_user
            spine_targets[sid] = (host, user)

primary_hosts: dict[str, tuple[str, str, int]] = {}
if ssh_config is not None and ssh_config.is_file():
    current_primary = ""
    current_host = ""
    current_user = ""
    current_line = 0
    for lineno, raw in enumerate(ssh_config.read_text(encoding="utf-8", errors="ignore").splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("Host "):
            parts = line.split()
            if len(parts) >= 2:
                current_primary = parts[1]
                current_host = ""
                current_user = ""
                current_line = lineno
            continue
        if not current_primary:
            continue
        if line.startswith("HostName "):
            current_host = line.split(None, 1)[1].strip()
        elif line.startswith("User "):
            current_user = line.split(None, 1)[1].strip()
            primary_hosts[current_primary] = (current_host, current_user, current_line)

if "spine_id_present_as_primary_host" in check_ids and bool(check_ids["spine_id_present_as_primary_host"].get("enforce", True)):
    for sid in sorted(spine_targets.keys()):
        path = f"{ssh_config_rel}::missing-primary-host/{sid}"
        if sid not in primary_hosts and not is_excepted(path):
            violations.append((path, f"spine target id '{sid}' missing as primary Host alias"))

if "no_untracked_primary_hosts" in check_ids and bool(check_ids["no_untracked_primary_hosts"].get("enforce", True)):
    for primary in sorted(primary_hosts.keys()):
        path = f"{ssh_config_rel}::extra-primary-host/{primary}"
        if primary not in spine_targets and not is_excepted(path):
            violations.append((path, f"primary Host alias '{primary}' not present in spine ssh.targets"))

if "host_user_parity" in check_ids and bool(check_ids["host_user_parity"].get("enforce", True)):
    for sid, (spine_host, spine_user) in sorted(spine_targets.items()):
        wb_row = primary_hosts.get(sid)
        if wb_row is None:
            continue
        wb_host, wb_user, _lineno = wb_row
        path = f"{ssh_config_rel}::host-user-mismatch/{sid}"
        mismatch_parts = []
        if wb_host != spine_host:
            mismatch_parts.append(f"host expected '{spine_host}' got '{wb_host}'")
        if wb_user != spine_user:
            mismatch_parts.append(f"user expected '{spine_user}' got '{wb_user}'")
        if mismatch_parts and not is_excepted(path):
            violations.append((path, "; ".join(mismatch_parts)))

if errors:
    for err in errors:
        print(f"D163 FAIL: contract :: {err}", file=sys.stderr)
    raise SystemExit(1)

if violations:
    for path, msg in violations:
        print(f"D163 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D163 FAIL: workbench ssh attach parity violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D163 PASS: workbench ssh attach parity lock valid")
PY
