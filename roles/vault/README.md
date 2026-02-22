# Vault HA Role

Ansible role for deploying HashiCorp Vault HA cluster to Kubernetes with Integrated Storage (Raft backend).

## Overview

This role deploys a production-ready Vault HA cluster using:
- **3 replicas** (one per control plane node) for high availability
- **Integrated Storage** (Raft) - no external database needed
- **Kubernetes auth** for workload authentication
- **AppRole** for automated access patterns
- **Persistent storage** with local-storage class

## Architecture

```
Vault HA Deployment on Control Plane:
├── vault-0 (Primary)
├── vault-1 (Secondary) 
└── vault-2 (Secondary)

All nodes share Raft-based storage
Single virtual service endpoint: vault.vault:8200
```

## Usage

### Deploy Vault

```bash
ansible-playbook -i inventory.yml k8s-vault-deploy.yml
```

### Or inline in another playbook

```yaml
- hosts: k8s_master_init
  roles:
    - role: vault
```

## Key Features

- ✅ **Auto HA**: Raft consensus across 3 pods
- ✅ **No external DB**: Integrated storage included
- ✅ **Kubernetes native**: Uses pods with persistent volumes
- ✅ **Kubernetes auth**: Service accounts authenticate to Vault
- ✅ **Secure defaults**: HTTPS, resource limits, RBAC
- ✅ **Idempotent**: Safe to re-run

## Configuration

Default settings in `defaults/main.yml`:

```yaml
vault_version: "1.16.0"
vault_namespace: vault
vault_replicas: 3
vault_replica_size: "10Gi"
vault_ui_enabled: true
```

Override in playbook:

```yaml
- hosts: k8s_master_init
  vars:
    vault_version: "1.16.0"
    vault_replicas: 3
  roles:
    - role: vault
```

## What Gets Deployed

1. **Vault Namespace**: `vault`
2. **Vault StatefulSet**: 3 replicas with Raft storage
3. **Persistent Volumes**: 10Gi per pod (configurable)
4. **Services**:
   - `vault` - Main Vault API service
   - `vault-ui` - Web UI service
5. **Storage Class**: `local-storage` for PVC provisioning

## Accessing Vault

### Web UI

```bash
kubectl port-forward -n vault svc/vault 8200:8200
# https://localhost:8200
```

### CLI Access

```bash
# Inside cluster
kubectl exec -it -n vault vault-0 -- vault status

# From local machine
export VAULT_ADDR=http://127.0.0.1:8200
vault login -method=kubernetes path=auth/kubernetes role=trading-agent
```

### In-cluster Service

From pods in the cluster:
```
http://vault.vault:8200
https://vault.vault:8200
```

## Security

### Initialization & Unsealing

**First time setup:**

```bash
# Initialization creates keys and root token
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=3 \
  -key-threshold=2

# Unsealing (requires 2 of 3 keys)
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
```

**Storage location:** `/tmp/vault-keys.json` on control node
⚠️ **CRITICAL**: Save these keys to secure, offline storage!

### Kubernetes Auth Method

Enable service accounts to authenticate to Vault:

```bash
vault auth enable kubernetes

vault write auth/kubernetes/config \
  kubernetes_host="$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
```

### Policies

Create policy for trading agent:

```hcl
# trading-agent-policy.hcl
path "secret/data/trading/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/trading/*" {
  capabilities = ["list", "read"]
}

path "pki_int/issue/trading-agent" {
  capabilities = ["create", "update"]
}
```

Apply policy:

```bash
vault policy write trading-agent trading-agent-policy.hcl
```

### AppRole for Automated Access

For non-human clients (trading agent):

```bash
# Enable AppRole auth
vault auth enable approle

# Create AppRole
vault write auth/approle/role/trading-agent \
  token_policies="trading-agent" \
  token_ttl=1h \
  token_max_ttl=4h

# Get role ID and secret ID
vault read auth/approle/role/trading-agent/role-id
vault write -f auth/approle/role/trading-agent/secret-id
```

## PKI Setup (for Certificates)

### Create Root CA

```bash
vault secrets enable pki

vault write -field=certificate pki/root/generate/internal \
  common_name="Trading System Root CA" \
  ttl=87600h

vault write pki/config/urls \
  issuing_certificates="https://vault.vault:8200/v1/pki/ca" \
  crl_distribution_points="https://vault.vault:8200/v1/pki/crl"
```

### Create Intermediate CA

```bash
vault secrets enable -path=pki_int pki

vault write -format=json pki_int/intermediate/generate/internal \
  common_name="Trading System Intermediate CA" \
  | jq -r .data.csr > pki_intermediate.csr

# Sign with root
vault write -format=json pki/root/sign-intermediate \
  csr=@pki_intermediate.csr \
  | jq -r .data.certificate > intermediate.cert.pem

# Import signed cert
vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem
```

## Monitoring & Maintenance

### Check Vault Status

```bash
kubectl exec -n vault vault-0 -- vault status
kubectl exec -n vault vault-0 -- vault operator raft list-peers
```

### Backup Raft Storage

```bash
kubectl exec -n vault vault-0 -- vault operator raft snapshot save backup.snap
kubectl cp vault/vault-0:backup.snap ./backup.snap
```

### View Audit Log

```bash
vault audit list
vault audit enable file file_path=/vault/logs/audit.log
```

## Troubleshooting

### Pods not starting

```bash
kubectl describe pod -n vault vault-0
kubectl logs -n vault vault-0
```

### Vault not unsealing automatically

Vault does NOT auto-unseal when pods restart. Manual unsealing required:

```bash
# Check if sealed
kubectl exec -n vault vault-0 -- vault status

# If sealed, unseal manually
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
```

### Storage issues

```bash
kubectl describe pvc -n vault
kubectl get pv
kubectl logs -n vault vault-0 | grep -i storage
```

### Authentication issues

```bash
vault auth list
vault auth show kubernetes
vault write auth/kubernetes/config ...
```

## Integration with Trading Agent

### Using Vault for Secrets

In your trading agent pod:

```yaml
# Pod spec with Vault agent injector
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/agent-inject-secret-trading: "secret/data/trading/credentials"
    vault.hashicorp.com/agent-inject-template-trading: |
      {{- with secret "secret/data/trading/credentials" -}}
      export SCHWAB_API_KEY="{{ .Data.data.schwab_key }}"
      {{- end }}
    vault.hashicorp.com/role: "trading-agent"
```

### Direct API Access

```bash
# From trading agent pod
curl --request POST \
  --data '{"jwt": "'$JWT'", "role": "trading-agent"}' \
  http://vault.vault:8200/v1/auth/kubernetes/login

# Retrieve secrets
curl -H "X-Vault-Token: $VAULT_TOKEN" \
  http://vault.vault:8200/v1/secret/data/trading/credentials
```

## Related Documentation

- [ArgoCD Deployment](argocd-deployment.md)
- [Kubernetes Deployment Strategy](../../KUBERNETES_DEPLOYMENT.md)
- [Vault Official Docs](https://www.vaultproject.io/docs)

## Next Steps

1. Deploy Vault: `ansible-playbook -i inventory.yml k8s-vault-deploy.yml`
2. Initialize and unseal Vault (manual one-time process)
3. Configure Kubernetes auth method
4. Create policies for trading agent
5. Deploy Istio service mesh for mTLS
6. Configure trading agent to use Vault for secrets
