---
jd_id: "00"
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
---

# Johnny Decimal Documentation System

The Agentic Spine uses the Johnny Decimal system for documentation organization.

## What is Johnny Decimal?

Johnny Decimal is a system for organizing files and folders using a numeric ID scheme:
- **XX** = Area (10-99)
- **XX.YY** = Category within area
- **XX.YY.ZZ** = Individual document

## Our Taxonomy

| Area | Name | Path |
|------|------|------|
| 10-19 | Core Contracts | docs/core/ |
| 20-29 | Governance | docs/governance/ |
| 30-39 | Brain | docs/brain/ |
| 40-49 | Legacy | docs/legacy/ |
| 50-59 | Pillars | docs/pillars/ |
| 60-69 | Product | docs/product/ |
| 70-79 | Planning | docs/planning/ |
| 90-99 | Root/Meta | ./ |

## How to Use

1. **Find a doc by ID**: Check `docs/jd/00.00-index.md` or `ops/bindings/docs.johnny_decimal.yaml`
2. **Add a new doc**: 
   - Assign the next available ID in the appropriate area
   - Update both the binding file and index
3. **Verify coverage**: Run `./bin/ops cap run docs.jd.status`

## Status Check

```bash
./bin/ops cap run docs.jd.status
```

This checks:
- No duplicate JD IDs
- All in-scope docs have JD IDs
- All exclusions are explicit
