#!/bin/bash
# Script to diagnose containerd issues

echo "=== Checking containerd status ==="
systemctl status containerd

echo -e "\n=== Checking containerd socket ==="
if [ -S /run/containerd/containerd.sock ]; then
    echo "Socket exists"
    ls -la /run/containerd/containerd.sock
else
    echo "Socket doesn't exist!"
    echo "Checking containerd directory:"
    ls -la /run 2>/dev/null | grep containerd || echo "No containerd directory in /run"
fi

echo -e "\n=== Checking runtime configuration ==="
if [ -f /etc/default/kubelet ]; then
    echo "Kubelet config file contents:"
    cat /etc/default/kubelet
else
    echo "No kubelet config file found!"
fi

if [ -f /etc/containerd/config.toml ]; then
    echo -e "\nContainerd config exists:"
    grep SystemdCgroup /etc/containerd/config.toml
    grep -A 5 plugins.*cri /etc/containerd/config.toml
else
    echo -e "\nNo containerd config found!"
fi

echo -e "\n=== Checking if crictl is configured ==="
if [ -f /etc/crictl.yaml ]; then
    echo "crictl config exists:"
    cat /etc/crictl.yaml
else
    echo "No crictl config found!"
fi

echo -e "\n=== Checking network plugin ==="
if [ -d /opt/cni/bin ]; then
    echo "CNI plugins directory exists:"
    ls -la /opt/cni/bin | head -n 5
else
    echo "No CNI plugins directory found!"
fi

echo -e "\n=== Attempting to connect to containerd ==="
if command -v ctr &>/dev/null; then
    ctr --address /run/containerd/containerd.sock version || echo "Failed to get containerd version"
    echo -e "\nContainers:"
    ctr --address /run/containerd/containerd.sock c ls 2>/dev/null || echo "Failed to list containers"
else
    echo "ctr command not found!"
fi

echo -e "\n=== Checking system logs ==="
journalctl -u containerd --no-pager -n 20
