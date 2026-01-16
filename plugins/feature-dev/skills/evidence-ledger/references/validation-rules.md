# Evidence Ledger Validation Rules Reference

Detailed rules for confidence scoring, blocking logic, and validation procedures.

## 1. Confidence Calculation

### Core Formula

```
confidence = clamp(support * (1 - contradict), 0, 1)

where:
  support = 1 - product(1 - strength_i) for i in supporting_links
  contradict = 1 - product(1 - strength_j) for j in contradicting_links
```

### Properties of This Formula

1. **Diminishing Returns**: Adding more supporting evidence has diminishing effect
   - 1 evidence at 0.8 strength → support = 0.8
   - 2 evidence at 0.8 strength → support = 0.96 (not 1.6)
   - 3 evidence at 0.8 strength → support = 0.992

2. **Contradiction Penalty**: Even small contradictions significantly reduce confidence
   - support = 0.9, contradict = 0.3 → confidence = 0.63
   - support = 0.9, contradict = 0.5 → confidence = 0.45

3. **Bounded Output**: Result is always between 0.0 and 1.0

### Worked Examples

**Example 1: Strong Support, No Contradiction**
```
Supporting links: [0.9, 0.8]
Contradicting links: []

support = 1 - (1-0.9) * (1-0.8) = 1 - 0.1 * 0.2 = 0.98
contradict = 0
confidence = 0.98 * (1 - 0) = 0.98

Result: PASS (>= 0.75)
```

**Example 2: Moderate Support with Minor Contradiction**
```
Supporting links: [0.7, 0.6]
Contradicting links: [0.3]

support = 1 - (1-0.7) * (1-0.6) = 1 - 0.3 * 0.4 = 0.88
contradict = 1 - (1-0.3) = 0.3
confidence = 0.88 * (1 - 0.3) = 0.616

Result: BLOCK (< 0.75)
```

**Example 3: Strong Support with Major Contradiction**
```
Supporting links: [0.9, 0.9, 0.85]
Contradicting links: [0.8]

support = 1 - (1-0.9) * (1-0.9) * (1-0.85) = 1 - 0.1 * 0.1 * 0.15 = 0.9985
contradict = 1 - (1-0.8) = 0.8
confidence = 0.9985 * (1 - 0.8) = 0.1997

Result: BLOCK (< 0.75) - contradiction dominates
```

---

## 2. Link Strength Assignment

### Base Strength by Source Tier

| Source Tier | Base Strength | Description |
|-------------|---------------|-------------|
| A | 0.85-0.95 | Primary source code, official docs |
| B | 0.70-0.84 | Config files, README, comments |
| C | 0.55-0.69 | External docs, third-party refs |
| D | 0.35-0.54 | Inferred, git patterns |

### Strength Modifiers

**Positive Modifiers (add to base):**
- Evidence is exact code match: +0.05
- Multiple independent corroborations: +0.05
- Recent file modification: +0.03
- Test assertions present: +0.05

**Negative Modifiers (subtract from base):**
- Interpretation required: -0.10
- Stale file (> 90 days): -0.05
- Low replicability: -0.10
- Context suggests exception case: -0.15
- Comment contradicts code: -0.20

### Final Strength Calculation

```
final_strength = clamp(base_strength + sum(modifiers), 0.0, 1.0)
```

---

## 3. Confidence Thresholds

### Threshold Scale

| Range | Classification | Action |
|-------|---------------|--------|
| 0.00-0.25 | Insufficient | BLOCK - Needs significant investigation |
| 0.26-0.50 | Weak | BLOCK - Needs more evidence |
| 0.51-0.74 | Moderate | BLOCK - Some gaps remain |
| 0.75-0.89 | Strong | PASS - Acceptable for proceeding |
| 0.90-1.00 | Excellent | PASS - High certainty |

### The 0.75 Threshold

**Why 0.75?**
- High enough to filter out uncertain claims
- Low enough to not require perfect evidence
- Mathematically requires either:
  - Multiple strong supporting evidence OR
  - One very strong evidence without contradiction

**No Exceptions Policy:**
- 0.74 is NOT "close enough"
- Critical claims cannot be "rounded up"
- User acknowledgment can bypass, but must be explicit

---

## 4. Blocking Conditions

### Automatic Block Triggers

| Condition | Rationale |
|-----------|-----------|
| Any critical claim < 0.75 | Critical claims form the foundation |
| Major contradiction unresolved | Contradictions indicate wrong direction |
| Source verification failed | Evidence chain is broken |
| Coverage < 70% | Major aspects uninvestigated |

### Claim Criticality

