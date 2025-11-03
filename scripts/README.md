# Scripts

This directory contains utility scripts for cluster management, validation, and operations.

## Structure

```
scripts/
├── bootstrap/               # Cluster initialization scripts
│   ├── generate-certs.sh   # PKI certificate generation
│   └── init-cluster.sh     # Cluster initialization helper
├── network/                 # Networking scripts
│   ├── deploy-cni.sh       # CNI deployment helper
│   └── test-network.sh     # Network connectivity tests
├── storage/                 # Storage scripts
│   ├── deploy-storage.sh   # Storage provisioner deployment
│   └── test-storage.sh     # Storage validation
├── validation/              # Validation and testing scripts
│   ├── 01-infrastructure.sh     # VM and infrastructure tests
│   ├── 02-cluster-health.sh     # Cluster health validation
│   ├── 03-networking.sh         # Network functionality tests
│   ├── 04-storage.sh            # Storage provisioning tests
│   └── 05-e2e-app.sh            # End-to-end application test
├── utils/                   # Utility scripts
│   ├── kubeconfig-merge.sh # Auto-merge kubeconfig
│   ├── kubectl-wrapper.sh  # kubectl helper
│   ├── backup.sh           # Cluster backup
│   ├── restore.sh          # Cluster restore
│   └── version-manager.sh  # Kubernetes version manager
└── examples/                # Example deployments
    ├── deploy-nginx.sh     # Simple nginx deployment
    └── test-apps/          # Sample applications
```

## Usage

Most scripts are designed to be run from the project root:

```bash
# Run validation
./scripts/validation/01-infrastructure.sh

# Deploy CNI
./scripts/network/deploy-cni.sh

# Merge kubeconfig
./scripts/utils/kubeconfig-merge.sh
```

## Script Guidelines

All scripts should:
- Include shebang (`#!/usr/bin/env bash`)
- Use `set -euo pipefail` for safety
- Provide clear error messages
- Log actions appropriately
- Be idempotent where possible
- Include usage documentation
