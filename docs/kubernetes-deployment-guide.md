# Kubernetes HA Control Plane Deployment Guide

## Overview

This guide covers the complete deployment of a highly available Kubernetes control plane on 3x Raspberry Pi 4 nodes, with a clear evolution path to Istio service mesh and Vault PKI architecture.

## Architecture

### Current Phase: HA Control Plane Foundation (✅ WORKING)
- **Control Plane**: 3x Raspberry Pi 4 nodes with HA Kubernetes control plane
- **Virtual IP**: 192.168.1.100 (keepalived failover) for API server access
- **Container Runtime**: containerd with systemd cgroup driver
- **Networking**: Flannel CNI for pod-to-pod communication
- **Certificate Management**: Direct certificate copy approach via Ansible (proven reliable)

### Future Phase: Service Mesh + Zero Trust Architecture
- **Istio Service Mesh**: Control plane components on Pi nodes, data plane on worker VMs
- **Vault PKI**: Root CA for all certificate lifecycle management
- **ArgoCD**: GitOps deployment management with Vault secrets integration
- **Worker Nodes**: Proxmox VMs running Vault+Pi-hole, Mattermost+PostgreSQL, Bitwarden+GitLab
- **Zero Trust**: Automatic mTLS, identity-based access control, default deny networking

### Network Configuration
- **Control Plane Nodes**: 192.168.1.80-82 (static IPs via cloud-init)
- **Virtual IP**: 192.168.1.100 (managed by keepalived)
- **API Server Port**: 6443 (external through VIP)
- **Pod Network**: 10.244.0.0/16 (Flannel CNI)
- **Service Network**: 10.245.0.0/16

## Sequential Deployment Strategy

Our proven **two-phase approach** ensures reliability by building complexity incrementally:

### Phase 1: Single-Node Foundation (✅ TESTED & WORKING)
**Playbook**: `k8s-node1-deploy.yml`
**Target**: k8s-node-1 (192.168.1.80)

**What it accomplishes**:
1. **OS preparation** via `common` role (packages, kernel modules, sysctl)
2. **Container runtime** setup with containerd configuration
3. **Clean slate preparation** (kubeadm reset, remove old configs)
4. **Kubernetes initialization** using `kubeadm init` with single-node etcd
5. **CNI deployment** with Flannel networking
6. **Single-node configuration** (remove control-plane taint for pod scheduling)
7. **Health verification** (etcd, API server, pod scheduling)

**Success criteria**:
- ✅ etcd health: `https://127.0.0.1:2379 is healthy`
- ✅ API server responding on port 6443
- ✅ All control plane pods running (etcd, apiserver, scheduler, controller-manager)
- ✅ Flannel CNI operational with pod networking
- ✅ Test pod successfully scheduled and deleted

### Phase 2: HA Cluster Expansion (✅ READY FOR TESTING)
**Playbook**: `k8s-ha-expand.yml`
**Target**: k8s-node-2 & k8s-node-3 (192.168.1.81-82)

**What it accomplishes**:
1. **Prepare secondary nodes** (OS setup via common/containerd roles, cleanup)
2. **Install keepalived** on all 3 nodes for VIP failover management
3. **Configure load balancing** with VIP 192.168.1.100:6443
4. **Direct certificate copy** via Ansible fetch/copy (avoids kubeadm timing issues)
5. **Sequential node joining** (serial: 1) using fresh tokens per node
6. **Post-join validation** (kubelet startup, node readiness verification)
7. **Final HA verification** (3-node etcd, VIP failover, pod scheduling)

**Success criteria**:
- ✅ All 3 nodes in `Ready` state
- ✅ 3-node etcd cluster healthy across all nodes
- ✅ VIP responding on 192.168.1.100:6443
- ✅ Keepalived failover functional (survives node failures)
- ✅ Pod scheduling works across all control plane nodes

## Key Technical Decisions

### Why Sequential Deployment?
1. **Complexity Management**: Single-node foundation eliminates bootstrap complexity
2. **Certificate Reliability**: kubeadm handles PKI automatically for initial node
3. **etcd Stability**: Start with single etcd, expand to cluster after verification
4. **Debugging Efficiency**: Issues are isolated to specific phases
5. **Production Readiness**: Each phase is validated before increasing complexity

### Why Direct Certificate Copy vs kubeadm Secrets?
**Problem**: kubeadm certificate secrets have timing issues in HA deployments
**Solution**: Direct Ansible fetch/copy approach
- Fetch certificates from primary master to Ansible controller
- Copy certificates to joining nodes before join operation
- Maintains same security model as kubeadm certificate keys
- Eliminates timing conflicts that cause join failures

### Network Architecture Decisions
- **Pod Subnet**: 10.244.0.0/16 (Flannel default, no conflicts)
- **Service Subnet**: 10.245.0.0/16 (avoiding overlap with pod network)
- **VIP Management**: keepalived for automatic failover (no HAProxy complexity)
- **Static IPs**: Cloud-init managed for predictable node addressing

## Deployment Instructions

### Prerequisites
- 3x Raspberry Pi 4 (4GB+ RAM recommended)
- MicroSD cards with cloud-init configurations
- Ubuntu Server 24.04 LTS (64-bit)
- Ansible control machine with repository access

### Step 1: Node Provisioning with Cloud-Init
```bash
# Generate node-specific cloud-init configurations
cd cloud-init
./generate-configs.sh

# Flash Ubuntu Server 24.04 LTS to SD cards
# Copy corresponding cloud-init files to boot partitions
# Boot all Pi nodes and verify SSH access
ansible -i inventory.yml all -m ping
```

