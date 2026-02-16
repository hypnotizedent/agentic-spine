# AOF Standards Pack v1

**Version:** 1.0
**Status:** Proposed
**Owner:** @ronny
**Created:** 2026-02-16
**Proposal Input:** `docs/governance/_audits/AOF_STANDARDS_PROPOSAL_INPUT_20260216.md`

---

## Purpose

Define eight enforceable standards that close root-cause drift across past/present/future spine surfaces. Each standard specifies:

- **What** must be true (declarative)
- **How** to enforce (capability/gate/contract)
- **When** to roll out (P1/P2/P3 phases)
- **How** to verify (acceptance tests)

---

## Standards Index

| ID | Standard | Impact | Phase | Enforce Mechanism |
|----|----------|--------|-------|-------------------|
| STD-001 | Boundary Authority | HIGH | P1 | Contract + Gate |
| STD-002 | Runtime Path Resolution | HIGH | P1 | Contract |
| STD-003 | Boundary Audit Strictness | HIGH | P1 | Capability |
| STD-004 | Catalog Freshness | MEDIUM | P2 | Capability |
| STD-005 | Mutation Atomicity | MEDIUM | P2 | Gate |
| STD-006 | CLI Shape | LOW | P3 | Lint |
| STD-007 | Output Vocabulary | MEDIUM | P3 | Gate |
| STD-008 | Topology Quality | MEDIUM | P2 | Capability |

---

## Standard Definitions

### STD-001: Boundary Authority Standard

**Declaration:**
> The authoritative surface set MUST be defined in exactly ONE source: `spine.boundary.baseline.yaml`. All other references (README.md, AGENTS.md, etc.) MUST derive from this source.

**Rationale:**
Currently three files define "what spine owns" independently:
- `README.md` (lines 14-19)
- `spine.boundary.baseline.yaml` (lines 13-21)
- `mailroom.runtime.contract.yaml` (implicit via tracked_contract_root)

This allows drift where a new surface is added to one but not others.

**Enforcement:**
| Mechanism | Implementation |
|-----------|----------------|
| Contract | Add `boundary_source: ops/bindings/spine.boundary.baseline.yaml` to `spine.schema.conventions.yaml` |
| Gate | Add D130 gate to validate README.md authoritative_surfaces matches baseline |
| Capability | Extend `surface-boundary-audit` to report baseline vs derived mismatches |

**Acceptance Tests:**
```bash
# AT-001.1: Baseline is single source of truth
yq e '.authoritative_surfaces' ops/bindings/spine.boundary.baseline.yaml \
  | diff - <(grep "^  - " README.md | sed 's/  - //')

# AT-001.2: Gate D130 exists and passes
./bin/ops cap run verify.core.run | grep "D130 PASS"

# AT-001.3: Adding new surface to baseline requires README update
# (manual test: add entry to baseline, run gate, expect FAIL)
```

**Rollout:** P1 (Week 1-2)

---

### STD-002: Runtime Path Resolution Standard

**Declaration:**
> All runtime path references MUST resolve from `mailroom.runtime.contract.yaml` as the authoritative source. Hardcoded paths are prohibited except in the contract itself.

**Rationale:**
`spine.boundary.baseline.yaml` hardcodes `/Users/ronnyworks/code/.runtime/spine-mailroom` while `mailroom.runtime.contract.yaml` defines `runtime_root`. If runtime_root changes, baseline is out of sync.

**Enforcement:**
| Mechanism | Implementation |
|-----------|----------------|
| Contract | Add `${runtime_root}` variable support to `spine.boundary.baseline.yaml` |
| Lint | Grep for hardcoded `/.runtime/` outside contract files |
| Capability | Extend `surface-boundary-audit` to validate runtime paths match contract |

**Acceptance Tests:**
```bash
# AT-002.1: No hardcoded runtime paths outside contracts
rg -n '/Users/ronnyworks/code/.runtime/' ops/ --include="*.sh" --include="*.yaml" \
  | grep -v mailroom.runtime.contract.yaml | grep -v spine.boundary.baseline.yaml

# AT-002.2: Contract defines runtime_root
yq e '.runtime_root' ops/bindings/mailroom.runtime.contract.yaml | grep -q "^/"

# AT-002.3: Boundary baseline uses runtime_root reference (post-migration)
yq e '.rules.runtime_only[0].destination' ops/bindings/spine.boundary.baseline.yaml \
  | grep -q "runtime_root"
```

