# Evidence Ledger Data Model Reference

Complete JSON Schema definitions for the Evidence Ledger system.

## Entity Relationship Overview

```
ResearchQuestion
     │
     │ 1:N
     ▼
  Claim ◄──────────────► EvidenceItem
     │        Link           │
     │        (M:N)          │
     │                       │
     │                       │
     └───────────────────────┘
                 │
                 │ N:1
                 ▼
              Source
```

## 1. ResearchQuestion

Defines the investigation scope and constraints.

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["rq_id", "title", "scope", "budgets", "status"],
  "properties": {
    "rq_id": {
      "type": "string",
      "pattern": "^rq_[0-9]{8}_[a-z0-9_]+$",
      "description": "Unique identifier: rq_{YYYYMMDD}_{feature_slug}"
    },
    "title": {
      "type": "string",
      "minLength": 10,
      "maxLength": 200,
      "description": "Human-readable description of the research question"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "scope": {
      "type": "object",
      "properties": {
        "domain_constraints": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Directories/files to focus on"
        },
        "exclude_patterns": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Glob patterns to exclude"
        },
        "time_window": {
          "type": "object",
          "properties": {
            "max_file_age_days": {"type": "integer", "nullable": true},
            "git_history_depth": {"type": "integer", "default": 50}
          }
        }
      }
    },
    "budgets": {
      "type": "object",
      "properties": {
        "max_sources": {"type": "integer", "default": 40},
        "max_claims": {"type": "integer", "default": 20},
        "max_evidence_per_claim": {"type": "integer", "default": 5},
        "max_agent_steps": {"type": "integer", "default": 80}
      }
    },
    "status": {
      "type": "string",
      "enum": ["draft", "in_progress", "validated", "blocked", "completed"]
    },
    "phase": {
      "type": "string",
      "enum": ["discovery", "exploration", "validation", "complete"]
    }
  }
}
```

### Example

```json
{
  "rq_id": "rq_20240115_oauth_auth",
  "title": "Implement OAuth2 authentication for user login",
  "created_at": "2024-01-15T10:30:00Z",
  "scope": {
    "domain_constraints": ["src/auth", "src/middleware", "src/routes"],
    "exclude_patterns": ["node_modules", "dist", "*.test.ts", "*.spec.ts"],
    "time_window": {
      "max_file_age_days": null,
      "git_history_depth": 50
    }
  },
  "budgets": {
    "max_sources": 40,
    "max_claims": 20,
    "max_evidence_per_claim": 5,
    "max_agent_steps": 80
  },
  "status": "in_progress",
  "phase": "exploration"
}
```

---

## 2. Source

Normalized reference to a file, documentation, or external resource.

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["source_id", "canonical_url", "source_type", "quality_tier"],
  "properties": {
    "source_id": {
      "type": "string",
      "pattern": "^src_[a-f0-9]{8,64}$",
      "description": "SHA256-based unique identifier"
    },
    "canonical_url": {
      "type": "string",
      "description": "file:// for local, https:// for external"
    },
    "source_type": {
      "type": "string",
      "enum": ["codebase_file", "documentation", "test_case", "configuration", "external_reference", "git_history"]
    },
    "metadata": {
      "type": "object",
      "properties": {
        "file_path": {"type": "string"},
        "language": {"type": "string"},
        "last_modified": {"type": "string", "format": "date-time"},
        "size_bytes": {"type": "integer"},
        "git_hash": {"type": "string"}
      }
    },
    "quality_tier": {
      "type": "string",
      "enum": ["A", "B", "C", "D"],
      "description": "A=primary code, B=config/docs, C=external, D=inferred"
    },
    "same_source_cluster_id": {
      "type": "string",
      "nullable": true,
      "description": "For deduplication of related sources"
    },
    "discovered_at": {
      "type": "string",
      "format": "date-time"
    },
    "discovered_by": {
      "type": "string",
      "description": "Agent ID that discovered this source"
    }
  }
}
```

### Quality Tier Definitions

| Tier | Description | Examples | Base Strength |
|------|-------------|----------|---------------|
| A | Primary source: authoritative, maintained | Source code, official docs, test assertions | 0.9 |
| B | Secondary source: informative, context | Config files, README, inline comments | 0.75 |
| C | Tertiary source: reference material | External docs, type definitions | 0.6 |
| D | Derived source: inferred, uncertain | Git patterns, indirect references | 0.4 |

### Example

```json
{
  "source_id": "src_a1b2c3d4e5f6",
  "canonical_url": "file:///home/user/project/src/auth/AuthService.ts",
  "source_type": "codebase_file",
  "metadata": {
    "file_path": "src/auth/AuthService.ts",
    "language": "typescript",
    "last_modified": "2024-01-10T08:00:00Z",
    "size_bytes": 4523,
    "git_hash": "abc123def456"
  },
  "quality_tier": "A",
  "same_source_cluster_id": null,
  "discovered_at": "2024-01-15T10:35:00Z",
  "discovered_by": "evidence-explorer-1"
}
```

