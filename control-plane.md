# Kubernetes Control Plane Architecture

This document provides details on the architecture, deployment, and configuration of the Kubernetes control plane in our Raspberry Pi cluster.

## Overview

The control plane consists of 3x Raspberry Pi 4 nodes running in High Availability (HA) configuration with the following components:

- **etcd**: Distributed key-value store for cluster state
- **kube-apiserver**: API server that exposes the Kubernetes API
- **kube-controller-manager**: Core controllers that manage the cluster state
- **kube-scheduler**: Watches for pods with no assigned node and selects nodes for them
- **keepalived + HAProxy**: Provides a Virtual IP (VIP) and load balancing for the API server

## Networking Architecture

The control plane uses a Virtual IP (VIP) to provide a single endpoint for the Kubernetes API server. This VIP is managed by keepalived which provides automatic failover between the nodes.

### Network Configuration:
- **Virtual IP**: 192.168.1.79
- **API Server Port**: 6443
- **etcd Client Port**: 2379
- **etcd Peer Port**: 2380

## etcd Deployment

etcd is deployed as a high availability cluster across all three control plane nodes. Each etcd instance has:

- Secure communication with TLS certificates
- Dedicated data directory (`/var/lib/etcd`)
- Properly configured peer and client endpoints
- Health check monitoring

Configuration parameters:
```
--initial-cluster=etcd1=https://[NODE1-IP]:2380,etcd2=https://[NODE2-IP]:2380,etcd3=https://[NODE3-IP]:2380
--initial-cluster-state=new
--initial-cluster-token=k8s-etcd-cluster
```

## API Server Configuration

The kube-apiserver is configured with:
- TLS certificates for secure communication
- Connection to the etcd cluster
- Authentication and authorization plugins
- Admission controllers
- Audit logging

## Certificate Management

A dedicated CA is used for creating and signing certificates for:
- etcd peer and client communication
- API server
- kubelet client certificates
- Controller manager and scheduler

## Load Balancer Configuration

HAProxy and Keepalived are configured to:
- Provide a Virtual IP (VIP) for high availability
- Load balance traffic to all API server instances
- Perform health checks against the API server instances
- Automatically failover if a node becomes unavailable

## Core Infrastructure Components

After the control plane is deployed, the following core infrastructure components are installed:

1. **ArgoCD**: Deployed via Helm for GitOps workflow
   - Uses a GitHub repository as the single source of truth
   - Configuration is defined using Helm charts and Kustomize
   - Syncs cluster state to match Git repository

2. **Ingress Controller**: NGINX or Traefik for ingress traffic
   - Manages external access to services
   - Handles TLS termination
   - Routes traffic based on hostnames and paths

3. **Cert-Manager**: For automated certificate management
   - Issues and renews Let's Encrypt certificates
   - Creates Kubernetes secrets for TLS certificates
   - Integrates with the ingress controller for HTTPS

## Deployment Process

The control plane is deployed using a fully automated Ansible-based process:

1. OS preparation (hostname, networking, packages)
2. Container runtime installation (containerd)
3. etcd cluster setup
4. Kubernetes components deployment (apiserver, controller-manager, scheduler)
5. Load balancer configuration (keepalived + HAProxy)
6. CNI plugin deployment
7. Core infrastructure deployment (ArgoCD, Ingress, Cert-Manager)

## Monitoring and Health Checks

The control plane health is monitored through:
- etcd health checks
- API server liveness probes
- keepalived state monitoring
- Component status checks

## Troubleshooting

Common issues and their resolutions:

1. **Node not joining cluster**: 
   - Use the fix-control-plane playbook to reset and rejoin the node
   - Check certificates and token validity

2. **etcd cluster issues**:
   - Verify etcd health with `etcdctl endpoint health`
   - Check logs with `journalctl -u etcd`

3. **API server unavailability**:
   - Check keepalived status and VIP availability
   - Verify HAProxy configuration and status
   - Check API server logs with `kubectl logs -n kube-system kube-apiserver-<node-name>`
