# Cluster Validation Guide

Comprehensive validation commands to verify your HA Kubernetes cluster is operational.

## Quick Health Check

```bash
# All nodes Ready
kubectl get nodes

# System pods running
kubectl get pods -A | grep -E '0/|Error|Pending'

# VIP access working  
kubectl cluster-info

# Browser test service
curl -s http://192.168.1.80:30080 | grep -i nginx
```

## Comprehensive Validation

### Node Health
```bash
# Node details and resource usage
kubectl get nodes -o wide
kubectl top nodes
kubectl describe nodes | grep -A5 -B5 -E 'Conditions|Capacity|Allocatable'
```

### Control Plane Components
```bash
# Control plane pod status
kubectl get pods -n kube-system -l tier=control-plane

# etcd cluster health
kubectl get pods -n kube-system -l component=etcd

# API server endpoints
kubectl get endpoints kubernetes
```

### Network Validation
```bash
# CNI pods operational
kubectl get pods -n kube-flannel
kubectl get daemonset -n kube-flannel

# Service mesh readiness
kubectl get pods -A -o wide | grep -E 'Running|Ready'

# DNS functionality
kubectl run test-dns --image=busybox --rm -i --restart=Never -- nslookup kubernetes.default.svc.cluster.local
```

### Workload Distribution
```bash
# Test pod scheduling across nodes
kubectl create deployment test-distribution --image=nginx:alpine --replicas=6
kubectl get pods -l app=test-distribution -o wide

# Cleanup
kubectl delete deployment test-distribution
```

### HA Failover Testing
```bash
# Test VIP failover (simulate node failure)
# Stop keepalived on current VIP holder
ssh k8s_80@192.168.1.80 "sudo systemctl stop keepalived"

# Verify VIP moves to another node
ping 192.168.1.100
kubectl --server=https://192.168.1.100:6443 get nodes

# Restore service
ssh k8s_80@192.168.1.80 "sudo systemctl start keepalived"
```

### Storage and Services
```bash
# Service discovery
kubectl get services -A

# Persistent volumes (if configured)
kubectl get pv,pvc -A

# Resource quotas and limits
kubectl get resourcequotas -A
```

## Performance Validation

### Resource Utilization
```bash
# Node resource usage
kubectl top nodes

# Pod resource consumption
kubectl top pods -A

# Cluster resource summary
kubectl describe nodes | grep -A5 -B5 Allocated
```

### Network Performance
```bash
# Inter-pod communication test
kubectl run test-client --image=busybox --rm -i --restart=Never -- ping -c 3 10.244.1.1

# Service mesh latency (basic)
kubectl run test-service --image=busybox --rm -i --restart=Never -- time wget -qO- test-nginx-service.test-workload.svc.cluster.local
```

## Security Validation

### Certificate Health
```bash
# Check certificate expiration
kubectl get csr

# Verify TLS endpoints
curl -k https://192.168.1.100:6443/version

# Service account tokens
kubectl get serviceaccounts -A
```

### RBAC Configuration
```bash
# Cluster roles and bindings
kubectl get clusterroles | head -20
kubectl get clusterrolebindings | head -10

# Namespace isolation
kubectl get networkpolicies -A
```

## Expected Results

✅ **Healthy Cluster Indicators:**
- All 3 nodes in `Ready` status
- All system pods `Running` with `1/1` or `X/X` ready
- VIP (192.168.1.100) responds to API calls
- nginx test service accessible via browser
- etcd cluster shows 3 healthy members
- Pod scheduling distributes across all nodes

❌ **Warning Signs:**
- Nodes in `NotReady` status
- Pods stuck in `Pending` or `CrashLoopBackOff`
- VIP not responding or pointing to failed node
- DNS resolution failures
- Uneven pod distribution (all on one node)

## Automated Health Script

For quick validation, use the included health check:
```bash
./cluster-health-check.sh
```

This validates your cluster is production-ready and follows the architecture described in [Deployment Guide](deployment-guide.md).

## Phase 1: SD Card Preparation and Initial Boot

### 1.1 Generate Cloud-Init Configurations

```bash
cd cloud-init
./generate-configs.sh
```

**Expected outcome:**
- Files are created in `cloud-init-output/` for each node
- Each node gets its own user-data, meta-data, and network-config files

**Verification steps:**
- Confirm files exist for each node
- Verify IP addresses and hostnames are correctly set in the configurations

### 1.2 Flash SD Cards

For each of the 3 Raspberry Pi nodes:

1. Flash Raspberry Pi OS Lite (64-bit) to an SD card
2. Mount the SD card
3. Copy the corresponding cloud-init files:
   ```bash
   # For node 1
   cp cloud-init-output/k8s-node-1-user-data /path/to/sdcard/user-data
   cp cloud-init-output/k8s-node-1-meta-data /path/to/sdcard/meta-data
   cp cloud-init-output/k8s-node-1-network-config /path/to/sdcard/network-config
   ```

**Expected outcome:**
- SD cards contain both the OS and cloud-init configuration files

### 1.3 Initial Boot and Network Configuration

1. Insert SD cards into each Raspberry Pi
2. Power on all nodes 
3. Wait for cloud-init to complete (approximately 5-10 minutes)

**Verification steps:**
- Ping each node using its configured IP address
- Try SSH connection to each node using the configured username and SSH key

## Phase 2: Kubernetes Cluster Deployment

### 2.1 Verify Ansible Connectivity

```bash
ansible -i inventory.yml all -m ping
```

**Expected outcome:**
- All nodes respond successfully to the ping

### 2.2 Deploy the Kubernetes Cluster

```bash
ansible-playbook -i inventory.yml k8s-cluster-deploy.yml
```

**Watch for:**
- Any errors or failures during playbook execution
- Especially during control plane join operations
- Verify final status message indicates successful deployment

**Troubleshooting if needed:**
- If control plane nodes fail to join:
  ```bash
  ansible-playbook -i inventory.yml playbooks/fix-control-plane.yml -e "target_nodes=k8s-node-2,k8s-node-3"
  ```

### 2.3 Access the Cluster

```bash
# Copy the kubeconfig from the primary control plane node
scp k8s_80@192.168.1.80:/etc/kubernetes/admin.conf ~/.kube/config

# Test cluster access
kubectl get nodes
```

**Expected outcome:**
- All 3 control plane nodes show as Ready
- Node roles are correctly assigned

## Phase 3: Core Infrastructure Deployment

### 3.1 Deploy Infrastructure Components

```bash
ansible-playbook -i inventory.yml deploy-infrastructure.yml
```

**Expected outcome:**
- No errors during deployment
- Components deployed in correct namespaces

### 3.2 Verify Infrastructure Components

```bash
kubectl get pods -n argocd
kubectl get pods -n traefik
kubectl get pods -n cert-manager
```

**Expected outcome:**
- All pods are Running and Ready

## Phase 4: Cluster Health Verification

Run the comprehensive cluster health check script:

```bash
./cluster-health-check.sh
```

**Expected outcome:**
- Script completes without errors
- All components show as healthy

## Documentation of Issues

For any issues encountered during testing, document:

1. **Phase of deployment:** During which step did the issue occur?
2. **Observed behavior:** What happened?
3. **Expected behavior:** What should have happened?
4. **Error messages:** Any relevant output
5. **Resolution:** How was the issue fixed?

## Rollback Procedure

If testing needs to be restarted:

```bash
ansible-playbook -i inventory.yml playbooks/cleanup-cluster.yml
```

Then start from Phase 2.2 again.
