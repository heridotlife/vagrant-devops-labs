#!/bin/bash

# Kubernetes Cluster Backup Script
# This script creates backups of the entire Kubernetes cluster

set -e

# Configuration
BACKUP_DIR="/opt/backups/k8s"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="k8s_backup_${DATE}"
MASTER_NODE="10.0.254.11"
BACKUP_RETENTION_DAYS=7

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

# Create backup directory
create_backup_dir() {
    log "Creating backup directory: ${BACKUP_DIR}/${BACKUP_NAME}"
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"
}

# Backup etcd
backup_etcd() {
    log "Backing up etcd..."
    
    # Get etcd pod name
    ETCD_POD=$(kubectl get pods -n kube-system | grep etcd | awk '{print $1}')
    
    if [[ -n "$ETCD_POD" ]]; then
        kubectl exec -n kube-system "$ETCD_POD" -- etcdctl snapshot save /tmp/etcd-snapshot.db
        kubectl cp kube-system/"$ETCD_POD":/tmp/etcd-snapshot.db "${BACKUP_DIR}/${BACKUP_NAME}/etcd-snapshot.db"
        log "Etcd backup completed"
    else
        warning "Etcd pod not found, skipping etcd backup"
    fi
}

# Backup all Kubernetes resources
backup_resources() {
    log "Backing up Kubernetes resources..."
    
    # Create resources backup directory
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/resources"
    
    # Get all namespaces
    NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
    
    for namespace in $NAMESPACES; do
        if [[ "$namespace" != "kube-system" && "$namespace" != "kube-public" ]]; then
            log "Backing up namespace: $namespace"
            mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/resources/${namespace}"
            
            # Backup all resources in namespace
            kubectl get all -n "$namespace" -o yaml > "${BACKUP_DIR}/${BACKUP_NAME}/resources/${namespace}/all-resources.yaml"
            
            # Backup configmaps
            kubectl get configmaps -n "$namespace" -o yaml > "${BACKUP_DIR}/${BACKUP_NAME}/resources/${namespace}/configmaps.yaml" 2>/dev/null || true
            
            # Backup secrets
            kubectl get secrets -n "$namespace" -o yaml > "${BACKUP_DIR}/${BACKUP_NAME}/resources/${namespace}/secrets.yaml" 2>/dev/null || true
            
            # Backup persistent volumes
            kubectl get pv -o yaml > "${BACKUP_DIR}/${BACKUP_NAME}/resources/persistent-volumes.yaml" 2>/dev/null || true
            kubectl get pvc --all-namespaces -o yaml > "${BACKUP_DIR}/${BACKUP_NAME}/resources/persistent-volume-claims.yaml" 2>/dev/null || true
        fi
    done
}

# Backup cluster configuration
backup_cluster_config() {
    log "Backing up cluster configuration..."
    
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/cluster-config"
    
    # Backup kubeconfig
    cp /etc/kubernetes/admin.conf "${BACKUP_DIR}/${BACKUP_NAME}/cluster-config/admin.conf"
    
    # Backup cluster info
    kubectl cluster-info dump > "${BACKUP_DIR}/${BACKUP_NAME}/cluster-config/cluster-info.json"
    
    # Backup nodes info
    kubectl get nodes -o yaml > "${BACKUP_DIR}/${BACKUP_NAME}/cluster-config/nodes.yaml"
    
    # Backup cluster roles and bindings
    kubectl get clusterroles -o yaml > "${BACKUP_DIR}/${BACKUP_NAME}/cluster-config/cluster-roles.yaml"
    kubectl get clusterrolebindings -o yaml > "${BACKUP_DIR}/${BACKUP_NAME}/cluster-config/cluster-role-bindings.yaml"
}

# Create backup manifest
create_backup_manifest() {
    log "Creating backup manifest..."
    
    cat > "${BACKUP_DIR}/${BACKUP_NAME}/backup-manifest.json" << EOF
{
    "backup_name": "${BACKUP_NAME}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "cluster_version": "$(kubectl version --short | grep Server | cut -d' ' -f3)",
    "node_count": "$(kubectl get nodes --no-headers | wc -l)",
    "namespace_count": "$(kubectl get namespaces --no-headers | wc -l)",
    "backup_components": [
        "etcd",
        "resources",
        "cluster-config"
    ]
}
EOF
}

# Compress backup
compress_backup() {
    log "Compressing backup..."
    cd "${BACKUP_DIR}"
    tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
    rm -rf "${BACKUP_NAME}"
    log "Backup compressed: ${BACKUP_NAME}.tar.gz"
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up backups older than ${BACKUP_RETENTION_DAYS} days..."
    find "${BACKUP_DIR}" -name "*.tar.gz" -mtime +${BACKUP_RETENTION_DAYS} -delete
}

# Main backup function
main() {
    log "Starting Kubernetes cluster backup..."
    
    check_master
    create_backup_dir
    backup_etcd
    backup_resources
    backup_cluster_config
    create_backup_manifest
    compress_backup
    cleanup_old_backups
    
    log "Backup completed successfully: ${BACKUP_NAME}.tar.gz"
    log "Backup location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
}

# Run main function
main "$@" 