# Documentation Index

## Essential Guides

### 🚀 Getting Started
- **[Quick Start](quick-start.md)** - Deploy in 30 minutes
- **[Deployment Guide](deployment-guide.md)** - Comprehensive deployment reference
- **[Post-Config Steps](post-config-steps.md)** - Cluster access and validation

### 🏗️ Architecture & Reference  
- **[Cluster Architecture](cluster-architecture.md)** - Current design and evolution path
- **[SD Card Preparation](sd-card-preparation-and-testing.md)** - Hardware setup guide

### 📦 Service Deployment Guides
- **[ArgoCD Deployment](argocd-deployment.md)** - GitOps controller setup
- **[Vault Deployment](vault-deployment.md)** - PKI and secrets management
- **[Istio Setup](istio-deployment.md)** - Service mesh and zero-trust networking (Coming)

### 🔧 Operations
- **[Validation Guide](testing-plan.md)** - Health checks and performance testing
- **[Troubleshooting](troubleshooting-guide.md)** - Common issues and solutions
- **[Pi Node Reset Guide](pi-node-reset.md)** - Control plane node reset procedures

### 📚 Reference Documentation
- **[Playbook Structure](playbook-structure.md)** - Ansible automation overview
- **[CNI Strategy](cni-deployment-strategy.md)** - Networking approach
- **[Component Order](component-initialization-order.md)** - Initialization sequence
- **[Kubernetes Deployment Guide](kubernetes-deployment-guide.md)** - Detailed technical guide
- **[Raspberry Pi Optimizations](raspberry-pi-optimizations.md)** - Hardware-specific tuning

## Documentation Strategy

### Current Focus (Phase 2: Infrastructure Services)
All documentation reflects the **working deployment with infrastructure services**:

**Phase 1: Cluster Foundation** ✅ COMPLETE
1. `k8s-node1-deploy.yml` - Foundation cluster
2. `k8s-ha-expand.yml` - HA expansion with VIP failover
3. `k8s-post-config.yml` - Validation and browser access

**Phase 2: Infrastructure Services** ✅ IN-PROGRESS
- `k8s-argocd-deploy.yml` - GitOps controller (DEPLOYED)
- `k8s-vault-deploy.yml` - Vault HA cluster (DEPLOYING)
- `k8s-istio-deploy.yml` - Service mesh (PLANNED)

### Automation Philosophy
- **Pure Ansible**: All operations embedded in playbooks
- **No Manual Steps**: Complete infrastructure-as-code approach
- **Idempotent**: Safe to re-run all playbooks
- **Comprehensive Validation**: Each phase includes health checks

## Quick Navigation

**Just want to deploy?** → [Quick Start](quick-start.md)  
**Deploy ArgoCD?** → [ArgoCD Deployment](argocd-deployment.md)  
**Deploy Vault?** → [Vault Deployment](vault-deployment.md)  
**Need troubleshooting?** → [Troubleshooting Guide](troubleshooting-guide.md)  
**Want to reset nodes?** → [Pi Node Reset Guide](pi-node-reset.md)  
**Setting up hardware?** → [SD Card Preparation](sd-card-preparation-and-testing.md)  

## Success Criteria

✅ **Phase 1 Complete When:**
- 3 nodes show `Ready` status
- VIP (192.168.1.100) responds to kubectl
- Browser access works: http://192.168.1.80:30080
- All cluster validation tests pass

✅ **Phase 2 In Progress:**
- ArgoCD deployed and ready for GitOps management
- Vault HA cluster initializing for secrets and PKI
- Istio service mesh deployment planned

Your cluster is evolving toward enterprise-grade security and automation!