# Kubernetes Cluster Architecture and Deployment

## Overview

This repository contains Ansible playbooks to deploy a highly available Kubernetes cluster on Raspberry Pi nodes. The deployment uses a carefully sequenced approach to ensure all components are properly initialized and configured.

## Architecture

The cluster is configured with:

- **HAProxy and Keepalived**: Provides a virtual IP (VIP) and load balancing across control plane nodes
- **Control Plane**: Multiple master nodes running the Kubernetes control plane components
- **Worker Nodes**: Nodes dedicated to running workloads

### Network Architecture

- **Virtual IP**: 192.168.1.100 (managed by Keepalived)
- **API Server Port**: 6444 (internal) / 6443 (external through HAProxy)
- **Pod Network**: 10.244.0.0/16 (Flannel CNI)
- **Service Network**: 10.245.0.0/16

## Port Configuration

To prevent port conflicts and ensure proper operation, we use a dual-port strategy:

1. **HAProxy**:
   - Listens on port 6443 (standard Kubernetes API port)
   - Forwards requests to kube-apiserver on each control plane node

2. **kube-apiserver**:
   - Configured to use port 6444 instead of the default 6443
   - Avoids conflicts with HAProxy on the control plane nodes
   - All health checks and internal references use port 6444 consistently

3. **kubelet configuration**:
   - Uses a bootstrap configuration with no certificate requirements initially
   - Transitions to using proper certificates once the API server is running
   - Updated to connect to API server on port 6444 directly

## Deployment Workflow

The deployment follows this sequence:

1. **OS Preparation**:
   - System packages and kernel configuration
   - Swap disabling and system optimization

2. **Container Runtime**:
   - Containerd installation and configuration
   - cgroup driver setup

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
