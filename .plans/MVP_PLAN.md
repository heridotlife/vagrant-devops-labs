# Kubernetes Lab - MVP Implementation Plan

## MVP Scope (Minimum Viable Product)

**Goal**: Production-quality Kubernetes cluster in 2-3 weeks, expandable later

### Core Features

**Infrastructure**:
- OS: CentOS Stream 9 only
- Nodes: 1 master + 2 workers
- Resources: 2GB RAM, 2 vCPU per node (6GB total)
- Hypervisor: VirtualBox
- Provisioner: Vagrant + Ansible

**Kubernetes**:
- Version: 1.31.x (latest stable)
- Setup: Manual "The Hard Way" (no kubeadm)
- Container Runtime: containerd only
- CNI: Calico only
- Storage: local-path-provisioner
- LoadBalancer: MetalLB
- DNS: CoreDNS

**Developer Experience**:
- Makefile interface (20+ essential targets)
- Auto kubeconfig merge to ~/.kube/config
- Environment-based configuration (.env)
- Basic validation (5 scripts)

**Security**:
- PKI: OpenSSL-based certificate generation
- TLS: All components encrypted
- RBAC: Enabled
- 10-year certificate validity

### Excluded from MVP (Add Later)

- ❌ Fedora CoreOS support
- ❌ Multiple Kubernetes versions (1.28.x, 1.29.x, 1.30.x)
- ❌ Alternative CNIs (Cilium, Flannel)
- ❌ Rook-Ceph storage
- ❌ cri-o container runtime
- ❌ Comprehensive validation (11 suites)
- ❌ Monitoring stack (Prometheus/Grafana)
- ❌ Binary caching system
- ❌ HA control plane (3 masters)

## Implementation Phases

### Phase 1: Foundation (Week 1)
**Effort**: 12-15 hours

1. **setup-macos.sh** (2 hours)
   - Install Homebrew, VirtualBox, Vagrant, Ansible
   - Install required Vagrant plugins
   - Validate prerequisites

2. **Project Structure** (1 hour)
   - Create directory hierarchy
   - Initialize all role directories
   - Set up basic .gitkeep files

3. **.env Configuration** (1 hour)
   - Create .env.example with MVP settings
   - Document all variables
   - Create validation script

4. **Vagrantfile** (3 hours)
   - CentOS Stream 9 box configuration
   - 1 master (10.240.0.11) + 2 workers (10.240.0.21-22)
   - Private network setup
   - Ansible provisioner integration

5. **Makefile** (3 hours)
   - Environment setup targets
   - VM lifecycle targets
   - Cluster operation targets
   - Validation targets
   - Self-documenting help

6. **Common Ansible Role** (3 hours)
   - Disable swap
   - Load kernel modules (overlay, br_netfilter)
   - Configure sysctl (IP forwarding)
   - Install base packages
   - Configure firewall
   - Setup NTP

### Phase 2: Kubernetes Core (Week 2-3)
**Effort**: 25-30 hours

1. **PKI Infrastructure** (4 hours)
   - OpenSSL-based certificate generation script
   - CA certificate
   - API server certificates (with all SANs)
   - Client certificates (admin, controller-manager, scheduler)
   - Worker certificates (kubelet, kube-proxy)
   - Service account key pair
   - Ansible role to distribute certificates

2. **Container Runtime** (3 hours)
   - Install containerd from official repos
   - Configure /etc/containerd/config.toml
   - Install CNI plugins
   - Configure crictl
   - Systemd service

3. **etcd Cluster** (4 hours)
   - Single-node etcd on master
   - TLS configuration
   - Systemd service
   - Health checks

4. **kube-apiserver** (4 hours)
   - Download binary
   - Systemd service configuration
   - All required flags
   - Encryption at rest
   - Health endpoint validation

5. **kube-controller-manager** (2 hours)
   - Download binary
   - Systemd service
   - Kubeconfig setup
   - Leader election

6. **kube-scheduler** (2 hours)
   - Download binary
   - Systemd service
   - Kubeconfig setup
   - Leader election

7. **kubelet** (4 hours)
   - Install on all nodes (master + workers)
   - Per-node certificates
   - Kubelet configuration file
   - Container runtime integration
   - Node registration

8. **kube-proxy** (2 hours)
   - Install on all nodes
   - Kubeconfig configuration
   - iptables mode
   - Systemd service

9. **Calico CNI** (3 hours)
   - Deploy Calico operator
   - Configure IP pool
   - Validate pod networking
   - Network policy support

10. **Kubeconfig Management** (2 hours)
    - Generate admin kubeconfig
    - Auto-merge script
    - Context switching
    - kubectl wrapper

### Phase 3: Essential Services (Week 3)
**Effort**: 8-10 hours

1. **CoreDNS** (2 hours)
   - Deploy CoreDNS
   - Configure cluster.local domain
   - Validate service discovery

2. **MetalLB** (3 hours)
   - Deploy MetalLB
   - Configure IP pool (10.240.0.200-220)
   - L2 advertisement
   - Test LoadBalancer service

3. **Storage** (3 hours)
   - Deploy local-path-provisioner
   - Create default StorageClass
   - Test PVC creation and mounting

### Phase 4: Validation (Week 3-4)
**Effort**: 6-8 hours

**Essential Validation Scripts**:
1. `01-infrastructure.sh` - VM health, network connectivity
2. `02-cluster-health.sh` - etcd, control plane, nodes
3. `03-networking.sh` - CNI, pod-to-pod, DNS
4. `04-storage.sh` - PVC provisioning, pod mounting
5. `05-e2e-app.sh` - Deploy complete application stack