**Rollout:** P1 (Week 1-2)

---

### STD-003: Boundary Audit Strictness Standard

**Declaration:**
> The boundary audit MUST validate `tracked_exceptions` entries exist in the tracked repo. Entries that no longer exist MUST be reported as warnings (not failures) with cleanup recommendations.

**Rationale:**
`mailroom.runtime.contract.yaml` defines 13 `tracked_exceptions` (lines 11-23) but `surface-boundary-audit` only scans rule globs, ignoring the exceptions list entirely.

**Enforcement:**
| Mechanism | Implementation |
|-----------|----------------|
| Capability | Extend `surface-boundary-audit` with `--check-tracked-exceptions` flag |
| Report | Add "Tracked Exceptions Audit" section to boundary audit output |

**Acceptance Tests:**
```bash
# AT-003.1: Audit includes tracked exceptions validation
./ops/plugins/surface/bin/surface-boundary-audit --check-tracked-exceptions 2>&1 \
  | grep -q "tracked_exceptions:"

# AT-003.2: Missing exception file produces warning
rm -f mailroom/inbox/.keep 2>/dev/null || true
./ops/plugins/surface/bin/surface-boundary-audit --check-tracked-exceptions --no-fail 2>&1 \
  | grep -q "WARN.*mailroom/inbox/.keep"
touch mailroom/inbox/.keep  # restore

# AT-003.3: All valid exceptions pass
./ops/plugins/surface/bin/surface-boundary-audit --check-tracked-exceptions
```

**Rollout:** P1 (Week 1-2)

---

### STD-004: Catalog Freshness Standard

**Declaration:**
> Domain capability catalogs MUST have `last_synced` date within 14 days of current date, OR be explicitly exempted in `binding.freshness.exemptions.yaml`.

**Rationale:**
`capability.domain.catalog.yaml` has `last_synced` per domain but no gate validates freshness. Stale catalogs may miss new capabilities added to `ops/capabilities.yaml`.

**Enforcement:**
| Mechanism | Implementation |
|-----------|----------------|
| Gate | Add D131 gate to validate catalog freshness |
| Capability | Add `catalog.domain.sync` to refresh catalogs |
| Exemption | Catalog already exempted in freshness policy |

**Acceptance Tests:**
```bash
# AT-004.1: Gate D131 validates catalog freshness
./bin/ops cap run verify.core.run | grep "D131 PASS"

# AT-004.2: Stale catalog entry fails gate
# (manual test: change last_synced to 30 days ago, expect FAIL)

# AT-004.3: Fresh catalog passes
yq e '.domains[0].last_synced = "'"$(date +%Y-%m-%d)"'"' -i ops/bindings/capability.domain.catalog.yaml
./bin/ops cap run verify.core.run | grep "D131 PASS"
```

**Rollout:** P2 (Week 3-4)

---

### STD-005: Mutation Atomicity Standard

**Declaration:**
> All scripts that modify YAML bindings with `yq e -i` or `sed -i` MUST acquire `git-lock` before mutation. The only exceptions are test scripts and scripts that operate on gitignored runtime paths.

**Rationale:**
11 mutating scripts do not use git-lock, creating race conditions in multi-agent sessions.

**Enforcement:**
| Mechanism | Implementation |
|-----------|----------------|
| Gate | Add D132 gate to check git-lock usage in mutating scripts |
| Lint | Pre-commit hook to validate new mutating scripts use git-lock |
| Library | Document git-lock requirement in `ops/lib/README.md` |

**Acceptance Tests:**
```bash
# AT-005.1: All mutating scripts use git-lock
for script in $(rg -l 'yq e -i' ops/plugins/*/bin/*); do
  grep -q 'git-lock.sh' "$script" || echo "MISSING: $script"
done

# AT-005.2: Gate D132 passes
./bin/ops cap run verify.core.run | grep "D132 PASS"

# AT-005.3: New mutating script fails without git-lock (pre-commit test)
# (manual test: create script with yq e -i but no git-lock, expect hook FAIL)
```

