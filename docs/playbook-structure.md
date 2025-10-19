# Playbook Structure Reference

*Detailed usage is covered in [Quick Start](quick-start.md) and [Deployment Guide](deployment-guide.md).*

## Main Deployment Playbooks

| Playbook | Purpose | Phase |
|----------|---------|-------|
| `k8s-node1-deploy.yml` | Deploy single-node foundation cluster (stable base) | Phase 1 |
| `k8s-ha-expand.yml` | Expand to 3-node HA control plane using direct certificate copy | Phase 2 |

## Current Architecture Strategy

Our deployment follows a **two-phase sequential approach**:

### Phase 1: Single-Node Foundation
- Establishes a stable single-node Kubernetes cluster
- Includes all control plane components on first node
- Deploys CNI networking (Flannel)
- Validates cluster health before proceeding

### Phase 2: HA Expansion
- Adds keepalived for VIP failover (192.168.1.100)
- Uses proven direct certificate copy approach (via Ansible fetch/copy)
- Sequential node joining (serial: 1) to avoid timing conflicts
- Post-join validation ensures each node becomes Ready

## Support Playbooks

Located in the `playbooks/` directory for specific operational tasks:

| Playbook | Purpose |
|----------|---------|
| `cleanup-cluster.yml` | Resets and cleans up an existing Kubernetes cluster |
| `fix-control-plane.yml` | Troubleshooting playbook to fix control plane join issues |
| `monitor-cluster.yml` | Cluster monitoring and health checks |
| `node-recovery.yml` | Recovery procedures for failed nodes |

## Roles Structure

The playbooks utilize these Ansible roles:

| Role | Purpose |
|------|---------|
| `common` | OS preparation, kernel modules, sysctl parameters |
| `containerd` | Container runtime installation and configuration |
| `cni` | Container Network Interface deployment (Flannel) |
| `kube_apiserver` | API server configuration including keepalived/VIP setup |

## Usage Examples

### Complete HA Deployment (Recommended)
```bash
# Phase 1: Deploy stable single-node foundation
ansible-playbook -i inventory.yml k8s-node1-deploy.yml

# Verify single-node cluster health
kubectl get nodes
kubectl get pods -A

# Phase 2: Expand to HA control plane
ansible-playbook -i inventory.yml k8s-ha-expand.yml

# Verify HA cluster
kubectl get nodes -o wide
```

### Reset Cluster
```bash
ansible-playbook -i inventory.yml playbooks/cleanup-cluster.yml
```

### Troubleshoot Control Plane Issues
```bash
ansible-playbook -i inventory.yml playbooks/fix-control-plane.yml -e "target_nodes=k8s-node-2,k8s-node-3"
```

## Future Evolution: Service Mesh Architecture

The current control plane foundation enables the next phase of architecture evolution:

1. **Istio Service Mesh Deployment**: Control plane components on Pi nodes
2. **Worker Node Addition**: Proxmox VMs for application workloads
3. **Vault PKI Integration**: Replace direct certificate copy with Vault-managed certificates
4. **ArgoCD GitOps**: Infrastructure-as-code management
5. **Zero Trust Networking**: Istio security policies and mTLS automation
```bash
ansible-playbook -i inventory.yml playbooks/cleanup-cluster.yml
```

### Fix Control Plane Join Issues
```bash
ansible-playbook -i inventory.yml playbooks/fix-control-plane.yml
```

### Verify Control Plane Health
```bash
ansible-playbook -i inventory.yml playbooks/verify-control-plane.yml
```
