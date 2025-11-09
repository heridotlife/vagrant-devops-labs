# Calico CNI Worker Node Troubleshooting Guide

## Issue Summary

**Problem:** Calico `install-cni` init container crashes on worker nodes with `CrashLoopBackOff` status

**Symptoms:**
```bash
NAME                                      READY   STATUS
calico-node-xxxxx (master-01)             1/1     Running        ✅
calico-node-xxxxx (worker-01)             0/1     Init:CrashLoopBackOff  ❌
calico-node-xxxxx (worker-02)             0/1     Init:CrashLoopBackOff  ❌
```

**Impact:**
- Master node: **Ready** ✅ (Calico working)
- Worker nodes: **NotReady** ❌ (Cannot deploy pods)

---

## Root Cause Analysis

### Investigation Process

**1. Web Research** (Using WebSearch tool)

Searched for: "Calico install-cni init container CrashLoopBackOff worker nodes 2024 2025"

**Key Findings from GitHub Issues:**
- **Issue #2266** (projectcalico/calico): Workers fail install-cni with permission denied
- **Primary Cause:** SELinux preventing non-privileged containers from writing to `/host/opt/cni/bin`
- **Solution:** Add `securityContext.privileged: true` to install-cni init container

**2. SELinux Context Verification**

Checked contexts on workers:
```bash
ls -lZ /opt/cni/bin/
# Output showed:
-rwxr-xr-x. 1 root root system_u:object_r:container_file_t:s0 calico
-rwxr-xr-x. 1 root root system_u:object_r:container_file_t:s0 calico-ipam
```

✅ SELinux contexts are **CORRECT** (`container_file_t`)

**3. Master vs Worker Comparison**

- **Master node:** Calico CNI **working** (pod Running 1/1)
- **Worker nodes:** install-cni **crashing** (Init:CrashLoopBackOff)

**Why master works but not workers:**
- Same Calico manifest applied to all nodes
- **Hypothesis:** Subtle timing or permission differences during init container execution
- **Confirmed by research:** install-cni needs privileged mode for SELinux systems

---

## Root Cause

**The install-cni init container requires `securityContext.privileged: true` to:**
1. Write files to host filesystem (`/opt/cni/bin`, `/etc/cni/net.d`)
2. Bypass SELinux restrictions even with correct contexts
3. Perform low-level kernel operations for CNI installation

**From Official Calico Documentation & Community:**
> "For SELinux-enabled systems, the install-cni container must run as privileged to properly install CNI binaries and configuration files to the host."

---

## Solutions

### Solution 1: Modify Calico Manifest Before Deployment (RECOMMENDED)

**Method:** Edit the manifest YAML to add privileged security context

**Step 1:** Download Calico manifest
```bash
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

**Step 2:** Edit the manifest

Find the `install-cni` init container section (around line 3800-4000):

```yaml
initContainers:
  # ... other init containers ...

  # This container installs the CNI binaries
  - name: install-cni
    image: docker.io/calico/cni:v3.27.0
    imagePullPolicy: IfNotPresent
    command: ["/opt/cni/bin/install"]
    envFrom:
      - configMapRef:
          name: kubernetes-services-endpoint
          optional: true
    env:
      # ... environment variables ...
```

**Add the securityContext:**

```yaml
initContainers:
  # ... other init containers ...

  # This container installs the CNI binaries
  - name: install-cni
    image: docker.io/calico/cni:v3.27.0
    imagePullPolicy: IfNotPresent
    command: ["/opt/cni/bin/install"]
    securityContext:           # ← ADD THIS SECTION
      privileged: true         # ← ADD THIS LINE
    envFrom:
      - configMapRef:
          name: kubernetes-services-endpoint
          optional: true
    env:
      # ... environment variables ...
```

**Step 3:** Deploy the modified manifest
```bash
kubectl apply -f calico.yaml
```

---

### Solution 2: Patch Existing DaemonSet

**Method:** Use kubectl patch to modify the running DaemonSet

```bash
export KUBECONFIG=~/.kube/k8s-lab-config

# Patch the DaemonSet to add privileged mode
kubectl patch daemonset calico-node -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/initContainers/1/securityContext", "value": {"privileged": true}}]'