**Rollout:** P2 (Week 3-4)

---

### STD-006: CLI Shape Standard

**Declaration:**
> New CLI commands MUST accept named flags (`--id`, `--status`, etc.) as primary interface. Positional arguments MAY be retained as backward-compatible aliases. Commands without named flags MUST have explicit exemption in `spine.schema.conventions.yaml`.

**Rationale:**
~40% of CLI commands use positional args as primary, violating the declared `preferred_argument_style: named_flags`.

**Enforcement:**
| Mechanism | Implementation |
|-----------|----------------|
| Lint | Add `cli-usage-lint` capability to check Usage: blocks |
| Exemption | Track commands with positional-only in conventions file |
| Documentation | Update ops/README.md with named flags requirement |

**Acceptance Tests:**
```bash
# AT-006.1: Lint capability exists
./bin/ops cap run cli.usage.lint 2>&1 | grep -q "cli usage lint"

# AT-006.2: New command with positional-only fails lint
# (manual test: create script with `Usage: cmd <arg>` only, expect WARN)

# AT-006.3: Named flags pass lint
# (manual test: create script with `Usage: cmd --id <ID>`, expect PASS)
```

**Rollout:** P3 (Week 5-6)

---

### STD-007: Output Vocabulary Standard

**Declaration:**
> All verify scripts and mutating capabilities MUST use standardized output prefixes:
> - `D## PASS` / `D## FAIL` for gate results
> - `WARN:` for non-blocking issues
> - `STOP:` for blocking preconditions
> - `ERROR:` for unexpected failures
> 
> Scripts MUST NOT use custom error functions or inconsistent casing.

