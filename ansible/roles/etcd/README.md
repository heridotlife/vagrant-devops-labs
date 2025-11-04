# etcd Role

Installs and configures etcd as the distributed key-value store for Kubernetes cluster state.

## Overview

This role implements etcd installation following "Kubernetes The Hard Way" methodology. etcd is the backing store for all cluster data in Kubernetes, storing the configuration data, state, and metadata.

## What is etcd?

etcd is a distributed reliable key-value store that is:
- **Consistent**: Uses Raft consensus algorithm
- **Highly Available**: Can run in a cluster of 3, 5, or 7 nodes
- **Secure**: Supports TLS client certificate authentication
- **Fast**: Benchmarked at 10,000 writes/sec

## Installed Components

### etcd
- **Version**: 3.5.16 (configurable)
- **Binaries**: `/usr/local/bin/{etcd,etcdctl,etcdutl}`
- **Data**: `/var/lib/etcd`
- **Config**: `/etc/etcd/etcd.env`

### Endpoints
- **Client**: `https://NODE_IP:2379` (Kubernetes API server connects here)
- **Peer**: `https://NODE_IP:2380` (etcd cluster communication)
- **Metrics**: `http://127.0.0.1:2381` (Prometheus metrics)

## Configuration

### Single-Node Setup (MVP)

For lab/development environments, a single etcd node is sufficient:

```yaml
etcd_initial_cluster: "{{ inventory_hostname }}=https://{{ ansible_default_ipv4.address }}:2380"
etcd_initial_cluster_state: "new"
```

### Multi-Node Setup (Production)

For production, use 3 or 5 nodes for high availability:

```yaml
etcd_initial_cluster: "master-01=https://10.240.0.11:2380,master-02=https://10.240.0.12:2380,master-03=https://10.240.0.13:2380"
```

### Security

etcd requires TLS certificates (from PKI role):

```yaml
etcd_ca_file: "/etc/kubernetes/pki/ca.crt"
etcd_cert_file: "/etc/kubernetes/pki/apiserver.crt"
etcd_key_file: "/etc/kubernetes/pki/apiserver.key"
etcd_client_cert_auth: true
etcd_peer_client_cert_auth: true
```

## Directory Structure

```
/usr/local/bin/
├── etcd         # etcd server
├── etcdctl      # etcd CLI tool
└── etcdutl      # etcd utility tool

/etc/etcd/
└── etcd.env     # Environment configuration

/var/lib/etcd/   # Data directory
└── member/
    ├── snap/    # Snapshots
    └── wal/     # Write-ahead log
```

## Usage

### Basic Usage

```yaml
- hosts: masters
  roles:
    - role: etcd
```

### With Custom Variables

```yaml
- hosts: masters
  roles:
    - role: etcd
      vars:
        etcd_version: "3.5.16"
        etcd_quota_backend_bytes: 8589934592  # 8GB
```

### Tags

```bash
# Install only
ansible-playbook site.yml --tags etcd,install

# Configure only
ansible-playbook site.yml --tags etcd,configure

# Verify only
ansible-playbook site.yml --tags etcd,verify
```

## Requirements

### Prerequisites
- PKI role must be run first (certificates required)
- Open ports: 2379 (client), 2380 (peer), 2381 (metrics)

### System Requirements
- 8GB disk space for data
- 2GB RAM minimum
- systemd for service management

## Variables

### Version Variables

```yaml
etcd_version: "3.5.16"
```

### Directory Variables

```yaml
etcd_bin_dir: "/usr/local/bin"
etcd_data_dir: "/var/lib/etcd"
etcd_config_dir: "/etc/etcd"
```

### Network Variables

```yaml
etcd_listen_client_urls: "https://NODE_IP:2379,https://127.0.0.1:2379"
etcd_advertise_client_urls: "https://NODE_IP:2379"
etcd_listen_peer_urls: "https://NODE_IP:2380"
etcd_initial_advertise_peer_urls: "https://NODE_IP:2380"
```

### Performance Variables

```yaml
etcd_snapshot_count: 10000              # Snapshots after N transactions
etcd_heartbeat_interval: 100            # Heartbeat in ms
etcd_election_timeout: 1000             # Election timeout in ms
etcd_quota_backend_bytes: 8589934592    # 8GB quota
```

## etcdctl Usage

### Basic Commands

