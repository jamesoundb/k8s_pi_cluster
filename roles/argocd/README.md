# ArgoCD Role

Ansible role for deploying ArgoCD (GitOps controller) to a Kubernetes cluster.

## Overview

This role installs and configures ArgoCD on your Kubernetes cluster, enabling GitOps-based deployment management. ArgoCD watches Git repositories and automatically syncs the desired state to your cluster.

## Role Structure

```
roles/argocd/
├── defaults/main.yml     # Default variables (version, namespace, configuration)
├── tasks/main.yml        # Installation and configuration tasks
└── templates/            # Optional: Helm values templates
```

## Key Features

- ✅ **GitOps Ready**: Manages Kubernetes resources from Git repositories
- ✅ **HA Configuration**: Multi-replica deployments for high availability
- ✅ **Secure by Default**: HTTPS enabled, admin password protected
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Comprehensive Verification**: Waits for all components to be ready

## Usage

### Basic Deployment

```bash
# Run the dedicated ArgoCD playbook
ansible-playbook -i inventory.yml k8s-argocd-deploy.yml
```

### Or inline in another playbook

```yaml
- hosts: k8s_master_init
  roles:
    - role: argocd
```

## Configuration

Edit variables in `defaults/main.yml` or override via playbook vars:

```yaml
- hosts: k8s_master_init
  vars:
    argocd_namespace: argocd
    argocd_version: v2.10.0
    argocd_server_insecure: false
  roles:
    - role: argocd
```

## What Gets Deployed

1. **ArgoCD Namespace**: `argocd` (configurable)
2. **Controllers**:
   - argocd-server (API + web UI)
   - argocd-repo-server (Git repository polling)
   - argocd-application-controller (GitOps synchronization engine)
3. **Supporting Services**:
   - argocd-redis (application state caching)
   - argocd-metrics (Prometheus metrics)

## Accessing ArgoCD

### Web UI

```bash
# Port-forward to local machine
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Visit: https://localhost:8080
# Username: admin
# Password: (get from secret below)
```

### Get Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### CLI Access

```bash
# Install ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/v2.10.0/argocd-linux-amd64
chmod +x argocd

# Login
./argocd login localhost:8080 --username admin --password <password>

# List applications
./argocd app list
```

## Configuring Git Repositories

For **private** repositories, create a secret:

```bash
# SSH key
kubectl create secret generic argocd-repo-creds \
  --from-file=ssh-privatekey=~/.ssh/id_rsa \
  -n argocd

# Or HTTPS credentials
kubectl create secret generic argocd-repo-creds \
  --from-literal=username=<username> \
  --from-literal=password=<token> \
  -n argocd
```

For **public** repositories, no credentials needed!

## Creating Applications

Create a `trading-agent-application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: trading-agent
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/trading-agent-gitops.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: trading
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
```

Apply it:

```bash
kubectl apply -f trading-agent-application.yaml
```

## Monitoring

### Check Status

```bash
# View all applications
kubectl get applications -n argocd

# View application details
kubectl describe application trading-agent -n argocd

# Check sync status
argocd app get trading-agent
```

### View Logs

```bash
# ArgoCD server logs
kubectl logs -f -n argocd deployment/argocd-server

# Repo server logs
kubectl logs -f -n argocd deployment/argocd-repo-server

# Application controller logs
kubectl logs -f -n argocd statefulset/argocd-application-controller
```

## Troubleshooting

### Pods Not Ready

```bash
# Check pod events
kubectl describe pod -n argocd <pod-name>

# Check logs
kubectl logs -n argocd <pod-name>
```

### Application Won't Sync

```bash
# Check application status
kubectl describe application trading-agent -n argocd

# Check controller logs
kubectl logs -f -n argocd statefulset/argocd-application-controller
```

### Cannot Access Git Repository

```bash
# Verify credentials secret exists
kubectl get secret -n argocd argocd-repo-creds

# Test connectivity
kubectl exec -it -n argocd <repo-server-pod> -- bash
# Then test git clone in the container
```

## Security Considerations

1. **Change Admin Password**: First login, change default password
2. **RBAC**: Configure role-based access control for users
3. **Private Repos**: Use sealed-secrets or similar for credentials
4. **Network Policies**: Restrict ArgoCD pod-to-pod communication
5. **TLS**: Enable TLS for web UI (set `argocd_tls_enabled: true`)

## Resource Usage

Default requests/limits are optimized for Raspberry Pi:

```yaml
server:
  requests: 128Mi memory, 100m CPU
  limits: 512Mi memory, 500m CPU
  
controller:
  requests: 256Mi memory, 100m CPU
  limits: 1Gi memory, 500m CPU
  
repo_server:
  requests: 128Mi memory, 100m CPU
  limits: 512Mi memory, 500m CPU
```

Adjust in `defaults/main.yml` for different cluster sizes.

## Related Documentation

- [Trading Agent GitOps Repository](https://github.com/yourusername/trading-agent-gitops)
- [ArgoCD Official Documentation](https://argo-cd.readthedocs.io)
- [Kubernetes Deployment Strategy](../../KUBERNETES_DEPLOYMENT.md)

## Next Steps

1. Deploy ArgoCD using this role: `ansible-playbook -i inventory.yml k8s-argocd-deploy.yml`
2. Create Kubernetes secret with trading credentials
3. Create Application from trading-agent-gitops repository
4. Monitor deployment: `kubectl logs -f -n argocd -l app.kubernetes.io/name=argocd-server`
