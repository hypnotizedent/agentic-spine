---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: onboarding-lifecycles
---

# Onboarding Playbook

> Canonical onboarding flow for new VM, agent, capability, tool/plugin, and folder/surface.

---

## 0) Global Start Gate

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops status
./bin/ops cap run spine.verify
```

Stop if:
- baseline verify is not green.
- onboarding scope is multi-step and not loop/proposal anchored.

---

## 1) New VM Onboarding

Commands:

```bash
./bin/ops cap run infra.vm.provision --help
./bin/ops cap run infra.vm.bootstrap --help
./bin/ops cap run vm.governance.audit
./bin/ops cap run spine.verify
```

Required updates:
- `ops/bindings/vm.lifecycle.yaml`
- infra identity/service/health/backup bindings + SSOT docs per VM contract

Stop gates:
- D35/D37/D45/D54/D69 failures
- missing VM lifecycle entry

Definition of done:
- VM appears governed in `vm.governance.audit`
- required SSOT/binding surfaces updated
- `spine.verify` pass receipt captured

---

## 2) New Agent Onboarding

Commands:

```bash
./bin/ops cap run monolith.search "agents.registry.yaml"
./bin/ops cap run spine.verify
```

Required updates:
- `ops/agents/<agent-id>.contract.md`
- `ops/bindings/agents.registry.yaml` (agent + routing rule)
- implementation path declared and valid

Stop gates:
- D49 fail
- contract missing for registered agent

Definition of done:
- agent contract + registry + routing are consistent
- onboarding receipt links governance + implementation surfaces
- `spine.verify` passes

---

## 3) New Capability Onboarding

Commands:

```bash
./bin/ops cap list
./bin/ops cap run spine.verify
```

Required updates:
- `ops/capabilities.yaml`
- `ops/plugins/MANIFEST.yaml`
- `ops/bindings/capability_map.yaml`
- tests or explicit D81 exemption

Stop gates:
- D63/D67/D81 failures
- capability registered without plugin/script parity

Definition of done:
- capability is discoverable via `ops cap list`
- registry/map/manifest are in parity
- verify gates pass with receipts

---

## 4) New Tooling/Plugin Onboarding

Commands:

```bash
./bin/ops cap run mcp.inventory.status
./bin/ops cap run spine.verify
```

Required updates:
- tool inventory binding (`cli.tools.inventory.yaml` or domain-specific inventory)
- plugin manifest/capability wiring if spine-native plugin
- governance doc pointer if new operator surface

Stop gates:
- D44 inventory drift
- D81 plugin test regression
- missing secrets preconditions for API-touching tools

Definition of done:
- tool/plugin appears in inventory and obeys governance boundary
- usage path is receipt-capable
- verify passes

---

## 5) New Folder/Surface Onboarding

Commands:

```bash
./bin/ops cap run monolith.tree
./bin/ops cap run spine.verify
```

Required updates:
- governance structure/index registration
- allowlist/policy binding if executable or sensitive
- archive classification if non-runtime

Stop gates:
- D17/D42/D76-D80 failures
- runtime-like surface created in workbench or home root

Definition of done:
- new surface classified and indexed
- enforcement path defined (existing or new gate)
- no path/case/authority drift

---

## 6) Final Closeout (All Onboarding)

```bash
./bin/ops cap run spine.verify
./bin/ops cap run agent.session.closeout
```

Definition of done:
- verify green
- receipts captured
- closeout traceability complete
