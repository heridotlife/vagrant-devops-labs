#!/bin/bash

# Monitoring Stack Backup Script
# This script creates backups of the monitoring stack (Prometheus, Grafana, Loki)

set -e

# Configuration
BACKUP_DIR="/opt/backups/monitoring"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="monitoring_backup_${DATE}"
MONITORING_VM="10.0.254.31"
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

# Check if running on monitoring VM
check_monitoring_vm() {
    if [[ "$(hostname)" != "monitoring" ]]; then
        error "This script must be run on monitoring VM"
        exit 1
    fi
}

# Create backup directory
create_backup_dir() {
    log "Creating backup directory: ${BACKUP_DIR}/${BACKUP_NAME}"
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"
}

# Backup Docker volumes
backup_docker_volumes() {
    log "Backing up Docker volumes..."
    
    # Create volumes backup directory
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/volumes"
    
    # Backup Prometheus data
    if docker volume ls | grep -q prometheus_data; then
        log "Backing up Prometheus data..."
        docker run --rm -v prometheus_data:/data -v "${BACKUP_DIR}/${BACKUP_NAME}/volumes:/backup" alpine tar czf /backup/prometheus_data.tar.gz -C /data .
    fi
    
    # Backup Grafana data
    if docker volume ls | grep -q grafana_data; then
        log "Backing up Grafana data..."
        docker run --rm -v grafana_data:/data -v "${BACKUP_DIR}/${BACKUP_NAME}/volumes:/backup" alpine tar czf /backup/grafana_data.tar.gz -C /data .
    fi
    
    # Backup Loki data
    if docker volume ls | grep -q loki_data; then
        log "Backing up Loki data..."
        docker run --rm -v loki_data:/data -v "${BACKUP_DIR}/${BACKUP_NAME}/volumes:/backup" alpine tar czf /backup/loki_data.tar.gz -C /data .
    fi
}

# Backup Docker Compose configuration
backup_configuration() {
    log "Backing up monitoring configuration..."
    
    # Create config backup directory
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/config"
    
    # Backup Docker Compose file
    if [[ -f "/opt/monitoring/docker-compose.yml" ]]; then
        cp "/opt/monitoring/docker-compose.yml" "${BACKUP_DIR}/${BACKUP_NAME}/config/"
    fi
    
    # Backup Prometheus configuration
    if [[ -f "/opt/monitoring/prometheus/prometheus.yml" ]]; then
        cp "/opt/monitoring/prometheus/prometheus.yml" "${BACKUP_DIR}/${BACKUP_NAME}/config/"
    fi
    
    # Backup Grafana dashboards and datasources
    if [[ -d "/opt/monitoring/grafana" ]]; then
        cp -r "/opt/monitoring/grafana" "${BACKUP_DIR}/${BACKUP_NAME}/config/"
    fi
}

# Backup container images
backup_images() {
    log "Backing up container images..."
    
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/images"
    
    # Save container images
    docker save prom/prometheus:latest -o "${BACKUP_DIR}/${BACKUP_NAME}/images/prometheus.tar"
    docker save grafana/grafana:latest -o "${BACKUP_DIR}/${BACKUP_NAME}/images/grafana.tar"
    docker save grafana/loki:latest -o "${BACKUP_DIR}/${BACKUP_NAME}/images/loki.tar"
    
    log "Container images backed up"
}

# Backup monitoring data
backup_monitoring_data() {
    log "Backing up monitoring data..."
    
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/data"
    
    # Export Prometheus data (if accessible)
    if curl -s http://localhost:9090/api/v1/status/targets > /dev/null 2>&1; then
        log "Exporting Prometheus data..."
        curl -s http://localhost:9090/api/v1/admin/tsdb/snapshot > "${BACKUP_DIR}/${BACKUP_NAME}/data/prometheus_snapshot.json" 2>/dev/null || true
    fi
    
    # Export Grafana dashboards
    if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
        log "Exporting Grafana dashboards..."
        # This would require Grafana API token for full export
        # For now, we'll just note that dashboards need manual export
        echo "Grafana dashboards need manual export via API" > "${BACKUP_DIR}/${BACKUP_NAME}/data/grafana_export_note.txt"
    fi
}

# Create backup manifest
create_backup_manifest() {
    log "Creating backup manifest..."
    
    cat > "${BACKUP_DIR}/${BACKUP_NAME}/backup-manifest.json" << EOF
{
    "backup_name": "${BACKUP_NAME}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "monitoring_vm": "${MONITORING_VM}",
    "backup_components": [
        "docker_volumes",
        "configuration",
        "container_images",
        "monitoring_data"
    ],
    "services": [
        "prometheus",
        "grafana",
        "loki"
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
    log "Starting monitoring stack backup..."
    
    check_monitoring_vm
    create_backup_dir
    backup_docker_volumes
    backup_configuration
    backup_images
    backup_monitoring_data
    create_backup_manifest
    compress_backup
    cleanup_old_backups
    
    log "Backup completed successfully: ${BACKUP_NAME}.tar.gz"
    log "Backup location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
}

# Run main function
main "$@" 