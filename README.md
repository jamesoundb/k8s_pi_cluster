# Kubernetes Raspberry Pi HA Cluster

Automated deployment of a production-ready, high-availability Kubernetes cluster on Raspberry Pi hardware using pure Ansible automation. Features Kubernetes 1.34.1 with VIP failover, automated certificate management, and end-to-end validation.

## 🚀 Quick Start

### Three-Phase Deployment

Deploy a fully validated HA Kubernetes cluster in three automated phases:

```bash
# Phase 1: Foundation cluster (single node)
ansible-playbook -i inventory.yml k8s-node1-deploy.yml

# Phase 2: HA expansion (add nodes 2&3 with VIP failover)  
ansible-playbook -i inventory.yml k8s-ha-expand.yml

# Phase 3: Post-configuration (taints, validation, optimization)
ansible-playbook -i inventory.yml k8s-post-config.yml
```

### Cluster Access Setup
After deployment, configure local access:
```bash
# Copy kubeconfig and configure VIP access
scp -i ~/.ssh/id_rsa k8s_80@192.168.1.80:/home/k8s_80/.kube/config ~/.kube/config
sed -i 's|https://192.168.1.80:6443|https://192.168.1.100:6443|g' ~/.kube/config

# Verify HA cluster access via VIP
kubectl get nodes
kubectl cluster-info
```

See [Post-Configuration Steps](docs/post-config-steps.md) for detailed access setup.

## 🎯 Architecture

**Control Plane (3x Raspberry Pi 4)**
- **Kubernetes**: v1.34.1 (latest stable)
- **Container Runtime**: containerd 1.7.28
- **Networking**: Flannel CNI (10.244.0.0/16)
- **High Availability**: keepalived VIP (192.168.1.100)
- **Certificate Management**: Direct certificate copy approach

**Key Features**
- ✅ True HA control plane with automatic failover
- ✅ End-to-end automation (no manual steps required)
- ✅ Minimal cloud-init for fast boot times (2-3 minutes)
- ✅ Production-ready security and networking
- ✅ Comprehensive validation and testing

## 📋 How the Playbooks Work

### k8s-node1-deploy.yml - Foundation Deployment
**Purpose**: Establishes a stable single-node Kubernetes cluster

**Key Steps**:
1. **OS Preparation** (`common` role): System optimization, kernel parameters, firewall
2. **Container Runtime** (`containerd` role): containerd installation and configuration  
3. **Kubernetes Installation**: Latest K8s 1.34.1 packages from official repositories
4. **Cluster Initialization**: `kubeadm init` with embedded configuration
5. **CNI Deployment**: Flannel networking setup and validation
6. **Single-Node Configuration**: Taint removal for workload scheduling

**Result**: Fully operational single-node cluster ready for HA expansion

### k8s-ha-expand.yml - HA Expansion  
**Purpose**: Converts single-node to 3-node HA cluster with VIP failover

**Key Steps**:
1. **Secondary Node Prep**: OS and containerd setup on nodes 2&3
2. **Kubernetes Installation**: K8s packages on secondary nodes
3. **VIP Configuration**: keepalived setup for 192.168.1.100 failover
4. **Certificate Management**: Direct certificate copy (resolves timing issues)
5. **Sequential Joining**: Nodes added one-by-one with fresh tokens
6. **HA Validation**: API server regeneration with VIP certificates

**Result**: 3-node HA cluster with VIP failover and certificate automation

### k8s-post-config.yml - Final Configuration
**Purpose**: Optimizes cluster for production workloads and validates functionality  

**Key Steps**:
1. **Taint Management**: Configure workload distribution across nodes
2. **Network Validation**: Verify Flannel CNI across all nodes
3. **HA Testing**: Test VIP failover and API server accessibility
4. **Workload Testing**: Deploy test applications to validate functionality
5. **Cluster Optimization**: Resource quotas, labels, and hardening
6. **Final Validation**: Comprehensive health checks

**Result**: Production-ready HA cluster with validated networking and failover

## 🛠 Deployment Philosophy

**Pure Ansible Automation**
- All operations embedded in playbooks and roles
- No shell scripts or manual interventions
- Idempotent - can be run multiple times safely
- Infrastructure as Code with version control

**Progressive Deployment**
- Phase 1: Stable foundation before complexity
- Phase 2: HA expansion with proven certificate management  
- Phase 3: Optimization and comprehensive validation

