# Kubernetes Pi Cluster - Simplified Deployment Guide

This guide provides a streamlined approach to setting up a Kubernetes cluster on Raspberry Pi devices from scratch.

## Prerequisites

- 3x Raspberry Pi 4 (4GB+ RAM)
- MicroSD cards for each Pi
- Network with DHCP (for initial boot)
- Linux/Mac workstation for preparation

## Deployment Process Overview

1. **Generate cloud-init configurations**
2. **Prepare SD cards** 
3. **Deploy the Kubernetes cluster**
4. **Deploy core infrastructure**
5. **Verify the deployment**

## Step-by-Step Instructions

### 1. Generate Cloud-Init Configurations

The cloud-init files will configure networking, user accounts, and SSH keys on first boot:

```bash
cd /home/james/k8s_stuff/k8s_pi_cluster/cloud-init
./generate-configs.sh
```

This will create the necessary cloud-init configuration files in the `cloud-init-output` directory.

### 2. Prepare SD Cards

For each Raspberry Pi:

1. Flash Raspberry Pi OS Lite (64-bit) to the SD card
2. Mount the SD card
3. Copy the corresponding cloud-init files to the boot partition:

```bash
# Example for k8s-node-1
cp cloud-init-output/k8s-node-1-user-data /path/to/sd/card/user-data
cp cloud-init-output/k8s-node-1-meta-data /path/to/sd/card/meta-data
cp cloud-init-output/k8s-node-1-network-config /path/to/sd/card/network-config
```

4. Insert the SD card into the Raspberry Pi and power it on
5. Wait for the Pi to boot and configure itself with the cloud-init settings

### 3. Deploy the Kubernetes Cluster

Once all Raspberry Pi nodes are running and accessible via SSH:

```bash
# Verify connectivity to all nodes
ansible -i inventory.yml all -m ping

# Deploy the full Kubernetes cluster
ansible-playbook -i inventory.yml k8s-cluster-deploy.yml
```

This single playbook handles:
- OS preparation
- Container runtime installation
- etcd cluster deployment
- API server and load balancer configuration
- Kubernetes component deployment
- CNI plugin installation

### 4. Deploy Core Infrastructure

After the cluster is running, deploy the core infrastructure components:

```bash
ansible-playbook -i inventory.yml deploy-infrastructure.yml
```

This will deploy:
- ArgoCD
- Ingress controller
- Cert-Manager

### 5. Verify the Deployment

Verify that the cluster is functioning correctly:

```bash
# Get the admin.conf from the first control plane node
scp k8s_80@192.168.1.80:/etc/kubernetes/admin.conf ~/.kube/config

# Check node status
kubectl get nodes

# Check pod status
kubectl get pods -A
```

## Cleanup and Reset

If you need to reset the cluster:

```bash
ansible-playbook -i inventory.yml playbooks/cleanup-cluster.yml
```

## Troubleshooting

If control plane nodes fail to join:

```bash
ansible-playbook -i inventory.yml playbooks/fix-control-plane.yml -e "target_nodes=k8s-node-2,k8s-node-3"
```