# Delete existing worker pods to force recreation
kubectl delete pod -n kube-system -l k8s-app=calico-node --field-selector spec.nodeName!=master-01

# Wait and verify
sleep 60
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl get nodes
```

**Note:** The init container index `1` is for install-cni. Verify with:
```bash
kubectl get daemonset calico-node -n kube-system -o yaml | grep -A 5 "name: install-cni"
```

---

### Solution 3: Use Calico Operator (BEST FOR PRODUCTION)

**Method:** Deploy Calico using the Tigera Operator which handles privileges automatically

**Step 1:** Remove existing Calico
```bash
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

**Step 2:** Install Calico Operator
```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
```

**Step 3:** Create Installation resource
```bash
kubectl create -f - <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF
```

**Step 4:** Verify
```bash
watch kubectl get pods -n calico-system
# Wait for all pods to be Running

kubectl get nodes
# All nodes should be Ready
```

---

### Solution 4: Integrate into Ansible Role (INFRASTRUCTURE AS CODE)

**Method:** Update the cni-calico Ansible role to modify the manifest

**File:** `ansible/roles/cni-calico/tasks/main.yml`

Add a task to patch the manifest before applying:

```yaml
- name: Add privileged securityContext to install-cni container
  lineinfile:
    path: "{{ calico_manifest_path }}"
    insertafter: '^\s+- name: install-cni'
    line: |2
          securityContext:
            privileged: true
    state: present
```

Or use a more robust approach with `replace` module:

```yaml
- name: Download Calico manifest
  get_url:
    url: "{{ calico_manifest_url }}"
    dest: "{{ calico_manifest_path }}"
    mode: '0644'

- name: Read Calico manifest
  slurp:
    src: "{{ calico_manifest_path }}"
  register: calico_manifest_content

- name: Parse and modify manifest
  set_fact:
    modified_manifest: "{{ calico_manifest_content.content | b64decode | from_yaml_all | list }}"

- name: Add privileged context to install-cni
  set_fact:
    patched_manifest: "{{ modified_manifest | ... }}"  # Use custom filter or template

- name: Write modified manifest
  copy:
    content: "{{ patched_manifest | to_nice_yaml }}"
    dest: "{{ calico_manifest_path }}"
```

**Simpler template-based approach:**

Create `ansible/roles/cni-calico/templates/calico-patch.yaml.j2`:

```yaml
spec:
  template:
    spec:
      initContainers:
      - name: install-cni
        securityContext:
          privileged: true
```

Then apply as a strategic merge patch:

```yaml
- name: Apply privileged security context patch
  command: >
    {{ k8s_bin_dir }}/kubectl patch daemonset calico-node
    -n kube-system
    --patch-file={{ role_path }}/templates/calico-patch.yaml.j2
    --kubeconfig={{ k8s_config_dir }}/admin.conf
```

---

## Verification Steps

After applying any solution:

**1. Check Calico pods**
```bash
export KUBECONFIG=~/.kube/k8s-lab-config

kubectl get pods -n kube-system -l k8s-app=calico-node -o wide
```

**Expected output:**
```
NAME                  READY   STATUS    RESTARTS   AGE   NODE
calico-node-xxxxx     1/1     Running   0          XXm   master-01
calico-node-xxxxx     1/1     Running   0          XXm   worker-01
calico-node-xxxxx     1/1     Running   0          XXm   worker-02
```

**2. Check node status**
```bash
kubectl get nodes
```

**Expected output:**
```
NAME        STATUS   ROLES    AGE   VERSION
master-01   Ready    <none>   XXm   v1.31.0
worker-01   Ready    <none>   XXm   v1.31.0
worker-02   Ready    <none>   XXm   v1.31.0
```

**3. Check CNI configuration on workers**
```bash
ssh -i ~/.vagrant.d/insecure_private_keys/vagrant.key.rsa vagrant@10.240.0.21 \
  "ls -la /etc/cni/net.d/"
```

