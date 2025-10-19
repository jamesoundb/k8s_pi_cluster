# Kubernetes HA Cluster Deployment Guide

Complete guide for deploying a production-ready 3-node HA Kubernetes cluster on Raspberry Pi hardware using automated Ansible playbooks.

## Quick Start

### Prerequisites
- 3x Raspberry Pi 4 (4GB+ RAM recommended)
- 3x MicroSD cards (32GB+ Class 10)
- Ubuntu Server 24.04 LTS images
- Ansible-capable workstation

### Complete Deployment (3 Phases)

```bash
# 1. Generate cloud-init configs
cd cloud-init && ./generate-configs.sh

# 2. Flash SD cards with configs and boot all nodes

# 3. Deploy cluster in sequence
ansible-playbook -i inventory.yml k8s-node1-deploy.yml     # Foundation
ansible-playbook -i inventory.yml k8s-ha-expand.yml       # HA expansion  
ansible-playbook -i inventory.yml k8s-post-config.yml     # Validation
```

**Expected Result**: 3-node HA cluster with VIP failover, browser-accessible test services, and full validation.

## Architecture

### Current: HA Control Plane Foundation ✅
- **3x Control Plane Nodes**: Raspberry Pi 4 (192.168.1.80-82)
- **Virtual IP**: 192.168.1.100 with keepalived failover
- **Container Runtime**: containerd 1.7.28
- **CNI**: Flannel (10.244.0.0/16 pod network)
- **Services**: 10.245.0.0/16 service network
- **HA Components**: 3x etcd, 3x API servers, controller-managers, schedulers

### Future: Service Mesh Evolution
- **Istio Service Mesh**: Control plane on Pi nodes, data plane on worker VMs
- **Vault PKI**: Root CA for certificate management and automatic rotation
- **ArgoCD GitOps**: Application deployment from Git repositories
- **Zero-Trust Networking**: mTLS between all services with policy enforcement

## Deployment Strategy

### Phase 1: Single-Node Foundation (k8s-node1-deploy.yml)
**Purpose**: Establish stable base cluster before HA complexity

1. **Node Preparation**: 
   - OS updates and kernel configuration
   - Container runtime (containerd) installation
   - Kubernetes package installation

2. **Cluster Initialization**:
   - kubeadm cluster init on first node
   - Control plane component deployment
   - Admin kubeconfig setup

3. **Networking Setup**:
   - Flannel CNI deployment
   - Network policy configuration
   - Single-node validation

### Phase 2: HA Expansion (k8s-ha-expand.yml)
**Purpose**: Add nodes 2&3 with VIP failover

1. **Certificate Management**:
   - Direct certificate copy via Ansible (proven approach)
   - Fresh token generation for each join
   - Secure certificate distribution

2. **Sequential Joining**:
   - Node 2 join with validation
   - Node 3 join with validation  
   - Serial execution prevents timing conflicts

3. **VIP Configuration**:
   - keepalived installation and config
   - Virtual IP (192.168.1.100) setup
   - Failover testing and validation

### Phase 3: Post-Configuration (k8s-post-config.yml)
**Purpose**: Optimization and comprehensive validation

1. **Cluster Optimization**:
   - Remove control-plane taints for workload distribution
   - Apply node labels for scheduling
   - Resource quota configuration

2. **Comprehensive Testing**:
   - Network connectivity validation
   - VIP failover testing
   - Multi-node workload deployment

3. **Browser Access Setup**:
   - NodePort service deployment
   - External access validation
   - Test workload with nginx (http://NODE_IP:30080)

## Post-Deployment Access

### Configure kubectl Access
```bash
# Copy kubeconfig from cluster
scp -i ~/.ssh/id_rsa k8s_80@192.168.1.80:/home/k8s_80/.kube/config ~/.kube/config

# Update for VIP access (recommended)
sed -i 's|https://192.168.1.80:6443|https://192.168.1.100:6443|g' ~/.kube/config

# Verify cluster access
kubectl cluster-info
kubectl get nodes -o wide
```

### Validate Deployment
```bash
# Check all nodes Ready
kubectl get nodes

# Verify system pods
kubectl get pods -A

# Test browser access (from post-config playbook)
curl http://192.168.1.80:30080  # nginx welcome page
```

## Technical Implementation

### Proven Solutions
1. **Direct Certificate Copy**: Ansible fetch/copy more reliable than kubeadm certificate keys
2. **Sequential Joining**: Serial node addition prevents timing conflicts
3. **VIP Integration**: keepalived provides true HA API server access
4. **Comprehensive Validation**: Each phase includes thorough health checks

### Key Components
- **kubeadm**: Kubernetes cluster initialization and management
- **containerd**: Container runtime with proper configuration for Pi hardware
- **Flannel**: Simple, reliable CNI for edge computing environments
- **keepalived**: VIP failover without external load balancer dependency

## Troubleshooting

### Common Issues
```bash
# Reset cluster if needed
ansible-playbook -i inventory.yml playbooks/cleanup-cluster.yml

# Fix control plane join issues
ansible-playbook -i inventory.yml playbooks/fix-control-plane.yml

# Check component health
kubectl get componentstatuses
kubectl get events --sort-by='.lastTimestamp'
```

### Network Validation
```bash
# CNI troubleshooting
kubectl get pods -n kube-flannel
kubectl describe nodes

# Service connectivity
kubectl run test-pod --image=busybox --rm -i --restart=Never -- nslookup kubernetes.default
```

## Next Steps: Service Mesh Evolution

1. **Add Worker Nodes**: Deploy Proxmox VMs and join as worker nodes
2. **Install Istio**: Deploy service mesh control plane
3. **Deploy Vault**: Establish PKI root CA for certificate management
4. **Setup ArgoCD**: Enable GitOps deployment workflows
5. **Configure Zero-Trust**: Implement mTLS and network policies

This foundation provides a robust platform for modern cloud-native applications with service mesh architecture and automated certificate lifecycle management.
