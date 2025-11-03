# Tests

This directory contains test suites for validating the Kubernetes cluster.

## Structure

```
tests/
├── unit/                    # Unit tests for scripts and components
├── integration/             # Integration tests
└── e2e/                     # End-to-end tests
```

## Validation Scripts

The main validation scripts are located in `scripts/validation/`:

1. **01-infrastructure.sh** - Infrastructure validation
   - VM status and health
   - Network connectivity between nodes
   - SSH access
   - System requirements (swap disabled, kernel modules loaded)

2. **02-cluster-health.sh** - Cluster health validation
   - etcd cluster health
   - Control plane component status
   - Node registration and status
   - System pod health

3. **03-networking.sh** - Network functionality
   - CNI installation
   - Pod-to-pod connectivity
   - Service discovery
   - DNS resolution

4. **04-storage.sh** - Storage provisioning
   - Storage class availability
   - PVC creation and binding
   - Pod volume mounting
   - Data persistence

5. **05-e2e-app.sh** - End-to-end application test
   - Multi-tier application deployment
   - Service connectivity
   - LoadBalancer functionality
   - Complete workflow validation

## Running Tests

```bash
# Run all validation tests
make test-all

# Run specific test
./scripts/validation/02-cluster-health.sh

# Run with verbose output
VERBOSE=1 ./scripts/validation/03-networking.sh
```

## Test Output

Tests provide clear PASS/FAIL status:
- ✓ (green) - Test passed
- ✗ (red) - Test failed
- ⚠ (yellow) - Warning

Failed tests include:
- Error description
- Suggested remediation steps
- Relevant log locations

## Writing Tests

When adding new tests:
- Follow the existing naming convention
- Provide clear success/failure messages
- Include troubleshooting hints
- Make tests idempotent
- Clean up test resources
- Document prerequisites
