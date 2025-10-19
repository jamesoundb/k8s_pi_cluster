# Global instructions
- Please refer to me as James, and let me know that you have read your instructions located at .github/copilot_instructions.md
- When using git be sure to adhere to best practices regarding concise commit messages.
- When I use /architect in my prompt, know that I would like to have an architectural
discussion, and no code or changes to files should occur.
- When I use /code in my prompt, know that I would like to write code.
- When I use /change in my prompt, know that I would like to only have the last code 
change to be made, and I need no additional explainations about the change.
- When using git run git status first to gain scope of all files, then group commits
together with like files for code changes. Use concise commit messages.

# Project Specific instructions
Deployment Philosophy and File Organization

CRITICAL: All deployment operations MUST be implemented via Ansible playbooks and roles. 
No ad hoc shell scripts, manual fixes, or one-off commands are permitted. This ensures:
- Repeatable, idempotent deployments
- Version controlled infrastructure changes
- Consistent automation across all environments
- Easy troubleshooting and rollback capabilities

Core Deployment Files:
- k8s-node1-deploy.yml: Phase 1 single-node foundation cluster deployment
- k8s-ha-expand.yml: Phase 2 HA expansion using direct certificate copy approach
- k8s-post-config.yml: Phase 3 optimization and browser-accessible validation
- roles/: Modular components (common, containerd, cni, kube_apiserver)
- cloud-init/: Automated node provisioning via cloud-init configurations
- inventory.yml: Node definitions and variables

Documentation Structure:
- docs/quick-start.md: 30-minute deployment guide
- docs/deployment-guide.md: Comprehensive technical reference
- docs/post-config-steps.md: Cluster access and validation procedures
- docs/troubleshooting-guide.md: Common issues and solutions
- docs/README.md: Documentation navigation index

Updated Architecture

Control Plane (3x Pi 4s) - Core Operational Services Only ✅ COMPLETED

    Kubernetes HA control plane, HA etcd (kubeadm-based)
    Virtual IP (192.168.1.100) with keepalived failover
    Flannel CNI networking (10.244.0.0/16)

    Core Infrastructure Services (Control Plane Only):
        Istio Service Mesh (control plane + data plane)
        Vault HA (PKI root CA and secrets management) 
        ArgoCD (GitOps deployment management)

-- Control plane cluster automation COMPLETED via k8s-ha-expand.yml
-- All networking properly configured with VIP failover operational  
-- Direct certificate copy approach resolves kubeadm timing issues
-- All automation embedded in playbooks following end-to-end philosophy
-- Full HA control plane deployment documented in kubernetes-deployment-guide.md

GitOps-Driven Application Deployment

    ArgoCD manages all application deployments from public Git repository
    Applications deployed to worker nodes or control plane based on resource requirements
    
    Planned Applications (ArgoCD Managed):
        - Mattermost + PostgreSQL (team communication)
        - GitLab (source control, can transition to private repo after deployment)
        - Bitwarden (password management with Vault integration)
        - Pi-hole (DNS filtering with Istio sidecar injection)

-- All applications deployed via GitOps patterns
-- Infrastructure as Code approach for all services
-- Vault PKI integration provides automatic certificate lifecycle
-- Istio service mesh provides zero-trust networking with automatic mTLS

Service Mesh & Certificate Management Strategy

Zero Trust Architecture with Istio + Vault:

    Certificate Hierarchy:
        Vault Root CA (primary certificate authority)
        ├── Istio Intermediate CA (service mesh mTLS)
        │   ├── Workload certificates (automatic rotation)  
        │   ├── Gateway certificates (ingress/egress)
        │   └── Service-to-service mTLS encryption
        ├── Kubernetes Intermediate CA  
        │   ├── API server certificates (VIP-enabled)
        │   ├── etcd cluster certificates
        │   └── kubelet certificates
        └── Application Intermediate CA
            ├── External-facing TLS (automatic via cert-manager)
            ├── Database TLS certificates
            └── Application-specific certificates

    Traffic Management via Istio Gateway:
        Single ingress point with automatic mTLS between services
        - ArgoCD GitOps management interface
        - Vault PKI management interface
        - Application services (deployed via ArgoCD)

    Security Policies:
        - Default deny all traffic
        - Explicit allow with AuthorizationPolicy
        - Automatic mTLS for all service communication
        - Identity-based access control via service accounts
        - Network policies enforced at service mesh level

