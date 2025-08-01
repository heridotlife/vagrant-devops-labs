# Backup and Recovery Guide

## Overview

This guide covers backup and recovery procedures for the Kubernetes cluster and monitoring stack.

## Backup Components

### Kubernetes Cluster Backup
- **etcd**: Cluster state and configuration
- **Resources**: All Kubernetes resources (pods, services, configmaps, etc.)
- **Cluster Config**: kubeconfig, cluster roles, and bindings

### Monitoring Stack Backup
- **Docker Volumes**: Prometheus, Grafana, and Loki data
- **Configuration**: Docker Compose files and service configs
- **Container Images**: All monitoring stack images

## Backup Scripts

### Kubernetes Backup
```bash
# Location: scripts/backup/k8s-backup.sh
# Usage: Run on master1 node
sudo ./scripts/backup/k8s-backup.sh
```

**What it backs up:**
- etcd snapshot
- All Kubernetes resources (namespaces, pods, services, etc.)
- Cluster configuration (kubeconfig, roles, bindings)
- Persistent volumes and claims

### Kubernetes Restore
```bash
# Location: scripts/backup/k8s-restore.sh
# Usage: Run on master1 node with backup file
sudo ./scripts/backup/k8s-restore.sh /opt/backups/k8s/k8s_backup_YYYYMMDD_HHMMSS.tar.gz
```

### Monitoring Stack Backup
```bash
# Location: scripts/backup/monitoring-backup.sh
# Usage: Run on monitoring VM
sudo ./scripts/backup/monitoring-backup.sh
```

**What it backs up:**
- Docker volumes (Prometheus, Grafana, Loki data)
- Configuration files
- Container images
- Monitoring data exports

## Backup Schedule

### Recommended Schedule
- **Kubernetes Cluster**: Daily backups
- **Monitoring Stack**: Weekly backups
- **Retention**: 7 days for daily backups, 30 days for weekly backups

### Automated Backups
Create cron jobs for automated backups:

```bash
# Kubernetes backup (daily at 2 AM)
0 2 * * * /opt/backups/k8s-backup.sh

# Monitoring backup (weekly on Sunday at 3 AM)
0 3 * * 0 /opt/backups/monitoring-backup.sh
```

## Backup Locations

### Default Backup Directories
- **Kubernetes**: `/opt/backups/k8s/`
- **Monitoring**: `/opt/backups/monitoring/`

### Backup File Format
- **Kubernetes**: `k8s_backup_YYYYMMDD_HHMMSS.tar.gz`
- **Monitoring**: `monitoring_backup_YYYYMMDD_HHMMSS.tar.gz`

## Recovery Procedures

### Full Cluster Recovery

1. **Prepare the environment**
   ```bash
   # Ensure you're on master1 node
   ssh vagrant@10.0.254.11
   ```

2. **Stop the cluster**
   ```bash
   sudo systemctl stop kubelet
   ```

3. **Restore from backup**
   ```bash
   sudo ./scripts/backup/k8s-restore.sh /opt/backups/k8s/k8s_backup_YYYYMMDD_HHMMSS.tar.gz
   ```

4. **Verify recovery**
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

### Monitoring Stack Recovery

1. **Stop monitoring services**
   ```bash
   cd /opt/monitoring
   docker-compose down
   ```

2. **Restore from backup**
   ```bash
   # Extract backup
   tar -xzf /opt/backups/monitoring/monitoring_backup_YYYYMMDD_HHMMSS.tar.gz
   
   # Restore Docker volumes
   docker run --rm -v /backup/prometheus_data.tar.gz:/backup.tar.gz -v prometheus_data:/data alpine tar xzf /backup.tar.gz -C /data
   docker run --rm -v /backup/grafana_data.tar.gz:/backup.tar.gz -v grafana_data:/data alpine tar xzf /backup.tar.gz -C /data
   docker run --rm -v /backup/loki_data.tar.gz:/backup.tar.gz -v loki_data:/data alpine tar xzf /backup.tar.gz -C /data
   
   # Restore configuration
   cp backup/config/* /opt/monitoring/
   
   # Start services
   docker-compose up -d
   ```

