# Configuration Files

This directory contains configuration files, manifests, and templates for Kubernetes components.

## Structure

```
configs/
├── pki/                     # PKI and certificate configurations
│   ├── ca-config.json      # CA configuration
│   ├── ca-csr.json         # CA signing request
│   └── cert-configs/       # Component certificate configs
├── cni/                     # CNI plugin manifests
│   └── calico.yaml         # Calico CNI manifest
├── metallb/                 # MetalLB configurations
│   ├── metallb.yaml        # MetalLB deployment
│   └── ipaddresspool.yaml  # IP pool configuration
├── storage/                 # Storage configurations
│   ├── local-path-provisioner.yaml  # Local path provisioner
│   └── storageclass.yaml   # Default storage class
└── kubeconfig/              # Kubeconfig templates
    └── kubeconfig.template # Kubeconfig template
```

## Usage

These configuration files are used by:
- Ansible playbooks (templates and manifests)
- Setup scripts (PKI generation)
- kubectl apply commands (Kubernetes manifests)

## PKI Directory

The `pki/` directory contains:
- Certificate configuration files (JSON)
- Generated certificates (*.pem files) - **not committed to git**
- Private keys (*.key files) - **not committed to git**

Generated certificates are created during cluster provisioning and should be backed up separately.

## Kubernetes Manifests

Manifest files (*.yaml) are applied to the cluster using kubectl:

```bash
kubectl apply -f configs/cni/calico.yaml
kubectl apply -f configs/metallb/
```

## Environment-Specific Configuration

Some configurations use environment variables from `.env`:
- Pod CIDR
- Service CIDR
- MetalLB IP pool range
- Kubernetes version