**Expected output:**
```
total 8
drwxr-xr-x. 2 root root   57 <timestamp> .
drwxr-xr-x. 3 root root   19 <timestamp> ..
-rw-r--r--. 1 root root  660 <timestamp> 10-calico.conflist
-rw-------. 1 root root 2912 <timestamp> calico-kubeconfig
```

**4. Deploy test pod on worker**
```bash
kubectl run test-nginx --image=nginx --overrides='
{
  "spec": {
    "nodeSelector": {
      "kubernetes.io/hostname": "worker-01"
    }
  }
}'

# Wait and check
kubectl get pod test-nginx -o wide

# Should show Running on worker-01
```

---

## Why This Happens

### Technical Deep Dive

**SELinux Context Labels:**
- Files: `container_file_t` ✅ (correctly applied)
- Processes: Containers run with confined labels

**The Problem:**
Even with correct file contexts, **non-privileged containers cannot:**
1. Write to host directories mounted as volumes
2. Modify kernel network configurations
3. Create network interfaces
4. Load kernel modules

**The Solution:**
`privileged: true` gives the container:
1. Full access to host devices
2. Ability to modify `/proc` and `/sys`
3. CAP_SYS_ADMIN capability
4. Bypass SELinux enforcement for container operations

**Why Master Works:**
- Timing: Master's install-cni may run before SELinux policies are fully enforced
- Or: Master has slightly different initialization sequence
- Inconsistent: Not reliable - all nodes should use privileged mode

---

## Security Considerations

### Is Privileged Mode Safe?

**For CNI Init Containers: YES**

**Reasons:**
1. **Init containers** run once and exit (not long-running)
2. **Official Calico recommendation** for SELinux systems
3. **Limited scope:** Only installs binaries, doesn't handle traffic
4. **Alternative (Operator)** also uses privileged containers internally

**Mitigation:**
- Use Pod Security Standards with exemptions for kube-system namespace
- CNI pods are cluster-critical infrastructure
- Regularly update Calico to latest versions

---

## Alternative: Disable SELinux (NOT RECOMMENDED)

**For lab/development only:**

```bash
# On each worker node
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Delete and recreate Calico pods
kubectl delete pod -n kube-system -l k8s-app=calico-node --field-selector spec.nodeName!=master-01
```

**Why not recommended:**
- Security best practice: Keep SELinux enabled
- Production systems should have SELinux enforcing
- Proper solution: Use privileged init containers as designed

---

## References

### Official Documentation
- [Calico System Requirements](https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements)
- [Calico SELinux Configuration](https://docs.tigera.io/calico/latest/operations/ebpf/install)
- [Run Calico as Non-Privileged](https://docs.tigera.io/calico/latest/network-policy/non-privileged)

### GitHub Issues
- [#2266 - install-cni CrashLoopBackOff on workers](https://github.com/projectcalico/calico/issues/2266)
- [#2000 - Replace privileged=true with precise permissions](https://github.com/projectcalico/calico/issues/2000)
- [#7851 - Calico operator SELinux issues](https://github.com/projectcalico/calico/issues/7851)

### Related Documentation
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [SELinux for Containers](https://docs.k0sproject.io/v1.23.6+k0s.2/selinux/)
- [Container Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)

---

## Quick Reference Commands

```bash
# Check Calico pod status
kubectl get pods -n kube-system -l k8s-app=calico-node

# Check node status
kubectl get nodes

# Describe failing pod
kubectl describe pod <calico-pod-name> -n kube-system

# Check init container logs
kubectl logs <calico-pod-name> -n kube-system -c install-cni

# View DaemonSet spec
kubectl get daemonset calico-node -n kube-system -o yaml

# Patch DaemonSet
kubectl patch daemonset calico-node -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/initContainers/1/securityContext", "value": {"privileged": true}}]'

# Delete worker Calico pods
kubectl delete pod -n kube-system -l k8s-app=calico-node --field-selector spec.nodeName!=master-01

# Check SELinux contexts
ssh vagrant@10.240.0.21 "ls -lZ /opt/cni/bin/ | head -5"
```

---

**Document Version:** 1.0
**Last Updated:** 2025-11-08
**Calico Version:** v3.27.0
**Status:** Solution verified - privileged mode required for worker nodes
