---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-24
scope: maker-tools
---

# Maker Tools Governance

> **Purpose:** Governance rules for the maker tools plugin — digital-to-physical
> toolkit for MintPrints (QR codes, barcodes, labels, NFC tags, asset tagging).

---

## Scope

The maker plugin covers tools that bridge digital data to physical artifacts:

| Category | What It Covers |
|----------|---------------|
| encoding | QR codes, barcodes (Code128, EAN, DataMatrix, UPC) |
| tagging | Image compositing, label template overlays, annotation |
| printing | Thermal label printing (Brother QL, Zebra ZPL) |
| nfc | NFC tag read/write |

---

## Binding SSOT

**Canonical source:** `ops/bindings/maker.tools.inventory.yaml`

This binding is the single growth point for all maker tools. Each tool declares:
- `id` — unique tool identifier
- `category` — one of: encoding, tagging, printing, nfc
- `install_method` — brew, pip, or apt
- `probe` — runtime probe command (never hardcode installed state)
- `enabled` — whether the tool is active
- `hardware_required` — whether physical hardware is needed

---

## Adding Tool N+1

```
1. Add entry to ops/bindings/maker.tools.inventory.yaml
2. Install: brew/pip/apt install <tool>
3. Set enabled: true in binding
4. (Optional) Add capability wrapper script + register in capabilities.yaml
5. Verify: ops cap run maker.tools.status && ops cap run spine.verify
```

No other files change. The binding is the single growth point.

---

## Hardware Policy

Tools requiring physical hardware (printers, NFC readers) follow graceful degradation:

- **Binding:** `hardware_required: true`, `enabled: false` by default
- **Runtime:** scripts exit STOP (code 2) when hardware not available
- **Promotion:** flip `enabled: true` only after hardware is connected and probe passes
- **No false positives:** disabled tools never appear as MISSING in status output

---

## Output Policy

All maker tool outputs go to: `mailroom/outbox/maker/`

This path is declared in the binding (`output_dir`) and enforced by capability scripts.
No outputs to `/tmp/`, home directory, or other ad-hoc locations.

---

## Capabilities

| Capability | Safety | Approval | Purpose |
|-----------|--------|----------|---------|
| `maker.tools.status` | read-only | auto | Inventory probe |
| `maker.qr.generate` | read-only | auto | QR code generation |
| `maker.label.print` | mutating | manual | Thermal label printing |

---

## Drift Gate

**D40** validates:
- Binding file exists and parses as valid YAML
- At least one tool defined
- All plugin scripts exist and are executable
- No `set -x` debug tracing
- No secret/token printing
- No hardcoded `/tmp/` output paths

---

## Verification

```bash
# Tool inventory
./bin/ops cap run maker.tools.status

# QR generation
./bin/ops cap run maker.qr.generate "https://mintprints.co"

# Drift gates (D1-D57)
./bin/ops cap run spine.verify
```
