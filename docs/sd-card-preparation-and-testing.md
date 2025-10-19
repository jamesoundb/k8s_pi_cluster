# Raspberry Pi SD Card Preparation & Testing Guide

This comprehensive guide covers SD card preparation, deployment, and testing for the Kubernetes HA control plane cluster using our proven two-phase deployment strategy.

## Overview

This guide supports the complete end-to-end validation process:
1. **SD Card Preparation**: Generate cloud-init configs and flash fresh SD cards
2. **Phase 1 Deployment**: Deploy stable single-node foundation cluster
3. **Phase 2 Deployment**: Expand to 3-node HA control plane
4. **Comprehensive Testing**: Validate complete cluster operation

## Prerequisites

- 3x Raspberry Pi 4 (4GB+ RAM recommended)
- 3x MicroSD cards (32GB+ Class 10)
- Ubuntu Server 24.04 LTS (64-bit) image
- Raspberry Pi Imager or similar flashing tool
- Linux/Mac workstation with Ansible

## Phase 1: SD Card Preparation

### 1.1 Generate Cloud-Init Configuration Files

```bash
# Navigate to the cloud-init directory
cd /home/james/k8s_stuff/k8s_pi_cluster/cloud-init

# Generate node-specific configuration files
./generate-configs.sh
```

This script will:
- Prompt for an SSH key to use or generate a new one
- Create cloud-init files for each node in `cloud-init-output/`:
  - `k8s-node-1-*` → k8s_80@192.168.1.80 
  - `k8s-node-2-*` → k8s_81@192.168.1.81
  - `k8s-node-3-*` → k8s_82@192.168.1.82

### 1.2 Download and Flash SD Cards

1. **Download Ubuntu Server Image**:
   - Get Ubuntu Server 24.04 LTS (64-bit) for Raspberry Pi
   - URL: https://ubuntu.com/download/raspberry-pi

2. **Flash SD Cards**:
   - Use Raspberry Pi Imager or similar tool
   - Flash the Ubuntu Server image to all 3 SD cards
   - **Do not** enable SSH or set passwords in imager (cloud-init will handle this)

### 1.3 Copy Cloud-Init Files to SD Cards

For each SD card, mount the boot partition and copy the corresponding cloud-init files:

```bash
# Create mount directory
mkdir -p /tmp/sd_boot

# Find the boot partition (usually /dev/sdX1 where X is the drive letter)
lsblk

# For k8s-node-1 SD card:
sudo mount /dev/sdX1 /tmp/sd_boot
sudo cp cloud-init-output/k8s-node-1-user-data /tmp/sd_boot/user-data
sudo cp cloud-init-output/k8s-node-1-network-config /tmp/sd_boot/network-config
sudo cp cloud-init-output/k8s-node-1-meta-data /tmp/sd_boot/meta-data
sudo umount /tmp/sd_boot

# Repeat for k8s-node-2 and k8s-node-3 SD cards with their respective files
```

### 1.4 Boot and Verify Node Setup

1. **Power Setup**:
   - Power down existing cluster if running
   - Insert fresh SD cards into each Raspberry Pi
   - Power on nodes **one at a time**, starting with k8s-node-1
   - Wait ~2-3 minutes for cloud-init to complete

2. **Verify Network Configuration**:
   ```bash
   # Test connectivity to each node
   ping -c 3 192.168.1.80
   ping -c 3 192.168.1.81
   ping -c 3 192.168.1.82
   
   # Test SSH access
   ssh k8s_80@192.168.1.80 'hostname && ip addr show eth0'
   ssh k8s_81@192.168.1.81 'hostname && ip addr show eth0'  
   ssh k8s_82@192.168.1.82 'hostname && ip addr show eth0'
   ```

3. **Verify Ansible Connectivity**:
   ```bash
   cd /home/james/k8s_stuff/k8s_pi_cluster
   ansible -i inventory.yml all -m ping
   ```

## Phase 2: Two-Phase Kubernetes Deployment

### 2.1 Deploy Single-Node Foundation (Phase 1)

Deploy the stable single-node foundation cluster:

```bash
cd /home/james/k8s_stuff/k8s_pi_cluster

# Deploy single-node foundation cluster
ansible-playbook -i inventory.yml k8s-node1-deploy.yml
```

**Track Phase 1 Progress**:
- [ ] OS preparation completed on k8s-node-1
- [ ] containerd installed and configured
- [ ] kubeadm initialization successful
- [ ] Single-node etcd healthy
- [ ] kube-apiserver responding on port 6443
- [ ] Flannel CNI deployed and operational
- [ ] Control-plane taint removed for pod scheduling

**Verify Phase 1 Success**:
```bash
# Check node status
kubectl get nodes

# Verify etcd health
sudo ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --endpoints=https://127.0.0.1:2379 \
  endpoint health

# Check all system pods
kubectl get pods -A

# Test pod scheduling
kubectl run test-pod --image=nginx --rm -it --restart=Never -- echo "Phase 1 Success"
```

**Phase 1 Success Criteria**:
- ✅ Node shows `Ready` status
- ✅ etcd health: `https://127.0.0.1:2379 is healthy`
- ✅ All control plane pods in `Running` state
- ✅ Flannel pods running in kube-flannel namespace
- ✅ Test pod successfully scheduled and executed

### 2.2 Expand to HA Control Plane (Phase 2)

Once Phase 1 is validated, expand to full HA:

```bash
# Expand to 3-node HA control plane
ansible-playbook -i inventory.yml k8s-ha-expand.yml
```

**Track Phase 2 Progress**:
- [ ] keepalived installed on all nodes
- [ ] Virtual IP (192.168.1.100) active and responding
- [ ] Certificates copied to joining nodes
- [ ] k8s-node-2 joined successfully 
- [ ] k8s-node-3 joined successfully
- [ ] All nodes show `Ready` status
- [ ] 3-node etcd cluster healthy

