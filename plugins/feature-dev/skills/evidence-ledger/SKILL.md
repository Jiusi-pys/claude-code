---
name: Evidence Ledger
description: This skill should be used when the user asks to "collect evidence", "validate claims", "check confidence scores", "use evidence ledger", "track discovery findings", "verify codebase facts", or needs guidance on structured evidence collection during feature development. Provides the Evidence Ledger data model, confidence calculation rules, and validation workflow.
version: 0.1.0
---

# Evidence Ledger for Feature Development

## Overview

The Evidence Ledger is a structured system for collecting, validating, and tracking evidence during the Discovery phase of feature development. It ensures all claims about the codebase are backed by verifiable evidence with explicit confidence scores.

**Core Principle**: Correct direction can progress slowly; wrong direction is not allowed to start.

## When to Use

- Starting feature development with `/feature-dev`
- Collecting evidence about existing codebase patterns
- Validating claims before making architectural decisions
- Ensuring sufficient confidence before implementation

## Core Components

### 1. Research Question

Defines the investigation scope with budgets and constraints. Created at the start of Phase 1.

```json
{
  "rq_id": "rq_{timestamp}_{feature_slug}",
  "title": "[Feature description]",
  "scope": {
    "domain_constraints": ["src/auth", "src/middleware"],
    "exclude_patterns": ["node_modules", "dist", "*.test.ts"]
  },
  "budgets": {
    "max_sources": 40,
    "max_claims": 20,
    "max_agent_steps": 80
  },
  "status": "in_progress"
}
```

### 2. Sources

Normalized references to files, documentation, or external resources. Each source has a unique ID based on content hash for deduplication.

**Quality Tiers:**
- **A**: Primary source code, official documentation, test files
- **B**: Configuration files, README, inline comments
- **C**: External documentation, third-party references
- **D**: Inferred/derived sources, git history patterns

### 3. Claims

Falsifiable statements about the codebase. Each claim starts with confidence = 0.0 until validated.

**Claim Types:**
- `pattern`: Recurring code pattern or convention
- `architecture`: Structural/design decision
- `dependency`: External or internal dependency relationship
- `convention`: Naming, style, or organizational convention
- `constraint`: Limitation or requirement
- `behavior`: Runtime behavior or data flow

**Status Values:**
- `open`: Not yet validated
- `supported`: Evidence supports (confidence >= 0.75)
- `refuted`: Evidence contradicts
- `mixed`: Conflicting evidence
- `insufficient`: Not enough evidence

### 4. Evidence Items

Specific excerpts or references supporting or contradicting claims:
- Exact quotes with file:line locators
- Context (surrounding lines)
- Credibility assessment (tier, replicability, freshness)

### 5. Links

Relationships between claims and evidence:
- `supports`: Evidence directly supports the claim
- `contradicts`: Evidence contradicts the claim
- `qualifies`: Evidence adds nuance/conditions
- `exemplifies`: Evidence is a specific example
- `context`: Evidence provides background

## Confidence Scoring

### Threshold

**0.75 is REQUIRED to proceed to the next phase. No exceptions.**

### Calculation Formula

```
support = 1 - product(1 - strength_i) for all supporting links
contradict = 1 - product(1 - strength_j) for all contradicting links
confidence = clamp(support * (1 - contradict), 0, 1)
```

This formula has diminishing returns for additional evidence (prevents "evidence stacking") and properly handles contradictions.

### Confidence Scale

- **0.00-0.25**: Insufficient evidence - BLOCK
- **0.26-0.50**: Weak support - BLOCK
- **0.51-0.74**: Moderate support - BLOCK
- **0.75-0.89**: Strong support - PASS
- **0.90-1.00**: Excellent support - PASS

### Link Strength Guidelines

- **0.9-1.0**: Direct, unambiguous evidence from primary source
- **0.7-0.89**: Strong evidence with minor interpretation
- **0.5-0.69**: Moderate evidence, some assumptions required
- **0.3-0.49**: Weak evidence, significant inference needed
- **0.0-0.29**: Circumstantial, mostly inferred

## Blocking Logic

### Block Conditions (ANY triggers block)

1. Any critical claim has confidence < 0.75
2. Unresolved contradictions exist
3. Key sources cannot be verified
4. Coverage of research question < 70%

### User Options When Blocked

1. **Supplement Investigation**: Launch additional explorers
2. **Acknowledge Assumptions**: Proceed with caveats (user accepts risk)
3. **Reduce Scope**: Only keep high-confidence claims

## Storage Location

Evidence is stored in `.claude/evidence/sessions/{session_id}/`:

```
.claude/evidence/
├── sessions/
│   └── {rq_id}/
│       ├── research-question.json
│       ├── sources.json
│       ├── claims.json
│       ├── evidence.json
│       ├── links.json
│       └── validation-report.json
└── index.json
```

## Workflow Integration

### Phase 1: Discovery

1. Define Research Question
2. Create storage directory
3. Set investigation budgets

### Phase 2: Evidence-Based Exploration

1. Launch 2-3 evidence-explorer agents (parallel)
2. Merge evidence (deduplicate sources)
3. Launch 2-3 evidence-reviewer agents (parallel)
4. Confidence gate check
5. Present findings or handle block

## Additional Resources

### Reference Files

- **`references/data-model.md`** - Complete JSON schema definitions
- **`references/validation-rules.md`** - Detailed confidence scoring rules

### Example Files

- **`examples/sample-ledger.json`** - Complete example ledger

### Utility Scripts

- **`scripts/validate-ledger.sh`** - Validate ledger JSON structure

## Quick Reference

### Creating a Claim

```json
{
  "claim_id": "clm_001",
  "claim_text": "[Falsifiable statement]",
  "claim_type": "pattern|architecture|dependency|convention|constraint|behavior",
  "status": "open",
  "confidence": 0.0
}
```

### Creating Evidence

```json
{
  "evidence_id": "ev_001",
  "source_id": "src_xxx",
  "extract": {
    "quote": "[EXACT text from source]",
    "locator": {"kind": "file_line", "value": "path/to/file.ts:45"}
  },
  "credibility": {"tier": "A", "replicability": "high", "freshness": "current"}
}
```

### Creating a Link

```json
{
  "link_id": "lnk_001",
  "claim_id": "clm_001",
  "evidence_id": "ev_001",
  "relation": "supports",
  "strength": 0.85,
  "reasoning": "[Why this evidence relates to the claim]"
}
```