## Backup Verification

### Verify Kubernetes Backup
```bash
# List available backups
ls -la /opt/backups/k8s/

# Check backup manifest
tar -tzf /opt/backups/k8s/k8s_backup_YYYYMMDD_HHMMSS.tar.gz | grep manifest
```

### Verify Monitoring Backup
```bash
# List available backups
ls -la /opt/backups/monitoring/

# Check backup contents
tar -tzf /opt/backups/monitoring/monitoring_backup_YYYYMMDD_HHMMSS.tar.gz
```

## Disaster Recovery

### Complete Cluster Failure

1. **Destroy and recreate VMs**
   ```bash
   vagrant destroy -f
   vagrant up
   ```

2. **Restore from backup**
   ```bash
   vagrant ssh master1
   sudo ./scripts/backup/k8s-restore.sh /opt/backups/k8s/latest_backup.tar.gz
   ```

3. **Restore monitoring stack**
   ```bash
   vagrant ssh monitoring
   sudo ./scripts/backup/monitoring-restore.sh /opt/backups/monitoring/latest_backup.tar.gz
   ```

### Partial Recovery

#### Single Node Failure
```bash
# Remove failed node
kubectl delete node <failed-node>

# Recreate node
vagrant up <node-name>

# Rejoin to cluster
vagrant ssh <node-name>
sudo kubeadm join --token <token> <master-ip>:6443
```

#### Service Recovery
```bash
# Check service status
kubectl get pods --all-namespaces

# Restart failed services
kubectl delete pod <failed-pod> -n <namespace>
```

## Backup Security

### Encryption
Consider encrypting sensitive backups:
```bash
# Encrypt backup
gpg -e -r your-email@domain.com backup_file.tar.gz

# Decrypt backup
gpg -d backup_file.tar.gz.gpg > backup_file.tar.gz
```

### Offsite Backup
Copy backups to external storage:
```bash
# Copy to external storage
scp /opt/backups/k8s/*.tar.gz user@backup-server:/backups/
```

## Monitoring Backup Health

### Backup Monitoring Dashboard
Create a Grafana dashboard to monitor backup health:

1. **Backup Success Rate**
2. **Backup Size Trends**
3. **Backup Duration**
4. **Storage Usage**

### Backup Alerts
Set up alerts for:
- Backup failures
- Backup size anomalies
- Storage space warnings
- Backup age warnings

## Troubleshooting

### Common Backup Issues

#### 1. Insufficient Storage
```bash
# Check available space
df -h /opt/backups/

# Clean up old backups
find /opt/backups/ -name "*.tar.gz" -mtime +7 -delete
```

#### 2. Permission Issues
```bash
# Fix permissions
sudo chown -R vagrant:vagrant /opt/backups/
sudo chmod +x /opt/backups/*.sh
```

#### 3. etcd Backup Failures
```bash
# Check etcd pod status
kubectl get pods -n kube-system | grep etcd

# Manual etcd backup
kubectl exec -n kube-system etcd-master1 -- etcdctl snapshot save /tmp/etcd-snapshot.db
```

### Recovery Issues

#### 1. Restore Fails
```bash
# Check backup integrity
tar -tzf backup_file.tar.gz

# Verify backup manifest
cat backup_file.tar.gz | tar -xO backup-manifest.json
```

#### 2. Cluster Not Ready After Restore
```bash
# Check node status
kubectl describe nodes

# Check system pods
kubectl get pods -n kube-system

# Restart kubelet
sudo systemctl restart kubelet
```

## Best Practices

1. **Test Recovery**: Regularly test backup restoration
2. **Multiple Copies**: Keep backups in multiple locations
3. **Documentation**: Document all backup and recovery procedures
4. **Monitoring**: Monitor backup success and storage usage
5. **Security**: Encrypt sensitive backups
6. **Retention**: Implement proper backup retention policies 