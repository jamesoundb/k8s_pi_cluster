# Documentation Index

## Essential Guides

### 🚀 Getting Started
- **[Quick Start](quick-start.md)** - Deploy in 30 minutes
- **[Deployment Guide](deployment-guide.md)** - Comprehensive deployment reference
- **[Post-Config Steps](post-config-steps.md)** - Cluster access and validation

### 🏗️ Architecture & Reference  
- **[Cluster Architecture](cluster-architecture.md)** - Current design and evolution path
- **[SD Card Preparation](sd-card-preparation-and-testing.md)** - Hardware setup guide

### 🔧 Operations
- **[Validation Guide](testing-plan.md)** - Health checks and performance testing
- **[Troubleshooting](troubleshooting-guide.md)** - Common issues and solutions

### 📚 Reference Documentation
- **[Playbook Structure](playbook-structure.md)** - Ansible automation overview
- **[CNI Strategy](cni-deployment-strategy.md)** - Networking approach
- **[Component Order](component-initialization-order.md)** - Initialization sequence
- **[Kubernetes Deployment Guide](kubernetes-deployment-guide.md)** - Detailed technical guide
- **[Raspberry Pi Optimizations](raspberry-pi-optimizations.md)** - Hardware-specific tuning

## Documentation Strategy

### Current Focus
All documentation reflects the **working 3-phase deployment**:
1. `k8s-node1-deploy.yml` - Foundation cluster
2. `k8s-ha-expand.yml` - HA expansion with VIP failover
3. `k8s-post-config.yml` - Validation and browser access

### Automation Philosophy
- **Pure Ansible**: All operations embedded in playbooks
- **No Manual Steps**: Complete infrastructure-as-code approach
- **Idempotent**: Safe to re-run all playbooks
- **Comprehensive Validation**: Each phase includes health checks

## Quick Navigation

**Just want to deploy?** → [Quick Start](quick-start.md)  
**Need troubleshooting?** → [Troubleshooting Guide](troubleshooting-guide.md)  
**Want architecture details?** → [Cluster Architecture](cluster-architecture.md)  
**Setting up hardware?** → [SD Card Preparation](sd-card-preparation-and-testing.md)  

## Success Criteria

✅ **Deployment Complete When:**
- 3 nodes show `Ready` status
- VIP (192.168.1.100) responds to kubectl
- Browser access works: http://192.168.1.80:30080
- All validation tests pass

Your cluster is production-ready and follows cloud-native best practices!