**Verify Phase 2 Success**:
```bash
# Check all nodes
kubectl get nodes -o wide

# Test VIP connectivity
ping -c 3 192.168.1.100
curl -k https://192.168.1.100:6443/healthz

# Verify 3-node etcd cluster
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://192.168.1.80:2379,https://192.168.1.81:2379,https://192.168.1.82:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health --cluster

# Test pod scheduling across all nodes
for i in {1..3}; do
  kubectl run test-pod-$i --image=nginx --rm -it --restart=Never -- hostname
done
```

**Phase 2 Success Criteria**:
- ✅ All 3 nodes in `Ready` state
- ✅ VIP (192.168.1.100) responding to API calls
- ✅ 3-node etcd cluster showing all members healthy
- ✅ Pods can be scheduled on any control plane node
- ✅ Failover testing (stop one node, cluster remains operational)

## Phase 3: Comprehensive Cluster Testing

### 3.1 Component Health Verification

```bash
# Check all system components
kubectl get pods -A -o wide

# Verify control plane components on each node
kubectl get pods -n kube-system -l tier=control-plane

# Check CNI networking
kubectl get pods -n kube-flannel

# Verify DNS resolution
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local
```

### 3.2 Network Connectivity Testing

```bash
# Test pod-to-pod networking across nodes
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: network-test-1
spec:
  nodeName: k8s-node-1
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: network-test-2  
spec:
  nodeName: k8s-node-2
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
EOF

# Test cross-node connectivity
kubectl exec network-test-1 -- ping -c 3 $(kubectl get pod network-test-2 -o jsonpath='{.status.podIP}')

# Clean up test pods
kubectl delete pod network-test-1 network-test-2
```

### 3.3 High Availability Testing

```bash
# Test VIP failover by stopping keepalived on different nodes
# Monitor VIP ownership: watch -n 1 'kubectl get nodes; echo; ip addr show | grep 192.168.1.100'

# Test API server availability during node failures
# In one terminal: watch -n 1 'curl -k https://192.168.1.100:6443/healthz'
# In another terminal: systemctl stop kubelet (on different nodes one at a time)
```

### 3.4 Service and Ingress Testing

```bash
# Deploy test service
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Test service connectivity
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -s http://test-service

# Clean up
kubectl delete deployment test-deployment
kubectl delete service test-service
```

## Testing Checklist

### SD Card Preparation
- [ ] Cloud-init configs generated successfully
- [ ] Ubuntu Server 24.04 LTS flashed to all 3 SD cards
- [ ] Cloud-init files copied to each SD card boot partition
- [ ] All nodes booted and accessible via SSH
- [ ] Network configuration applied correctly (static IPs)
- [ ] Ansible connectivity verified

### Phase 1: Single-Node Foundation
- [ ] k8s-node1-deploy.yml executed successfully
- [ ] Node k8s-node-1 shows `Ready` status
- [ ] etcd health check passes
- [ ] All control plane pods running
- [ ] Flannel CNI operational
- [ ] Test pod scheduling works
- [ ] API server accessible on port 6443

### Phase 2: HA Expansion  
- [ ] k8s-ha-expand.yml executed successfully
- [ ] keepalived installed and VIP active
- [ ] k8s-node-2 joined successfully
- [ ] k8s-node-3 joined successfully
- [ ] All 3 nodes show `Ready` status
- [ ] 3-node etcd cluster healthy
- [ ] VIP (192.168.1.100) responds to API calls
- [ ] Pod scheduling works across all nodes

### Comprehensive Testing
- [ ] All system pods running across all nodes
- [ ] DNS resolution functional
- [ ] Pod-to-pod networking across nodes
- [ ] Service networking functional
- [ ] VIP failover testing successful
- [ ] API server remains available during node failures

## Troubleshooting Common Issues

### SSH Connection Issues
```bash
# If SSH fails, check cloud-init status on the Pi
# Connect via console/keyboard and check:
sudo cloud-init status
sudo journalctl -u cloud-init-local.service
sudo journalctl -u cloud-init.service
```

### Phase 1 Deployment Issues
```bash
# Check containerd status
sudo systemctl status containerd

# Check kubelet logs
sudo journalctl -u kubelet -f

# Reset and retry if needed
sudo kubeadm reset -f
# Re-run k8s-node1-deploy.yml
```

### Phase 2 Join Issues
```bash
# Generate fresh join token
kubeadm token create --ttl=15m

# Check certificate availability
ls -la /etc/kubernetes/pki/

# Reset joining node if needed
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes
```

### Network Issues
```bash
# Check Flannel pods
kubectl get pods -n kube-flannel

# Check CNI configuration
sudo ls -la /etc/cni/net.d/

# Restart Flannel if needed
kubectl delete pods -n kube-flannel -l app=flannel
```

### VIP Issues
```bash
# Check keepalived status
sudo systemctl status keepalived

# Check which node has VIP
ip addr show | grep 192.168.1.100

# Check keepalived logs
sudo journalctl -u keepalived -f
```

## Success Criteria Summary

**Complete Success** requires all of the following:
- ✅ All 3 nodes showing `Ready` status in kubectl get nodes
- ✅ VIP (192.168.1.100) responding to Kubernetes API calls
- ✅ 3-node etcd cluster with all members healthy
- ✅ All system pods running across all control plane nodes
- ✅ Pod networking functional across all nodes with Flannel CNI
- ✅ Service discovery and DNS resolution working
- ✅ High availability validated (cluster survives single node failures)
- ✅ Pod scheduling works on all control plane nodes

This testing validates the complete foundation for service mesh evolution with Istio and Vault PKI integration.