---

## 3. Claim

A falsifiable statement about the codebase.

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["claim_id", "claim_text", "claim_type", "status", "confidence"],
  "properties": {
    "claim_id": {
      "type": "string",
      "pattern": "^clm_[0-9]{3,6}$"
    },
    "rq_id": {
      "type": "string",
      "description": "Research question this claim belongs to"
    },
    "claim_text": {
      "type": "string",
      "minLength": 20,
      "maxLength": 500,
      "description": "Clear, falsifiable statement"
    },
    "claim_type": {
      "type": "string",
      "enum": ["pattern", "architecture", "dependency", "convention", "constraint", "behavior"]
    },
    "scope": {
      "type": "object",
      "properties": {
        "files": {
          "type": "array",
          "items": {"type": "string"}
        },
        "domains": {
          "type": "array",
          "items": {"type": "string"}
        }
      }
    },
    "is_critical": {
      "type": "boolean",
      "default": false,
      "description": "If true, must meet threshold to proceed"
    },
    "status": {
      "type": "string",
      "enum": ["open", "supported", "refuted", "mixed", "insufficient"]
    },
    "confidence": {
      "type": "number",
      "minimum": 0.0,
      "maximum": 1.0
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "created_by": {
      "type": "string"
    },
    "validation": {
      "type": "object",
      "properties": {
        "reviewed_by": {"type": "string", "nullable": true},
        "reviewed_at": {"type": "string", "format": "date-time", "nullable": true},
        "final_confidence": {"type": "number", "nullable": true},
        "validation_notes": {"type": "string", "nullable": true}
      }
    }
  }
}
```

### Claim Type Definitions

| Type | Description | Criticality |
|------|-------------|-------------|
| `pattern` | Recurring code pattern or convention | Medium |
| `architecture` | Structural/design decision | **High** |
| `dependency` | External or internal dependency | **High** |
| `convention` | Naming, style, organization | Low |
| `constraint` | Limitation or requirement | **High** |
| `behavior` | Runtime behavior or data flow | Medium |

### Example

```json
{
  "claim_id": "clm_001",
  "rq_id": "rq_20240115_oauth_auth",
  "claim_text": "AuthService uses JWT tokens with RS256 algorithm for authentication",
  "claim_type": "pattern",
  "scope": {
    "files": ["src/auth/AuthService.ts", "src/auth/JWTUtils.ts"],
    "domains": ["authentication", "security"]
  },
  "is_critical": false,
  "status": "open",
  "confidence": 0.0,
  "created_at": "2024-01-15T10:40:00Z",
  "created_by": "evidence-explorer-1",
  "validation": {
    "reviewed_by": null,
    "reviewed_at": null,
    "final_confidence": null,
    "validation_notes": null
  }
}
```

---

## 4. EvidenceItem

A specific excerpt or reference supporting/contradicting a claim.

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["evidence_id", "source_id", "evidence_type", "extract", "credibility"],
  "properties": {
    "evidence_id": {
      "type": "string",
      "pattern": "^ev_[0-9]{3,6}$"
    },
    "source_id": {
      "type": "string",
      "description": "Reference to Source"
    },
    "evidence_type": {
      "type": "string",
      "enum": ["code_reference", "documentation", "test_case", "configuration", "git_history", "external_reference"]
    },
    "extract": {
      "type": "object",
      "required": ["quote", "locator"],
      "properties": {
        "quote": {
          "type": "string",
          "maxLength": 500,
          "description": "EXACT text from source (max 3 lines)"
        },
        "locator": {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "enum": ["file_line", "file_range", "section", "anchor_hash"]
            },
            "value": {
              "type": "string",
              "description": "e.g., 'src/auth/AuthService.ts:45-47'"
            }
          }
        },
        "context": {
          "type": "object",
          "properties": {
            "before": {"type": "string", "maxLength": 200},
            "after": {"type": "string", "maxLength": 200}
          }
        }
      }
    },
    "credibility": {
      "type": "object",
      "properties": {
        "tier": {
          "type": "string",
          "enum": ["A", "B", "C", "D"]
        },
        "replicability": {
          "type": "string",
          "enum": ["high", "medium", "low"]
        },
        "freshness": {
          "type": "string",
          "enum": ["current", "recent", "stale"]
        }
      }
    },
    "tags": {
      "type": "array",
      "items": {"type": "string"}
    },
    "collected_at": {
      "type": "string",
      "format": "date-time"
    },
    "collected_by": {
      "type": "string"
    }
  }
}
```

### Credibility Definitions

**Replicability:**
- `high`: Deterministic, will always be the same
- `medium`: Mostly stable, minor variations possible
- `low`: Volatile, may change frequently

**Freshness:**
- `current`: Modified within last 30 days
- `recent`: Modified 30-90 days ago
- `stale`: Modified more than 90 days ago

### Example

