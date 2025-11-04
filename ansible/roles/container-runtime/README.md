# Container Runtime Role

Installs and configures containerd as the container runtime for Kubernetes cluster.

## Overview

This role implements the container runtime layer following "Kubernetes The Hard Way" methodology, manually installing and configuring containerd with all necessary components.

## Installed Components

### Containerd
- **Version**: 1.7.22 (configurable)
- **Binary**: `/usr/local/bin/containerd`
- **Config**: `/etc/containerd/config.toml`
- **Socket**: `/run/containerd/containerd.sock`

### runc
- **Version**: 1.1.14 (configurable)
- **Binary**: `/usr/local/bin/runc`
- **Purpose**: OCI runtime for running containers

### CNI Plugins
- **Version**: 1.5.1 (configurable)
- **Directory**: `/opt/cni/bin/`
- **Config**: `/etc/cni/net.d/`
- **Purpose**: Container networking

## Key Configuration

### Systemd Cgroup Driver
**CRITICAL for Kubernetes compatibility**:
```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

This setting ensures containerd uses systemd for cgroup management, which is required for Kubernetes.

### Sandbox Image
```toml
sandbox_image = "registry.k8s.io/pause:3.9"
```

The pause container image used for pod sandboxes.

### Runtime Endpoint
```
unix:///run/containerd/containerd.sock
```

Kubelet will connect to containerd via this socket.

## Directory Structure

```
/usr/local/bin/
├── containerd
├── containerd-shim
├── containerd-shim-runc-v1
├── containerd-shim-runc-v2
├── ctr
└── runc

/etc/containerd/
└── config.toml

/opt/cni/bin/
├── bridge
├── dhcp
├── firewall
├── host-device
├── host-local
├── ipvlan
├── loopback
├── macvlan
├── portmap
├── ptp
├── sbr
├── static
├── tuning
├── vlan
└── vrf

/var/lib/containerd/  (runtime data)
/run/containerd/      (sockets and state)
```

## Usage

### Basic Usage

```yaml
- hosts: all
  roles:
    - role: container-runtime
```

### With Custom Variables

```yaml
- hosts: all
  roles:
    - role: container-runtime
      vars:
        containerd_version: "1.7.22"
        runc_version: "1.1.14"
        cni_plugins_version: "1.5.1"
```

### Targeted Installation

Use tags to run specific parts:

```bash
# Install only containerd
ansible-playbook site.yml --tags container-runtime,install

# Configure only
ansible-playbook site.yml --tags container-runtime,configure

# Verify installation
ansible-playbook site.yml --tags container-runtime,verify
```

## Requirements

### System Requirements
- Linux kernel with overlay and br_netfilter modules
- systemd for service management
- Internet access for downloading binaries

### Kernel Modules
The role automatically loads:
- `overlay` - OverlayFS for container layers
- `br_netfilter` - Bridge netfilter for networking

## Variables

### Version Variables

```yaml
containerd_version: "1.7.22"
runc_version: "1.1.14"
cni_plugins_version: "1.5.1"
```

### Directory Variables

```yaml
containerd_bin_dir: "/usr/local/bin"
containerd_config_dir: "/etc/containerd"
cni_bin_dir: "/opt/cni/bin"
cni_config_dir: "/etc/cni/net.d"
```

### Configuration Variables

```yaml
# Use systemd cgroup driver (required for Kubernetes)
containerd_use_systemd_cgroup: true

# Sandbox (pause) container image
containerd_sandbox_image: "registry.k8s.io/pause:3.9"

# Runtime configuration
containerd_runtime: "runc"
containerd_snapshotter: "overlayfs"
```

### Optional: Registry Mirrors

For faster image pulls in lab environments:

```yaml
containerd_registry_mirrors:
  "docker.io":
    - "https://mirror.gcr.io"
  "registry.k8s.io":
    - "https://k8s.gcr.io"
```

### Optional: Insecure Registries

For development/lab environments:

```yaml
containerd_insecure_registries:
  - "registry.local:5000"
  - "10.0.0.100:5000"
```

## Tags

- `containerd` - All containerd tasks
- `preflight` - Preflight checks
- `install` - Containerd installation
- `runc` - runc installation
- `cni` - CNI plugins installation
- `configure` - Configuration
- `service` - Systemd service setup
- `verify` - Verification

## Handlers

- `restart containerd` - Restarts containerd service
- `reload containerd` - Reloads containerd service

## Verification

### Manual Verification

```bash
# Check containerd version
containerd --version

# Check runc version
runc --version

# List CNI plugins
ls -l /opt/cni/bin/

# Check containerd service
systemctl status containerd

# Test containerd
ctr version
ctr plugins ls

# Verify systemd cgroup setting
grep SystemdCgroup /etc/containerd/config.toml
```

### Expected Output

```
Client:
  Version:  v1.7.22
  ...

Server:
  Version:  v1.7.22
  ...
```

## Integration with Kubernetes

### Kubelet Configuration

When configuring kubelet, use these settings:

```yaml
container_runtime: containerd
container_runtime_endpoint: unix:///run/containerd/containerd.sock
```

### CRI Configuration

Containerd implements the Kubernetes Container Runtime Interface (CRI), allowing kubelet to manage containers without needing dockershim.

## Troubleshooting

### Service Won't Start

```bash
# Check service status
systemctl status containerd

# Check logs
journalctl -u containerd -f

# Verify configuration syntax
containerd config dump
```

### Socket Not Found

```bash
# Check if containerd is running
systemctl is-active containerd

# Verify socket exists
ls -l /run/containerd/containerd.sock

# Restart if needed
systemctl restart containerd
```

### Configuration Issues

```bash
# Dump current configuration
containerd config dump > /tmp/containerd-config-dump.toml

# Compare with expected configuration
diff /etc/containerd/config.toml /tmp/containerd-config-dump.toml
```

### CNI Plugins Not Found

```bash
# Verify CNI directory
ls -l /opt/cni/bin/

# Re-run CNI installation
ansible-playbook site.yml --tags containerd,cni
```

## Security Considerations

1. **Binary Integrity**
   - Binaries downloaded from official GitHub releases
   - Consider verifying checksums in production

2. **Socket Permissions**
   - containerd.sock is only accessible by root
   - kubelet must run as root or in containerd group

3. **Registry Security**
   - Use TLS for registry connections in production
   - Avoid insecure registries in production

4. **Resource Limits**
   - systemd service includes OOMScoreAdjust=-999
   - Prevents containerd from being killed under memory pressure

## Performance Tuning

### For Lab Environments

```yaml
# Smaller resource limits for constrained environments
containerd_grpc_max_recv_message_size: 8388608   # 8MB
containerd_grpc_max_send_message_size: 8388608   # 8MB
```

### For Production

```yaml
# Larger limits for production workloads
containerd_grpc_max_recv_message_size: 33554432  # 32MB
containerd_grpc_max_send_message_size: 33554432  # 32MB
```

## References

- [containerd Documentation](https://containerd.io/docs/)
- [Kubernetes CRI](https://kubernetes.io/docs/concepts/architecture/cri/)
- [runc GitHub](https://github.com/opencontainers/runc)
- [CNI Plugins](https://github.com/containernetworking/plugins)
- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
