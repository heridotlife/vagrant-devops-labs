# Installation Guide

## Prerequisites

Before installing the Kubernetes cluster, ensure you have the following software installed:

### Required Software
- **Vagrant** (version 2.2.0 or higher)
- **VirtualBox** (version 6.0 or higher)
- **Ansible** (version 2.9 or higher)

### System Requirements
- **RAM**: Minimum 8GB (16GB recommended)
- **Storage**: At least 50GB free space
- **CPU**: 4 cores minimum (8 cores recommended)

## Installation Steps

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/vagrant-devops-labs.git
cd vagrant-devops-labs
```

### 2. Verify Prerequisites
```bash
# Check Vagrant version
vagrant --version

# Check VirtualBox version
VBoxManage --version

# Check Ansible version
ansible --version
```

### 3. Network Configuration
The cluster uses the `10.0.254.0/24` network with the following IP assignments:

| Node Type | Hostname | IP Address |
|-----------|----------|------------|
| Master 1 | master1 | 10.0.254.11 |
| Master 2 | master2 | 10.0.254.12 |
| Master 3 | master3 | 10.0.254.13 |
| Worker 1 | worker1 | 10.0.254.21 |
| Worker 2 | worker2 | 10.0.254.22 |
| Worker 3 | worker3 | 10.0.254.23 |
| Monitoring | monitoring | 10.0.254.31 |

### 4. Deploy the Cluster
```bash
# Start all VMs and deploy the cluster
vagrant up

# Check cluster status
vagrant ssh master1
kubectl get nodes
```

### 5. Verify Installation
```bash
# Check all nodes are ready
kubectl get nodes

# Check system pods
kubectl get pods --all-namespaces

# Check cluster info
kubectl cluster-info
```

## Post-Installation

### Access the Cluster
```bash
# SSH into master node
vagrant ssh master1

# Copy kubeconfig to local machine (optional)
vagrant scp master1:/etc/kubernetes/admin.conf ./kubeconfig
export KUBECONFIG=./kubeconfig
```

### Monitoring Stack
The monitoring stack is automatically deployed on the monitoring VM:
- **Prometheus**: http://10.0.254.31:9090
- **Grafana**: http://10.0.254.31:3000 (admin/admin)
- **Loki**: http://10.0.254.31:3100

## Troubleshooting

### Common Issues

#### 1. Vagrant Up Fails
```bash
# Check VirtualBox status
VBoxManage list vms

# Destroy and recreate VMs
vagrant destroy -f
vagrant up
```

#### 2. Ansible Playbook Failures
```bash
# Run Ansible manually
ansible-playbook -i ansible/inventory ansible/k8s-master.yml
```

#### 3. Kubernetes Nodes Not Ready
```bash
# Check node status
kubectl describe nodes

# Check system pods
kubectl get pods -n kube-system
```

### Network Issues
```bash
# Test network connectivity
./scripts/utils/test_network.sh

# Check firewall rules
sudo ufw status
```

## Configuration

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

## Security Considerations

1. **Network Security**: The cluster uses private networking
2. **Authentication**: Default kubeconfig is copied to master node
3. **RBAC**: Basic RBAC is enabled by default
4. **Network Policies**: Calico network policies can be configured

## Maintenance

### Regular Tasks
- Monitor cluster health: `kubectl get nodes`
- Check system pods: `kubectl get pods -n kube-system`
- Review logs: `kubectl logs -n kube-system`

### Backup Procedures
See [Backup Documentation](../backup/BACKUP_GUIDE.md) for detailed backup procedures.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review logs in `/var/log/`
3. Check Ansible playbook output
4. Verify network connectivity 