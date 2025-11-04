#!/usr/bin/env bash

#############################################################################
# Kubeconfig Merge Script
#############################################################################
# Fetches the admin kubeconfig from the master node and merges it with
# the local kubeconfig file
#
# Usage:
#   ./kubeconfig-merge.sh
#
#############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MASTER_NODE="master-01"
REMOTE_KUBECONFIG="/etc/kubernetes/admin.conf"
LOCAL_KUBECONFIG="$HOME/.kube/config"
TEMP_KUBECONFIG="/tmp/k8s-lab-config-$(date +%s)"
CLUSTER_NAME="${CLUSTER_NAME:-k8s-lab}"

# Functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if vagrant is available
if ! command -v vagrant &> /dev/null; then
    print_error "Vagrant is not installed or not in PATH"
    exit 1
fi

# Check if master node is running
print_info "Checking if master node is running..."
if ! vagrant status "$MASTER_NODE" 2>/dev/null | grep -q "running"; then
    print_error "Master node ($MASTER_NODE) is not running"
    print_info "Start the cluster with: make up"
    exit 1
fi
print_success "Master node is running"

# Fetch kubeconfig from master node
print_info "Fetching kubeconfig from master node..."
if ! vagrant ssh "$MASTER_NODE" -c "sudo cat $REMOTE_KUBECONFIG" > "$TEMP_KUBECONFIG" 2>/dev/null; then
    print_error "Failed to fetch kubeconfig from master node"
    print_warning "The Kubernetes cluster may not be initialized yet"
    print_info "Initialize the cluster with: make cluster-init"
    rm -f "$TEMP_KUBECONFIG"
    exit 1
fi

# Verify the kubeconfig content
if [ ! -s "$TEMP_KUBECONFIG" ]; then
    print_error "Downloaded kubeconfig is empty"
    rm -f "$TEMP_KUBECONFIG"
    exit 1
fi
print_success "Kubeconfig fetched successfully"

# Update server address to use localhost (assuming kubectl proxy or port-forward)
# or the actual master node IP
print_info "Updating server address in kubeconfig..."
MASTER_IP=$(vagrant ssh "$MASTER_NODE" -c "hostname -I | awk '{print \$2}'" 2>/dev/null | tr -d '\r\n' || echo "10.240.0.11")
sed -i.bak "s|server: https://.*:6443|server: https://${MASTER_IP}:6443|g" "$TEMP_KUBECONFIG"
print_success "Server address updated to https://${MASTER_IP}:6443"

# Create .kube directory if it doesn't exist
mkdir -p "$HOME/.kube"

# Backup existing kubeconfig if it exists
if [ -f "$LOCAL_KUBECONFIG" ]; then
    BACKUP_FILE="${LOCAL_KUBECONFIG}.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$LOCAL_KUBECONFIG" "$BACKUP_FILE"
    print_info "Backed up existing kubeconfig to: $BACKUP_FILE"

    # Merge configs
    print_info "Merging kubeconfig with existing config..."
    KUBECONFIG="$LOCAL_KUBECONFIG:$TEMP_KUBECONFIG" kubectl config view --flatten > "${LOCAL_KUBECONFIG}.merged"
    mv "${LOCAL_KUBECONFIG}.merged" "$LOCAL_KUBECONFIG"
    print_success "Kubeconfig merged successfully"
else
    # No existing config, just copy the new one
    print_info "Creating new kubeconfig..."
    cp "$TEMP_KUBECONFIG" "$LOCAL_KUBECONFIG"
    print_success "Kubeconfig created successfully"
fi

# Set the context
print_info "Setting kubectl context to $CLUSTER_NAME..."
kubectl config use-context "kubernetes-admin@kubernetes" 2>/dev/null || \
    kubectl config use-context "$(kubectl config get-contexts -o name | head -1)" || \
    print_warning "Could not set context automatically"

# Clean up
rm -f "$TEMP_KUBECONFIG" "${TEMP_KUBECONFIG}.bak"

# Verify connection
echo ""
print_info "Verifying connection to cluster..."
if kubectl cluster-info &>/dev/null; then
    print_success "Successfully connected to cluster!"
    echo ""
    kubectl get nodes
else
    print_warning "Could not verify connection to cluster"
    print_info "You may need to configure port forwarding or update the server address"
    print_info "Current kubeconfig location: $LOCAL_KUBECONFIG"
fi

echo ""
print_success "Kubeconfig setup complete!"
print_info "You can now use kubectl to interact with your cluster"
