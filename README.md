# Local Kubernetes Cluster with Vagrant, Ansible, and VirtualBox

This repository provides a complete local Kubernetes cluster setup using Vagrant, Ansible, and VirtualBox. The cluster consists of 3 control plane nodes, 3 worker nodes, and a dedicated monitoring VM running on the 10.0.254.0/24 network.

## 🚀 Features

- **Multi-Node Kubernetes Cluster**: 3 master nodes + 3 worker nodes
- **Separate Monitoring Stack**: Dedicated VM with Prometheus, Grafana, and Loki
- **Automated Deployment**: Full automation with Ansible playbooks
- **Comprehensive Backup**: Automated backup and recovery procedures
- **Dynamic Configuration**: Environment-based Kubernetes version management
- **Production-Ready**: Security, monitoring, and documentation included

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- **Vagrant** (version 2.2.0 or higher)
- **VirtualBox** (version 6.0 or higher)
- **Ansible** (version 2.9 or higher)

### System Requirements
- **RAM**: Minimum 8GB (16GB recommended)
- **Storage**: At least 50GB free space
- **CPU**: 4 cores minimum (8 cores recommended)

## 🏗️ Architecture

### Network Configuration
The cluster uses the `10.0.254.0/24` network with the following IP assignments:

| Node Type | Hostname | IP Address | Purpose |
|-----------|----------|------------|---------|
| Master 1 | master1 | 10.0.254.11 | Control Plane |
| Master 2 | master2 | 10.0.254.12 | Control Plane |
| Master 3 | master3 | 10.0.254.13 | Control Plane |
| Worker 1 | worker1 | 10.0.254.21 | Worker Node |
| Worker 2 | worker2 | 10.0.254.22 | Worker Node |
| Worker 3 | worker3 | 10.0.254.23 | Worker Node |
| Monitoring | monitoring | 10.0.254.31 | Monitoring Stack |

### Monitoring Stack
- **Prometheus**: Metrics collection and storage (port 9090)
- **Grafana**: Visualization and dashboards (port 3000)
- **Loki**: Log aggregation (port 3100)

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/hveda/vagrant-devops-labs.git
cd vagrant-devops-labs
```

### 2. Deploy the Cluster
```bash
# Start all VMs and deploy the cluster
vagrant up

# Check cluster status
vagrant ssh master1
kubectl get nodes
```

### 3. Access the Monitoring Stack
- **Prometheus**: http://10.0.254.31:9090
- **Grafana**: http://10.0.254.31:3000 (admin/admin)
- **Loki**: http://10.0.254.31:3100

## 📁 Project Structure

```
vagrant-devops-labs/
├── Vagrantfile                    # Main Vagrant configuration
├── README.md                      # This file
├── .plans/                        # Development plans
│   └── DEVELOPMENT_PLAN.md       # Current development plan
├── ansible/                       # Ansible automation
│   ├── inventory                  # Host inventory
│   ├── group_vars/               # Group variables
│   ├── k8s-master.yml           # Master node setup
│   ├── k8s-worker.yml           # Worker node setup
│   ├── monitoring-setup.yml      # Monitoring VM setup
│   └── k8s-monitoring-config.yml # K8s monitoring config
├── configs/                       # Configuration files
│   ├── kubernetes/               # K8s configurations
│   ├── monitoring/               # Monitoring configs
│   └── network/                  # Network configurations
├── docs/                         # Documentation
│   ├── setup/                    # Setup guides
│   ├── monitoring/               # Monitoring docs
│   ├── backup/                   # Backup procedures
│   └── troubleshooting/          # Troubleshooting guides
├── scripts/                      # Utility scripts
│   ├── deployment/               # Deployment scripts
│   ├── monitoring/               # Monitoring scripts
│   ├── backup/                   # Backup procedures
│   │   ├── k8s-backup.sh       # K8s cluster backup
│   │   ├── k8s-restore.sh      # K8s cluster restore
│   │   └── monitoring-backup.sh # Monitoring stack backup
│   └── utils/                    # Utility scripts
└── monitoring/                    # Monitoring configurations
    ├── grafana/                  # Grafana configs
    ├── prometheus/               # Prometheus configs
    └── loki/                     # Loki configs
```

## 🔧 Configuration

### Kubernetes Version
The default Kubernetes version is `1.19.5`. To change it:

```bash
# Set environment variable
export K8S_VERSION=1.20.0

