---
status: planned
owner: "@ronny"
created: "2026-03-03"
scope: taxlegal-case-templates
domain: tax-legal
gap: GAP-OP-1440
loop: LOOP-TAXLEGAL-W1-BUSINESS-LIFECYCLE-PLAYBOOKS-20260303
plan: PLAN-TAX-LEGAL-OPS-WORKER-20260303
---

# Tax-Legal Case Templates

> Repeatable packet generation templates by lifecycle stage.
> Each template defines the standard directory structure, required files,
> checklist items, and evidence expectations for a given case type.

## 1. Case Directory Structure (All Types)

```text
mailroom/state/cases/tax-legal/
  CASE-TAXLEGAL-YYYYMMDD-####/
    intake.md                       # Case intake summary and triage
    checklist.yaml                  # Required actions checklist
    source-registry.lock.yaml       # Pinned source versions for this case
    sources/                        # Local source snapshots
      federal/                      # IRS, FinCEN sources
      florida/                      # Florida DOR, Sunbiz sources
      local/                        # County and city sources
    research/                       # Research outputs
      answers.md                    # Citation-anchored research findings
      citations.json                # Structured citation records
    drafts/                         # Draft outputs
      filing-packet.md              # Assembled filing packet draft
      attorney-cpa-memo.md          # Review memo for professional
      outbound-emails/              # Draft communications (preview-only)
    risk/                           # Risk assessment
      risk-classification.yaml      # Green/yellow/red classification
    receipt.md                      # Case lifecycle receipt (evidence chain)
```

## 2. Template: Formation Case

### intake.md

```markdown
# Case Intake: Formation

- **Case ID**: CASE-TAXLEGAL-YYYYMMDD-####
- **Case Type**: formation
- **Created**: YYYY-MM-DD
- **Jurisdiction Profile**: 33441 (Deerfield Beach, FL / Broward County)
- **Status**: intake

## Entity Details

- **Entity Type**: [LLC / Corp / other]
- **Entity Name**: [proposed name]
- **State of Formation**: Florida
- **Principal Address**: ref:infisical:[path]
- **Registered Agent**: [name / service]

## Privacy Preferences

- **Public-Record Minimization**: [yes / no]
- **Registered Agent Address**: [use agent address as principal: yes / no]
- **See**: ANONYMITY_PRIVACY_MODEL.md

## Intake Checklist

See: checklist.yaml
```

### checklist.yaml

```yaml
case_id: CASE-TAXLEGAL-YYYYMMDD-####
case_type: formation
jurisdiction_profile: "33441"

steps:
  - id: FRM-01
    action: "File Articles of Organization with Florida DOS"
    jurisdiction: florida_state
    agency: "Florida Division of Corporations"
    status: pending
    evidence_path: null
    deadline: null

  - id: FRM-02
    action: "Apply for EIN (Form SS-4)"
    jurisdiction: federal
    agency: IRS
    status: pending
    evidence_path: null
    deadline: null

  - id: FRM-03
    action: "File FinCEN BOI Report"
    jurisdiction: federal
    agency: FinCEN
    status: pending
    evidence_path: null
    deadline: "90 days from formation"

  - id: FRM-04
    action: "Designate registered agent"
    jurisdiction: florida_state
    agency: "Florida Division of Corporations"
    status: pending
    evidence_path: null

  - id: FRM-05
    action: "Draft operating agreement"
    jurisdiction: internal
    status: pending
    evidence_path: null
    human_review_required: true

  - id: FRM-06
    action: "Evaluate and elect tax classification"
    jurisdiction: federal
    agency: IRS
    status: pending
    evidence_path: null
    human_review_required: true
    deadline: "75 days from formation (if S-Corp election)"

  - id: FRM-07
    action: "Register for Florida sales tax (if applicable)"
    jurisdiction: florida_state
    agency: "Florida Department of Revenue"
    status: pending
    conditional: true

  - id: FRM-08
    action: "Apply for Broward County Business Tax Receipt"
    jurisdiction: broward_county
    status: pending
    evidence_path: null

  - id: FRM-09
    action: "Apply for Deerfield Beach Business Tax Receipt"
    jurisdiction: deerfield_beach
    status: pending
    evidence_path: null

  - id: FRM-10
    action: "Apply for Home Occupation Permit (if home-based)"
    jurisdiction: deerfield_beach
    status: pending
    conditional: true

  - id: FRM-11
    action: "Verify zoning compatibility"
    jurisdiction: deerfield_beach
    status: pending
    evidence_path: null
```

