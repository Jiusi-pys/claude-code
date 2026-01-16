# Feature Development Plugin

A comprehensive, structured workflow for feature development with Evidence Ledger system for verifiable evidence collection, confidence-based validation, and specialized agents for codebase exploration, architecture design, and quality review.

## Overview

The Feature Development Plugin provides a systematic 7-phase approach to building new features. Instead of jumping straight into code, it guides you through understanding the codebase with **verifiable evidence**, asking clarifying questions, designing architecture, and ensuring quality—resulting in better-designed features that integrate seamlessly with your existing code.

**Version 2.0**: Introduces the **Evidence Ledger** system for structured, auditable codebase analysis with confidence-based progression gates.

## Philosophy

Building features requires more than just writing code. You need to:
- **Collect verifiable evidence** about the codebase before making decisions
- **Validate claims** with confidence scores before proceeding
- **Ask questions** to clarify ambiguous requirements
- **Design thoughtfully** before implementing
- **Review for quality** after building

**Core Principle**: Correct direction can progress slowly; wrong direction is not allowed to start.

## Command: `/feature-dev`

Launches a guided feature development workflow with 7 distinct phases.

**Usage:**
```bash
/feature-dev Add user authentication with OAuth
```

Or simply:
```bash
/feature-dev
```

The command will guide you through the entire process interactively.

## The 7-Phase Workflow

### Phase 1: Discovery & Research Question

**Goal**: Understand what needs to be built and establish the investigation scope

**What happens:**
- Clarifies the feature request if it's unclear
- Asks what problem you're solving
- Identifies constraints and requirements
- **Creates a Research Question** with scope and budgets
- **Creates evidence storage directory**: `.claude/evidence/sessions/{rq_id}/`
- Summarizes understanding and confirms with you

**Example:**
```
You: /feature-dev Add caching
Claude: Let me understand what you need...
        - What should be cached? (API responses, computed values, etc.)
        - What are your performance requirements?
        - Do you have a preferred caching solution?

Creating Research Question:
- rq_id: rq_20240115_caching
- Scope: src/api, src/services
- Budgets: 40 sources, 20 claims, 80 agent steps
```

### Phase 2: Evidence-Based Exploration

**Goal**: Collect structured, verifiable evidence about the codebase and validate claims meet confidence threshold

**What happens:**

#### Step 2.1: Launch Evidence Explorers
- Launches 2-3 `evidence-explorer` agents in parallel
- Each agent explores different aspects (similar features, architecture, patterns)
- Agents collect evidence in the **Evidence Ledger format**:
  - **Sources**: File references with quality tiers (A/B/C/D)
  - **Claims**: Falsifiable statements about the codebase
  - **Evidence**: Exact quotes with file:line locators
  - **Links**: Claim-evidence relationships with strength scores

#### Step 2.2: Merge Evidence
- Deduplicates sources
- Merges claims, evidence, and links
- Reads all key files identified by agents

#### Step 2.3: Validate Evidence
- Launches 2-3 `evidence-reviewer` agents with different perspectives:
  - **Source Quality Reviewer**: Verifies source tiers and credibility
  - **Evidence Accuracy Reviewer**: Checks quotes match actual files
  - **Claim Logic Reviewer**: Assesses if evidence supports claims
- Assigns confidence scores (0.0-1.0)
- Identifies contradictions and gaps

#### Step 2.4: Confidence Gate

**CRITICAL**: Claims must reach **confidence >= 0.75** to proceed.

- **If passed**: Proceeds to Phase 3
- **If blocked**: Presents low-confidence claims and asks you to choose:
  - **Supplement Investigation**: Launch more explorers
  - **Acknowledge Assumptions**: Proceed with explicit risk acknowledgment
  - **Reduce Scope**: Only keep well-supported claims

