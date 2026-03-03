---
status: planned
owner: "@ronny"
created: "2026-03-03"
scope: taxlegal-business-lifecycle-playbook
domain: tax-legal
gap: GAP-OP-1438
loop: LOOP-TAXLEGAL-W1-BUSINESS-LIFECYCLE-PLAYBOOKS-20260303
plan: PLAN-TAX-LEGAL-OPS-WORKER-20260303
---

# Tax-Legal Business Lifecycle Playbook

> Operator procedures for each business lifecycle stage from formation
> through dissolution. All procedures are research-and-coordination tasks
> that require human professional review before external action.

## 1. Formation

### Objective

Establish a new business entity with all required federal, state, and local registrations.

### Prerequisites

- Chosen entity type (LLC, Corp, etc.) and state of formation
- Jurisdiction profile resolved (default: 33441 Deerfield Beach/Broward)
- Registered agent identified
- Privacy/anonymity preferences documented (see ANONYMITY_PRIVACY_MODEL.md)

### Procedure

1. **Create case**: `taxlegal.case.intake -- --type formation --jurisdiction 33441`
2. **State formation**:
   - Research Articles of Organization requirements via Sunbiz
   - Draft articles with registered agent designation
   - Flag for attorney review before filing
3. **Federal registrations**:
   - Apply for EIN via IRS online (Form SS-4)
   - File FinCEN BOI Report within 90 days of formation
   - Evaluate and elect tax classification (default LLC, S-Corp if applicable)
4. **State tax registrations**:
   - Register for Florida sales tax if selling taxable goods/services
   - Register for reemployment tax if hiring employees
5. **Local registrations**:
   - Apply for Broward County Business Tax Receipt
   - Apply for City of Deerfield Beach Business Tax Receipt
   - Apply for Home Occupation Permit if operating from residence
   - Verify zoning compatibility
6. **Privacy setup**:
   - Configure registered agent for public-record privacy
   - Verify public exposure minimization per ANONYMITY_PRIVACY_MODEL.md
7. **Close case**: with all registration receipts as evidence

### Evidence Required

- Articles of Organization receipt
- EIN confirmation letter
- Registered agent acceptance
- All tax registration confirmations
- Local license/permit receipts
- Zoning compatibility verification

### Risk Considerations

- Missing FinCEN BOI Report: $500/day penalty after 90 days
- Missing state registration: cannot legally transact in Florida
- Missing local licenses: subject to code enforcement

---

## 2. Amendment and Address Correction

### Objective

Update business registration records when entity details change (address, members, registered agent, name).

### Prerequisites

- Entity must be in formed and active state
- Change details documented and approved by operator

### Procedure

1. **Create case**: `taxlegal.case.intake -- --type address_amendment --jurisdiction 33441`
2. **Amendment sequencing** (order matters):
   a. File state amendment with Florida DOS first (Articles of Amendment)
   b. File IRS address change (Form 8822-B) for federal records
   c. Update registered agent if changing (requires state filing + agent acceptance)
   d. Update local licenses with new information
   e. Update FinCEN BOI Report if beneficial ownership changed
3. **Verify cascade**: confirm all downstream registrations reflect changes
4. **Close case**: with all amendment receipts as evidence

### Evidence Required

- Amendment filing receipt from Florida DOS
- IRS Form 8822-B confirmation
- Updated local license receipts
- Registered agent change acceptance (if applicable)

### Risk Considerations

- Filing amendments out of order can cause rejection
- Annual Report must reflect current information (May 1 deadline)
- FinCEN BOI changes must be reported within 30 days

---

## 3. Local Compliance (Home Occupation and BTR)

### Objective

Maintain local business licensing and home occupation compliance.

### Prerequisites

- Entity formed and registered at state level
- Physical operating location identified
- Zoning district verified

### Procedure

1. **Create case**: `taxlegal.case.intake -- --type local_compliance --jurisdiction 33441`
2. **Home Occupation Permit** (if applicable):
   - Research Deerfield Beach home occupation ordinance requirements
   - Verify zoning district permits home-based business use
   - Compile application with required documentation
   - Flag for operator submission
3. **Business Tax Receipt (BTR)**:
   - Broward County BTR application
   - City of Deerfield Beach BTR application
   - Verify business classification code matches actual operations
4. **Renewal tracking**:
   - Register recurring deadlines per deadline contract
   - Set escalation windows for approaching renewals
