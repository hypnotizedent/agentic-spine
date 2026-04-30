#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPS="$ROOT/ops/capabilities.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
CONTRACT="$ROOT/ops/bindings/l2.courthouse.safe.contract.yaml"
AUTH_BIN="$ROOT/ops/plugins/core/authority/bin"

fail() { echo "D454 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -f "$CAPS" ]] || fail "missing capabilities registry"
[[ -f "$MANIFEST" ]] || fail "missing plugin manifest"
[[ -f "$CONTRACT" ]] || fail "missing courthouse/safe contract"

for script in secret-reference-status token-custody-status secret-injection-status domain-core-status courthouse-safe-status; do
  [[ -x "$AUTH_BIN/$script" ]] || fail "missing executable authority script: $script"
  "$AUTH_BIN/$script" --self-check >/dev/null
done

python3 - "$CAPS" "$MANIFEST" "$CONTRACT" "$AUTH_BIN" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

import yaml

caps_path = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
contract_path = Path(sys.argv[3])
auth_bin = Path(sys.argv[4])
root = caps_path.parents[1]
north_star_path = root / "NORTH_STAR.md"


def fail(message: str) -> None:
    print(f"D454 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


required = {
    "secret.reference.status": "secret-reference-status",
    "token.custody.status": "token-custody-status",
    "secret.injection.status": "secret-injection-status",
    "domain.core.status": "domain-core-status",
    "courthouse.safe.status": "courthouse-safe-status",
}

caps = load_yaml(caps_path).get("capabilities") or {}
for cap, script in required.items():
    row = caps.get(cap)
    if not isinstance(row, dict):
        fail(f"missing capability: {cap}")
    if row.get("safety") != "read-only":
        fail(f"{cap} must remain read-only")
    if row.get("approval") != "auto":
        fail(f"{cap} must remain auto-approved readback")
    if row.get("script_path") != f"./ops/plugins/core/authority/bin/{script}":
        fail(f"{cap} script_path drifted")

manifest = load_yaml(manifest_path)
authority = next((p for p in manifest.get("plugins", []) if isinstance(p, dict) and p.get("name") == "authority"), None)
if not authority:
    fail("authority plugin missing")
scripts = set(authority.get("scripts") or [])
cap_ids = set(authority.get("capabilities") or [])
for cap, script in required.items():
    if f"bin/{script}" not in scripts:
        fail(f"authority manifest missing script: {script}")
    if cap not in cap_ids:
        fail(f"authority manifest missing capability: {cap}")

contract = load_yaml(contract_path)
contract_text = contract_path.read_text(encoding="utf-8")
north_star = north_star_path.read_text(encoding="utf-8")
if "The canonical repository is self-hosted Gitea at `git.ronny.works`." not in north_star:
    fail("NORTH_STAR.md Distribution Authority no longer declares Gitea canonical")
if "GitHub (`github.com/hypnotizedent/agentic-spine`) is a read-only" not in north_star:
    fail("NORTH_STAR.md Distribution Authority no longer declares GitHub read-only distribution")
reconciliation = contract.get("authority_reconciliation") or {}
if "NORTH_STAR.md" not in (reconciliation.get("governing_sources") or []):
    fail("contract must cite NORTH_STAR.md as governing source for repo distribution truth")
if "Gitea is canonical source/courthouse; GitHub is publication/distribution." != reconciliation.get("resolved_model"):
    fail("contract resolved_model must preserve Gitea canonical / GitHub publication truth")
if "operator_answers:" in contract_text:
    fail("contract must not present old Q&A as direct implementation authority; use authority_reconciliation")
boundary = contract.get("boundary") or {}
if boundary.get("courthouse_holds") is None or boundary.get("safe_holds") is None:
    fail("contract must name courthouse_holds and safe_holds")
for forbidden in ["secret values", "token values", "live credential dumps"]:
    if forbidden not in (boundary.get("forbidden_readback") or []):
        fail(f"contract missing forbidden readback: {forbidden}")
classes = contract.get("courthouse_classes") or {}
for klass in ["gitea-self-hosted"]:
    if klass not in classes:
        fail(f"contract missing first-class courthouse class: {klass}")
for forbidden_class in ["github-cloud-public", "github-cloud-private"]:
    if forbidden_class in classes:
        fail(f"GitHub must not be encoded as courthouse class: {forbidden_class}")
publication_classes = contract.get("publication_classes") or {}
for klass in ["github-cloud-publication-public", "github-cloud-publication-private"]:
    if klass not in publication_classes:
        fail(f"contract missing publication class: {klass}")
if "github_mirror_class" in contract_text:
    fail("contract must not collapse GitHub into github_mirror_class")
domains = contract.get("domains") or {}
for domain in ["forge", "safe"]:
    if domain not in domains:
        fail(f"contract missing domain card: {domain}")
if domains.get("forge", {}).get("courthouse_class") != "gitea-self-hosted":
    fail("forge domain must expose courthouse_class=gitea-self-hosted")
for domain in ["github-public", "github-private"]:
    row = domains.get(domain) or {}
    if row.get("class") != "publication":
        fail(f"{domain} must be publication class, not courthouse")
    if row.get("courthouse_class") != "gitea-self-hosted":
        fail(f"{domain} must point back to gitea-self-hosted as canonical source")

flag_checks = {
    "secret-reference-status": ["--service", "__no_such_service__", "--json"],
    "secret-reference-status::namespace": ["--namespace", "/spine/platform/security", "--json"],
    "secret-reference-status::unsanctioned": ["--unsanctioned-only", "--json"],
    "token-custody-status": ["--class", "RUNNER_TOKEN", "--json"],
    "token-custody-status::rotation": ["--no-rotation-posture", "--json"],
    "secret-injection-status": ["--unsanctioned-only", "--json"],
    "domain-core-status": ["--summary", "--json"],
}
for label, args in flag_checks.items():
    script = label.split("::", 1)[0]
    proc = subprocess.run([str(auth_bin / script), *args], text=True, capture_output=True)
    if proc.returncode != 0:
        fail(f"{script} flag check failed for {args}: {proc.stderr or proc.stdout}")

forge = subprocess.run([str(auth_bin / "domain-core-status"), "--domain", "forge", "--json"], text=True, capture_output=True)
if forge.returncode != 0:
    fail(f"domain-core-status --domain forge failed: {forge.stderr or forge.stdout}")
forge_payload = yaml.safe_load(forge.stdout)
forge_rows = forge_payload.get("rows") or []
if not forge_rows or not forge_rows[0].get("courthouse_class"):
    fail("domain.core.status --domain forge must emit courthouse_class")
for field in ["token_classes", "backup_targets", "restore_proof_age", "observability_probe", "runtime_node_placement"]:
    if field not in forge_rows[0]:
        fail(f"domain.core.status --domain forge missing {field}")

secret_patterns = [
    re.compile(r"eyJ[A-Za-z0-9_-]{20,}"),
    re.compile(r"-----BEGIN [A-Z ]+-----"),
    re.compile(r"(password|secret|token|api_key)\s*[:=]\s*['\"]?[A-Za-z0-9_./+=-]{12,}", re.I),
]
for script in required.values():
    proc = subprocess.run([str(auth_bin / script)], text=True, capture_output=True)
    if proc.returncode != 0:
        fail(f"{script} failed: {proc.stderr or proc.stdout}")
    for pattern in secret_patterns:
        if pattern.search(proc.stdout):
            fail(f"{script} output looks like it disclosed a secret value")

print("D454 PASS: L2 courthouse/safe readbacks are registered, read-only, and value-silent")
PY
