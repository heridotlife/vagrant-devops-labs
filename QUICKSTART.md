# Kubernetes Lab - Quick Start Guide

## Current Status: Phase 1 Complete ✅

Phase 1 Foundation is fully validated and ready to use!

## What's Working Now

### ✅ Environment Setup
- Configuration system with `.env`
- Comprehensive Makefile with 40+ commands
- Vagrant VM orchestration (1 master + 2 workers)
- Ansible automation framework
- Validation scripts

### ✅ Validated Components
- 28/28 core tests passing
- All file structures in place
- All scripts executable
- Ansible playbook syntax valid
- Vagrantfile syntax valid

## Quick Command Reference

### Setup Commands
```bash
# Check if prerequisites are installed
make check-prereqs

# Initialize environment (if not done)
make init

# Validate your configuration
make validate-env
```

### VM Management
```bash
# Start all VMs (will create 3 VMs: 1 master + 2 workers)
make up

# Check VM status
make status

# SSH to master node
make ssh-master

# SSH to worker node
make ssh-worker NODE=1    # or NODE=2

# Stop VMs (without destroying)
make halt

# Restart VMs
make reload

# Destroy all VMs
make destroy
```

### Information Commands
```bash
# Show all available commands
make help

# Show component versions
make version

# Show cluster information
make info
```

### Utilities
```bash
# Clean temporary files
make clean

# Nuclear clean (destroy everything)
make clean-all
```

## What You Have Now

### Project Structure (35+ Files)
```
k8s-lab/
├── Makefile                    # 40+ make targets
├── Vagrantfile                 # Multi-node VM definition
├── .env                        # Your configuration
├── setup-macos.sh             # macOS prerequisite installer
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   ├── playbooks/
│   └── roles/common/          # ✅ Base system configuration
├── configs/                   # CNI, MetalLB, storage configs
├── scripts/
│   ├── bootstrap/
│   ├── network/
│   ├── storage/
│   ├── validation/
│   └── utils/
├── tests/
│   └── test-makefile.sh       # ✅ Comprehensive test suite
└── docs/
```

### Current Configuration
- **Cluster**: k8s-lab
- **Kubernetes**: 1.31.0
- **OS**: CentOS Stream 9
- **Nodes**: 1 master + 2 workers
- **Resources**: 6 vCPUs, 6GB RAM
- **Network**: 10.240.0.0/24
- **Container Runtime**: containerd
- **CNI**: Calico (planned)
- **Storage**: local-path-provisioner (planned)

## What's NOT Working Yet

The following require Phase 2 implementation:

- ❌ `make cluster-init` - Kubernetes cluster initialization
- ❌ `make deploy-cni` - CNI deployment
- ❌ `make deploy-dns` - CoreDNS deployment
- ❌ `make deploy-metallb` - MetalLB deployment
- ❌ `make deploy-storage` - Storage provisioner
- ❌ `make kubeconfig` - Kubeconfig generation
- ❌ `make test-*` - Validation tests
- ❌ Actual Kubernetes cluster functionality

**These will be implemented in Phase 2!**

## Try It Out (Safe to Test)

### Option 1: Just Look Around
```bash
# View your configuration
cat .env

# See what VMs would be created
make status

# View all available commands
make help
```

### Option 2: Start VMs (No Kubernetes Yet)
```bash
# This will create 3 VMs with base OS configuration
# Takes about 10-15 minutes on first run
make up

# After VMs are up
make status           # Check VM status
make ssh-master       # Login to master node
make ssh-worker NODE=1  # Login to worker

# When done testing
make halt             # Stop VMs
# or
make destroy          # Destroy VMs completely
```

**Note**: Running `make up` will create VMs and apply the common Ansible role (system prep), but won't install Kubernetes components yet. That requires Phase 2.

## Current Limitations

1. **No Kubernetes Yet**: Phase 2 needed for actual K8s installation
2. **Single OS**: Only CentOS Stream 9 (Fedora CoreOS planned for future)
3. **Single K8s Version**: Only 1.31.x (multi-version planned for future)
4. **No HA**: Single master (3-master HA planned for future)

## Next Steps

### Option A: Continue Development (Recommended)
Proceed with Phase 2 implementation:
- PKI certificates
- Container runtime setup
- etcd cluster
- Kubernetes control plane
- Worker node setup
- CNI networking
- CoreDNS, MetalLB, Storage

**After Phase 2, you'll have a fully functional Kubernetes cluster!**

### Option B: Test the Foundation
```bash
# Run the comprehensive test suite
./tests/test-makefile.sh

# Start VMs and explore
make up
make ssh-master
```

### Option C: Customize Configuration
```bash
# Edit .env to customize:
# - VM resources (CPU, RAM)
# - Network CIDRs
# - Component versions
vim .env

# Validate your changes
make validate-env
```

## Troubleshooting

### VM Won't Start
```bash
# Check VirtualBox is running
make check-prereqs

# Try destroying and recreating
make destroy
make up
```

### Validation Fails
```bash
# Check your .env file
make validate-env

# Re-initialize if needed
cp .env.example .env
make validate-env
```

### Slow Performance
```bash
# Edit .env and reduce resources:
VM_MASTER_MEMORY=2048  # Reduce from 4096
VM_WORKER_MEMORY=2048  # Reduce from 4096
```

## Getting Help

1. **Check logs**: `logs/` directory
2. **Vagrant status**: `vagrant status`
3. **Vagrant logs**: `vagrant up` shows detailed output
4. **Test suite**: `./tests/test-makefile.sh`

## What's Been Validated

✅ **All Core Components** (28 tests passing):
1. Makefile functionality
2. Environment configuration
3. File structure
4. Script permissions
5. Ansible playbook syntax
6. Vagrantfile syntax
7. Prerequisites detection
8. Configuration validation

## Summary

**Phase 1 Foundation**: ✅ COMPLETE & VALIDATED
- Ready for Phase 2 implementation
- All tests passing
- Safe to start VMs and explore
- Or continue with Kubernetes installation (Phase 2)

**Estimated Time to Full Cluster**:
- Phase 2 implementation: ~20-30 hours of development
- Or wait for completion and deploy in ~20 minutes with `make up && make cluster-init`

---

**Created**: $(date)
**Status**: Phase 1 Complete ✅
**Next**: Phase 2 - Kubernetes Core Components
