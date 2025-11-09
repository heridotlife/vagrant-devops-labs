#!/usr/bin/env bash

#############################################################################
# Phase 2 Validation Test Suite
#############################################################################
# Tests Phase 2 implementation (Kubernetes core components)
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

#############################################################################
# Test Categories
#############################################################################

test_ansible_roles() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Ansible Roles Structure"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    local roles=(
        "common"
        "pki"
        "container-runtime"
        "etcd"
    )

    for role in "${roles[@]}"; do
        if [ -d "ansible/roles/$role" ]; then
            log_pass "Role exists: $role"

            # Check for main tasks file
            if [ -f "ansible/roles/$role/tasks/main.yml" ]; then
                log_pass "  └─ tasks/main.yml exists"
            else
                log_fail "  └─ tasks/main.yml missing"
            fi

            # Check for defaults
            if [ -f "ansible/roles/$role/defaults/main.yml" ]; then
                log_pass "  └─ defaults/main.yml exists"
            else
                log_skip "  └─ defaults/main.yml not found (optional)"
            fi

            # Check for README
            if [ -f "ansible/roles/$role/README.md" ]; then
                log_pass "  └─ README.md exists"
            else
                log_skip "  └─ README.md not found (optional)"
            fi
        else
            log_fail "Role missing: $role"
        fi
    done
}

test_ansible_configuration() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Ansible Configuration"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    # Test ansible.cfg
    if [ -f "ansible/ansible.cfg" ]; then
        log_pass "ansible.cfg exists"

        # Check roles_path
        if grep -q "roles_path.*=.*./roles" ansible/ansible.cfg; then
            log_pass "  └─ roles_path configured correctly"
        else
            log_fail "  └─ roles_path misconfigured"
        fi
    else
        log_fail "ansible.cfg missing"
    fi

    # Test playbook
    if [ -f "ansible/playbooks/site.yml" ]; then
        log_pass "site.yml playbook exists"
    else
        log_fail "site.yml playbook missing"
    fi

    # Test requirements.yml
    if [ -f "ansible/requirements.yml" ]; then
        log_pass "requirements.yml exists"
    else
        log_skip "requirements.yml not found"
    fi
}

test_ansible_syntax() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Ansible Syntax"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if command -v ansible-playbook >/dev/null 2>&1; then
        if (cd ansible && ansible-playbook --syntax-check playbooks/site.yml) >/dev/null 2>&1; then
            log_pass "Playbook syntax valid"
        else
            log_fail "Playbook syntax error"
        fi
    else
        log_skip "Ansible not installed"
    fi
}

test_role_documentation() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Role Documentation"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    local roles=("common" "pki" "container-runtime" "etcd")

    for role in "${roles[@]}"; do
        if [ -f "ansible/roles/$role/README.md" ]; then
            # Check README has minimum content
            if [ $(wc -l < "ansible/roles/$role/README.md") -gt 20 ]; then
                log_pass "$role: README has comprehensive documentation"
            else
                log_fail "$role: README is too short"
            fi
        else
            log_skip "$role: No README found"
        fi
    done
}

test_makefile_integration() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Makefile Integration"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    # Test that cluster-init target exists
    if grep -q "^cluster-init:" Makefile; then
        log_pass "make cluster-init target exists"
    else
        log_fail "make cluster-init target missing"
    fi

    # Test help command
    if make help >/dev/null 2>&1; then
        log_pass "make help works"
    else
        log_fail "make help failed"
    fi
}

test_phase2_completeness() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Testing Phase 2 Completeness"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    # Completed roles
    local completed_roles=("pki" "container-runtime" "etcd")
    for role in "${completed_roles[@]}"; do
        if [ -d "ansible/roles/$role" ]; then
            log_pass "Phase 2 role implemented: $role"
        else
            log_fail "Phase 2 role missing: $role"
        fi
    done

    # Pending roles (should not exist yet)
    local pending_roles=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "kubelet" "kube-proxy")
    for role in "${pending_roles[@]}"; do
        if [ -d "ansible/roles/$role" ]; then
            log_skip "Future role exists early: $role"
        else
            log_pass "Future role not yet implemented: $role (expected)"
        fi
    done
}

#############################################################################
# Main Test Runner
#############################################################################

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║              Phase 2 Validation Test Suite               ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    log_info "Starting Phase 2 validation tests..."
    echo ""

    # Change to project root
    cd "$(dirname "$0")/.."

    # Run test categories
    test_ansible_roles
    test_ansible_configuration
    test_ansible_syntax
    test_role_documentation
    test_makefile_integration
    test_phase2_completeness

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
        echo "Phase 2 progress: 3/10 roles completed (30%)"
        echo ""
        echo "Completed:"
        echo "  ✓ PKI role (certificates)"
        echo "  ✓ Container runtime role (containerd)"
        echo "  ✓ etcd role (datastore)"
        echo ""
        echo "Pending:"
        echo "  ⏳ kube-apiserver role"
        echo "  ⏳ kube-controller-manager role"
        echo "  ⏳ kube-scheduler role"
        echo "  ⏳ kubelet role"
        echo "  ⏳ kube-proxy role"
        echo "  ⏳ CNI role (Calico)"
        echo "  ⏳ kubeconfig generation"
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
