---
status: planned
owner: "@ronny"
created: "2026-03-03"
scope: taxlegal-anonymity-privacy-model
domain: tax-legal
gap: GAP-OP-1439
loop: LOOP-TAXLEGAL-W1-BUSINESS-LIFECYCLE-PLAYBOOKS-20260303
plan: PLAN-TAX-LEGAL-OPS-WORKER-20260303
---

# Tax-Legal Anonymity and Privacy Model

> Distinguishes public-record privacy from legal reporting obligations.
> Frames anonymity guidance as public-surface minimization, not concealment
> from legal or federal reporting requirements.

## 1. Guiding Principle

The goal of this model is **public-surface minimization**: reducing unnecessary
exposure of personal information in public records and business registrations
while maintaining full compliance with all legal, tax, and federal reporting
obligations.

This is explicitly **NOT**:
- Concealment from government agencies
- Evasion of legal reporting requirements
- Hiding beneficial ownership from FinCEN or tax authorities
- Creating untraceable entity structures

## 2. Public vs. Reporting Privacy

### 2.1 Public-Record Privacy (Minimizable)

These are records visible to the general public through online searches,
state databases, and public records requests. Minimization strategies are
legitimate and common.

| Record | Default Exposure | Minimization Strategy |
|--------|------------------|----------------------|
| Articles of Organization | Member/manager name and address on Florida DOS | Use registered agent address as principal address |
| Annual Report | Member/manager name and address on Sunbiz | Use registered agent address; some states allow agent-only filings |
| Business Tax Receipt | Owner name and business address | Home occupation: may use business name only in some jurisdictions |
| Domain WHOIS | Registrant name, email, address | WHOIS privacy (standard with most registrars) |
| Mailing address | Physical address in business correspondence | Use PO Box or registered agent for business mail |

### 2.2 Legal Reporting Privacy (Non-Minimizable)

These are records required by law for government agencies. Full and accurate
disclosure is mandatory regardless of public-surface preferences.

| Obligation | Agency | Detail |
|-----------|--------|--------|
| FinCEN BOI Report | FinCEN | Full beneficial ownership with SSN/passport, address, DOB |
| Federal Tax Returns | IRS | Full EIN, SSN, income reporting |
| State Tax Returns | Florida DOR | Full EIN, business details, revenue |
| Employment Tax | IRS/FL | Full SSN for employees |
| Sales Tax Registration | Florida DOR | Full business details |

### 2.3 The Bright Line

**Public records**: minimize personal exposure through legitimate structural choices.
**Government reporting**: full disclosure, no minimization, no exceptions.

Any research output that suggests reducing or obscuring government reporting
obligations is a boundary violation per the agent boundary contract.

## 3. Structural Privacy Choices

### 3.1 Registered Agent

A registered agent provides a primary mechanism for public-record privacy:

- Agent's address appears as the entity's principal address on state filings
- Reduces personal home address exposure in public databases
- Registered agent services range from ~$50-300/year
- Florida requires a registered agent with a physical FL address

**Research scope**: the agent may research registered agent options and present
comparison tables. The agent must NOT recommend a specific provider or make
representations about privacy guarantees.

### 3.2 Business Address Strategy

| Option | Public Exposure | Compliance Impact | Cost |
|--------|----------------|-------------------|------|
| Home address | Full home address in public records | Fully compliant | $0 |
| Registered agent address | Agent address in public records | Compliant if agent is valid FL address | $50-300/yr |
| Virtual office | Virtual office address in public records | Compliant if real commercial address | $100-500/yr |
| PO Box | PO Box for mailing only | Not valid for state principal address | $50-200/yr |

### 3.3 Entity Naming

- Business name is always public record
- Operating under a different name (DBA/fictitious name) requires Florida fictitious name registration
- Personal name can be kept out of public-facing business materials but remains in government filings

## 4. PII Handling in Case Artifacts

All privacy controls for case artifact PII are governed by the privacy contract:
`ops/bindings/taxlegal.privacy.contract.yaml`

Key rules:
- SSN, EIN, DOB, account numbers: secret path references only (never in artifacts)
- Full addresses: secret path references for personal addresses
- Business addresses: may appear in case artifacts if they are the registered/public address
- Email addresses: may appear in case artifacts with redact-before-log policy

## 5. Privacy Review Triggers

The following case conditions trigger a privacy review checkpoint:

1. Any case involving entity formation (registered agent and address strategy decisions)
2. Any case involving address amendment (public record exposure changes)
3. Any enforcement response (verify response does not unnecessarily expose personal information)
4. Any case where personal and business addresses are identical
5. Any case involving beneficial ownership reporting changes

## 6. External AI Transcript Policy

When ingesting AI-generated privacy/anonymity guidance:

1. Treat all claims about privacy protections as hypotheses
2. Verify claimed privacy mechanisms against actual state statutes and agency rules
3. Never accept claims about "anonymous LLC" structures without primary-source verification
4. Flag any suggestions that approach government reporting concealment as `rejected`

## 7. Cross-References

- Agent boundary contract: `docs/governance/TAX_LEGAL_AGENT_BOUNDARY.md`
- Privacy contract: `ops/bindings/taxlegal.privacy.contract.yaml`
- Lifecycle playbook: `docs/governance/domains/tax-legal/BUSINESS_LIFECYCLE_PLAYBOOK.md`
- Case templates: `docs/governance/domains/tax-legal/CASE_TEMPLATES.md`
