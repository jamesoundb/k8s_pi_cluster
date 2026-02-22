# Kubernetes Cluster Architecture

## Overview

Production-ready 3-node HA Kubernetes cluster on Raspberry Pi hardware with automated deployment and service mesh evolution path. Built using pure Ansible automation following infrastructure-as-code principles.

## Current Architecture ✅ OPERATIONAL

### HA Control Plane (3x Raspberry Pi 4)
- **Kubernetes**: v1.34.1 with kubeadm-based HA deployment
- **Virtual IP**: 192.168.1.100:6443 with keepalived failover
- **Container Runtime**: containerd 1.7.28 optimized for ARM64
- **CNI**: Flannel networking with pod distribution across nodes
- **Certificate Management**: Direct certificate copy via Ansible (proven reliable)

### Network Architecture
- **Virtual IP**: 192.168.1.100 (keepalived failover)
- **Control Plane**: 192.168.1.80-82 (static IPs)
- **Pod Network**: 10.244.0.0/16 (Flannel)
- **Service Network**: 10.245.0.0/16
- **External Access**: NodePort services (30000-32767)

### Deployment Automation
**3-Phase Sequential Deployment:**
1. `k8s-node1-deploy.yml` - Single-node foundation cluster
2. `k8s-ha-expand.yml` - HA expansion with VIP failover  
3. `k8s-post-config.yml` - Optimization and validation

**Key Features:**
- Pure Ansible automation (no manual steps)
- Idempotent playbooks with comprehensive validation
- Browser-accessible test services via NodePort
- Complete infrastructure-as-code approach

## Current Infrastructure Services ✅

### Phase 2: Infrastructure Services (In Progress)

**✅ ArgoCD Deployed**
- GitOps controller managing application deployments
- Namespace: `argocd` (7 pods, all Running)
- Admin credentials: username=`admin`, password displayed during deployment
- Ready to manage: `trading-agent-gitops` Git repository
- Access: `kubectl port-forward -n argocd svc/argocd-server 8080:443`

**⏳ Vault HA Deploying**
- 3-replica Raft backend launching on control plane nodes
- Namespace: `vault` (storage and pods initializing)
- Storage: local-storage provisioner with 10Gi per pod
- Features: Kubernetes auth, AppRole, PKI root CA
- Next: Manual initialization and unsealing (keys in `/tmp/vault-keys.json`)

**📋 Istio Service Mesh (Planned)**
- Deploys after Vault stabilization
- Requires: Vault HA operational, PKI configured
- Provides: mTLS, traffic management, policy enforcement
- Integration: Istio CA ↔ Vault intermediate CA certificate chain

### Evolution Path: Service Mesh & Zero Trust

### Phase 3: Advanced Service Mesh
- **Istio Sidecar Injection**: Automatic mTLS for services
- **Zero Trust Networking**: Policy-driven service communication  
- **Observability Stack**: Prometheus, Grafana, Jaeger, Kiali
- **Application Deployment**: Trading agent, Bitwarden, Mattermost, GitLab, Pi-hole

### Future Architecture Vision
```
Control Plane (Pi) + Service Mesh Control Plane
├── Worker VM 1: Vault HA + Pi-hole (DNS filtering)
├── Worker VM 2: Mattermost + PostgreSQL HA  
└── Worker VM 3: Bitwarden + GitLab Server

Certificate Management:
├── Vault Root CA → Istio Intermediate CA → Service mTLS
├── Automatic certificate rotation and distribution
└── Zero-trust service-to-service communication
```

**Traffic Management:**
- Single ingress point via Istio Gateway
- Service mesh policies: Default deny all traffic
- Explicit allow with AuthorizationPolicy
- Automatic mTLS for all service communication
- Identity-based access control via service accounts

## Current Deployment Workflow (Two-Phase Approach)

### Phase 1: Single-Node Foundation
The deployment begins with establishing a stable single-node cluster:

1. **Node Provisioning**:
   - Cloud-init configuration for static networking and user setup
   - SSH key distribution and user account creation
   - Kernel module and sysctl parameter pre-configuration

2. **OS Preparation**:
   - System packages and kernel configuration
   - Swap disabling and system optimization
   - Container runtime (containerd) installation

3. **Single-Node Cluster**:
   - kubeadm-based cluster initialization
   - Control plane components deployment
   - CNI plugin (Flannel) installation
   - Node readiness and health verification

### Phase 2: HA Expansion  
Once the foundation is stable, expand to high availability:

1. **Load Balancing Setup**:
   - Keepalived deployment for VIP failover
   - Virtual IP (192.168.1.100) configuration

2. **Certificate Distribution**:
   - Direct certificate copy via Ansible fetch/copy
   - Avoids kubeadm certificate secret timing issues
   - Ensures consistent PKI across all control plane nodes

3. **Sequential Node Joining**:
   - Add nodes 2 and 3 one at a time (serial: 1)
   - Fresh token generation for each join operation
   - Post-join kubelet startup and node readiness verification

4. **Final Validation**:
   - All nodes in Ready state
   - CNI networking functional across all nodes
   - Control plane components running on all nodes

3. **Network Infrastructure**:
   - HAProxy and Keepalived installation
   - VIP configuration

4. **First Control Plane**:
   - Bootstrap kubelet configuration
   - API server setup on port 6444
   - Update all kubeconfig files

5. **CNI Installation**:
   - Flannel network plugin deployment

6. **Additional Control Plane Nodes**:
   - Join additional control plane nodes
   - Configuration synchronization

7. **Worker Nodes**:
   - Join worker nodes to the cluster

## Troubleshooting

### Common Issues

1. **API Server not starting**:
   - Check if ports 6443/6444 are already in use
   - Verify kubelet is running with proper configuration
   - Check API server manifest has consistent port configuration

2. **Nodes not joining**:
   - Ensure VIP is accessible from all nodes
   - Check join command has correct token and certificate hash
   - Verify kubelet is properly configured on joining nodes

3. **Network connectivity issues**:
   - Verify Flannel is properly deployed
   - Check node network interfaces and firewalls
   - Ensure Pod and Service CIDR don't conflict with existing networks

## Maintenance

### Adding New Nodes

1. Add the node to the inventory file under the appropriate group
2. Run the node-specific playbook:
   - `ansible-playbook -i inventory.ini playbooks/add-control-plane.yml` (for control plane)
   - `ansible-playbook -i inventory.ini playbooks/add-worker.yml` (for worker)

### Upgrading the Cluster

To upgrade Kubernetes components:

1. Update the Kubernetes version variable in `group_vars/all.yml`
2. Run `ansible-playbook -i inventory.ini playbooks/upgrade-cluster.yml`

## Security Considerations

- The API server uses TLS for secure communication
- All internal communication uses certificates managed by kubeadm
- Kubelet bootstrap security is temporarily relaxed but transitions to secure mode
- RBAC configuration is applied for proper access control

### RBAC Configuration

The cluster uses Role-Based Access Control (RBAC) to secure access to resources:

- A dedicated playbook (`playbooks/create-rbac.yml`) establishes core RBAC permissions
- The kubernetes-admin user is bound to the cluster-admin role for full administrative access
- This configuration is applied after API server initialization but before CNI deployment
- Proper RBAC setup is critical for secure cluster management and operation