```bash
# Set API version
export ETCDCTL_API=3

# Set certificates
export ETCDCTL_CACERT=/etc/kubernetes/pki/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/apiserver.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/apiserver.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379

# Check cluster health
etcdctl endpoint health

# Check cluster status
etcdctl endpoint status --write-out=table

# List members
etcdctl member list --write-out=table

# Put/Get key-value
etcdctl put /test "hello world"
etcdctl get /test

# List all keys
etcdctl get / --prefix --keys-only

# Watch for changes
etcdctl watch /registry --prefix

# Create snapshot
etcdctl snapshot save /tmp/etcd-snapshot.db

# Restore from snapshot
etcdctl snapshot restore /tmp/etcd-snapshot.db
```

### Kubernetes-Specific Operations

```bash
# List all pods (stored in etcd)
etcdctl get /registry/pods --prefix --keys-only

# List all namespaces
etcdctl get /registry/namespaces --prefix --keys-only

# Count total keys
etcdctl get / --prefix --keys-only | wc -l
```

## Verification

The role includes comprehensive verification:

1. **Health Check**: Verifies cluster is healthy
2. **Status Check**: Shows cluster member status
3. **Member List**: Lists all cluster members
4. **Read/Write Test**: Tests basic operations
5. **Service Status**: Confirms systemd service is active

### Manual Verification

```bash
# Check service
systemctl status etcd

# Check logs
journalctl -u etcd -f

# Test etcdctl
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver.crt \
  --key=/etc/kubernetes/pki/apiserver.key \
  endpoint health

# Check data directory
du -sh /var/lib/etcd
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
journalctl -u etcd -n 50 --no-pager

# Common issues:
# 1. Certificates not found
ls -l /etc/kubernetes/pki/

# 2. Port already in use
ss -tlnp | grep -E '2379|2380'

# 3. Data directory permissions
ls -ld /var/lib/etcd
```

### Cluster Health Issues

```bash
# Check member status
etcdctl member list

# Check endpoint health
etcdctl endpoint health --cluster

# Check alarms
etcdctl alarm list
```

### Performance Issues

```bash
# Check metrics
curl http://127.0.0.1:2381/metrics

# Check backend size
etcdctl endpoint status --write-out=table

# Compact old revisions
etcdctl compact $(etcdctl endpoint status --write-out="json" | jq -r '.Status[0].revision')

# Defragment
etcdctl defrag
```

### Data Corruption

```bash
# Create backup
etcdctl snapshot save /tmp/backup.db

# Check snapshot
etcdctl snapshot status /tmp/backup.db

# Restore if needed
systemctl stop etcd
rm -rf /var/lib/etcd
etcdctl snapshot restore /tmp/backup.db --data-dir=/var/lib/etcd
systemctl start etcd
```

## Backup and Recovery

### Automated Backups

Create a cron job for regular backups:

```bash
# /etc/cron.daily/etcd-backup
#!/bin/bash
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver.crt \
  --key=/etc/kubernetes/pki/apiserver.key \
  snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db
```

### Disaster Recovery

1. Stop etcd service
2. Remove corrupted data
3. Restore from snapshot
4. Restart service

```bash
systemctl stop etcd
rm -rf /var/lib/etcd
etcdctl snapshot restore /backup/etcd-latest.db \
  --data-dir=/var/lib/etcd \
  --name={{ inventory_hostname }} \
  --initial-cluster={{ etcd_initial_cluster }} \
  --initial-advertise-peer-urls={{ etcd_initial_advertise_peer_urls }}
systemctl start etcd
```

## Security Considerations

1. **Certificate Authentication**
   - All client connections require valid TLS certificates
   - Peer communication is also encrypted

2. **Network Security**
   - Metrics endpoint (2381) is unencrypted - bind to localhost only
   - Client/peer ports should be firewalled to cluster nodes only

3. **Data at Rest**
   - etcd data is not encrypted on disk
   - Use encrypted storage volumes for production

4. **Access Control**
   - Only Kubernetes API server should access etcd
   - Do not expose etcd directly to the internet

## Monitoring

### Metrics Available

- `etcd_server_has_leader`: Leader election status
- `etcd_server_leader_changes_seen_total`: Leader changes
- `etcd_disk_backend_commit_duration_seconds`: Disk latency
- `etcd_network_peer_round_trip_time_seconds`: Network latency
- `etcd_mvcc_db_total_size_in_bytes`: Database size

### Prometheus Integration

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'etcd'
    static_configs:
      - targets: ['master-01:2381']
```

## References

- [etcd Official Documentation](https://etcd.io/docs/)
- [etcd Operations Guide](https://etcd.io/docs/v3.5/op-guide/)
- [Kubernetes etcd](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
- [etcd Raft Consensus](https://raft.github.io/)
- [Kubernetes The Hard Way - etcd](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/07-bootstrapping-etcd.md)