5. **Close case**: with all permit/receipt confirmations

### Evidence Required

- Home Occupation Permit confirmation
- Broward County BTR receipt
- Deerfield Beach BTR receipt
- Zoning compatibility verification

### Risk Considerations

- Operating without BTR is a code enforcement violation
- Home occupation restrictions vary by zoning district
- BTR renewal deadline: September 30 (Broward County)

---

## 4. Enforcement Remediation

### Objective

Respond to code enforcement, zoning violations, or regulatory notices within required timelines.

### Prerequisites

- Original enforcement notice received and digitized
- Response deadline identified from notice

### Procedure

1. **Create case**: `taxlegal.case.intake -- --type enforcement_remediation --jurisdiction 33441`
2. **Notice intake**:
   - Scan/photograph original notice
   - Extract notice date, case number, violation description, response deadline
   - Register notice as source in case registry
3. **Assessment**:
   - Identify cited ordinance or regulation from primary sources
   - Assess factual accuracy of violation claims
   - Classify severity (see enforcement response contract)
4. **Response drafting**:
   - Draft formal response with citation-backed arguments
   - Include corrective action plan if violation is confirmed
   - Include dispute evidence if violation is contested
   - Flag for attorney review (MANDATORY)
5. **Attorney review**: attorney reviews and signs off on response
6. **Operator submission**: operator submits response via required channel
7. **Corrective action**: complete corrective actions per approved plan
8. **Closure**: obtain closure confirmation from issuing agency

### Evidence Required

- Original notice (scan or photo)
- Cited ordinance primary source
- Assessment with citations
- Response letter with attorney sign-off
- Submission receipt
- Corrective action evidence
- Agency closure confirmation

### Risk Considerations

- Missing response deadline can result in fines, liens, or escalated enforcement
- Attorney review is mandatory for all enforcement responses
- Some violations have mandatory hearing dates that cannot be rescheduled

### Detailed Contract

See: `ops/bindings/taxlegal.enforcement.response.contract.yaml`

---

## 5. Dissolution and Closure

### Objective

Properly dissolve a business entity and close all registrations, accounts, and tax obligations.

### Prerequisites

- Dissolution decision documented and approved
- All current filings and taxes must be current (no overdue obligations)
- No open enforcement cases

### Procedure

1. **Create case**: `taxlegal.case.intake -- --type closure --jurisdiction 33441`
2. **Pre-dissolution checklist**:
   - Verify all filings are current (annual report, tax returns)
   - Verify no open enforcement cases
   - Verify no outstanding tax obligations
3. **Federal closeout**:
   - File final federal tax return with dissolution checkbox
   - File final payroll tax returns if applicable
   - Cancel EIN (IRS Letter 147C)
4. **State closeout**:
   - File Articles of Dissolution with Florida DOS
   - File final Florida tax returns
   - Cancel sales tax registration
   - Cancel reemployment tax registration if applicable
5. **Local closeout**:
   - Cancel Broward County BTR
   - Cancel Deerfield Beach BTR
   - Cancel Home Occupation Permit if applicable
6. **Account closeout**:
   - Close business bank accounts
   - Cancel business insurance policies
   - Notify registered agent of dissolution
7. **Record retention**:
   - Activate retention policy per retention contract
   - Archive all case artifacts per SLA profile
8. **Close case**: with all closeout confirmations

### Evidence Required

- Final tax return receipts (federal, state)
- Articles of Dissolution receipt
- License/permit cancellation confirmations
- Bank account closure confirmations
- Registered agent notification receipt

### Risk Considerations

- Failing to file dissolution can result in continued annual report obligations
- Final tax returns have specific deadlines relative to dissolution date
- Record retention requirements survive dissolution (7 years under balanced SLA)

---

## Cross-References

- Anonymity/privacy model: `docs/governance/domains/tax-legal/ANONYMITY_PRIVACY_MODEL.md`
- Case templates: `docs/governance/domains/tax-legal/CASE_TEMPLATES.md`
- Lifecycle events contract: `ops/bindings/taxlegal.lifecycle.events.contract.yaml`
- Enforcement response contract: `ops/bindings/taxlegal.enforcement.response.contract.yaml`
- Jurisdiction profile: `ops/bindings/taxlegal.jurisdiction.profile.33441.yaml`
- Deadline contract: `ops/bindings/taxlegal.deadline.contract.yaml`
