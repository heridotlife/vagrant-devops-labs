#!/bin/bash

# Kubernetes Cluster Restore Script
# This script restores the cluster from a backup

set -e

# Configuration
BACKUP_DIR="/opt/backups/k8s"
MASTER_NODE="10.0.254.11"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check if running on master node
check_master() {
    if [[ "$(hostname)" != "master1" ]]; then
        error "This script must be run on master1 node"
        exit 1
    fi
}

# Check if backup file exists
check_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        exit 1
    fi
    
    log "Found backup file: $backup_file"
}

# Extract backup
extract_backup() {
    local backup_file="$1"
    local extract_dir="/tmp/k8s_restore_$(date +%s)"
    
    log "Extracting backup to: $extract_dir"
    mkdir -p "$extract_dir"
    tar -xzf "$backup_file" -C "$extract_dir"
    
    # Find the extracted directory
    local extracted_dir=$(find "$extract_dir" -maxdepth 1 -type d -name "k8s_backup_*" | head -1)
    
    if [[ -z "$extracted_dir" ]]; then
        error "Could not find extracted backup directory"
        exit 1
    fi
    
    echo "$extracted_dir"
}

# Restore etcd
restore_etcd() {
    local backup_dir="$1"
    local etcd_snapshot="$backup_dir/etcd-snapshot.db"
    
    if [[ -f "$etcd_snapshot" ]]; then
        log "Restoring etcd from snapshot..."
        
        # Stop kubelet
        systemctl stop kubelet
        
        # Get etcd pod name
        ETCD_POD=$(kubectl get pods -n kube-system | grep etcd | awk '{print $1}')
        
        if [[ -n "$ETCD_POD" ]]; then
            # Copy snapshot to etcd pod
            kubectl cp "$etcd_snapshot" kube-system/"$ETCD_POD":/tmp/etcd-snapshot.db
            
            # Restore etcd
            kubectl exec -n kube-system "$ETCD_POD" -- etcdctl snapshot restore /tmp/etcd-snapshot.db --data-dir=/var/lib/etcd-restored
            
            # Stop etcd
            kubectl exec -n kube-system "$ETCD_POD" -- pkill etcd
            
            # Replace etcd data
            kubectl exec -n kube-system "$ETCD_POD" -- mv /var/lib/etcd-restored /var/lib/etcd
            
            log "Etcd restore completed"
        else
            warning "Etcd pod not found, skipping etcd restore"
        fi
        
        # Start kubelet
        systemctl start kubelet
    else
        warning "Etcd snapshot not found in backup"
    fi
}

# Restore cluster configuration
restore_cluster_config() {
    local backup_dir="$1"
    local cluster_config_dir="$backup_dir/cluster-config"
    
    if [[ -d "$cluster_config_dir" ]]; then
        log "Restoring cluster configuration..."
        
        # Restore admin.conf if it exists
        if [[ -f "$cluster_config_dir/admin.conf" ]]; then
            cp "$cluster_config_dir/admin.conf" /etc/kubernetes/admin.conf
            log "Restored admin.conf"
        fi
        
        # Restore cluster roles and bindings
        if [[ -f "$cluster_config_dir/cluster-roles.yaml" ]]; then
            kubectl apply -f "$cluster_config_dir/cluster-roles.yaml"
            log "Restored cluster roles"
        fi
        
        if [[ -f "$cluster_config_dir/cluster-role-bindings.yaml" ]]; then
            kubectl apply -f "$cluster_config_dir/cluster-role-bindings.yaml"
            log "Restored cluster role bindings"
        fi
    else
        warning "Cluster configuration not found in backup"
    fi
}

# Restore resources
restore_resources() {
    local backup_dir="$1"
    local resources_dir="$backup_dir/resources"
    
    if [[ -d "$resources_dir" ]]; then
        log "Restoring Kubernetes resources..."
        
        # Restore persistent volumes first
        if [[ -f "$resources_dir/persistent-volumes.yaml" ]]; then
            kubectl apply -f "$resources_dir/persistent-volumes.yaml"
            log "Restored persistent volumes"
        fi
        
        if [[ -f "$resources_dir/persistent-volume-claims.yaml" ]]; then
            kubectl apply -f "$resources_dir/persistent-volume-claims.yaml"
            log "Restored persistent volume claims"
        fi
        
        # Restore namespaces and resources
        for namespace_dir in "$resources_dir"/*/; do
            if [[ -d "$namespace_dir" ]]; then
                local namespace=$(basename "$namespace_dir")
                log "Restoring namespace: $namespace"
                
                # Create namespace if it doesn't exist
                kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
                
                # Restore all resources in namespace
                if [[ -f "$namespace_dir/all-resources.yaml" ]]; then
                    kubectl apply -f "$namespace_dir/all-resources.yaml"
                fi
                
                # Restore configmaps
                if [[ -f "$namespace_dir/configmaps.yaml" ]]; then
                    kubectl apply -f "$namespace_dir/configmaps.yaml"
                fi
                
                # Restore secrets
                if [[ -f "$namespace_dir/secrets.yaml" ]]; then
                    kubectl apply -f "$namespace_dir/secrets.yaml"
                fi
            fi
        done
    else
        warning "Resources not found in backup"
    fi
}

# Verify restore
verify_restore() {
    log "Verifying restore..."
    
    # Check cluster health
    kubectl get nodes
    kubectl get pods --all-namespaces
    
    # Check etcd health
    kubectl get pods -n kube-system | grep etcd
    
    log "Restore verification completed"
}

# Cleanup
cleanup() {
    local extract_dir="$1"
    
    if [[ -d "$extract_dir" ]]; then
        log "Cleaning up temporary files..."
        rm -rf "$extract_dir"
    fi
}

# Main restore function
main() {
    if [[ $# -eq 0 ]]; then
        error "Usage: $0 <backup_file.tar.gz>"
        echo "Available backups:"
        ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No backups found"
        exit 1
    fi
    
    local backup_file="$1"
    
    log "Starting Kubernetes cluster restore..."
    
    check_master
    check_backup "$backup_file"
    
    local extract_dir=$(extract_backup "$backup_file")
    
    # Stop kubelet before restore
    systemctl stop kubelet
    
    restore_etcd "$extract_dir"
    restore_cluster_config "$extract_dir"
    restore_resources "$extract_dir"
    
    # Start kubelet after restore
    systemctl start kubelet
    
    # Wait for cluster to be ready
    log "Waiting for cluster to be ready..."
    sleep 30
    
    verify_restore
    cleanup "$extract_dir"
    
    log "Restore completed successfully"
}

# Run main function
main "$@" 