**Rationale:**
1072 lines of error/output prefixes with multiple patterns (FAIL, D## FAIL, err(), echo "FAIL:", etc.).

**Enforcement:**
| Mechanism | Implementation |
|-----------|----------------|
| Gate | Add D133 gate to validate output vocabulary |
| Template | Provide `output-vocabulary.sh` library with standard functions |
| Migration | Batch-fix existing scripts in P3 |

**Acceptance Tests:**
```bash
# AT-007.1: Gate D133 validates vocabulary
./bin/ops cap run verify.core.run | grep "D133 PASS"

# AT-007.2: Non-standard prefix detected
# (manual test: add `echo "Error:"` to verify script, expect FAIL)

# AT-007.3: Library provides standard functions
grep -q 'fail()' ops/lib/output-vocabulary.sh
grep -q 'warn()' ops/lib/output-vocabulary.sh
grep -q 'stop()' ops/lib/output-vocabulary.sh
```

**Rollout:** P3 (Week 5-6)

---

### STD-008: Topology Quality Standard

**Declaration:**
> Gate execution topology metadata MUST be valid:
> - `path_triggers` entries MUST reference existing files/directories
> - `capability_prefixes` MUST match at least one capability in registry
> - `depends_on` domains MUST exist in topology

**Rationale:**
`gate.execution.topology.yaml` defines 14 domains with path_triggers and capability_prefixes but no gate validates these references.

**Enforcement:**
| Mechanism | Implementation |
|-----------|----------------|
| Capability | Extend `gate-topology-validate` to check path existence |
| Gate | Add D134 gate for topology metadata validation |
| Report | Include topology quality in `surface.audit.full` output |

**Acceptance Tests:**
```bash
# AT-008.1: Gate D134 validates topology metadata
./bin/ops cap run verify.core.run | grep "D134 PASS"

# AT-008.2: Invalid path_trigger detected
# (manual test: add path_trigger: "nonexistent/path/", expect FAIL)

# AT-008.3: Capability prefix matches registry
# (verify all prefixes have matching capabilities)
```

**Rollout:** P2 (Week 3-4)

---

## Rollout Phases

### Phase 1 (P1) — Week 1-2: Foundation

| Standard | Work Items | Effort |
|----------|------------|--------|
| STD-001 | Add D130 gate, baseline→README sync | 2h |
| STD-002 | Add runtime_root variable support | 2h |
| STD-003 | Extend boundary audit with tracked_exceptions | 2h |

**Gate Addition:** D130 (Boundary Authority), D131 (Catalog Freshness) — but only D130 enforced in P1.

**Exit Criteria:**
- D130 PASS
- All runtime paths resolve from contract
- Boundary audit reports tracked exceptions status

---

### Phase 2 (P2) — Week 3-4: Quality Gates

| Standard | Work Items | Effort |
|----------|------------|--------|
| STD-004 | Add D131 gate (already added in P1, enforce in P2) | 1h |
| STD-005 | Add D132 gate, fix 11 missing git-lock scripts | 3h |
| STD-008 | Add D134 gate, extend gate-topology-validate | 2h |

**Gate Addition:** D132 (Mutation Atomicity), D134 (Topology Quality)

**Exit Criteria:**
- D131 PASS (catalog freshness)
- D132 PASS (git-lock coverage)
- D134 PASS (topology metadata)

---

### Phase 3 (P3) — Week 5-6: Polish

| Standard | Work Items | Effort |
|----------|------------|--------|
| STD-006 | Add cli.usage.lint capability | 2h |
| STD-007 | Add D133 gate, batch-fix existing scripts | 4h |

**Gate Addition:** D133 (Output Vocabulary)

**Exit Criteria:**
- cli.usage.lint capability available
- D133 PASS (vocabulary normalized)

---

## Explicit Non-Goals

1. **Field alias migration** — Tracked separately in `SPINE_CONVENTIONS_PHASE2B_BACKLOG_20260216.md`
2. **Status enum alignment** — Tracked separately in Phase 2C
3. **Breaking CLI changes** — Named flags added as aliases only
4. **Multi-agent write protocol** — Out of scope (relies on mailroom/proposals)
5. **Performance optimization** — No runtime improvements in this pack
6. **New domain onboarding** — Standards apply to existing domains only
7. **Workbench boundary changes** — Only spine-side enforcement

---

## Acceptance Test Summary

| Standard | Test ID | Description |
|----------|---------|-------------|
| STD-001 | AT-001.1 | Baseline matches README |
| STD-001 | AT-001.2 | D130 gate exists and passes |
| STD-002 | AT-002.1 | No hardcoded runtime paths |
| STD-002 | AT-002.2 | Contract defines runtime_root |
| STD-003 | AT-003.1 | Audit validates tracked_exceptions |
| STD-003 | AT-003.2 | Missing exception produces warning |
| STD-004 | AT-004.1 | D131 validates catalog freshness |
| STD-005 | AT-005.1 | All mutating scripts use git-lock |
| STD-005 | AT-005.2 | D132 gate passes |
| STD-006 | AT-006.1 | cli.usage.lint capability exists |
| STD-007 | AT-007.1 | D133 validates vocabulary |
| STD-007 | AT-007.3 | Standard library exists |
| STD-008 | AT-008.1 | D134 validates topology metadata |

---

## Gate Addition Summary

| Gate ID | Standard | Description | Phase |
|---------|----------|-------------|-------|
| D130 | STD-001 | Boundary authority consistency | P1 |
| D131 | STD-004 | Catalog freshness validation | P2 |
| D132 | STD-005 | Mutation atomicity (git-lock) | P2 |
| D133 | STD-007 | Output vocabulary normalization | P3 |
| D134 | STD-008 | Topology metadata quality | P2 |

---

## References

- **Input Analysis:** `docs/governance/_audits/AOF_STANDARDS_PROPOSAL_INPUT_20260216.md`
- **Conventions Audit:** `docs/governance/_audits/SPINE_CONVENTIONS_CANONICAL_AUDIT_20260216.md`
- **Conventions Backlog:** `docs/governance/_audits/SPINE_CONVENTIONS_PHASE2B_BACKLOG_20260216.md`
- **Schema Conventions:** `ops/bindings/spine.schema.conventions.yaml`
- **Boundary Baseline:** `ops/bindings/spine.boundary.baseline.yaml`
- **Gate Topology:** `ops/bindings/gate.execution.topology.yaml`

---

*Standards Pack v1 — Proposed 2026-02-16*