```json
{
  "evidence_id": "ev_001",
  "source_id": "src_a1b2c3d4e5f6",
  "evidence_type": "code_reference",
  "extract": {
    "quote": "const token = jwt.sign(payload, privateKey, { algorithm: 'RS256' });",
    "locator": {
      "kind": "file_line",
      "value": "src/auth/AuthService.ts:45"
    },
    "context": {
      "before": "// Generate JWT token for authenticated user",
      "after": "return { token, expiresIn: '1h' };"
    }
  },
  "credibility": {
    "tier": "A",
    "replicability": "high",
    "freshness": "current"
  },
  "tags": ["jwt", "authentication", "rs256"],
  "collected_at": "2024-01-15T10:42:00Z",
  "collected_by": "evidence-explorer-1"
}
```

---

## 5. Link

Relationship between a Claim and an EvidenceItem.

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["link_id", "claim_id", "evidence_id", "relation", "strength"],
  "properties": {
    "link_id": {
      "type": "string",
      "pattern": "^lnk_[0-9]{3,6}$"
    },
    "claim_id": {
      "type": "string"
    },
    "evidence_id": {
      "type": "string"
    },
    "relation": {
      "type": "string",
      "enum": ["supports", "contradicts", "qualifies", "exemplifies", "context"]
    },
    "strength": {
      "type": "number",
      "minimum": 0.0,
      "maximum": 1.0
    },
    "reasoning": {
      "type": "string",
      "maxLength": 300,
      "description": "Brief explanation of relationship"
    },
    "confounders": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Factors that might weaken the relationship"
    },
    "applies_under": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Conditions where this link applies"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "created_by": {
      "type": "string"
    }
  }
}
```

### Relation Types

| Relation | Description | Impact on Confidence |
|----------|-------------|---------------------|
| `supports` | Evidence directly supports the claim | Increases confidence |
| `contradicts` | Evidence contradicts the claim | Decreases confidence |
| `qualifies` | Evidence adds nuance/conditions | Neutral to slight decrease |
| `exemplifies` | Evidence is a specific example | Slight increase |
| `context` | Evidence provides background | Neutral |

### Strength Guidelines

| Strength | Description |
|----------|-------------|
| 0.9-1.0 | Direct, unambiguous evidence from primary source |
| 0.7-0.89 | Strong evidence with minor interpretation needed |
| 0.5-0.69 | Moderate evidence, some assumptions required |
| 0.3-0.49 | Weak evidence, significant inference needed |
| 0.0-0.29 | Circumstantial, mostly inferred |

### Example

```json
{
  "link_id": "lnk_001",
  "claim_id": "clm_001",
  "evidence_id": "ev_001",
  "relation": "supports",
  "strength": 0.9,
  "reasoning": "The code directly shows RS256 algorithm being used in jwt.sign call",
  "confounders": [],
  "applies_under": ["standard authentication flow"],
  "created_at": "2024-01-15T10:45:00Z",
  "created_by": "evidence-explorer-1"
}
```

---

## 6. ValidationReport

Summary of reviewer findings.

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["report_id", "rq_id", "aggregate_confidence", "proceed_recommendation"],
  "properties": {
    "report_id": {
      "type": "string",
      "pattern": "^vr_[0-9]{8}_[0-9]{6}$"
    },
    "rq_id": {
      "type": "string"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "reviewers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "reviewer_id": {"type": "string"},
          "perspective": {"type": "string"}
        }
      }
    },
    "claim_summaries": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "claim_id": {"type": "string"},
          "final_confidence": {"type": "number"},
          "status": {"type": "string"},
          "issues": {"type": "array", "items": {"type": "string"}}
        }
      }
    },
    "aggregate_confidence": {
      "type": "number",
      "minimum": 0.0,
      "maximum": 1.0
    },
    "coverage_percentage": {
      "type": "number",
      "minimum": 0,
      "maximum": 100
    },
    "blocking_issues": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "claim_id": {"type": "string"},
          "reason": {"type": "string"},
          "remediation": {"type": "string"}
        }
      }
    },
    "proceed_recommendation": {
      "type": "string",
      "enum": ["approve", "block"]
    },
    "block_reason": {
      "type": "string",
      "nullable": true
    }
  }
}
```

### Example

```json
{
  "report_id": "vr_20240115_103500",
  "rq_id": "rq_20240115_oauth_auth",
  "created_at": "2024-01-15T10:35:00Z",
  "reviewers": [
    {"reviewer_id": "evidence-reviewer-1", "perspective": "Evidence Accuracy"},
    {"reviewer_id": "evidence-reviewer-2", "perspective": "Contradiction Hunter"}
  ],
  "claim_summaries": [
    {
      "claim_id": "clm_001",
      "final_confidence": 0.82,
      "status": "supported",
      "issues": []
    }
  ],
  "aggregate_confidence": 0.82,
  "coverage_percentage": 85,
  "blocking_issues": [],
  "proceed_recommendation": "approve",
  "block_reason": null
}
```