## 3. Template: Enforcement Remediation Case

### intake.md

```markdown
# Case Intake: Enforcement Remediation

- **Case ID**: CASE-TAXLEGAL-YYYYMMDD-####
- **Case Type**: enforcement_remediation
- **Created**: YYYY-MM-DD
- **Jurisdiction Profile**: 33441 (Deerfield Beach, FL / Broward County)
- **Status**: intake

## Notice Details

- **Notice Date**: [date on notice]
- **Agency**: [issuing agency]
- **Case/Violation Number**: [from notice]
- **Violation Description**: [from notice]
- **Response Deadline**: [from notice]
- **Notice Scan Path**: sources/local/[filename]

## Severity Assessment

- **Initial Severity**: [low / medium / high / critical]
- **Penalty Risk**: [description]

## Response Timeline

- **Response Due**: [date]
- **Days Remaining**: [calculated]
- **Attorney Review Required**: yes (MANDATORY)
```

### checklist.yaml

```yaml
case_id: CASE-TAXLEGAL-YYYYMMDD-####
case_type: enforcement_remediation
jurisdiction_profile: "33441"

steps:
  - id: ENF-01
    action: "Scan and digitize original notice"
    status: pending
    evidence_path: null

  - id: ENF-02
    action: "Extract notice metadata (date, case number, violation, deadline)"
    status: pending

  - id: ENF-03
    action: "Identify cited ordinance or regulation"
    status: pending
    evidence_path: null
    source_id: null

  - id: ENF-04
    action: "Assess factual accuracy of violation claims"
    status: pending
    evidence_path: "research/assessment.md"

  - id: ENF-05
    action: "Classify severity and response urgency"
    status: pending
    evidence_path: "risk/risk-classification.yaml"

  - id: ENF-06
    action: "Draft response letter with citation-backed arguments"
    status: pending
    evidence_path: "drafts/response-letter.md"
    human_review_required: true

  - id: ENF-07
    action: "Draft corrective action plan (if violation confirmed)"
    status: pending
    evidence_path: "drafts/corrective-action-plan.md"
    conditional: true

  - id: ENF-08
    action: "Attorney review and sign-off"
    status: pending
    evidence_path: "drafts/attorney-cpa-memo.md"
    human_review_required: true

  - id: ENF-09
    action: "Operator submits response to agency"
    status: pending
    operator_action_required: true

  - id: ENF-10
    action: "Complete corrective actions per plan"
    status: pending
    conditional: true

  - id: ENF-11
    action: "Obtain agency closure confirmation"
    status: pending
    evidence_path: null
```

## 4. Template: Address Amendment Case

### checklist.yaml

```yaml
case_id: CASE-TAXLEGAL-YYYYMMDD-####
case_type: address_amendment
jurisdiction_profile: "33441"

steps:
  - id: AMD-01
    action: "File Articles of Amendment with Florida DOS (state first)"
    jurisdiction: florida_state
    status: pending
    evidence_path: null

  - id: AMD-02
    action: "File IRS address change (Form 8822-B)"
    jurisdiction: federal
    status: pending
    evidence_path: null

  - id: AMD-03
    action: "Update registered agent (if changing)"
    jurisdiction: florida_state
    status: pending
    conditional: true

  - id: AMD-04
    action: "Update Broward County BTR with new information"
    jurisdiction: broward_county
    status: pending
    evidence_path: null

  - id: AMD-05
    action: "Update Deerfield Beach BTR with new information"
    jurisdiction: deerfield_beach
    status: pending
    evidence_path: null

  - id: AMD-06
    action: "Update FinCEN BOI Report (if beneficial ownership changed)"
    jurisdiction: federal
    status: pending
    conditional: true
    deadline: "30 days from change"

  - id: AMD-07
    action: "Verify all downstream registrations reflect changes"
    status: pending
```