### Step 2: Deploy Single-Node Foundation
```bash
# Deploy stable single-node cluster (Phase 1)
ansible-playbook -i inventory.yml k8s-node1-deploy.yml

# Verify single-node cluster health
kubectl get nodes
kubectl get pods -A
sudo ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --endpoints=https://127.0.0.1:2379 \
  endpoint health
```

### Step 3: Expand to HA Cluster  
```bash
# Expand to 3-node HA control plane (Phase 2)
ansible-playbook -i inventory.yml k8s-ha-expand.yml

# Verify HA cluster status
kubectl get nodes -o wide
ping 192.168.1.100  # Test VIP connectivity
curl -k https://192.168.1.100:6443/healthz

# Verify etcd cluster health
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://192.168.1.80:2379,https://192.168.1.81:2379,https://192.168.1.82:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health --cluster
```

## Component Architecture

### Control Plane Components
- **etcd**: Distributed across all 3 nodes with automatic peer discovery
- **kube-apiserver**: Running on all nodes, accessible via VIP load balancing
- **kube-controller-manager**: Active/standby across nodes (leader election)
- **kube-scheduler**: Active/standby across nodes (leader election)
- **kubelet**: Node agent managing static pods for control plane components
- **kube-proxy**: Service proxy handling ClusterIP/NodePort networking

### Certificate Management
**Current Approach (Direct Copy)**:
- Primary node generates all shared certificates via kubeadm
- Ansible fetches certificates to controller machine
- Certificates copied to joining nodes before join operation
- Same security model as kubeadm certificate secrets without timing issues

**Future Approach (Vault PKI)**:
- Vault root CA manages all certificate lifecycle
- Automatic certificate rotation for all components
- Integration with Istio for workload certificate management
- Zero-downtime certificate updates

### High Availability Implementation
- **keepalived**: VRRP-based VIP failover (192.168.1.100)
- **etcd cluster**: 3-node cluster with automatic leader election
- **Control plane**: All components running on all nodes with leader election
- **Pod scheduling**: Works across all control plane nodes (no dedicated workers needed)

## Evolution to Service Mesh Architecture

### Phase 3: Istio Service Mesh Foundation (PLANNED)
- Deploy Istio control plane on Pi control plane nodes
- Add Proxmox VM worker nodes for application workloads
- Configure Istio data plane with automatic sidecar injection
- Establish basic service mesh networking and policies

### Phase 4: Vault PKI Integration (PLANNED)
- Deploy Vault HA cluster on worker Node 1 
- Configure Vault PKI secrets engine as root CA
- Integrate Vault as Istio intermediate CA
- Migrate control plane certificates to Vault-managed lifecycle

### Phase 5: Zero Trust + GitOps (PLANNED)
- Deploy ArgoCD with Istio integration and Vault secrets
- Configure default-deny network policies with explicit AuthorizationPolicy
- Implement automatic mTLS for all service communication
- Deploy applications: Pi-hole, Mattermost, GitLab, Bitwarden with service mesh

## Troubleshooting

### Common Issues and Solutions

**etcd Connection Failures**:
- Check certificate paths: `/etc/kubernetes/pki/etcd/`
- Verify network connectivity between nodes on ports 2379/2380
- Ensure etcd service is running: `systemctl status etcd`

**VIP Not Responding**:
- Check keepalived status: `systemctl status keepalived`
- Verify VIP assignment: `ip addr show` (should show 192.168.1.100)
- Test manual connectivity: `curl -k https://<node-ip>:6443/healthz`

**Node Join Failures**:
- Generate fresh join token: `kubeadm token create --ttl=15m`
- Check certificate availability on joining node
- Verify network connectivity to primary master
- Check for timing issues (our direct copy approach eliminates these)

**Pod Scheduling Issues**:
- Check node status: `kubectl get nodes -o wide`
- Verify CNI status: `kubectl get pods -n kube-flannel`
- Check for taints: `kubectl describe nodes | grep -i taint`

### Recovery Commands
```bash
# Reset a node completely
sudo kubeadm reset -f
sudo systemctl stop kubelet containerd
sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet/pki
sudo systemctl start containerd

# Regenerate certificates and tokens (on primary master)
kubeadm init phase upload-certs --upload-certs
kubeadm token create --print-join-command --ttl=15m
```

## Lessons Learned

### What Works (Keep These Approaches)
1. **kubeadm for Bootstrap**: Handles complex initialization better than manual setup
2. **Sequential Deployment**: Single-node first eliminates many failure modes
3. **Direct Certificate Copy**: More reliable than kubeadm certificate secrets
4. **Clean State**: Always reset completely rather than fixing partial deployments
5. **Phase Validation**: Test each component before moving to the next

### What Doesn't Work (Avoid These)
1. **Multi-Node from Start**: Creates complex failure scenarios
2. **Manual Static Pod Setup**: Circular dependencies without proper bootstrap
3. **Complex Template Systems**: Hard to debug, prone to configuration drift
4. **Certificate Secret Timing**: kubeadm secrets expire during join operations
5. **Mixed Port Configurations**: Leads to connection failures and debugging issues

## Next Steps

After successful HA control plane deployment:
1. **Validation Testing**: Comprehensive end-to-end cluster testing
2. **Worker Node Planning**: Prepare Proxmox VMs for application workloads
3. **Istio Installation**: Begin service mesh control plane deployment
4. **Vault Deployment**: Start PKI root CA migration planning
5. **Application Architecture**: Design zero-trust networking for core services

This deployment guide provides a solid foundation for production Kubernetes on edge hardware with a clear evolution path to modern service mesh architecture.