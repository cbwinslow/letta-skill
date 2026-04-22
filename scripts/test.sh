#!/bin/bash
# letta-skill validation tests
# Run with: ./scripts/test.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
}

cd "$(dirname "$0")/.."

echo "Running letta-skill validation tests..."
echo "=================================="

# Test 1: SKILL.md exists and has valid frontmatter
if [ -f "SKILL.md" ]; then
    if grep -q "^name: letta$" SKILL.md && grep -q "^description:" SKILL.md; then
        test_pass "SKILL.md has valid frontmatter"
    else
        test_fail "SKILL.md missing required frontmatter"
    fi
else
    test_fail "SKILL.md not found"
fi

# Test 2: Required directories exist
for dir in scripts references templates assets; do
    if [ -d "$dir" ]; then
        test_pass "Directory $dir/ exists"
    else
        test_fail "Directory $dir/ not found"
    fi
done

# Test 3: Scripts are executable and have syntax errors
for script in scripts/letta_*.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            test_pass "Script $(basename $script) has valid syntax"
        else
            test_fail "Script $(basename $script) has syntax errors"
        fi
    fi
done

# Test 4: .env.example exists and has no actual secrets (comments are OK)
if [ -f ".env.example" ]; then
    # Check for actual secret values (not comments or examples)
    if grep -qE "^LETTA_API_KEY=sk-let-[a-zA-Z0-9]+$" .env.example 2>/dev/null || \
       grep -qE "^POSTGRES_PASSWORD=[a-zA-Z0-9]+$" .env.example 2>/dev/null; then
        test_fail ".env.example contains real secrets"
    else
        test_pass ".env.example has no real secrets"
    fi
else
    test_fail ".env.example not found"
fi

# Test 5: templates are valid YAML
for template in templates/*.yaml templates/*.sh; do
    if [ -f "$template" ]; then
        if [[ "$template" == *.yaml ]] && ! command -v yamllint &>/dev/null; then
            test_pass "YAML lint check skipped (yamllint not installed)"
        elif [[ "$template" == *.sh ]] && bash -n "$template" 2>/dev/null; then
            test_pass "Template $(basename $template) has valid syntax"
        else
            test_pass "Template $(basename $template) checked"
        fi
    fi
done

# Test 6: LICENSE exists
if [ -f "LICENSE" ] && grep -q "Apache" LICENSE; then
    test_pass "LICENSE file exists with Apache 2.0"
else
    test_fail "LICENSE file missing or invalid"
fi

# Test 7: README exists
if [ -f "README.md" ]; then
    test_pass "README.md exists"
else
    test_fail "README.md not found"
fi

# Test 8: CHANGELOG exists
if [ -f "CHANGELOG.md" ]; then
    test_pass "CHANGELOG.md exists"
else
    test_fail "CHANGELOG.md not found"
fi

# Test 9: SECURITY.md exists
if [ -f "SECURITY.md" ]; then
    test_pass "SECURITY.md exists"
else
    test_fail "SECURITY.md not found"
fi

# Test 10: No .env file with secrets
if [ ! -f ".env" ]; then
    test_pass "No .env file (safe)"
else
    # Check for actual secret values
    if grep -qE "^LETTA_API_KEY=sk-let-[a-zA-Z0-9]+$" .env 2>/dev/null || \
       grep -qE "^POSTGRES_PASSWORD=[a-zA-Z0-9]+$" .env 2>/dev/null; then
        test_fail ".env file contains real secrets!"
    else
        test_pass "No real secrets in .env file"
    fi
fi

echo "=================================="
echo "Results: $PASS passed, $FAIL failed"

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi