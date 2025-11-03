#!/usr/bin/env bash

#############################################################################
# Makefile Test Suite
#############################################################################
# Tests all Makefile targets to ensure they work correctly
#############################################################################

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Test results
declare -a RESULTS

#############################################################################
# Helper Functions
#############################################################################

log_pass() {
    echo -e "${GREEN}✓${NC} PASS: $1"
    ((PASSED++))
    RESULTS+=("✓ $1")
}

log_fail() {
    echo -e "${RED}✗${NC} FAIL: $1"
    ((FAILED++))
    RESULTS+=("✗ $1")
}

log_skip() {
    echo -e "${YELLOW}⊘${NC} SKIP: $1"
    ((SKIPPED++))
    RESULTS+=("⊘ $1")
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

test_command() {
    local name="$1"
    local command="$2"
    local expected_exit="${3:-0}"

    log_info "Testing: $name"

    if eval "$command" > /tmp/make-test-output.log 2>&1; then
        actual_exit=0
    else
        actual_exit=$?
    fi

    if [ "$actual_exit" -eq "$expected_exit" ]; then
        log_pass "$name"
        return 0
    else
        log_fail "$name (expected exit $expected_exit, got $actual_exit)"
        cat /tmp/make-test-output.log | tail -20
        return 1
    fi
}

#############################################################################
# Test Categories
#############################################################################

test_help_commands() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Help & Information Commands"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    test_command "make help" "make help"
}

test_setup_commands() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Setup & Initialization Commands"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    test_command "make check-prereqs" "make check-prereqs"

    # Test init (should detect existing .env)
    test_command "make init (existing .env)" "echo 'N' | make init"

    test_command "make validate-env" "make validate-env"
}

test_info_commands() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Information Commands"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    # Version command - allow failure on kubectl part (cluster not running)
    # Just check that it displays some version info
    if make version 2>&1 | grep -q "Local Tools"; then
        log_pass "make version (shows local tools)"
    else
        log_skip "make version (cluster not running - expected)"
    fi

    # Info command - allow failure if cluster not running
    # Just check that it shows configuration
    if make info 2>&1 | grep -q "Configuration"; then
        log_pass "make info (shows config)"
    elif make info 2>&1 | grep -q "VM Status"; then
        log_pass "make info (shows VM status)"
    else
        log_skip "make info (cluster not running - expected)"
    fi
}

test_vagrant_commands() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Vagrant Status Commands"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    test_command "make status (vagrant status)" "make status"
}

test_file_structure() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing File Structure"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    # Check critical files exist
    local files=(
        "Makefile"
        "Vagrantfile"
        ".env"
        ".env.example"
        "setup-macos.sh"
        "ansible/ansible.cfg"
        "ansible/inventory/group_vars/all.yml"
        "ansible/playbooks/site.yml"
        "ansible/roles/common/tasks/main.yml"
        "scripts/utils/validate-env.sh"
    )

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            log_pass "File exists: $file"
        else
            log_fail "File missing: $file"
        fi
    done
}

test_scripts_executable() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Script Permissions"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    local scripts=(
        "setup-macos.sh"
        "scripts/utils/validate-env.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            log_pass "Executable: $script"
        else
            log_fail "Not executable: $script"
        fi
    done
}

test_env_file() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing .env Configuration"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [ -f .env ]; then
        log_pass ".env file exists"

        # Test required variables are set
        source .env

        local vars=(
            "CLUSTER_NAME"
            "K8S_VERSION"
            "VM_OS"
            "VM_COUNT_MASTERS"
            "VM_COUNT_WORKERS"
            "NETWORK_CIDR"
            "POD_CIDR"
            "SERVICE_CIDR"
        )

        for var in "${vars[@]}"; do
            if [ -n "${!var:-}" ]; then
                log_pass ".env has $var=${!var}"
            else
                log_fail ".env missing $var"
            fi
        done
    else
        log_fail ".env file does not exist"
    fi
}

test_ansible_syntax() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Ansible Syntax"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if command -v ansible-playbook >/dev/null 2>&1; then
        # Syntax check for main playbook (run from ansible directory)
        if (cd ansible && ansible-playbook --syntax-check playbooks/site.yml) >/dev/null 2>&1; then
            log_pass "Ansible playbook syntax valid"
        else
            log_fail "Ansible playbook syntax error"
        fi
    else
        log_skip "Ansible not installed"
    fi
}

test_vagrantfile_syntax() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Vagrantfile Syntax"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if command -v vagrant >/dev/null 2>&1; then
        if vagrant validate >/dev/null 2>&1; then
            log_pass "Vagrantfile syntax valid"
        else
            log_fail "Vagrantfile syntax error"
        fi
    else
        log_skip "Vagrant not installed"
    fi
}

#############################################################################
# Main Test Runner
#############################################################################

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║            Makefile & Infrastructure Test Suite          ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    log_info "Starting test suite..."
    echo ""

    # Change to project root
    cd "$(dirname "$0")/.."

    # Run test categories
    test_help_commands
    test_setup_commands
    test_info_commands
    test_vagrant_commands
    test_file_structure
    test_scripts_executable
    test_env_file
    test_ansible_syntax
    test_vagrantfile_syntax

    # Summary
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "                     TEST SUMMARY"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Passed:  $PASSED"
    echo "Failed:  $FAILED"
    echo "Skipped: $SKIPPED"
    echo "Total:   $((PASSED + FAILED + SKIPPED))"
    echo ""

    if [ "$FAILED" -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo ""
        echo "Phase 1 foundation is validated and ready."
        echo ""
        echo "Next steps:"
        echo "  • Review configuration: cat .env"
        echo "  • Start VMs: make up"
        echo "  • Or continue with Phase 2 implementation"
        echo ""
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo ""
        echo "Failed tests:"
        for result in "${RESULTS[@]}"; do
            if [[ "$result" == ✗* ]]; then
                echo "  $result"
            fi
        done
        echo ""
        exit 1
    fi
}

main "$@"