# Redeploy cluster
vagrant provision
```

### Resource Allocation
Modify the Vagrantfile to adjust VM resources:

```ruby
vb.memory = "2048"  # Memory in MB
vb.cpus = 2         # Number of CPUs
```

## 💾 Backup and Recovery

### Automated Backups
The project includes comprehensive backup procedures:

```bash
# Kubernetes cluster backup (run on master1)
sudo ./scripts/backup/k8s-backup.sh

# Kubernetes cluster restore
sudo ./scripts/backup/k8s-restore.sh /opt/backups/k8s/k8s_backup_YYYYMMDD_HHMMSS.tar.gz

# Monitoring stack backup (run on monitoring VM)
sudo ./scripts/backup/monitoring-backup.sh
```

### Backup Schedule
- **Kubernetes Cluster**: Daily backups (7-day retention)
- **Monitoring Stack**: Weekly backups (30-day retention)

## 📚 Documentation

### Setup and Installation
- [Installation Guide](docs/setup/INSTALLATION.md) - Complete setup instructions
- [Folder Structure](docs/FOLDER_STRUCTURE.md) - Project organization

### Monitoring
- [Monitoring Guide](docs/monitoring/MONITORING_GUIDE.md) - Complete monitoring stack documentation
- Dashboard creation and customization
- Alert configuration and management
- Log management with Loki

### Backup and Recovery
- [Backup Guide](docs/backup/BACKUP_GUIDE.md) - Comprehensive backup procedures
- Disaster recovery procedures
- Automated backup scheduling
- Backup verification methods

## 🔍 Monitoring and Observability

### Pre-configured Dashboards
- **Kubernetes Cluster Overview**: Overall cluster health
- **Node Exporter Dashboard**: Individual node metrics
- **Prometheus Dashboard**: Self-monitoring

### Metrics Collection
- **Node Metrics**: CPU, memory, disk, network usage
- **Kubernetes Metrics**: Pod status, resource usage
- **Application Metrics**: Custom application metrics

### Log Management
- **Centralized Logging**: All logs aggregated in Loki
- **Log Queries**: Powerful LogQL queries
- **Log Visualization**: Integrated with Grafana

## 🛠️ Maintenance

### Regular Tasks
```bash
# Check cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# Monitor system pods
kubectl get pods -n kube-system

# Check monitoring stack
docker ps  # On monitoring VM
```

### Backup Verification
```bash
# List available backups
ls -la /opt/backups/k8s/
ls -la /opt/backups/monitoring/

# Verify backup integrity
tar -tzf backup_file.tar.gz
```

## 🔒 Security

### Network Security
- Private network configuration
- Firewall rules for monitoring ports
- Secure API endpoints

### Access Control
- RBAC enabled by default
- Grafana authentication configured
- Secure kubeconfig management

## 🚨 Troubleshooting

### Common Issues

#### 1. Vagrant Up Fails
```bash
# Check VirtualBox status
VBoxManage list vms

# Destroy and recreate VMs
vagrant destroy -f
vagrant up
```

#### 2. Kubernetes Nodes Not Ready
```bash
# Check node status
kubectl describe nodes

# Check system pods
kubectl get pods -n kube-system
```

#### 3. Monitoring Stack Issues
```bash
# Test network connectivity
./scripts/utils/test_network.sh

# Check monitoring services
docker ps  # On monitoring VM
```

### Network Issues
```bash
# Test network connectivity
./scripts/utils/test_network.sh

# Check firewall rules
sudo ufw status
```

## 🎯 Development Status

### Completed Features ✅
- [x] Multi-node Kubernetes cluster setup
- [x] Separate monitoring VM with Prometheus, Grafana, Loki
- [x] Dynamic Kubernetes version management
- [x] Comprehensive backup and recovery procedures
- [x] Complete documentation suite
- [x] Organized project structure
- [x] Network configuration (10.0.254.0/24)

### Planned Features 🔄
- [ ] Security hardening
- [ ] Performance optimization
- [ ] Advanced monitoring dashboards
- [ ] CI/CD pipeline integration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:
1. Check the [troubleshooting section](#-troubleshooting)
2. Review the [documentation](#-documentation)
3. Check logs in `/var/log/`
4. Verify network connectivity

## 📊 System Requirements

### Minimum Requirements
- **RAM**: 8GB
- **Storage**: 50GB
- **CPU**: 4 cores

### Recommended Requirements
- **RAM**: 16GB
- **Storage**: 100GB
- **CPU**: 8 cores

## 🔄 Version History

- **v1.0.0**: Initial release with basic Kubernetes cluster
- **v1.1.0**: Added monitoring stack (Prometheus, Grafana, Loki)
- **v1.2.0**: Implemented backup procedures and comprehensive documentation
- **v1.3.0**: Organized project structure and improved configuration management

