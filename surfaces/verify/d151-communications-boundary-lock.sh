#!/usr/bin/env bash
# TRIAGE: Communications boundary: Outlook must not be automated sender, stale domains must not appear, stack contract mailboxes must not stub to Outlook.
# D151: Communications boundary lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
violations=0

fail_v() {
  echo "  VIOLATION: $*" >&2
  violations=$((violations + 1))
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "D151 FAIL: missing command: $1" >&2; exit 1; }
}

need_cmd yq

STACK_CONTRACT="$ROOT/ops/bindings/communications.stack.contract.yaml"
PROVIDER_CONTRACT="$ROOT/ops/bindings/communications.providers.contract.yaml"

# --- Check 1: Stack contract send_test must NOT use Outlook ---
send_test_sender=$(yq e '.pilot.send_test.default_sender' "$STACK_CONTRACT" 2>/dev/null)
send_test_recipient=$(yq e '.pilot.send_test.default_recipient' "$STACK_CONTRACT" 2>/dev/null)

if [[ "$send_test_sender" == *"@mintprints.com" ]]; then
  fail_v "send_test.default_sender uses Outlook domain: $send_test_sender"
fi
if [[ "$send_test_recipient" == *"@mintprints.com" ]]; then
  fail_v "send_test.default_recipient uses Outlook domain: $send_test_recipient"
fi

# --- Check 2: Stack contract mailboxes must NOT all stub to Outlook ---
outlook_stubs=0
mailbox_count=0
while IFS= read -r addr; do
  [[ -z "$addr" || "$addr" == "null" ]] && continue
  mailbox_count=$((mailbox_count + 1))
  if [[ "$addr" == *"@mintprints.com" ]]; then
    outlook_stubs=$((outlook_stubs + 1))
  fi
done < <(yq e '.pilot.mailboxes[].address' "$STACK_CONTRACT" 2>/dev/null)

if [[ $mailbox_count -gt 0 && $outlook_stubs -eq $mailbox_count ]]; then
  fail_v "all $mailbox_count stack contract mailboxes stub to Outlook (@mintprints.com)"
fi

# --- Check 3: Lane C mailboxes must be @spine.ronny.works (not stale @spine.mintprints.co) ---
while IFS= read -r addr; do
  [[ -z "$addr" || "$addr" == "null" ]] && continue
  if [[ "$addr" == *"@spine.mintprints.co" ]]; then
    fail_v "stale Lane C domain in mailbox: $addr (should be @spine.ronny.works)"
  fi
done < <(yq e '.pilot.mailboxes[].address' "$STACK_CONTRACT" 2>/dev/null)

if [[ "$send_test_sender" == *"@spine.mintprints.co" ]]; then
  fail_v "send_test.default_sender uses stale Lane C domain: $send_test_sender"
fi
if [[ "$send_test_recipient" == *"@spine.mintprints.co" ]]; then
  fail_v "send_test.default_recipient uses stale Lane C domain: $send_test_recipient"
fi

# --- Check 4: No mintprintshop.com in any contract sender field ---
for contract in "$STACK_CONTRACT" "$PROVIDER_CONTRACT"; do
  if grep -q "mintprintshop\.com" "$contract" 2>/dev/null; then
    fail_v "stale domain mintprintshop.com found in $(basename "$contract")"
  fi
done

# --- Check 5: Provider contract must agree on Resend execution mode ---
top_mode=$(yq e '.transactional.mode' "$PROVIDER_CONTRACT" 2>/dev/null)
resend_mode=$(yq e '.providers.resend.execution_mode' "$PROVIDER_CONTRACT" 2>/dev/null)
if [[ "$top_mode" != "$resend_mode" && "$top_mode" != "null" && "$resend_mode" != "null" ]]; then
  fail_v "provider contract mode mismatch: transactional.mode=$top_mode vs resend.execution_mode=$resend_mode"
fi

# --- Check 6: Stack contract transactional.mode must match provider ---
stack_tx_mode=$(yq e '.transactional.mode' "$STACK_CONTRACT" 2>/dev/null)
if [[ "$stack_tx_mode" != "$top_mode" && "$stack_tx_mode" != "null" && "$top_mode" != "null" ]]; then
  fail_v "stack contract transactional.mode=$stack_tx_mode disagrees with provider contract mode=$top_mode"
fi

# --- Result ---
if [[ $violations -gt 0 ]]; then
  echo "D151 FAIL: communications boundary lock: $violations violation(s) detected" >&2
  exit 1
fi

echo "D151 PASS: communications boundary lock valid (checks=6, violations=0)"
