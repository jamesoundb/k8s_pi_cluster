#!/bin/bash
# Troubleshooting script for unresponsive nodes

NODE_IP=$1
NODE_NAME=$2

if [ -z "$NODE_IP" ] || [ -z "$NODE_NAME" ]; then
    echo "Usage: $0 <node-ip> <node-name>"
    echo "Example: $0 192.168.1.80 k8s-node-1"
    exit 1
fi

echo "=== Troubleshooting Node: $NODE_NAME ($NODE_IP) ==="

echo "1. Checking connectivity..."
if ping -c 3 -W 2 $NODE_IP &>/dev/null; then
    echo "   ✓ Node is responding to ping"
    PING_OK=true
else
    echo "   ✗ Node is not responding to ping"
    PING_OK=false
fi

echo "2. Checking if ports are open (if node is pingable)..."
if [ "$PING_OK" = true ]; then
    # Check SSH port
    if nc -z -w 3 $NODE_IP 22 &>/dev/null; then
        echo "   ✓ SSH port (22) is open"
    else
        echo "   ✗ SSH port (22) is closed or filtered"
    fi
    
    # Check Kubernetes API port
    if nc -z -w 3 $NODE_IP 6443 &>/dev/null; then
        echo "   ✓ Kubernetes API port (6443) is open"
    else
        echo "   ✗ Kubernetes API port (6443) is closed or filtered"
    fi
fi

echo "3. Recommendations:"
if [ "$PING_OK" = false ]; then
    echo "   • Node is completely unreachable - physical intervention required"
    echo "   • Check power, network connection, and SD card integrity"
    echo "   • Consider connecting a monitor to check for boot errors"
else
    echo "   • Node is pingable but may have SSH or service issues"
    echo "   • Try rebooting with 'ansible $NODE_NAME -i inventory.yml -m reboot -b' if SSH works"
    echo "   • Check service status with 'ansible $NODE_NAME -i inventory.yml -m shell -a \"systemctl status kubelet\" -b'"
fi

echo "===== Troubleshooting complete ====="
