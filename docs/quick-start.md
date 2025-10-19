# Quick Start Guide

Get your 3-node HA Kubernetes cluster running in under 30 minutes.

## Prerequisites Checklist

- [ ] 3x Raspberry Pi 4 (4GB+ RAM)
- [ ] 3x MicroSD cards (32GB+ Class 10) 
- [ ] Ubuntu Server 24.04 LTS images
- [ ] SSH key pair (`~/.ssh/id_rsa`)
- [ ] Ansible installed on workstation

## 5-Step Deployment

### Step 1: Generate Configurations
```bash
cd /home/james/k8s_stuff/k8s_pi_cluster/cloud-init
./generate-configs.sh
```

### Step 2: Prepare SD Cards
For each Pi, flash Ubuntu and copy cloud-init configs:
```bash
# Flash Ubuntu to SD card, then:
cp cloud-init-output/k8s-node-X-* /path/to/sd/boot/
```

### Step 3: Boot Nodes
Insert SD cards and power on all 3 Pis. Wait 5 minutes for cloud-init setup.

### Step 4: Deploy Cluster
```bash
# Test connectivity
ansible -i inventory.yml all -m ping

# Deploy in sequence (30 minutes total)
ansible-playbook -i inventory.yml k8s-node1-deploy.yml     # ~10min - Foundation
ansible-playbook -i inventory.yml k8s-ha-expand.yml       # ~15min - HA expansion
ansible-playbook -i inventory.yml k8s-post-config.yml     # ~5min  - Validation
```

### Step 5: Configure Access
```bash
# Copy kubeconfig
scp -i ~/.ssh/id_rsa k8s_80@192.168.1.80:/home/k8s_80/.kube/config ~/.kube/config

# Update for VIP access
sed -i 's|https://192.168.1.80:6443|https://192.168.1.100:6443|g' ~/.kube/config

# Verify cluster
kubectl get nodes
```

## Success Validation

✅ **All nodes Ready**:
```bash
kubectl get nodes
# Expected: 3 nodes in Ready status
```

✅ **VIP failover working**:
```bash
kubectl cluster-info
# Expected: API server at https://192.168.1.100:6443
```

✅ **Browser access working**:
```
Open: http://192.168.1.80:30080
# Expected: nginx welcome page
```

## What You Get

- **HA Kubernetes v1.34.1** across 3 nodes
- **VIP failover** at 192.168.1.100:6443
- **Flannel networking** with pod distribution
- **Browser-accessible services** via NodePort
- **Complete automation** with zero manual steps

## Next Steps

1. **Deploy Applications**: Use `kubectl apply` or Helm charts
2. **Add Worker Nodes**: Join Proxmox VMs for dedicated workloads  
3. **Install Service Mesh**: Deploy Istio for advanced networking
4. **Setup GitOps**: Install ArgoCD for automated deployments

## Need Help?

- **Documentation**: [Full Deployment Guide](deployment-guide.md)
- **Troubleshooting**: [Common Issues](troubleshooting-guide.md)
- **Architecture**: [Cluster Architecture](cluster-architecture.md)

Your cluster is production-ready and follows cloud-native best practices!
