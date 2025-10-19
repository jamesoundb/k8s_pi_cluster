#!/bin/bash
# Comprehensive diagnostics for Kubernetes API server startup issues
# Run this on the primary control plane node to diagnose initialization problems

# Text formatting for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========== SYSTEM INFORMATION ==========${NC}"
uname -a
free -m
df -h /var/lib/etcd /var/lib/kubelet

echo -e "${BLUE}========== NETWORK CONFIGURATION ==========${NC}"
echo -e "${YELLOW}Checking for Virtual IP (192.168.1.100)...${NC}"
ip addr show | grep -A 2 "192.168.1.100" || echo -e "${RED}Virtual IP not found!${NC}"
echo ""

echo -e "${YELLOW}Checking port bindings (6443/6444)...${NC}"
ss -tulpn | grep -E '6443|6444' || echo -e "${RED}API server port not bound!${NC}"
echo ""

echo -e "${BLUE}========== KEEPALIVED STATUS ==========${NC}"
if systemctl is-active --quiet keepalived; then
    echo -e "${GREEN}Keepalived is running${NC}"
    systemctl status keepalived | grep -E "Active:|Main PID:" 
    echo -e "${YELLOW}Checking if check_apiserver.sh script exists...${NC}"
    if [ -f /etc/keepalived/check_apiserver.sh ]; then
        echo -e "${GREEN}check_apiserver.sh exists${NC}"
        grep -A 2 "curl" /etc/keepalived/check_apiserver.sh
    else
        echo -e "${RED}check_apiserver.sh NOT found!${NC}"
    fi
else
    echo -e "${RED}Keepalived is NOT running!${NC}"
fi

echo -e "${BLUE}========== HAPROXY STATUS ==========${NC}"
if systemctl is-active --quiet haproxy; then
    echo -e "${GREEN}HAProxy is running${NC}"
    systemctl status haproxy | grep -E "Active:|Main PID:"
else
    echo -e "${RED}HAProxy is NOT running!${NC}"
    echo -e "${YELLOW}Attempting to check HAProxy configuration...${NC}"
    grep -A 5 "bind" /etc/haproxy/haproxy.cfg || echo -e "${RED}Cannot find HAProxy configuration!${NC}"
fi

echo -e "${BLUE}========== CONTAINERD STATUS ==========${NC}"
if systemctl is-active --quiet containerd; then
    echo -e "${GREEN}Containerd is running${NC}"
else
    echo -e "${RED}Containerd is NOT running!${NC}"
fi
crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock info 2>/dev/null || echo -e "${RED}Cannot connect to containerd!${NC}"

echo -e "${BLUE}========== KUBELET STATUS ==========${NC}"
if systemctl is-active --quiet kubelet; then
    echo -e "${GREEN}Kubelet is running${NC}"
else
    echo -e "${RED}Kubelet is NOT running!${NC}"
fi
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
