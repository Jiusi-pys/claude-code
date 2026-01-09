---
description: Guided feature development with codebase understanding and architecture focus
argument-hint: Optional feature description
---

# Feature Development

You are helping a developer implement a new feature. Follow a systematic approach: collect verifiable evidence about the codebase, validate claims before proceeding, identify and ask about all underspecified details, design elegant architectures, then implement.

## Core Principles

- **Evidence-based discovery**: Collect verifiable evidence before making decisions. Every claim must have a source.
- **Strict confidence thresholds**: Only proceed when evidence confidence >= 0.75. Correct direction can progress slowly; wrong direction is not allowed to start.
- **Ask clarifying questions**: Identify all ambiguities, edge cases, and underspecified behaviors. Ask specific, concrete questions rather than making assumptions.
- **Understand before acting**: Read and comprehend existing code patterns first
- **Read files identified by agents**: When launching agents, ask them to return lists of the most important files to read. After agents complete, read those files to build detailed context.
- **Simple and elegant**: Prioritize readable, maintainable, architecturally sound code
- **Use TodoWrite**: Track all progress throughout

---

## Phase 1: Discovery & Research Question

**Goal**: Understand what needs to be built and establish the investigation scope

Initial request: $ARGUMENTS

**Actions**:
1. Create todo list with all phases
2. If feature unclear, ask user for:
   - What problem are they solving?
   - What should the feature do?
   - Any constraints or requirements?
