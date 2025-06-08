#!/bin/bash
# Comprehensive diagnostics for Kubernetes API server startup issues
# Run this on the primary control plane node to diagnose initialization problems

echo "========== SYSTEM INFORMATION =========="
uname -a
free -m
df -h /var/lib/etcd /var/lib/kubelet

echo "========== NETWORK CONFIGURATION =========="
ip addr show
ip route show
ss -tulpn | grep -E '6443|6444'

echo "========== CONTAINERD STATUS =========="
systemctl status containerd
crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock info

echo "========== KUBELET STATUS =========="
systemctl status kubelet
journalctl -xeu kubelet | tail -n 50

echo "========== CONTAINER STATUS =========="
echo "All containers:"
crictl ps -a
echo "API server containers:"
crictl ps -a | grep kube-apiserver
echo "etcd containers:"
crictl ps -a | grep etcd

echo "========== KUBERNETES MANIFESTS =========="
echo "API server manifest:"
cat /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null || echo "API server manifest not found"
echo "etcd manifest:"
cat /etc/kubernetes/manifests/etcd.yaml 2>/dev/null || echo "etcd manifest not found"

echo "========== CONTAINER LOGS =========="
APISERVER_ID=$(crictl ps -a | grep kube-apiserver | head -n 1 | awk '{print $1}')
if [ -n "$APISERVER_ID" ]; then
  echo "API server container logs:"
  crictl logs $APISERVER_ID
else
  echo "No API server container found"
fi

ETCD_ID=$(crictl ps -a | grep etcd | head -n 1 | awk '{print $1}')
if [ -n "$ETCD_ID" ]; then
  echo "etcd container logs:"
  crictl logs $ETCD_ID
else
  echo "No etcd container found"
fi

echo "========== KUBELET CONFIGURATION =========="
cat /var/lib/kubelet/config.yaml 2>/dev/null || echo "Kubelet config not found"
cat /var/lib/kubelet/kubeadm-flags.env 2>/dev/null || echo "Kubelet flags not found"

echo "========== DNS CONFIGURATION =========="
cat /etc/hosts
cat /etc/resolv.conf
getent hosts $(hostname)
getent hosts localhost

echo "========== KUBEADM CONFIGURATION =========="
cat /etc/kubernetes/kubeadm-init-config.yaml 2>/dev/null || echo "kubeadm init config not found"
