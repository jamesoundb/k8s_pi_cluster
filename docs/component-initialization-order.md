# Component Initialization Order

*This information is now integrated into the [Deployment Guide](deployment-guide.md). This document is maintained for reference only.*

## Critical Sequence

1. **OS Preparation** → containerd → Kubernetes packages
2. **etcd** → Certificates → API Server  
3. **kubelet** → Controller Manager → Scheduler
4. **CNI Plugin** → Network validation
5. **VIP Setup** → HA validation

See the [Deployment Guide](deployment-guide.md) for complete implementation details.

## Why This Order Matters

- **etcd first**: Other components depend on the key-value store
- **Certificates before API**: Secure communication required
- **CNI after control plane**: Networking needs running cluster
- **Serial joining**: Prevents certificate timing conflicts

Our playbooks handle this sequence automatically - no manual intervention required.

Before any Kubernetes components are deployed, the base OS must be configured:

- Update system packages
- Configure kernel parameters (`fs.inotify.max_user_watches`, `vm.swappiness`, etc.)
- Load required kernel modules (`overlay`, `br_netfilter`)
- Disable swap
- Configure networking (static IPs, hostname resolution)
- Install system dependencies

### 2. Container Runtime

The container runtime must be installed and configured before any Kubernetes component:

- Install containerd
- Configure containerd to use systemd cgroup driver
- Configure CNI directories
- Configure containerd to work with Kubernetes
- Start containerd service
- Verify containerd socket is available

### 3. etcd Cluster

etcd is the foundation of the cluster and must be operational first:

- Create data directories
- Generate or distribute CA certificates
- Create etcd server certificates
- Deploy etcd configuration
- Start etcd service
- Verify etcd cluster health

### 4. Certificate Authority (CA) Infrastructure

A proper certificate infrastructure must be established:

- Create the Kubernetes CA
- Generate certificates for API server
- Generate certificates for kubelet client
- Generate certificates for service accounts
- Generate certificates for other control plane components
- Distribute certificates to all control plane nodes

### 5. API Server

The API server is the central coordination point:

- Deploy API server with etcd connection information
- Configure API server flags
- Create systemd service or static pod manifest
- Start API server
- Verify API server health

### 6. Kubelet

The kubelet must run on all nodes:

- Configure kubelet to use containerd
- Configure kubelet authorization to API server
- Create kubelet systemd service
- Start kubelet service
- Register node with API server

### 7. Controller Manager

The controller manager handles core cluster state:

- Configure connection to API server
- Configure certificates
- Start controller manager
- Verify controller manager is running

### 8. Scheduler

The scheduler is responsible for pod placement:

- Configure connection to API server
- Configure scheduling parameters
- Start scheduler service
- Verify scheduler is operational

### 9. Networking Solution (CNI)

After all control plane components are running:

- Deploy networking solution (Flannel, Calico, etc.)
- Configure pod CIDR
- Configure service CIDR
- Verify pod-to-pod communication

### 10. Core Add-ons

After the basic cluster is functional:

- Deploy CoreDNS
- Deploy kube-proxy
- Deploy metrics server
- Verify basic cluster functionality

### 11. Additional Infrastructure

Once the core cluster is operational:

- Deploy ingress controller
- Deploy certificate management
- Deploy storage solutions
- Deploy monitoring and logging

## Implementation in Ansible Playbooks

Our playbooks and roles are structured to respect this initialization order:

1. **common role** - OS preparation
2. **containerd role** - Container runtime setup
3. **etcd role** - etcd cluster deployment
4. **certificates playbook** - Certificate generation and distribution
5. **kube_apiserver role** - API server deployment
6. **kubelet role** - Kubelet configuration
7. **kube_controller_manager role** - Controller manager deployment
8. **kube_scheduler role** - Scheduler deployment
9. **cni role** - Networking configuration
10. **post-install playbook** - Core add-ons and validation

## Critical Dependencies

These dependencies must be respected for successful cluster initialization:

1. **etcd → API server**: API server needs to connect to etcd
2. **Certificates → All components**: All components need proper certificates
3. **API server → Controller/Scheduler**: These components connect to the API server
4. **kubelet → Container runtime**: Kubelet requires a functioning container runtime
5. **Networking → Cluster functionality**: Pod-to-pod networking is essential

## Bootstrapping with kubeadm

When using kubeadm, this initialization order is handled automatically, but understanding it helps troubleshoot issues:

1. kubeadm creates certificates
2. kubeadm creates kubeconfig files
3. kubeadm creates static pod manifests
4. kubelet starts static pods in dependency order
5. kubeadm waits for control plane to be ready
6. kubeadm applies labels and taints
7. kubeadm creates bootstrap token
8. kubeadm configures networking

## Troubleshooting Component Dependency Failures

When initialization fails, check these dependencies:

1. **API server unable to start**: Check etcd connectivity and certificate paths
2. **Controller manager unable to connect**: Check API server connectivity
3. **Pods stuck in pending**: Check CNI deployment and kubelet logs
4. **Node not ready**: Check kubelet and container runtime status
5. **Certificate errors**: Check certificate paths and permissions

## Verification

After initialization, verify the cluster state by checking:

1. Node status: `kubectl get nodes`
2. Pod status: `kubectl get pods -A`
3. Component status: `kubectl get componentstatuses`
4. API server health: `curl -k https://[VIP]:6443/healthz`
5. etcd health: `ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --endpoints=https://localhost:2379 endpoint health`
