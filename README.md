# Kubernetes Raspberry Pi Cluster

This repository contains Ansible roles and playbooks for setting up a high-availability Kubernetes cluster on Raspberry Pi hardware.

## Architecture

- **Control Plane**: 3x Raspberry Pi 4s running in HA configuration with etcd
- **Worker Nodes**: Future Lenovo M920Q nodes (to be added later)

## Prerequisites

- 3x Raspberry Pi 4 (4GB RAM or more) with Ubuntu 20.04 or newer
- Static IP addresses configured for each Pi
- SSH access to each Pi
- Ansible installed on your control machine

## Critical Configuration Notes

### etcd Configuration
The etcd cluster is configured to use the actual node IPs rather than the virtual IP (VIP) for peer communication:
- Peer URLs use the node's actual IP (e.g., 192.168.1.80) instead of VIP
- Client URLs still use the VIP for API server communication
- This ensures stable etcd cluster formation before the VIP becomes active

### API Server Configuration
The API server is configured with:
- Proper etcd client certificate paths
- Integration with the VIP for external access
- Updated admission controllers for Kubernetes 1.29.0 compatibility (using PodSecurity instead of PodSecurityPolicy)

## Directory Structure

```
├── group_vars/            # Variables shared across all hosts
│   └── all.yml            # Global variables
├── inventory.ini          # Legacy INI-format inventory (backward compatibility)
├── inventory.yml          # YAML inventory with better structure
├── k8s-cluster-deploy.yml # Main playbook that orchestrates all roles
├── playbooks/             # Additional playbooks
│   ├── ha-control-plane.yml  # HA-specific setup
│   └── post-install.yml      # Post-installation tasks
└── roles/                 # Ansible roles corresponding to K8s components
    ├── common/            # OS preparation
    ├── containerd/        # Container runtime
    ├── etcd/              # Distributed key-value store
    ├── kube_apiserver/    # Kubernetes API Server
    ├── kube_controller_manager/ # Controller Manager
    ├── kube_scheduler/    # Scheduler
    ├── kubelet/           # Node agent
    ├── kube_proxy/        # Network proxy
    └── cni/               # Container Network Interface
```

## Deployment Order

The deployment follows the Kubernetes control plane provisioning order:

1. OS Preparation (common role)
2. Container Runtime (containerd)
3. etcd Cluster
4. kube-apiserver
5. kube-controller-manager
6. kube-scheduler
7. kubelet
8. kube-proxy
9. CNI Plugin (Calico)

## Usage

### Deploy the complete Kubernetes cluster

```bash
ansible-playbook -i inventory.yml k8s-cluster-deploy.yml
```

### Deploy only the high-availability control plane

```bash
ansible-playbook -i inventory.yml playbooks/ha-control-plane.yml
```

### Deploy post-installation components (ArgoCD, Cert-Manager, Ingress)

```bash
ansible-playbook -i inventory.yml playbooks/post-install.yml
```

## Core Infrastructure

After deployment, the following core infrastructure components will be installed:

- **ArgoCD**: GitOps continuous delivery tool
- **Cert-Manager**: Certificate management for Kubernetes
- **NGINX Ingress Controller**: Kubernetes ingress controller

## High Availability

The control plane uses:
- **Keepalived**: Provides a virtual IP (VIP) for the control plane
- **HAProxy**: Load balances API requests across the control plane nodes

## Worker Node Plans

Future worker nodes (Lenovo M920Q) will run:
- Node 1: Vault + Pi-hole
- Node 2: Mattermost + PostgreSQL
- Node 3: Plex server + media storage