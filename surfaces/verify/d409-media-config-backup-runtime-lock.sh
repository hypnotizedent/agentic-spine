#!/usr/bin/env bash
# D409: media-home config backup runtime lock
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEDULE="$ROOT/ops/bindings/backup.schedule.yaml"
INVENTORY="$ROOT/ops/bindings/backup.inventory.yaml"
SSH_TARGETS="$ROOT/ops/bindings/ssh.targets.yaml"
SSH_RESOLVE="$ROOT/ops/lib/ssh-resolve.sh"
TEMPLATE="$ROOT/ops/plugins/domains/media/bin/media-config-backup.sh"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; echo "D409 FAIL: 1 check(s) failed"; exit 1; }
command -v ssh >/dev/null 2>&1 || { err "ssh not installed"; echo "D409 FAIL: 1 check(s) failed"; exit 1; }
[[ -f "$SCHEDULE" ]] || { err "missing backup.schedule.yaml"; echo "D409 FAIL: 1 check(s) failed"; exit 1; }
[[ -f "$INVENTORY" ]] || { err "missing backup.inventory.yaml"; echo "D409 FAIL: 1 check(s) failed"; exit 1; }
[[ -f "$SSH_TARGETS" ]] || { err "missing ssh.targets.yaml"; echo "D409 FAIL: 1 check(s) failed"; exit 1; }
[[ -f "$TEMPLATE" ]] || { err "missing media-home backup template: $TEMPLATE"; echo "D409 FAIL: 1 check(s) failed"; exit 1; }

# shellcheck source=/dev/null
source "$SSH_RESOLVE"

JOB_HOST="$(yq -r '.jobs[] | select(.id == "media-config-media-home-cold-sync-daily") | .host // ""' "$SCHEDULE" 2>/dev/null || true)"
JOB_SCRIPT="$(yq -r '.jobs[] | select(.id == "media-config-media-home-cold-sync-daily") | .script_ref // ""' "$SCHEDULE" 2>/dev/null || true)"
TARGET_HOST="$(yq -r '.targets[] | select(.name == "app-media-config-media-home") | .host // ""' "$INVENTORY" 2>/dev/null || true)"
TARGET_PATH="$(yq -r '.targets[] | select(.name == "app-media-config-media-home") | .base_path // ""' "$INVENTORY" 2>/dev/null || true)"
PVE_HOST="$(yq -r '.ssh.targets[] | select(.id == "pve") | .host // ""' "$SSH_TARGETS" 2>/dev/null || true)"

[[ "$JOB_HOST" == "media-home" ]] || err "backup.schedule host is '$JOB_HOST', expected 'media-home'"
[[ "$JOB_SCRIPT" == "/usr/local/bin/media-config-backup.sh" ]] || err "backup.schedule script_ref is '$JOB_SCRIPT', expected '/usr/local/bin/media-config-backup.sh'"
[[ "$TARGET_HOST" == "pve" ]] || err "backup inventory target host is '$TARGET_HOST', expected 'pve'"
[[ "$TARGET_PATH" == "/md1400/backup-cold/apps/media-config/media-home" ]] || err "backup inventory target path is '$TARGET_PATH'"
[[ -n "$PVE_HOST" ]] || err "pve host missing from ssh.targets.yaml"

read -r MEDIA_HOME_HOST MEDIA_HOME_PATH <<<"$(ssh_resolve_ssh_host_with_fallback media-home 8 || true)"
MEDIA_HOME_USER="$(yq -r '.ssh.targets[] | select(.id == "media-home") | .user // "ubuntu"' "$SSH_TARGETS" 2>/dev/null || true)"
if [[ -z "$MEDIA_HOME_HOST" || "$MEDIA_HOME_PATH" == "unreachable" ]]; then
  err "unable to resolve reachable SSH host for media-home"
else
  ok "resolved media-home via $MEDIA_HOME_PATH -> $MEDIA_HOME_HOST"
fi

if [[ "$ERRORS" -eq 0 ]]; then
  LOCAL_SUM="$(shasum -a 256 "$TEMPLATE" | awk '{print $1}')"
  REMOTE_CHECK=$(ssh -n \
    -o ConnectTimeout=8 \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "${MEDIA_HOME_USER}@${MEDIA_HOME_HOST}" \
    "sudo bash -lc '
      remote_sum=\$(sha256sum /usr/local/bin/media-config-backup.sh | awk \"{print \\\$1}\") &&
      test \"\$remote_sum\" = \"$LOCAL_SUM\" &&
      test -x /usr/local/bin/media-config-backup.sh &&
      test -f /etc/cron.d/media-config-backup &&
      grep -Fqx \"15 4 * * * root /usr/local/bin/media-config-backup.sh >> /var/log/media-config-backup.log 2>&1\" /etc/cron.d/media-config-backup &&
      ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${PVE_HOST} \"test -d ${TARGET_PATH}\"
    '" 2>&1) || {
      err "remote runtime check failed: ${REMOTE_CHECK:-unknown error}"
    }
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D409 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "media-home config backup runtime lock passed"
exit 0
