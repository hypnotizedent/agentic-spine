#!/usr/bin/env bash
# aof.bootstrap — Seed environment + identity contracts from AOF profiles.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
PROFILE_DIR="$ROOT/ops/profiles"

ENV_NAME=""
PROFILE="minimal"
TARGET_DIR="$ROOT"
FORCE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  bootstrap-spine.sh --environment-name <name> [--profile <minimal|product|production>] [--target <dir>] [--force] [--dry-run]

Examples:
  bootstrap-spine.sh --environment-name mint-modules --profile product
  bootstrap-spine.sh --environment-name lab-01 --profile minimal --target /opt/spine --force
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment-name|--env-name) ENV_NAME="${2:-}"; shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --target) TARGET_DIR="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$ENV_NAME" ]] || { echo "ERROR: --environment-name is required" >&2; exit 2; }
[[ "$ENV_NAME" =~ ^[a-z0-9-]+$ ]] || { echo "ERROR: invalid environment name '$ENV_NAME' (kebab-case only)" >&2; exit 2; }
case "$PROFILE" in
  minimal|product|production) ;;
  *) echo "ERROR: invalid --profile '$PROFILE' (expected minimal|product|production)" >&2; exit 2 ;;
esac

PROFILE_FILE="$PROFILE_DIR/$PROFILE.yaml"
[[ -f "$PROFILE_FILE" ]] || { echo "ERROR: profile not found: $PROFILE_FILE" >&2; exit 1; }

ENV_FILE="$TARGET_DIR/.environment.yaml"
IDENTITY_FILE="$TARGET_DIR/.identity.yaml"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
NODE_ID="$(hostname 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' || echo node-unknown)"
SPINE_VERSION="${SPINE_VERSION:-v1.0.0}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY RUN: aof.bootstrap"
  echo "  root:      $ROOT"
  echo "  target:    $TARGET_DIR"
  echo "  profile:   $PROFILE_FILE"
  echo "  env file:  $ENV_FILE"
  echo "  id file:   $IDENTITY_FILE"
  exit 0
fi

mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/mailroom/inbox/queued" "$TARGET_DIR/mailroom/outbox" "$TARGET_DIR/mailroom/state" "$TARGET_DIR/receipts/sessions"

if [[ -f "$ENV_FILE" && "$FORCE" -ne 1 ]]; then
  echo "ERROR: $ENV_FILE exists (use --force to overwrite)" >&2
  exit 1
fi

if [[ -f "$IDENTITY_FILE" && "$FORCE" -ne 1 ]]; then
  echo "ERROR: $IDENTITY_FILE exists (use --force to overwrite)" >&2
  exit 1
fi

cp "$PROFILE_FILE" "$ENV_FILE"
if command -v yq >/dev/null 2>&1; then
  yq -i ".environment.name = \"$ENV_NAME\"" "$ENV_FILE"
  yq -i ".environment.deployed_at = \"$NOW\"" "$ENV_FILE"
else
  # Fallback when yq is absent: profile templates start with empty values.
  sed -i.bak "s/^  name: \"\"$/  name: \"$ENV_NAME\"/" "$ENV_FILE" 2>/dev/null || true
  sed -i.bak "s/^  deployed_at: \"\"$/  deployed_at: \"$NOW\"/" "$ENV_FILE" 2>/dev/null || true
  rm -f "$ENV_FILE.bak"
fi

cat > "$IDENTITY_FILE" <<EOF
version: "1.0"
identity:
  node_id: $NODE_ID
  deployed_at: $NOW
  spine_version: $SPINE_VERSION
  org: ""
  role: standalone
  environment: $ENV_NAME
EOF

echo "AOF bootstrap complete."
echo "  environment: $ENV_FILE"
echo "  identity:    $IDENTITY_FILE"
echo ""
echo "Next:"
echo "  1. ./ops/plugins/aof/bin/validate-environment.sh --environment-file \"$ENV_FILE\" --identity-file \"$IDENTITY_FILE\""
echo "  2. ./bin/ops cap run aof.contract.status"
