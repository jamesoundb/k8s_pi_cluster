# Vault HA Deployment Quick Reference

## Architecture Overview

```
Trading System Security Stack

┌─────────────────────────────────────────┐
│     Vault HA (Control Plane)            │
│  ├─ vault-0 (Primary - Raft leader)    │
│  ├─ vault-1 (Secondary)                │
│  └─ vault-2 (Secondary)                │
└────────────┬────────────────────────────┘
             │ Integrated Storage (Raft)
         ┌───┴────────────────┐
         │  Shared State      │
         │  (Auto-replicated) │
         └───────────────────┘

Provides:
✅ PKI Root CA (for all certificates)
✅ Secret management (Schwab, Discord credentials)
✅ Dynamic credentials (AppRole for trading agent)
✅ Audit logging (compliance/investigation)
✅ High availability (survives node failures)
```

## Quick Start

```bash
# 1. Deploy Vault HA
cd /home/james/k8s_stuff/k8s_pi_cluster
ansible-playbook -i inventory.yml k8s-vault-deploy.yml

# This will take 5-10 minutes on Raspberry Pi
```

## Important: First-Time Setup (Manual)

After deployment, Vault is **sealed** and needs initialization:

```bash
# 1. Access pod
kubectl exec -it -n vault vault-0 -- sh

# 2. Initialize (creates unseal keys and root token)
vault operator init -key-shares=3 -key-threshold=2

# ⚠️ SAVE THE OUTPUT SOMEWHERE SECURE!
# This is a one-time output with:
# - 3 unseal keys (need 2 to unseal)
# - Root token (for admin access)

# 3. Unseal with 2 keys
vault operator unseal <KEY_1>
vault operator unseal <KEY_2>

# 4. Verify status
vault status
```

**CRITICAL:** Save the init output to secure, offline storage!

## Common Commands

### Access Vault

```bash
# Web UI
kubectl port-forward -n vault svc/vault 8200:8200
# Then: https://localhost:8200 (login with root token)

# External CLI
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=<your-root-token>
vault status

# From pod
kubectl exec -it -n vault vault-0 -- vault status
```

### Unseal if Restarted

```bash
# Check if sealed
kubectl exec -n vault vault-0 -- vault status | grep Sealed

# Unseal (need 2 keys)
kubectl exec -n vault vault-0 -- vault operator unseal <KEY_1>
kubectl exec -n vault vault-0 -- vault operator unseal <KEY_2>

# Verify all replicas unsealed
for pod in vault-{0,1,2}; do
  kubectl exec -n vault $pod -- vault status | grep Sealed
done
```

### Configure Kubernetes Auth

```bash
# Inside Vault pod
vault auth enable kubernetes

# Get Kubernetes API info (hardcode or use env vars)
vault write auth/kubernetes/config \
  kubernetes_host="https://192.168.1.100:6443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

# Verify
vault auth list
```

### Create Policies

```bash
# Create policy for trading agent
vault policy write trading-agent - <<EOF
path "secret/data/trading/*" {
  capabilities = ["read", "list"]
}
path "pki_int/issue/trading-agent" {
  capabilities = ["create", "update"]
}
EOF

# Verify
vault policy list
vault policy read trading-agent
```

### Set Up AppRole (for automated access)

```bash
# Enable AppRole
vault auth enable approle

# Create role for trading agent
vault write auth/approle/role/trading-agent \
  token_policies="trading-agent" \
  token_ttl=1h

# Get credentials for trading agent to use
ROLE_ID=$(vault read -field=role_id auth/approle/role/trading-agent/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/trading-agent/secret-id)

# Store these as Kubernetes secrets for trading agent
echo "ROLE_ID: $ROLE_ID"
echo "SECRET_ID: $SECRET_ID"
```

### Store Secrets

```bash
# Enable KV secrets
vault secrets enable -path=secret kv-v2

# Store trading credentials
vault kv put secret/trading/credentials \
  schwab_client_id="..." \
  schwab_client_secret="..." \
  discord_webhook_url="..."

# Verify
vault kv get secret/trading/credentials
```

### Setup PKI (for certificates)

```bash
# Enable PKI
vault secrets enable pki

# Create root CA
vault write -field=certificate pki/root/generate/internal \
  common_name="Trading System Root CA" \
  ttl=87600h > /tmp/ca.crt

# Enable intermediate CA
vault secrets enable -path=pki_int pki

# Full setup instructions in role README
```

## Deployment Timeline

1. **Deploy (5-10 min)**: Replicas start, raft consensus forms
2. **Init (1 min manual)**: Create unseal keys, root token
3. **Unseal (1 min manual)**: Provide 2 keys to unseal
4. **Config (5 min)**: Enable auth methods, policies, secrets
5. **Ready (0%Done → Full HA)**: All 3 replicas operational

## What's Next

1. ✅ Vault deployed and running
2. **Init + Unseal** (manual, one-time)
3. Configure Kubernetes auth
4. Store trading credentials
5. Deploy Istio service mesh
6. Configure trading agent to use Vault
7. Deploy trading agent via ArgoCD

## Monitoring

```bash
# Check pod status
kubectl get pods -n vault

# Check storage
kubectl get pvc -n vault

# View logs
kubectl logs -n vault vault-0
kubectl logs -n vault vault-1
kubectl logs -n vault vault-2

# Leadership status
kubectl exec -n vault vault-0 -- vault operator raft list-peers
```

## Security Best Practices

1. **Save keys**: `/tmp/vault-keys.json` → secure offline storage
2. **Rotate tokens**: Use temporary tokens, not root token for everything
3. **Audit logs**: Enable and monitor
4. **RBAC**: Limit policies to minimum required
5. **TLS**: Use mTLS between services (via Istio)
6. **Backup**: Regular Raft snapshots

## Troubleshooting

**Pods stuck in pending?**
```bash
kubectl describe pod -n vault vault-0
# Check storage class and PVC provisioning
```

**Can't unseal?**
```bash
# Verify keys are correct
# Try different 2 of 3 keys
# Check pod logs: kubectl logs -n vault vault-0
```

**Network issues?**
```bash
# Verify service DNS
kubectl exec -it -n vault vault-0 -- nslookup vault.vault
# Should resolve to vault service across all pods
```

## File Locations

- **Playbook**: `/home/james/k8s_stuff/k8s_pi_cluster/k8s-vault-deploy.yml`
- **Role**: `/home/james/k8s_stuff/k8s_pi_cluster/roles/vault/`
- **Init keys**: `/tmp/vault-keys.json` (save to secure location!)

## Related Documentation

- [Vault Role README](roles/vault/README.md)
- [ArgoCD Documentation](docs/argocd-deployment.md)
- [Cluster Architecture](docs/cluster-architecture.md)