**Critical Claim Types (auto-marked):**
- `architecture` - Structural decisions are foundational
- `dependency` - Wrong dependencies cause cascade failures
- `constraint` - Constraints are hard requirements

**Non-Critical Claim Types (manual override available):**
- `pattern` - Patterns can have exceptions
- `convention` - Conventions are guidelines
- `behavior` - Behavior can vary by context

### Coverage Calculation

```
coverage = (claims_with_confidence >= 0.75) / total_claims * 100

# For research question coverage:
coverage = (addressed_aspects / total_aspects) * 100
```

---

## 5. Verification Procedures

### Source Verification Checklist

- [ ] File exists at canonical_url
- [ ] File content hash matches (if recorded)
- [ ] File modification date is as expected
- [ ] Quality tier is appropriate

### Evidence Verification Checklist

- [ ] Quote matches file content EXACTLY
- [ ] Line numbers are correct
- [ ] Context lines are representative
- [ ] No cherry-picking (surrounding code doesn't contradict)

### Claim Verification Checklist

- [ ] Claim is falsifiable
- [ ] Claim scope matches evidence coverage
- [ ] Claim type is appropriate
- [ ] All linked evidence actually relates to claim

---

## 6. Contradiction Handling

### Contradiction Severity

| Severity | Description | Impact |
|----------|-------------|--------|
| Major | Direct logical contradiction | Link strength 0.7-1.0 |
| Moderate | Partial contradiction or exception | Link strength 0.4-0.69 |
| Minor | Edge case or unusual circumstance | Link strength 0.1-0.39 |

### Resolution Strategies

**Strategy 1: Narrow the Claim**
- Original: "All API endpoints require authentication"
- Narrowed: "All user-facing API endpoints require authentication"

**Strategy 2: Add Qualification**
- Original: "The app uses PostgreSQL for all data storage"
- Qualified: "The app uses PostgreSQL for persistent data; Redis for caching"

**Strategy 3: Split the Claim**
- Original: "Authentication uses JWT"
- Split into:
  - "User authentication uses JWT"
  - "Service-to-service auth uses API keys"

**Strategy 4: Accept Contradiction**
- Mark claim as `mixed`
- Document both supporting and contradicting evidence
- Let user decide how to proceed

---

## 7. User Override Procedures

### When User Can Override

Users can override blocking decisions when:
1. They acknowledge the risk explicitly
2. The claim is not architecture/dependency/constraint type
3. They provide justification

### Override Format

```json
{
  "override_id": "ovr_001",
  "claim_id": "clm_002",
  "original_confidence": 0.62,
  "override_reason": "User acknowledges risk; will validate during implementation",
  "user_acknowledgment": "I understand this claim has moderate confidence and may need revision",
  "override_at": "2024-01-15T11:00:00Z"
}
```

### Override Tracking

All overrides must be:
1. Recorded in validation-report.json
2. Flagged for review during Phase 6 (Quality Review)
3. Considered technical debt if not validated

---

## 8. Aggregate Metrics

### Key Metrics

| Metric | Formula | Threshold |
|--------|---------|-----------|
| Aggregate Confidence | mean(claim_confidences) | >= 0.75 |
| Support Rate | supported_claims / total_claims | >= 0.70 |
| Block Rate | blocked_claims / total_claims | <= 0.30 |
| Coverage | addressed_aspects / total_aspects | >= 0.70 |

### Health Indicators

**Healthy Evidence Ledger:**
- Aggregate confidence >= 0.75
- No unresolved major contradictions
- All sources verified
- Coverage >= 70%

**Unhealthy Evidence Ledger:**
- Aggregate confidence < 0.60
- Multiple major contradictions
- Source verification failures
- Coverage < 50%

---

## 9. Re-Investigation Triggers

### When to Launch Additional Explorers

1. **Low Confidence Cluster**: Multiple claims in same area < 0.75
2. **Missing Evidence**: Gap identified but no supporting evidence found
3. **Contradiction Discovery**: Need to investigate alternative implementations
4. **Scope Expansion**: User adds new requirements mid-workflow

### Re-Investigation Budget

```
additional_budget = min(
  original_budget * 0.5,
  remaining_budget
)
```

---

## 10. Validation Report Requirements

### Minimum Required Fields

```json
{
  "report_id": "required",
  "rq_id": "required",
  "aggregate_confidence": "required",
  "proceed_recommendation": "required (approve|block)",
  "claim_summaries": "required (array)",
  "blocking_issues": "required (array, can be empty)"
}
```

### Quality Criteria

A validation report is considered complete when:
1. All claims have been reviewed
2. All evidence has been verified
3. Confidence scores are calculated
4. Blocking issues are documented
5. Proceed recommendation is justified