**Example output:**
```
Evidence Validation Results:

Supported Claims (confidence >= 0.75):
- clm_001: "AuthService uses JWT with RS256" (0.88)
  Evidence: src/auth/AuthService.ts:45
- clm_002: "Tokens expire in 1 hour" (0.92)
  Evidence: src/auth/AuthService.ts:46

Blocked Claims (confidence < 0.75):
- clm_003: "All API endpoints require authentication" (0.62)
  Missing: No evidence of global middleware configuration
  Contradiction found: src/routes/health.ts has no auth

Aggregate confidence: 0.81
Recommendation: BLOCK - clm_003 needs more evidence

Options:
a) Investigate API middleware configuration
b) Acknowledge assumption and proceed
c) Remove clm_003 from scope
```

### Phase 3: Clarifying Questions

**Goal**: Fill in gaps and resolve all ambiguities

**What happens:**
- Reviews Evidence Ledger findings and feature request
- References evidence when asking questions
- Presents all questions in an organized list
- **Waits for your answers before proceeding**

**Example:**
```
Based on evidence found in src/auth/AuthService.ts:45:

1. JWT Algorithm: Found RS256 being used. Should the new feature also use RS256?
2. Token expiry: Found 1-hour expiry. Should caching respect this?
3. Auth exceptions: Found health endpoint without auth. What other endpoints?
```

### Phase 4: Architecture Design

**Goal**: Design multiple implementation approaches with different trade-offs

**What happens:**
- Launches 2-3 `code-architect` agents
- Each architect references Evidence Ledger claims when justifying design
- Presents comparison with trade-offs and recommendation
- **Asks which approach you prefer**

### Phase 5: Implementation

**Goal**: Build the feature

**What happens:**
- **Waits for explicit approval**
- Follows codebase conventions discovered in Evidence Ledger
- References specific claims when making decisions

### Phase 6: Quality Review

**Goal**: Ensure code is simple, DRY, elegant, and functionally correct

**What happens:**
- Launches 3 `code-reviewer` agents
- Verifies implementation against Evidence Ledger claims
- Checks if Phase 2 assumptions need re-validation

### Phase 7: Summary

**Goal**: Document what was accomplished

**What happens:**
- Summarizes what was built
- References key Evidence Ledger findings
- Reports Evidence Ledger session location

## Agents

### `evidence-explorer` (NEW in v2.0)

**Purpose**: Collects structured evidence for feature development discovery

**Focus areas:**
- Source discovery with quality tier assessment
- Claim formulation (falsifiable statements)
- Evidence collection (exact quotes, file:line locators)
- Link creation (claim-evidence relationships)

**Tools**: Glob, Grep, LS, Read, NotebookRead, TodoWrite
- **Deliberately excludes** WebFetch, WebSearch for reliability

**Output format:**
```json
{
  "sources": [...],
  "claims": [...],
  "evidence": [...],
  "links": [...],
  "key_files": [...],
  "investigation_notes": "..."
}
```

### `evidence-reviewer` (NEW in v2.0)

**Purpose**: Validates evidence and assigns confidence scores

**Focus areas:**
- Source verification (file exists, content matches)
- Evidence accuracy (quotes exact, locators correct)
- Claim logic (evidence actually supports claims)
- Contradiction hunting

**Model**: opus (uses more powerful model for critical validation)

**Output:**
- Confidence scores (0.0-1.0)
- Verification results
- Contradictions found
- Proceed/block recommendation

### `code-explorer`

**Purpose**: Deeply analyzes existing codebase features by tracing execution paths

**When triggered:**
- Can be invoked manually for exploration
- Replaced by `evidence-explorer` for Phase 2 workflow

### `code-architect`

**Purpose**: Designs feature architectures and implementation blueprints

**When triggered:**
- Automatically in Phase 4
- References Evidence Ledger claims for decisions

### `code-reviewer`

**Purpose**: Reviews code for bugs, quality issues, and project conventions

**When triggered:**
- Automatically in Phase 6
- Verifies against Evidence Ledger claims

## Evidence Ledger System

### Overview

The Evidence Ledger is a structured system for collecting, validating, and tracking evidence during the Discovery phase. It ensures all claims about the codebase are backed by verifiable evidence with explicit confidence scores.

### Data Model