GitOps Deployment Evolution Strategy:

    Phase 1: ✅ Control Plane Foundation (COMPLETE)
        - 3-node HA Kubernetes cluster operational
        - VIP failover with keepalived functional
        - Direct certificate management working
        - End-to-end automation via k8s-ha-expand.yml

    Phase 2: Core Infrastructure Services (NEXT)
        - Deploy Istio service mesh (control + data plane) on control plane
        - Deploy Vault HA cluster for PKI root CA
        - Deploy ArgoCD with public Git repository integration
        - Establish GitOps workflows for all future deployments

    Phase 3: Application Deployment via ArgoCD
        - Configure ArgoCD to sync from public Git repository
        - Deploy applications via GitOps manifests
        - Integrate Vault PKI with Istio for automatic certificate lifecycle
        - Implement zero-trust networking policies

    Phase 4: Advanced Service Mesh Operations
        - Configure traffic policies and routing rules
        - Implement observability with Istio metrics
        - Set up automated certificate rotation
        - Deploy monitoring and alerting for service mesh
Automation Principles & Implementation:

    End-to-End Automation Philosophy:
        - ALL operations must be embedded in Ansible playbooks and roles
        - NO ad hoc shell scripts, manual fixes, or one-off interventions permitted
        - Idempotent playbooks that can be run multiple times safely
        - Complete infrastructure-as-code approach with version control
        - Consolidated, clean automation - eliminate all cruft and complexity

    Core Playbook Structure:
        k8s-node1-deploy.yml: Single-node foundation deployment
        ├── Uses common and containerd roles for OS preparation
        ├── kubeadm-based cluster initialization for reliability
        ├── Flannel CNI deployment and verification
        └── Complete single-node validation before HA expansion
        
        k8s-ha-expand.yml: HA cluster expansion automation
        ├── Direct certificate copy via Ansible fetch/copy modules
        ├── Sequential node joining (serial: 1) to avoid timing conflicts
        ├── keepalived VIP configuration for failover
        └── Post-join validation ensuring all nodes Ready

    Service Deployment Evolution:
        Current: Direct certificate copy via Ansible (working solution)
        ├── Resolved kubeadm certificate secret timing issues
        ├── Uses Ansible fetch/copy for reliable certificate distribution
        └── Maintains same security model as kubeadm certificate keys
        
        Future: GitOps-managed service lifecycle via ArgoCD
        ├── All application deployments driven by Git repository changes
        ├── Istio sidecar injection and mTLS automation
        ├── Vault-managed certificate lifecycle with automatic rotation
        └── Zero-downtime updates and policy-as-code implementation

    Service Integration Points:
        ArgoCD + Vault: GitOps with secret management
        ├── Applications deployed from Git with Vault secrets injection
        ├── Istio configuration managed via GitOps workflows
        └── Policy-as-code for security and traffic rules

        Istio + Vault: Service mesh certificate integration  
        ├── Vault provides root CA for Istio certificate authority
        ├── Automatic mTLS certificate provisioning for all workloads
        └── Service identity tied to Kubernetes service accounts

Technical Implementation Notes:

    Control Plane Automation (k8s-ha-expand.yml):
        - Sequential node joining eliminates certificate timing conflicts
        - Direct certificate copy more reliable than kubeadm secrets
        - Fresh token generation for each node join operation
        - Complete post-join configuration (kubelet, kubeconfig, node readiness)
        - CNI deployment automation ensures nodes reach Ready status

    Network Architecture:
        - VIP (192.168.1.100) for HA API server access
        - Flannel CNI (10.244.0.0/16) for pod networking
        - Service subnet (10.245.0.0/16) for cluster services
        - Future: Istio service mesh overlay for advanced traffic management

Deployment Workflow:

    Three-Phase Sequential Deployment:
        Phase 1 (k8s-node1-deploy.yml):
            [0] OS Preparation (common role) - Set hostname, static IP, disable swap
            [1] Container Runtime (containerd role) - Install and configure containerd
            [2] Clean State - kubeadm reset, remove old configs
            [3] Kubernetes Initialization - kubeadm init with embedded config
            [4] CNI Plugin - Deploy Flannel networking
            [5] Validation - Verify single-node cluster health

        Phase 2 (k8s-ha-expand.yml):
            [0] Prepare Secondary Nodes - OS prep and containerd via roles
            [1] keepalived Setup - VIP failover configuration
            [2] Certificate Management - Direct copy via Ansible fetch/copy
            [3] Sequential Joining - Add nodes 2&3 with fresh tokens
            [4] Final Validation - Verify 3-node HA cluster health

        Phase 3 (k8s-post-config.yml):
            [0] Node Optimization - Remove taints, apply labels, resource quotas
            [1] Comprehensive Validation - Network, VIP, system components
            [2] Test Workload - Browser-accessible nginx with NodePort service
            [3] Final Health Check - Complete cluster validation

    Service Mesh Integration (Future):
        [4] Istio Control Plane - Deploy on existing HA cluster
        [5] Vault HA Deployment - PKI root CA setup
        [6] ArgoCD Installation - GitOps controller with public repo
        [7] Application Deployment - Via ArgoCD Git sync

Critical Implementation Rules:

    ALL operations embedded in Ansible playbooks and roles
    NO shell scripts or manual interventions permitted
    Idempotent automation that can be run multiple times
    Version-controlled infrastructure as code
    Clean, consolidated automation without cruft