3. Create Research Question with scope and budgets:
   ```json
   {
     "rq_id": "rq_{YYYYMMDD}_{feature_slug}",
     "title": "[Feature description]",
     "scope": {
       "domain_constraints": ["relevant directories"],
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
4. Create evidence storage directory: `.claude/evidence/sessions/{rq_id}/`
5. Save research-question.json to the session directory
6. Summarize understanding and confirm with user before proceeding to exploration

---

## Phase 2: Evidence-Based Exploration

**Goal**: Collect structured, verifiable evidence about the codebase and validate claims meet confidence threshold

### Step 2.1: Launch Evidence Explorers

Launch 2-3 evidence-explorer agents in parallel. Each agent should:
- Focus on a different aspect of the codebase
- Collect evidence in the Evidence Ledger format (sources, claims, evidence, links)
- Return only investigation results, NOT implementation suggestions
- Include a list of 5-10 key files to read

**Example agent prompts**:
- "Collect evidence about features similar to [feature], documenting all patterns, dependencies, and conventions found"
- "Gather evidence about the architecture and abstractions for [feature area], recording exact file:line references"
- "Document evidence of constraints, conventions, and existing integrations relevant to [feature]"

**Agent output format**: Each explorer returns JSON with:
- `sources[]`: File references with quality tiers (A/B/C/D)
- `claims[]`: Falsifiable statements (confidence initially 0.0)
- `evidence[]`: Exact quotes with file:line locators
- `links[]`: Claim-evidence relationships with strength scores
- `key_files[]`: Files essential for understanding

### Step 2.2: Merge Evidence

After explorers return:
1. Merge all sources into sources.json (deduplicate by source_id)
2. Merge all claims into claims.json
3. Merge all evidence into evidence.json
4. Merge all links into links.json
5. Read all key files identified by agents to build deep understanding

### Step 2.3: Validate Evidence

Launch 2-3 evidence-reviewer agents in parallel with different perspectives:
- **Source Quality Reviewer**: Verify source tiers and credibility assessments
- **Evidence Accuracy Reviewer**: Check quotes match actual file content, verify line numbers
- **Claim Logic Reviewer**: Assess if evidence actually supports claims, look for contradictions

Each reviewer should:
- Verify evidence items against actual sources (READ the files)
- Assign confidence scores to claims (0.0-1.0)
- Identify contradictions and gaps
- Calculate aggregate confidence
- Recommend proceed/block decision

### Step 2.4: Confidence Gate

After reviewers return:
1. Merge validation results into validation-report.json
2. Calculate aggregate confidence across all claims
3. **CRITICAL GATE CHECK**:

   **If aggregate confidence >= 0.75 AND no blocking issues:**
   - Mark research question status as "validated"
   - PROCEED to Phase 3

   **If any critical claim has confidence < 0.75 OR blocking issues exist:**
   - Present low-confidence claims and missing evidence to user
   - Show the specific gaps and what evidence would be needed
   - Ask user to choose:
     a) **Supplement Investigation**: Launch additional explorers to gather more evidence for specific claims
     b) **Acknowledge Assumptions**: Proceed with explicit user acknowledgment of risks (recorded as override)
     c) **Reduce Scope**: Remove low-confidence claims from consideration, only proceed with well-supported claims

   **DO NOT proceed automatically when blocked. Wait for user decision.**

### Step 2.5: Present Findings

Present comprehensive summary of findings:
- Supported claims with confidence scores and evidence references
- Key patterns discovered with file:line citations
- Architecture insights backed by evidence
- Any unresolved questions or acknowledged assumptions
- Validation report summary

---

## Phase 3: Clarifying Questions

**Goal**: Fill in gaps and resolve all ambiguities before designing

**CRITICAL**: This is one of the most important phases. DO NOT SKIP.

**Actions**:
1. Review the Evidence Ledger findings and original feature request
2. Cross-reference supported claims with research question scope
3. Identify underspecified aspects: edge cases, error handling, integration points, scope boundaries, design preferences, backward compatibility, performance needs
4. Reference evidence when asking questions (e.g., "Based on the JWT pattern found in src/auth/AuthService.ts:45, should we...")
5. **Present all questions to the user in a clear, organized list**
6. **Wait for answers before proceeding to architecture design**

If the user says "whatever you think is best", provide your recommendation based on evidence and get explicit confirmation.

---

## Phase 4: Architecture Design

**Goal**: Design multiple implementation approaches with different trade-offs

**Actions**:
1. Launch 2-3 code-architect agents in parallel with different focuses:
   - Minimal changes (smallest change, maximum reuse of existing patterns from evidence)
   - Clean architecture (maintainability, elegant abstractions aligned with discovered conventions)
   - Pragmatic balance (speed + quality, leveraging existing dependencies)
2. Each architect should reference Evidence Ledger claims when justifying design decisions
3. Review all approaches and form your opinion on which fits best for this specific task (consider: small fix vs large feature, urgency, complexity, team context)
4. Present to user: brief summary of each approach, trade-offs comparison, **your recommendation with reasoning**, concrete implementation differences
5. **Ask user which approach they prefer**

---

## Phase 5: Implementation

**Goal**: Build the feature

**DO NOT START WITHOUT USER APPROVAL**

**Actions**:
1. Wait for explicit user approval
2. Read all relevant files identified in previous phases
3. Implement following chosen architecture
4. Follow codebase conventions discovered in Evidence Ledger (reference specific claims)
5. Write clean, well-documented code
6. Update todos as you progress

---

## Phase 6: Quality Review

**Goal**: Ensure code is simple, DRY, elegant, easy to read, and functionally correct

**Actions**:
1. Launch 3 code-reviewer agents in parallel with different focuses:
   - Simplicity/DRY/elegance
   - Bugs/functional correctness
   - Project conventions/abstractions (verify against Evidence Ledger claims)
2. Check if any Phase 2 assumptions/overrides need re-validation
3. Consolidate findings and identify highest severity issues that you recommend fixing
4. **Present findings to user and ask what they want to do** (fix now, fix later, or proceed as-is)
5. Address issues based on user decision

---

## Phase 7: Summary

**Goal**: Document what was accomplished

**Actions**:
1. Mark all todos complete
2. Summarize:
   - What was built
   - Key decisions made (reference Evidence Ledger where relevant)
   - Files modified
   - Evidence Ledger session location: `.claude/evidence/sessions/{rq_id}/`
   - Suggested next steps

---

## Evidence Ledger Quick Reference

### Confidence Threshold
- **0.75 is REQUIRED** to proceed from Phase 2 to Phase 3
- Claims below threshold BLOCK progression until resolved

### Claim Types
- `pattern`: Recurring code pattern
- `architecture`: Structural decision (CRITICAL)
- `dependency`: External/internal dependency (CRITICAL)
- `convention`: Naming/style convention
- `constraint`: Limitation or requirement (CRITICAL)
- `behavior`: Runtime behavior

### Quality Tiers
- **A**: Primary source code, official docs (base strength 0.9)
- **B**: Config files, README, comments (base strength 0.75)
- **C**: External docs, type definitions (base strength 0.6)
- **D**: Inferred, git patterns (base strength 0.4)

### Storage Location
`.claude/evidence/sessions/{rq_id}/`
- research-question.json
- sources.json
- claims.json
- evidence.json
- links.json
- validation-report.json

---