| Entity | Description |
|--------|-------------|
| **ResearchQuestion** | Investigation scope and budgets |
| **Source** | Normalized file reference with quality tier |
| **Claim** | Falsifiable statement about the codebase |
| **EvidenceItem** | Exact quote with file:line locator |
| **Link** | Claim-evidence relationship with strength |
| **ValidationReport** | Reviewer findings and confidence scores |

### Quality Tiers

| Tier | Description | Base Strength |
|------|-------------|---------------|
| A | Primary source code, official docs | 0.9 |
| B | Config files, README, comments | 0.75 |
| C | External docs, type definitions | 0.6 |
| D | Inferred, git patterns | 0.4 |

### Confidence Scoring

```
confidence = clamp(support * (1 - contradict), 0, 1)

where:
  support = 1 - product(1 - strength_i) for supporting links
  contradict = 1 - product(1 - strength_j) for contradicting links
```

**Threshold**: 0.75 is REQUIRED to proceed from Phase 2 to Phase 3.

### Storage Location

Evidence is stored in `.claude/evidence/sessions/{rq_id}/`:
- `research-question.json`
- `sources.json`
- `claims.json`
- `evidence.json`
- `links.json`
- `validation-report.json`

### Validation Script

```bash
./skills/evidence-ledger/scripts/validate-ledger.sh .claude/evidence/sessions/rq_20240115_auth
```

## Best Practices

1. **Use the full workflow for complex features**: The 7 phases ensure thorough planning
2. **Trust the confidence gate**: If blocked, investigate rather than bypass
3. **Answer clarifying questions with evidence context**: Phase 3 questions reference specific code
4. **Choose architecture deliberately**: Phase 4 decisions are backed by evidence
5. **Don't skip code review**: Phase 6 validates against Evidence Ledger claims

## When to Use This Plugin

**Use for:**
- New features that touch multiple files
- Features requiring architectural decisions
- Complex integrations with existing code
- Features where requirements are somewhat unclear

**Don't use for:**
- Single-line bug fixes
- Trivial changes
- Well-defined, simple tasks
- Urgent hotfixes

## Directory Structure

```
plugins/feature-dev/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── evidence-explorer.md    # NEW: Evidence collection
│   ├── evidence-reviewer.md    # NEW: Evidence validation
│   ├── code-explorer.md        # Codebase exploration
│   ├── code-architect.md       # Architecture design
│   └── code-reviewer.md        # Code review
├── commands/
│   └── feature-dev.md          # Main command
├── skills/
│   └── evidence-ledger/        # NEW: Evidence Ledger skill
│       ├── SKILL.md
│       ├── references/
│       │   ├── data-model.md
│       │   └── validation-rules.md
│       ├── examples/
│       │   └── sample-ledger.json
│       └── scripts/
│           └── validate-ledger.sh
├── hooks/
│   └── hooks.json              # NEW: Session hooks
└── README.md
```

## Troubleshooting

### Confidence gate keeps blocking

**Issue**: Phase 2 blocks due to low confidence

**Solution**:
- Check which claims are below threshold
- Launch additional explorers for specific areas
- Consider if claims are too broad (narrow them)
- Acknowledge assumptions if appropriate

### Evidence quotes don't match

**Issue**: Reviewer reports quotes don't match files

**Solution**:
- Files may have changed since exploration
- Re-run explorers to get fresh evidence
- Check if the right file version is being examined

### Too many claims

**Issue**: Explorer generates too many claims

**Solution**:
- Narrow the research question scope
- Reduce budgets in research question
- Focus explorers on specific aspects

## Authors

- Sid Bidasaria (sbidasaria@anthropic.com) - Original author
- Jiusi - Evidence Ledger system implementation

## Version

2.0.0

## Changelog

### v2.0.0
- Added Evidence Ledger system for structured evidence collection
- New `evidence-explorer` agent for focused discovery
- New `evidence-reviewer` agent for validation
- Confidence-based gate (0.75 threshold) in Phase 2
- JSON-based evidence storage in `.claude/evidence/sessions/`
- Validation script for ledger verification
- Session hooks for directory management
