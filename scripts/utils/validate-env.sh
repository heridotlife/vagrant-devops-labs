#!/usr/bin/env bash

#############################################################################
# Environment Configuration Validator
#############################################################################
# Validates .env file for correctness and compatibility
#############################################################################

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Counters
ERRORS=0
WARNINGS=0
CHECKS=0

#############################################################################
# Helper Functions
#############################################################################

error() {
    echo -e "${RED}✗${NC} ERROR: $*"
    ERRORS=$((ERRORS + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} WARNING: $*"
    WARNINGS=$((WARNINGS + 1))
}

success() {
    echo -e "${GREEN}✓${NC} $*"
    CHECKS=$((CHECKS + 1))
}

info() {
    echo -e "  $*"
}

#############################################################################
# Validation Functions
#############################################################################

check_env_file() {
    if [ ! -f .env ]; then
        error ".env file not found"
        info "Run: make init (or cp .env.example .env)"
        return 1
    fi
    success ".env file exists"
}

validate_k8s_version() {
    if [ -z "${K8S_VERSION:-}" ]; then
        error "K8S_VERSION not set"
        return 1
    fi

    # Check if version is supported (MVP: only 1.31.x)
    if [[ ! "$K8S_VERSION" =~ ^1\.31\. ]]; then
        error "K8S_VERSION must be 1.31.x for MVP (got: $K8S_VERSION)"
        return 1
    fi

    success "Kubernetes version: $K8S_VERSION"
}

validate_vm_config() {
    # Check VM counts
    if [ "${VM_COUNT_MASTERS:-1}" -ne 1 ]; then
        warn "MVP supports only 1 master (got: ${VM_COUNT_MASTERS:-1})"
    fi

    if [ "${VM_COUNT_WORKERS:-2}" -lt 2 ]; then
        warn "At least 2 workers recommended (got: ${VM_COUNT_WORKERS:-2})"
    fi

    # Check resources
    local total_memory=$((VM_MASTER_MEMORY * VM_COUNT_MASTERS + VM_WORKER_MEMORY * VM_COUNT_WORKERS))
    local total_cpus=$((VM_MASTER_CPUS * VM_COUNT_MASTERS + VM_WORKER_CPUS * VM_COUNT_WORKERS))

    success "Total resources: ${total_cpus} vCPUs, ${total_memory}MB RAM"

    if [ "$total_memory" -gt 16384 ]; then
        warn "Total RAM allocation (${total_memory}MB) is high for a 32GB Mac"
    fi

    if [ "${VM_OS:-}" != "centos-stream-9" ]; then
        error "VM_OS must be 'centos-stream-9' for MVP (got: ${VM_OS:-})"
    fi
}

validate_network_config() {
    # Validate CIDR format (basic check)
    if [[ ! "${NETWORK_CIDR:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        error "NETWORK_CIDR invalid format: ${NETWORK_CIDR:-}"
        return 1
    fi

    if [[ ! "${POD_CIDR:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        error "POD_CIDR invalid format: ${POD_CIDR:-}"
        return 1
    fi

    if [[ ! "${SERVICE_CIDR:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        error "SERVICE_CIDR invalid format: ${SERVICE_CIDR:-}"
        return 1
    fi

    success "Network CIDRs configured correctly"

    # Check MetalLB IP range is within NETWORK_CIDR
    local network_prefix=$(echo "$NETWORK_CIDR" | cut -d'/' -f1 | cut -d'.' -f1-3)
    local metallb_prefix=$(echo "$METALLB_IP_START" | cut -d'.' -f1-3)

    if [ "$network_prefix" != "$metallb_prefix" ]; then
        error "MetalLB IP range must be within NETWORK_CIDR"
        info "  NETWORK_CIDR: $NETWORK_CIDR"
        info "  MetalLB range: $METALLB_IP_START - $METALLB_IP_END"
        return 1
    fi

    success "MetalLB IP pool configured correctly"
}

validate_container_runtime() {
    if [ "${CONTAINER_RUNTIME:-}" != "containerd" ]; then
        error "CONTAINER_RUNTIME must be 'containerd' for MVP (got: ${CONTAINER_RUNTIME:-})"
        return 1
    fi

    if [ "${CGROUP_DRIVER:-}" != "systemd" ]; then
        error "CGROUP_DRIVER must be 'systemd' (got: ${CGROUP_DRIVER:-})"
        return 1
    fi

    success "Container runtime: containerd with systemd cgroup driver"
}

validate_cni() {
    if [ "${CNI_PLUGIN:-}" != "calico" ]; then
        error "CNI_PLUGIN must be 'calico' for MVP (got: ${CNI_PLUGIN:-})"
        return 1
    fi

    success "CNI plugin: Calico ${CALICO_VERSION:-}"
}

validate_storage() {
    if [ "${STORAGE_PROVISIONER:-}" != "local-path" ]; then
        warn "STORAGE_PROVISIONER should be 'local-path' for MVP (got: ${STORAGE_PROVISIONER:-})"
    fi

    success "Storage provisioner: ${STORAGE_PROVISIONER:-local-path}"
}

validate_feature_flags() {
    # Check that MVP-incompatible features are disabled
    if [ "${ENABLE_HA_CONTROL_PLANE:-false}" = "true" ]; then
        error "HA control plane not supported in MVP"
    fi

    if [ "${ENABLE_FEDORA_COREOS:-false}" = "true" ]; then
        error "Fedora CoreOS not supported in MVP"
    fi

    if [ "${ENABLE_MULTI_VERSION:-false}" = "true" ]; then
        error "Multi-version support not available in MVP"
    fi

    success "Feature flags validated"
}

check_conflicts() {
    # Check for common network conflicts
    if route -n get default | grep -q "10.240.0"; then
        warn "Potential network conflict with existing route to 10.240.0.0/24"
        info "This may cause connectivity issues"
    fi
}

#############################################################################
# Main
#############################################################################

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║           Environment Configuration Validation                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Load .env file
    if ! check_env_file; then
        exit 1
    fi

    # Source .env
    set -a
    source .env
    set +a

    echo ""
    echo "Validating configuration..."
    echo ""

    # Run validations
    validate_k8s_version
    validate_vm_config
    validate_network_config
    validate_container_runtime
    validate_cni
    validate_storage
    validate_feature_flags
    check_conflicts

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed!${NC}"
        echo ""
        echo "Configuration summary:"
        echo "  • Cluster: ${CLUSTER_NAME}"
        echo "  • Kubernetes: ${K8S_VERSION}"
        echo "  • Nodes: ${VM_COUNT_MASTERS} master + ${VM_COUNT_WORKERS} workers"
        echo "  • Resources: $((VM_MASTER_CPUS * VM_COUNT_MASTERS + VM_WORKER_CPUS * VM_COUNT_WORKERS)) vCPUs, $((VM_MASTER_MEMORY * VM_COUNT_MASTERS + VM_WORKER_MEMORY * VM_COUNT_WORKERS))MB RAM"
        echo "  • Network: ${NETWORK_CIDR}"
        echo "  • CNI: ${CNI_PLUGIN}"
        echo "  • Storage: ${STORAGE_PROVISIONER}"
        echo ""
        echo "Ready to proceed with: make up"
        exit 0
    elif [ "$ERRORS" -eq 0 ]; then
        echo -e "${YELLOW}✓ Validation passed with warnings${NC}"
        echo ""
        echo "  Checks: $CHECKS"
        echo "  Warnings: $WARNINGS"
        echo ""
        echo "Review warnings above and proceed if acceptable."
        exit 0
    else
        echo -e "${RED}✗ Validation failed!${NC}"
        echo ""
        echo "  Checks: $CHECKS"
        echo "  Warnings: $WARNINGS"
        echo "  Errors: $ERRORS"
        echo ""
        echo "Please fix errors in .env and try again."
        exit 1
    fi
}

main "$@"
