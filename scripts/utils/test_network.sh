#!/bin/bash

# Test script for network connectivity in the Kubernetes cluster
# This script tests connectivity between all nodes in the 10.0.254.0/24 network

echo "Testing network connectivity for Kubernetes cluster..."
echo "Network: 10.0.254.0/24"
echo "=========================================="

# Test master nodes
echo "Testing master nodes connectivity..."
for i in {11..13}; do
    echo "Testing connectivity to master node: 10.0.254.$i"
    if ping -c 1 -W 2 10.0.254.$i > /dev/null 2>&1; then
        echo "✅ 10.0.254.$i is reachable"
    else
        echo "❌ 10.0.254.$i is not reachable"
    fi
done

echo ""
echo "Testing worker nodes connectivity..."
# Test worker nodes
for i in {21..23}; do
    echo "Testing connectivity to worker node: 10.0.254.$i"
    if ping -c 1 -W 2 10.0.254.$i > /dev/null 2>&1; then
        echo "✅ 10.0.254.$i is reachable"
    else
        echo "❌ 10.0.254.$i is not reachable"
    fi
done

echo ""
echo "Network test completed!"
echo "Note: Nodes may not be reachable until 'vagrant up' is executed." 