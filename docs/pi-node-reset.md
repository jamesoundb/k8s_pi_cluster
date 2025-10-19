# Pi Control Plane Node Reset Guide

This guide provides comprehensive procedures for resetting the Raspberry Pi control plane nodes without requiring SD card re-imaging.

## Overview

When testing deployments or recovering from issues, you can reset your Raspberry Pi nodes to a clean state remotely using Ansible automation. This preserves the base Ubuntu installation, SSH access, and user accounts while completely removing Kubernetes components.

## Prerequisites

- SSH access to all nodes
- Ansible connectivity working: `ansible -i inventory.yml all -m ping`
- Backup any important data (this process is destructive)

## Reset Options

### Option 1: Complete Reset (Recommended for Testing)

**Use Case**: Full validation of deployment process, complete cluster rebuild

```bash
# Reset all nodes to completely clean state
ansible-playbook -i inventory.yml reset-cluster.yml

# Verify nodes are clean
ansible -i inventory.yml all -m shell -a "systemctl status kubelet" 
# Should show: "Unit kubelet.service could not be found"

# Redeploy from scratch (full 3-phase process)
ansible-playbook -i inventory.yml k8s-node1-deploy.yml
ansible-playbook -i inventory.yml k8s-ha-expand.yml  
ansible-playbook -i inventory.yml k8s-post-config.yml
```

**What it does**:
- Stops all Kubernetes services
- Removes all Kubernetes packages and configuration
- Cleans container runtime and images
- Resets network interfaces and iptables
- Removes system modifications
- Returns node to base Ubuntu state

**Time**: ~5 minutes per node

### Option 2: Graceful Shutdown + Reset

**Use Case**: Clean shutdown of production cluster before rebuild

```bash
# First gracefully shutdown cluster (preserves data integrity)
ansible-playbook -i inventory.yml shutdown-cluster.yml

# Then reset to clean state
ansible-playbook -i inventory.yml reset-cluster.yml

# Redeploy cluster
ansible-playbook -i inventory.yml k8s-node1-deploy.yml
ansible-playbook -i inventory.yml k8s-ha-expand.yml
ansible-playbook -i inventory.yml k8s-post-config.yml
```

**What it does**:
- Gracefully drains workloads
- Safely stops etcd cluster
- Cleanly shuts down control plane
- Then performs complete reset

**Time**: ~10 minutes total

### Option 3: Individual Node Reset

**Use Case**: Reset specific problematic nodes while keeping cluster

```bash
# Reset single node
ansible-playbook -i inventory.yml reset-cluster.yml --limit k8s-node-1

# Reset multiple specific nodes  
ansible-playbook -i inventory.yml reset-cluster.yml --limit k8s-node-1,k8s-node-2

# Reset all except one
ansible-playbook -i inventory.yml reset-cluster.yml --limit '!k8s-node-3'
```

**What it does**:
- Targets specific nodes only
- Useful for replacing failed nodes
- Other cluster nodes remain operational

**Time**: ~5 minutes per targeted node

### Option 4: Quick Kubernetes-only Reset

**Use Case**: Fast reset keeping system packages for rapid redeployment

```bash
# Reset Kubernetes components only (keeps packages)
ansible all -i inventory.yml -b -m shell -a "kubeadm reset -f"
ansible all -i inventory.yml -b -m file -a "path=/etc/kubernetes state=absent"
ansible all -i inventory.yml -b -m file -a "path=/var/lib/etcd state=absent"
ansible all -i inventory.yml -b -m file -a "path=/var/lib/kubelet state=absent"

# Clean network interfaces
ansible all -i inventory.yml -b -m shell -a "ip link delete flannel.1 || true"
ansible all -i inventory.yml -b -m shell -a "ip link delete cni0 || true"

# Restart containerd
ansible all -i inventory.yml -b -m systemd -a "name=containerd state=restarted"

# Redeploy (faster since packages remain)
ansible-playbook -i inventory.yml k8s-node1-deploy.yml
ansible-playbook -i inventory.yml k8s-ha-expand.yml
ansible-playbook -i inventory.yml k8s-post-config.yml
```

**What it does**:
- Removes only Kubernetes configuration and data
- Keeps packages and base system setup
- Fastest option for quick redeployment

**Time**: ~2 minutes total

## Verification Steps

After any reset, verify the node state:

```bash
# Check no Kubernetes processes running
ansible all -i inventory.yml -m shell -a "ps aux | grep -E '(kube|etcd)' | grep -v grep || echo 'Clean'"

# Verify no Kubernetes services
ansible all -i inventory.yml -m shell -a "systemctl status kubelet || echo 'Not found (good)'"

# Check network interfaces clean
ansible all -i inventory.yml -m shell -a "ip link show | grep -E '(flannel|cni|docker)' || echo 'Clean'"

# Verify file cleanup
ansible all -i inventory.yml -m shell -a "ls /etc/kubernetes /var/lib/etcd 2>/dev/null || echo 'Directories removed'"
```

## Troubleshooting

### Node Unreachable During Reset
```bash
# Skip unreachable nodes automatically
ansible-playbook -i inventory.yml reset-cluster.yml --limit @failed_hosts

# Or target only reachable nodes
ansible-playbook -i inventory.yml reset-cluster.yml --limit 'all:!unreachable_node'
```

### Reset Stuck on Specific Task
```bash
# Run reset with verbose output
ansible-playbook -i inventory.yml reset-cluster.yml -vvv

# Skip specific steps if needed
ansible-playbook -i inventory.yml reset-cluster.yml --skip-tags "network_cleanup,package_removal"
```

### Manual Emergency Reset
If automation fails, SSH to nodes individually:
```bash
ssh k8s_80@192.168.1.80

# Manual reset commands
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet
sudo systemctl stop kubelet containerd
sudo apt remove -y kubeadm kubelet kubectl containerd
sudo reboot
```

## Best Practices

1. **Always test connectivity first**:
   ```bash
   ansible -i inventory.yml all -m ping
   ```

2. **Use graceful shutdown for production**:
   ```bash
   ansible-playbook -i inventory.yml shutdown-cluster.yml
   ```

3. **Backup important data**:
   ```bash
   # Backup etcd data before reset (if needed)
   ansible k8s-node-1 -i inventory.yml -m fetch -a "src=/var/lib/etcd dest=./etcd-backup"
   ```

4. **Document any customizations**:
   - Note any manual configuration changes
   - Save custom application data
   - Record network or storage modifications

5. **Verify deployment after reset**:
   ```bash
   # Run complete validation
   kubectl get nodes
   kubectl get pods -A
   curl http://192.168.1.80:30080  # Browser test
   ```

## Recovery Scenarios

### Complete Cluster Failure
```bash
# Option 1: Full reset and redeploy
ansible-playbook -i inventory.yml reset-cluster.yml
ansible-playbook -i inventory.yml k8s-node1-deploy.yml
ansible-playbook -i inventory.yml k8s-ha-expand.yml
ansible-playbook -i inventory.yml k8s-post-config.yml
```

### Single Node Failure
```bash
# Reset failed node and rejoin
ansible-playbook -i inventory.yml reset-cluster.yml --limit failed_node
ansible-playbook -i inventory.yml k8s-ha-expand.yml --limit failed_node
```

### Network Configuration Issues
```bash
# Reset network components only
ansible all -i inventory.yml -b -m shell -a "kubeadm reset phase cleanup-node"
ansible-playbook -i inventory.yml k8s-post-config.yml
```

This reset capability enables rapid iteration and testing while maintaining the pure Ansible automation philosophy of the project.