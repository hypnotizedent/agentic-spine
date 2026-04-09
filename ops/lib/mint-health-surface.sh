#!/usr/bin/env bash
# Thin compatibility wrapper — authority lives in mint-modules.
# See: mint-modules/scripts/lib/mint-health-surface.sh
#
# This file is sourced (not executed). It delegates to the Mint-local copy
# which is the canonical authority for Mint health surface helpers.
_MINT_MODULES_ROOT="${MINT_MODULES_ROOT:-$HOME/code/mint-modules}"
# shellcheck source=/dev/null
source "$_MINT_MODULES_ROOT/scripts/lib/mint-health-surface.sh"