### Phase 5: Documentation (Week 4)
**Effort**: 6-8 hours

1. **README.md** (3 hours)
   - Quick start guide
   - Prerequisites
   - Installation steps
   - Common operations
   - Troubleshooting basics

2. **ARCHITECTURE.md** (2 hours)
   - System overview
   - Network topology
   - Component communication
   - Design decisions

3. **TROUBLESHOOTING.md** (2 hours)
   - Common issues and solutions
   - Debugging commands
   - Log locations
   - Recovery procedures

## Network Configuration

```
Host Network: 10.240.0.0/24
├── Master Node: 10.240.0.11 (master-01)
├── Worker Node 1: 10.240.0.21 (worker-01)
├── Worker Node 2: 10.240.0.22 (worker-02)
└── MetalLB Pool: 10.240.0.200-10.240.0.220

Pod Network: 10.244.0.0/16
Service Network: 10.96.0.0/16
Cluster DNS: 10.96.0.10
```

## Resource Allocation

**Per-Node Resources**:
- CPU: 2 cores
- Memory: 2GB RAM
- Disk: 40GB

**Total Host Consumption**:
- CPU: 6 cores
- Memory: 6GB RAM
- Disk: 120GB

## Makefile Targets (MVP)

**Setup**:
- `make setup-macos` - Install prerequisites
- `make init` - Initialize .env
- `make validate-env` - Validate configuration

**VM Lifecycle**:
- `make up` - Start all VMs
- `make halt` - Stop VMs
- `make destroy` - Destroy VMs
- `make ssh-master` - SSH to master
- `make ssh-worker NODE=1` - SSH to worker

**Cluster**:
- `make cluster-init` - Initialize cluster
- `make cluster-info` - Show cluster status
- `make deploy-cni` - Deploy Calico
- `make deploy-dns` - Deploy CoreDNS
- `make deploy-metallb` - Deploy MetalLB
- `make deploy-storage` - Deploy storage

**Validation**:
- `make test-all` - Run all tests
- `make test-infra` - Test infrastructure
- `make test-cluster` - Test cluster health
- `make test-network` - Test networking
- `make test-storage` - Test storage

**Utilities**:
- `make kubeconfig` - Regenerate kubeconfig
- `make logs COMPONENT=apiserver` - View logs
- `make clean` - Clean temporary files
- `make help` - Show all targets

## Success Criteria

✅ **Phase 1 Complete When**:
- Fresh Mac can run `make setup-macos && make init && make up`
- 3 VMs running (1 master + 2 workers)
- All nodes accessible via SSH
- Common role applied successfully

✅ **Phase 2 Complete When**:
- `kubectl get nodes` shows 3 nodes Ready
- `kubectl get pods -A` shows all system pods Running
- Pod-to-pod communication working across nodes
- DNS resolution functional

✅ **Phase 3 Complete When**:
- CoreDNS resolving service names
- LoadBalancer services get external IPs
- PVC provisioning and mounting works

✅ **Phase 4 Complete When**:
- All 5 validation scripts pass
- Example application deployed and accessible

✅ **Phase 5 Complete When**:
- Documentation complete and accurate
- New user can follow README to deploy cluster

## Timeline

**Week 1**: Foundation
- Days 1-2: setup-macos.sh, project structure, .env
- Days 3-4: Vagrantfile, Makefile
- Day 5: Common role, testing

**Week 2**: Kubernetes Core Part 1
- Days 6-7: PKI, container runtime
- Days 8-9: etcd, kube-apiserver
- Day 10: controller-manager, scheduler

**Week 3**: Kubernetes Core Part 2 + Services
- Days 11-12: kubelet, kube-proxy
- Days 13-14: Calico CNI, kubeconfig
- Day 15: CoreDNS, MetalLB, storage

**Week 4**: Validation + Documentation
- Days 16-17: Validation scripts
- Days 18-19: Documentation
- Day 20: Final testing, cleanup

## Future Enhancements (Post-MVP)

**Phase 6: Multi-OS Support**
- Add Fedora CoreOS support
- OS selection via .env

**Phase 7: Multi-Version Support**
- Support K8s 1.28.x, 1.29.x, 1.30.x
- Version switching mechanism

**Phase 8: Advanced Networking**
- Alternative CNIs (Cilium, Flannel)
- CNI comparison and switching

**Phase 9: Advanced Storage**
- Rook-Ceph cluster
- Advanced storage features

**Phase 10: Monitoring**
- Prometheus + Grafana
- Loki for logs
- Alerting

**Phase 11: Advanced Features**
- HA control plane (3 masters)
- Binary caching system
- Service mesh (Istio/Linkerd)
- GitOps (ArgoCD/FluxCD)

## Risk Mitigation

**High-Risk Areas**:
1. **PKI Setup** - Comprehensive testing, rollback procedures
2. **Network Connectivity** - Incremental validation, troubleshooting guide
3. **etcd Health** - Backup/restore procedures, health monitoring
4. **CNI Issues** - Detailed debugging guide, fallback procedures

**Mitigation Strategy**:
- Test after each component
- Maintain rollback capability
- Comprehensive logging
- Clear error messages
- Detailed troubleshooting docs

## Getting Started

After plan approval, begin with:
```bash
# Phase 1.1 - Create setup-macos.sh
# This is the foundation for everything else
```
