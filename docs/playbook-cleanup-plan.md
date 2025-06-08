# Playbook Analysis and Cleanup Plan

## Essential Playbooks (Keep)

1. **k8s-cluster-deploy.yml**
   - Main deployment playbook that orchestrates the entire cluster setup

2. **deploy-infrastructure.yml**
   - Deploys core infrastructure components (ArgoCD, Ingress, Cert-Manager)

3. **playbooks/cleanup-cluster.yml**
   - Essential for resetting the cluster when needed

4. **playbooks/fix-control-plane.yml**
   - Important for troubleshooting control plane join issues

5. **playbooks/os-prep.yml**
   - Used by k8s-cluster-deploy.yml for OS preparation

6. **playbooks/container-runtime.yml**
   - Used by k8s-cluster-deploy.yml for container runtime setup

7. **playbooks/cni-plugin.yml**
   - Used for CNI plugin installation

## Playbooks to Remove (Redundant or Incorporated)

1. **k8s-cluster-init.yml**
   - Redundant as functionality is incorporated into k8s-cluster-deploy.yml

2. **k8s-setup.yml**
   - Redundant with k8s-cluster-deploy.yml

3. **k8s-worker-setup.yml**
   - Redundant as worker setup is part of k8s-cluster-deploy.yml

4. **main-k8s-deploy.yml**
   - Redundant with k8s-cluster-deploy.yml

5. **flannel-test.yml**
   - Testing playbook, not part of the main deployment

6. **playbooks/join-control-plane.yml**
   - Functionality incorporated into k8s-cluster-deploy.yml

7. **playbooks/join-single-control-plane.yml**
   - Redundant with other playbooks

8. **playbooks/first-control-plane.yml**
   - Functionality incorporated into k8s-cluster-deploy.yml

9. **playbooks/execute-join.yml**
   - Functionality incorporated into k8s-cluster-deploy.yml

10. **playbooks/network-infra.yml**
    - Functionality incorporated into k8s-cluster-deploy.yml

11. **playbooks/port-configuration.yml**
    - Functionality incorporated into k8s-cluster-deploy.yml

12. **playbooks/ha-control-plane.yml**
    - Functionality incorporated into k8s-cluster-deploy.yml

13. **playbooks/deploy-cluster.yml**
    - Redundant with k8s-cluster-deploy.yml

## Shell Scripts to Clean Up

Already removed:
1. cleanup-k8s.sh
2. deploy-ha-control-plane.sh
3. deploy.sh
4. fix-control-plane-join.sh

## Cloud-Init Script (Keep)

- **cloud-init/generate-configs.sh**
  - Essential for generating the initial SD card configurations
