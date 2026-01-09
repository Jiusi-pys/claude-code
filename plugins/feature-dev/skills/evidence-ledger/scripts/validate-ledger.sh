#!/bin/bash
# validate-ledger.sh - Validate Evidence Ledger JSON structure and calculate metrics
#
# Usage: validate-ledger.sh <ledger-directory>
#        validate-ledger.sh --help
#
# Example: validate-ledger.sh .claude/evidence/sessions/rq_20240115_auth

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Help message
show_help() {
    cat << EOF
Evidence Ledger Validator

Usage: validate-ledger.sh <ledger-directory>

Arguments:
  ledger-directory    Path to the Evidence Ledger session directory
                      (e.g., .claude/evidence/sessions/rq_20240115_auth)

Expected files in directory:
  - research-question.json
  - sources.json
  - claims.json
  - evidence.json
  - links.json
  - validation-report.json (optional)

Validation checks:
  1. All required files exist
  2. JSON syntax is valid
  3. Required fields are present
  4. ID references are consistent
  5. Confidence scores are within bounds
  6. Source quality tiers are valid

Exit codes:
  0 - All validations passed
  1 - Validation errors found
  2 - Invalid arguments or missing files
EOF
}

# Validate JSON syntax
validate_json() {
    local file=$1
    if [ -f "$file" ]; then
        if jq empty "$file" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $file - Valid JSON"
            return 0
        else
            echo -e "${RED}✗${NC} $file - Invalid JSON syntax"
            return 1
        fi
    else
        echo -e "${YELLOW}?${NC} $file - Not found (optional)"
        return 0
    fi
}

# Check required fields in JSON
check_required_fields() {
    local file=$1
    shift
    local fields=("$@")
    local missing=()

    for field in "${fields[@]}"; do
        if ! jq -e ".$field" "$file" > /dev/null 2>&1; then
            missing+=("$field")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        return 0
    else
        echo -e "${RED}  Missing fields: ${missing[*]}${NC}"
        return 1
    fi
}

# Validate research-question.json
validate_research_question() {
    local file="$1/research-question.json"
    echo "Validating research-question.json..."

    if [ ! -f "$file" ]; then
        echo -e "${RED}✗${NC} research-question.json - Required file missing"
        return 1
    fi

    validate_json "$file" || return 1
    check_required_fields "$file" "rq_id" "title" "scope" "budgets" "status" || return 1

    # Validate status enum
    local status=$(jq -r '.status' "$file")
    case "$status" in
        draft|in_progress|validated|blocked|completed)
            echo -e "${GREEN}  Status: $status${NC}"
            ;;
        *)
            echo -e "${RED}  Invalid status: $status${NC}"
            return 1
            ;;
    esac

    return 0
}

# Validate sources.json
validate_sources() {
    local file="$1/sources.json"
    echo "Validating sources.json..."

    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}?${NC} sources.json - Not found (may be empty)"
        return 0
    fi

    validate_json "$file" || return 1

    local count=$(jq 'length' "$file")
    echo -e "${GREEN}  Sources found: $count${NC}"

    # Validate quality tiers
    local invalid_tiers=$(jq '[.[] | select(.quality_tier | IN("A", "B", "C", "D") | not)] | length' "$file")
    if [ "$invalid_tiers" -gt 0 ]; then
        echo -e "${RED}  Found $invalid_tiers sources with invalid quality_tier${NC}"
        return 1
    fi

    return 0
}

# Validate claims.json
validate_claims() {
    local file="$1/claims.json"
    echo "Validating claims.json..."

    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}?${NC} claims.json - Not found (may be empty)"
        return 0
    fi

    validate_json "$file" || return 1

    local count=$(jq 'length' "$file")
    echo -e "${GREEN}  Claims found: $count${NC}"

    # Validate confidence scores
    local invalid_confidence=$(jq '[.[] | select(.confidence < 0 or .confidence > 1)] | length' "$file")
    if [ "$invalid_confidence" -gt 0 ]; then
        echo -e "${RED}  Found $invalid_confidence claims with invalid confidence (must be 0-1)${NC}"
        return 1
    fi

    # Validate claim types
    local valid_types='["pattern", "architecture", "dependency", "convention", "constraint", "behavior"]'
    local invalid_types=$(jq --argjson valid "$valid_types" '[.[] | select(.claim_type | IN($valid[]) | not)] | length' "$file")
    if [ "$invalid_types" -gt 0 ]; then
        echo -e "${RED}  Found $invalid_types claims with invalid claim_type${NC}"
        return 1
    fi

    # Calculate metrics
    local supported=$(jq '[.[] | select(.status == "supported")] | length' "$file")
    local avg_confidence=$(jq '[.[].confidence] | add / length' "$file" 2>/dev/null || echo "0")

    echo -e "${GREEN}  Supported claims: $supported / $count${NC}"
    echo -e "${GREEN}  Average confidence: $avg_confidence${NC}"

    # Threshold check
    if (( $(echo "$avg_confidence >= 0.75" | bc -l) )); then
        echo -e "${GREEN}  ✓ Meets 0.75 threshold${NC}"
    else
        echo -e "${YELLOW}  ⚠ Below 0.75 threshold${NC}"
    fi

    return 0
}

