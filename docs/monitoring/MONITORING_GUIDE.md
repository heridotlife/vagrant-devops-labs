# Monitoring Guide

## Overview

This guide covers the monitoring stack setup, configuration, and usage for the Kubernetes cluster.

## Monitoring Stack Components

### Prometheus
- **Purpose**: Metrics collection and storage
- **Port**: 9090
- **URL**: http://10.0.254.31:9090

### Grafana
- **Purpose**: Visualization and dashboards
- **Port**: 3000
- **URL**: http://10.0.254.31:3000
- **Default Credentials**: admin/admin

### Loki
- **Purpose**: Log aggregation
- **Port**: 3100
- **URL**: http://10.0.254.31:3100

## Architecture

```
Kubernetes Cluster (10.0.254.11-23)
    ↓ (metrics)
Prometheus (10.0.254.31:9090)
    ↓ (data)
Grafana (10.0.254.31:3000)
    ↓ (logs)
Loki (10.0.254.31:3100)
```

## Installation

### Automatic Installation
The monitoring stack is automatically installed when you run:
```bash
vagrant up
```

### Manual Installation
If you need to install manually:

```bash
# SSH into monitoring VM
vagrant ssh monitoring

# Run monitoring setup
sudo ansible-playbook -i /vagrant/ansible/inventory /vagrant/ansible/monitoring-setup.yml
```

## Configuration

### Prometheus Configuration
Location: `/opt/monitoring/prometheus/prometheus.yml`

**Key Configuration:**
```yaml
scrape_configs:
  - job_name: 'kubernetes-masters'
    static_configs:
      - targets: 
        - '10.0.254.11:9100'
        - '10.0.254.12:9100'
        - '10.0.254.13:9100'
```

### Grafana Configuration
Location: `/opt/monitoring/grafana/`

**Default Settings:**
- Admin user: admin
- Admin password: admin
- Sign-up disabled
- Anonymous access disabled

### Loki Configuration
Location: `/opt/monitoring/loki/`

**Default Settings:**
- Local storage
- Single instance mode
- HTTP API enabled

## Accessing the Monitoring Stack

### Web Interfaces

#### Prometheus
```bash
# Access Prometheus UI
open http://10.0.254.31:9090

# Or use curl
curl http://10.0.254.31:9090/api/v1/status/targets
```

#### Grafana
```bash
# Access Grafana UI
open http://10.0.254.31:3000

# Login with admin/admin
```

#### Loki
```bash
# Access Loki UI
open http://10.0.254.31:3100
```

### API Access

#### Prometheus API
```bash
# Get all metrics
curl http://10.0.254.31:9090/api/v1/query?query=up

# Get targets
curl http://10.0.254.31:9090/api/v1/targets

# Get rules
curl http://10.0.254.31:9090/api/v1/rules
```

#### Grafana API
```bash
# Get dashboards (requires authentication)
curl -u admin:admin http://10.0.254.31:3000/api/dashboards

# Get datasources
curl -u admin:admin http://10.0.254.31:3000/api/datasources
```

## Dashboards

### Pre-configured Dashboards

#### 1. Kubernetes Cluster Overview
- **Purpose**: Overall cluster health
- **Metrics**: Node status, pod count, resource usage
- **URL**: Grafana → Dashboards → Kubernetes Cluster Overview

#### 2. Node Exporter Dashboard
- **Purpose**: Individual node metrics
- **Metrics**: CPU, memory, disk, network usage
- **URL**: Grafana → Dashboards → Node Exporter

#### 3. Prometheus Dashboard
- **Purpose**: Prometheus self-monitoring
- **Metrics**: Prometheus performance, storage, targets
- **URL**: Grafana → Dashboards → Prometheus

### Creating Custom Dashboards

#### 1. Access Grafana
```bash
open http://10.0.254.31:3000
```

#### 2. Create New Dashboard
1. Click "+" → "Dashboard"
2. Add new panel
3. Select Prometheus as data source
4. Write PromQL query

#### 3. Example Queries
```promql
# CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Disk usage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100
```

## Alerts

### Pre-configured Alerts

#### 1. Node Down Alert
```yaml
alert: NodeDown
expr: up == 0
for: 1m
labels:
  severity: critical
annotations:
  summary: "Node {{ $labels.instance }} is down"
```

#### 2. High CPU Usage
```yaml
alert: HighCPUUsage
expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
for: 5m
labels:
  severity: warning
```

#### 3. High Memory Usage
```yaml
alert: HighMemoryUsage
expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
for: 5m
labels:
  severity: warning
```

### Adding Custom Alerts

