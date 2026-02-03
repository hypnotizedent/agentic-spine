---
description: Query RAG knowledge base about Mint OS or infrastructure
argument-hint: <question>
allowed-tools: Bash(mint:*)
---

Query the RAG knowledge base with: `mint ask "$ARGUMENTS"`

The RAG has ~9,300 vectors indexed from:
- mint-os/ (187 docs)
- infrastructure/ (122 docs)
- Governance docs, runbooks, schemas

Use this BEFORE guessing about:
- How features work
- Schema definitions
- What failed before
- Deployment procedures