**Validated Approach**
- Direct certificate copy resolves kubeadm timing conflicts
- Minimal cloud-init reduces boot time from 30+ minutes to 2-3 minutes
- Sequential node joining prevents cluster formation issues
- End-to-end testing validates all components

## 📋 Prerequisites

**Hardware**
- 3x Raspberry Pi 4 (4GB+ RAM recommended)
- MicroSD cards (32GB+ each)
- Network with static IP capability

**Software**  
- Ubuntu 24.04 LTS Server (64-bit) for Pi nodes
- Ansible installed on control machine
- SSH access configured

## 🔧 Initial Setup

### 1. Prepare Cloud-Init Configurations
```bash
cd cloud-init
./generate-configs.sh
# Follow prompts to generate node-specific configurations
```

### 2. Flash and Boot Nodes
1. Flash Ubuntu 24.04 LTS Server to SD cards
2. Copy cloud-init configs to boot partition of each SD card
3. Boot all nodes and verify SSH connectivity

### 3. Deploy Kubernetes Cluster
Run the three-phase deployment as shown in Quick Start above.

### 4. Configure Access
Follow [Post-Configuration Steps](docs/post-config-steps.md) to set up kubectl access.

## ✅ Deployment Validation

**Expected Results After Successful Deployment:**

```bash
# Cluster status
$ kubectl get nodes
NAME         STATUS   ROLES           AGE   VERSION
k8s-node-1   Ready    control-plane   35m   v1.34.1
k8s-node-2   Ready    control-plane   14m   v1.34.1
k8s-node-3   Ready    control-plane   11m   v1.34.1

# VIP access
$ kubectl cluster-info
Kubernetes control plane is running at https://192.168.1.100:6443
CoreDNS is running at https://192.168.1.100:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

**Key Success Indicators:**
- ✅ All nodes show "Ready" status  
- ✅ All system pods running across nodes
- ✅ VIP (192.168.1.100) responds to API requests
- ✅ Flannel CNI operational on all nodes
- ✅ Test workloads deploy and communicate

## 📚 Documentation

**Essential Guides:**
- **[Quick Start](docs/quick-start.md)** - Deploy in 30 minutes
- **[Deployment Guide](docs/deployment-guide.md)** - Comprehensive deployment reference  
- **[Post-Config Steps](docs/post-config-steps.md)** - Cluster access and validation
- **[Troubleshooting](docs/troubleshooting-guide.md)** - Common issues and solutions

**Reference Documentation:**
- [Cluster Architecture](docs/cluster-architecture.md) - Design and evolution path
- [Validation Guide](docs/testing-plan.md) - Health checks and testing  
- [SD Card Preparation](docs/sd-card-preparation-and-testing.md) - Hardware setup
- [Documentation Index](docs/README.md) - Complete guide navigation

## 🔧 Troubleshooting

### Quick Diagnostics
```bash
# Check node connectivity
ansible -i inventory.yml all -m ping

# Cluster health check  
kubectl get nodes -o wide
kubectl get pods -A

# VIP failover test
kubectl --server=https://192.168.1.100:6443 get nodes
```

### Common Issues
- **Certificate errors**: Re-copy kubeconfig from cluster
- **VIP not accessible**: Check keepalived status on nodes
- **Nodes NotReady**: Verify kubelet and CNI pod status
- **Flannel issues**: Check CNI pods and network configuration

## 🚀 Next Steps

With your HA cluster operational, you're ready for:

1. **Service Mesh**: Deploy Istio for advanced traffic management
2. **GitOps**: Install ArgoCD for continuous deployment  
3. **Secrets Management**: Deploy Vault for PKI and secrets
4. **Monitoring**: Add Prometheus and Grafana for observability
5. **Applications**: Deploy production workloads with HA guarantees

## 📋 Network Configuration

- **Virtual IP**: `192.168.1.100:6443` (HA API access)
- **Node IPs**: `192.168.1.80-82` (individual nodes)  
- **Pod CIDR**: `10.244.0.0/16` (Flannel)
- **Service CIDR**: `10.245.0.0/16` (cluster services)
- **SSH Access**: `~/.ssh/id_rsa` key with users `k8s_80-82`

The cluster provides true high availability with automatic failover and is ready for production workloads!