#### 1. Edit Prometheus Rules
```bash
# Edit rules file
sudo nano /opt/monitoring/prometheus/rules.yml
```

#### 2. Add Alert Rule
```yaml
groups:
  - name: custom_alerts
    rules:
      - alert: CustomAlert
        expr: your_metric > threshold
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Custom alert description"
```

#### 3. Reload Prometheus
```bash
# Reload configuration
curl -X POST http://10.0.254.31:9090/-/reload
```

## Log Management

### Loki Configuration

#### 1. Add Loki as Data Source
1. Go to Grafana → Configuration → Data Sources
2. Add Loki data source
3. URL: `http://loki:3100`

#### 2. Query Logs
```logql
# All logs
{job="kubernetes-pods"}

# Error logs
{job="kubernetes-pods"} |= "error"

# Specific namespace
{job="kubernetes-pods", namespace="default"}
```

### Log Collection Setup

#### 1. Install Promtail
```bash
# On each Kubernetes node
sudo apt-get install promtail
```

#### 2. Configure Promtail
```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://10.0.254.31:3100/loki/api/v1/push

scrape_configs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_kubernetes_io_config_hash]
        target_label: __path__
        regex: (.+)
        replacement: /var/log/pods/*$1/*.log
```

## Troubleshooting

### Common Issues

#### 1. Prometheus Not Scraping Targets
```bash
# Check targets
curl http://10.0.254.31:9090/api/v1/targets

# Check node exporter on nodes
curl http://10.0.254.11:9100/metrics
```

#### 2. Grafana Can't Connect to Prometheus
```bash
# Check Prometheus is running
docker ps | grep prometheus

# Check network connectivity
curl http://prometheus:9090/api/v1/status/targets
```

#### 3. Loki Not Receiving Logs
```bash
# Check Loki is running
docker ps | grep loki

# Check log collection
curl http://10.0.254.31:3100/ready
```

### Performance Tuning

#### 1. Prometheus Storage
```yaml
# In prometheus.yml
storage:
  tsdb:
    retention.time: 15d
    retention.size: 50GB
```

#### 2. Grafana Performance
```ini
# In grafana.ini
[server]
max_concurrent_connections = 100

[database]
max_open_conn = 100
max_idle_conn = 100
```

#### 3. Loki Performance
```yaml
# In loki-config.yaml
limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

## Maintenance

### Regular Tasks

#### 1. Check Service Health
```bash
# Check all services
docker ps

# Check service logs
docker logs prometheus
docker logs grafana
docker logs loki
```

#### 2. Backup Monitoring Data
```bash
# Run backup script
sudo ./scripts/backup/monitoring-backup.sh
```

#### 3. Update Dashboards
1. Export dashboards from Grafana
2. Version control dashboard JSON files
3. Import updated dashboards

### Monitoring the Monitoring Stack

#### 1. Self-Monitoring Dashboard
Create a dashboard to monitor the monitoring stack itself:
- Prometheus uptime
- Grafana performance
- Loki ingestion rate
- Storage usage

#### 2. Alert on Monitoring Issues
```yaml
alert: PrometheusDown
expr: up{job="prometheus"} == 0
for: 1m
labels:
  severity: critical
```

## Security

### Access Control

#### 1. Grafana Authentication
- Change default admin password
- Set up LDAP/AD integration
- Configure role-based access

#### 2. Network Security
- Use HTTPS for all web interfaces
- Configure firewall rules
- Restrict access to monitoring ports

#### 3. Data Security
- Encrypt sensitive metrics
- Secure API endpoints
- Regular security updates

## Scaling

### Horizontal Scaling

#### 1. Multiple Prometheus Instances
```yaml
# Use Prometheus federation
scrape_configs:
  - job_name: 'federate'
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job="kubernetes-pods"}'
    static_configs:
      - targets:
        - 'prometheus-1:9090'
        - 'prometheus-2:9090'
```

#### 2. Grafana Clustering
- Use external database (PostgreSQL)
- Configure session storage
- Load balance multiple instances

#### 3. Loki Clustering
- Use external object storage
- Configure multiple Loki instances
- Set up distributed tracing

## Best Practices

1. **Start Small**: Begin with basic metrics, expand gradually
2. **Use Labels**: Properly label metrics for better querying
3. **Set Retention**: Configure appropriate data retention periods
4. **Monitor Alerts**: Don't create too many alerts initially
5. **Document Dashboards**: Document the purpose of each dashboard
6. **Regular Backups**: Backup monitoring data regularly
7. **Performance Monitoring**: Monitor the monitoring stack itself
8. **Security First**: Implement security measures from the start 