## 5. Template: Dissolution Case

### checklist.yaml

```yaml
case_id: CASE-TAXLEGAL-YYYYMMDD-####
case_type: closure
jurisdiction_profile: "33441"

steps:
  - id: DIS-01
    action: "Verify all filings are current (no overdue obligations)"
    status: pending

  - id: DIS-02
    action: "Verify no open enforcement cases"
    status: pending

  - id: DIS-03
    action: "File final federal tax return with dissolution checkbox"
    jurisdiction: federal
    status: pending
    evidence_path: null

  - id: DIS-04
    action: "File final Florida tax returns"
    jurisdiction: florida_state
    status: pending
    evidence_path: null

  - id: DIS-05
    action: "File Articles of Dissolution with Florida DOS"
    jurisdiction: florida_state
    status: pending
    evidence_path: null

  - id: DIS-06
    action: "Cancel Florida sales tax registration"
    jurisdiction: florida_state
    status: pending
    conditional: true

  - id: DIS-07
    action: "Cancel Broward County Business Tax Receipt"
    jurisdiction: broward_county
    status: pending
    evidence_path: null

  - id: DIS-08
    action: "Cancel Deerfield Beach Business Tax Receipt"
    jurisdiction: deerfield_beach
    status: pending
    evidence_path: null

  - id: DIS-09
    action: "Cancel Home Occupation Permit (if applicable)"
    jurisdiction: deerfield_beach
    status: pending
    conditional: true

  - id: DIS-10
    action: "Close business bank accounts"
    status: pending
    evidence_path: null
    operator_action_required: true

  - id: DIS-11
    action: "Notify registered agent of dissolution"
    status: pending
    evidence_path: null

  - id: DIS-12
    action: "Activate retention policy for all case artifacts"
    status: pending
```

## 6. Risk Classification Template

### risk/risk-classification.yaml

```yaml
case_id: CASE-TAXLEGAL-YYYYMMDD-####
assessed_at: "YYYY-MM-DDTHH:MM:SSZ"
assessed_by: taxlegal-researcher

overall_risk: green  # green | yellow | red

factors:
  - factor: citation_coverage
    assessment: complete  # complete | partial | missing
    detail: "All claims backed by primary source citations"

  - factor: source_conflicts
    assessment: none  # none | minor | major
    detail: "No conflicting sources identified"

  - factor: unknown_claims
    assessment: none  # none | few | many
    detail: "No unknown claims on critical requirements"

  - factor: deadline_proximity
    assessment: safe  # safe | approaching | urgent | overdue
    detail: "No deadlines within escalation window"

  - factor: pii_exposure
    assessment: clean  # clean | flagged | incident
    detail: "Privacy scan passed with no issues"

  - factor: enforcement_severity
    assessment: null  # low | medium | high | critical | null
    detail: "Not an enforcement case"

open_questions: []
human_review_required: false
```

## Cross-References

- Case lifecycle contract: `ops/bindings/taxlegal.case.lifecycle.contract.yaml`
- Lifecycle events contract: `ops/bindings/taxlegal.lifecycle.events.contract.yaml`
- Enforcement response contract: `ops/bindings/taxlegal.enforcement.response.contract.yaml`
- Lifecycle playbook: `docs/governance/domains/tax-legal/BUSINESS_LIFECYCLE_PLAYBOOK.md`
- Jurisdiction profile: `ops/bindings/taxlegal.jurisdiction.profile.33441.yaml`