# Validate evidence.json
validate_evidence() {
    local file="$1/evidence.json"
    local sources_file="$1/sources.json"
    echo "Validating evidence.json..."

    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}?${NC} evidence.json - Not found (may be empty)"
        return 0
    fi

    validate_json "$file" || return 1

    local count=$(jq 'length' "$file")
    echo -e "${GREEN}  Evidence items found: $count${NC}"

    # Validate source references if sources.json exists
    if [ -f "$sources_file" ]; then
        local source_ids=$(jq '[.[].source_id] | unique' "$sources_file")
        local orphan_refs=$(jq --argjson valid "$source_ids" '[.[] | select(.source_id | IN($valid[]) | not)] | length' "$file")
        if [ "$orphan_refs" -gt 0 ]; then
            echo -e "${RED}  Found $orphan_refs evidence items with invalid source_id references${NC}"
            return 1
        fi
    fi

    # Validate credibility tiers
    local invalid_cred=$(jq '[.[] | select(.credibility.tier | IN("A", "B", "C", "D") | not)] | length' "$file")
    if [ "$invalid_cred" -gt 0 ]; then
        echo -e "${RED}  Found $invalid_cred evidence items with invalid credibility.tier${NC}"
        return 1
    fi

    return 0
}

# Validate links.json
validate_links() {
    local file="$1/links.json"
    local claims_file="$1/claims.json"
    local evidence_file="$1/evidence.json"
    echo "Validating links.json..."

    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}?${NC} links.json - Not found (may be empty)"
        return 0
    fi

    validate_json "$file" || return 1

    local count=$(jq 'length' "$file")
    echo -e "${GREEN}  Links found: $count${NC}"

    # Validate strength scores
    local invalid_strength=$(jq '[.[] | select(.strength < 0 or .strength > 1)] | length' "$file")
    if [ "$invalid_strength" -gt 0 ]; then
        echo -e "${RED}  Found $invalid_strength links with invalid strength (must be 0-1)${NC}"
        return 1
    fi

    # Validate relation types
    local valid_relations='["supports", "contradicts", "qualifies", "exemplifies", "context"]'
    local invalid_relations=$(jq --argjson valid "$valid_relations" '[.[] | select(.relation | IN($valid[]) | not)] | length' "$file")
    if [ "$invalid_relations" -gt 0 ]; then
        echo -e "${RED}  Found $invalid_relations links with invalid relation type${NC}"
        return 1
    fi

    # Validate claim references if claims.json exists
    if [ -f "$claims_file" ]; then
        local claim_ids=$(jq '[.[].claim_id] | unique' "$claims_file")
        local orphan_claims=$(jq --argjson valid "$claim_ids" '[.[] | select(.claim_id | IN($valid[]) | not)] | length' "$file")
        if [ "$orphan_claims" -gt 0 ]; then
            echo -e "${RED}  Found $orphan_claims links with invalid claim_id references${NC}"
            return 1
        fi
    fi

    # Validate evidence references if evidence.json exists
    if [ -f "$evidence_file" ]; then
        local evidence_ids=$(jq '[.[].evidence_id] | unique' "$evidence_file")
        local orphan_evidence=$(jq --argjson valid "$evidence_ids" '[.[] | select(.evidence_id | IN($valid[]) | not)] | length' "$file")
        if [ "$orphan_evidence" -gt 0 ]; then
            echo -e "${RED}  Found $orphan_evidence links with invalid evidence_id references${NC}"
            return 1
        fi
    fi

    return 0
}

# Validate validation-report.json
validate_report() {
    local file="$1/validation-report.json"
    echo "Validating validation-report.json..."

    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}?${NC} validation-report.json - Not found (optional)"
        return 0
    fi

    validate_json "$file" || return 1
    check_required_fields "$file" "report_id" "rq_id" "aggregate_confidence" "proceed_recommendation" || return 1

    local recommendation=$(jq -r '.proceed_recommendation' "$file")
    case "$recommendation" in
        approve)
            echo -e "${GREEN}  Recommendation: APPROVE${NC}"
            ;;
        block)
            local reason=$(jq -r '.block_reason // "No reason specified"' "$file")
            echo -e "${YELLOW}  Recommendation: BLOCK - $reason${NC}"
            ;;
        *)
            echo -e "${RED}  Invalid recommendation: $recommendation${NC}"
            return 1
            ;;
    esac

    local agg_conf=$(jq -r '.aggregate_confidence' "$file")
    echo -e "${GREEN}  Aggregate confidence: $agg_conf${NC}"

    return 0
}

# Main function
main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi

    if [ -z "$1" ]; then
        echo -e "${RED}Error: No ledger directory specified${NC}"
        echo "Usage: validate-ledger.sh <ledger-directory>"
        exit 2
    fi

    local ledger_dir="$1"

    if [ ! -d "$ledger_dir" ]; then
        echo -e "${RED}Error: Directory not found: $ledger_dir${NC}"
        exit 2
    fi

    echo "========================================="
    echo "Evidence Ledger Validator"
    echo "Directory: $ledger_dir"
    echo "========================================="
    echo ""

    local errors=0

    validate_research_question "$ledger_dir" || ((errors++))
    echo ""

    validate_sources "$ledger_dir" || ((errors++))
    echo ""

    validate_claims "$ledger_dir" || ((errors++))
    echo ""

    validate_evidence "$ledger_dir" || ((errors++))
    echo ""

    validate_links "$ledger_dir" || ((errors++))
    echo ""

    validate_report "$ledger_dir" || ((errors++))
    echo ""

    echo "========================================="
    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}All validations passed!${NC}"
        exit 0
    else
        echo -e "${RED}Validation completed with $errors error(s)${NC}"
        exit 1
    fi
}

main "$@"
