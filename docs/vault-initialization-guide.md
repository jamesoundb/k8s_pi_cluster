# Vault HA Initialization & Configuration Guide

**Status**: Vault deployment in progress - storage directories now created via Kubernetes

---

## Overview

This guide covers the complete Vault HA cluster initialization, unsealing, and PKI configuration process. All operations are automated through Ansible playbooks following infrastructure-as-code principles.

---

## Phase 1: Vault Deployment Status

### Current State (Feb 21, 2026)

```
✅ Vault namespace created (vault)
✅ Storage class configured (local-storage)
✅ PersistentVolumes created on all 3 worker nodes (10Gi each)
✅ /mnt/vault-data directories prepared via Kubernetes debug pods
✅ Vault pods being created (3x StatefulSet)
✅ Vault Agent Injector deployed (for secrets injection)
```

### Expected Timeline

- **Pod Startup**: 2-3 minutes (container creation + init)
- **Readiness Probe**: Checks seal status every 5 seconds
- **Initialization**: Automatic (3 unseal keys, 2-of-3 threshold)
- **Auto-Unsealing**: Triggered once keys extracted
- **Total Time**: ~10-15 minutes from pod creation to Ready state

---

## Phase 2: Vault Pod Readiness (Automated)

### What the Playbook Does

The `k8s-vault-deploy.yml` playbook automatically:

1. **Creates PVs & PVCs** - Persistent storage for Raft backend
2. **Waits for Pod Readiness** - Monitors vault status via readiness probe
3. **Initializes Vault** - Generates 3 unseal keys (2-of-3 threshold)
4. **Extracts Keys** - Saves to `/tmp/vault-keys.json` on control plane
5. **Auto-Unseals** - Uses extracted keys to unseal all pods

### Monitoring Deployment

```bash
# Watch Vault pods come up
watch kubectl get pods -n vault -o wide

# Check PVC binding
kubectl get pvc -n vault

# View Vault pod logs (once Running)
kubectl logs -n vault vault-0

# Check seal status
kubectl exec -it -n vault vault-0 -- vault status -tls-skip-verify
```

---

## Phase 3: Manual Key Backup (CRITICAL)

**⚠️ IMPORTANT**: After initialization completes, keys are at `/tmp/vault-keys.json` on control plane.

### Extract and Secure Keys

```bash
# Connect to control plane and retrieve initialization output
cat /tmp/vault-keys.json | jq .

# Expected format:
{
  "keys": ["key1_b64", "key2_b64", "key3_b64"],
  "keys_base64": ["key1_b64", "key2_b64", "key3_b64"],
  "root_token": "hvs.xxxxxxxxxxxx",
  "unseal_keys_b64": ["key1_b64", "key2_b64", "key3_b64"],
  "unseal_keys_hex": ["key1_hex", "key2_hex", "key3_hex"]
}
```

### Save to Secure Offline Storage

1. **Extract Root Token**: Write to encrypted password manager / offline storage
2. **Extract Unseal Keys**: Save 2 keys separately (encrypted, offline)
3. **Keep Keys Separated**: Don't store all keys in one location
4. **Verify Access**: Ensure you can recover at least 2 keys for emergency unsealing

---

## Phase 4: Vault PKI Configuration

### Goal
Create Vault PKI intermediate CA for Istio mTLS certificate lifecycle.

### Prerequisites Checklist

- [ ] Vault pods all Running (1/1 Ready)
- [ ] All pods show sealed=false (`vault status` shows `Sealed: false`)
- [ ] Root token available
- [ ] Keys stored securely offline

### Configuration Steps

#### Step 1: Connect to Vault

```bash
# Port-forward to Vault API
kubectl port-forward -n vault vault-0 8200:8200 &

# Or use in-cluster access via service
VAULT_ADDR="http://vault.vault.svc.cluster.local:8200"
VAULT_TOKEN="<root-token-here>"
export VAULT_ADDR VAULT_TOKEN

# Verify status
vault status
```

#### Step 2: Enable PKI Secrets Engine

```bash
# Enable PKI at /pki path
vault secrets enable pki

# Configure max TTL (10 years)
vault secrets tune -max-lease-ttl=87600h pki

# Generate root CA
vault write -field=certificate pki/root/generate/internal \
  common_name="Kubernetes Root CA" \
  ttl=87600h > /tmp/root_ca.crt

# Configure CA issuing URL
vault write pki/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/pki/crl"
```

#### Step 3: Create Intermediate CA for Istio

```bash
# Enable PKI at /pki_int path
vault secrets enable -path=pki_int pki

# Configure max TTL
vault secrets tune -max-lease-ttl=43800h pki_int

# Generate intermediate CSR
vault write -field=csr pki_int/intermediate/generate/internal \
  common_name="Istio Intermediate CA" \
  ttl=43800h > /tmp/pki_int.csr

# Sign CSR with root CA
vault write -field=certificate pki/root/sign-intermediate \
  csr=@/tmp/pki_int.csr \
  common_name="Istio Intermediate CA" \
  ttl=43800h > /tmp/intermediate.crt

# Set intermediate certificate
vault write pki_int/intermediate/set-signed \
  certificate=@/tmp/intermediate.crt

# Create role for Istio
vault write pki_int/roles/istio-ca \
  allowed_domains=istio,istio-system,vault,vault.vault.svc.cluster.local \
  allow_subdomains=true \
  generate_lease=true \
  max_ttl=720h
```

#### Step 4: Enable Kubernetes Authentication

```bash
# Enable kubernetes auth method
vault auth enable kubernetes

# Configure kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

# Create policy for Istio
cat > /tmp/istio-policy.hcl <<EOF
path "pki_int/sign/istio-ca" {
  capabilities = ["create", "update"]
}
path "pki_int/issue/istio-ca" {
  capabilities = ["create", "update"]
}
EOF

# Write policy
vault policy write istio-ca /tmp/istio-policy.hcl

# Configure kubernetes auth role for istio-system
vault write auth/kubernetes/role/istio-ca \
  bound_service_account_names=istiod \
  bound_service_account_namespaces=istio-system \
  policies=istio-ca \
  ttl=1h
```

---

## Phase 5: Istio-Vault Integration

### Configuration

Once Vault PKI is configured, enable Istio integration:

```bash
cd /home/james/k8s_stuff/k8s_pi_cluster

# Update Istio role defaults to enable Vault integration
cat > roles/istio/defaults/main.yml <<'EOF'
...
vault_integration_enabled: true
vault_pki_path: "pki_int"
vault_pki_role: "istio-ca"
vault_ca_cert: "secret/data/vault-ca-cert"
EOF

# Redeploy Istio with Vault integration
ansible-playbook -i inventory.yml k8s-istio-deploy.yml
```

### Verification

```bash
# Check Istio CA is using Vault
kubectl get issuers -n istio-system
kubectl describe issuer -n istio-system vault-pki

# Verify certificates are issued by Vault
kubectl get certs -A
kubectl describe cert -n istio-system istio-ca --all-namespaces
```

---

## Phase 6: Application Secret Injection

### Enable Vault Secrets Injection for Trading Agent

```bash
# Label trading namespace for secret injection
kubectl label namespace trading vault-injection=enabled

# Create Vault secret for trading agent
vault kv put secret/trading-agent \
  schwab-api-key="<api-key>" \
  schwab-oauth-token="<oauth-token>" \
  discord-webhook="<webhook-url>"

# Create Kubernetes auth role for trading agent
vault write auth/kubernetes/role/trading-agent \
  bound_service_account_names=trading-agent \
  bound_service_account_namespaces=trading \
  policies=trading-agent \
  ttl=1h

# Create policy
cat > /tmp/trading-agent-policy.hcl <<EOF
path "secret/data/trading-agent" {
  capabilities = ["read"]
}
EOF

vault policy write trading-agent /tmp/trading-agent-policy.hcl
```

### Deploy Trading Agent with Vault Injection

```bash
# Update trading-agent manifests to include Vault annotations
cat > manifests/trading-agent-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trading-agent
  namespace: trading
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "trading-agent"
        vault.hashicorp.com/agent-inject-secret-credentials: "secret/data/trading-agent"
        vault.hashicorp.com/agent-inject-template-credentials: |
          export SCHWAB_API_KEY="{{ .Data.data.schwab_api_key }}"
          export DISCORD_WEBHOOK="{{ .Data.data.discord_webhook }}"
EOF
```

---

## Troubleshooting

### Vault Pods Not Becoming Ready

```bash
# Check pod status
kubectl describe pod -n vault vault-0

# Check for mount errors
kubectl describe pod -n vault vault-0 | grep -A5 "Events:"

# Verify PVCs are bound
kubectl get pvc -n vault

# Fix: Create mount directories if missing
kubectl apply  -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: fix-mounts
  namespace: vault
spec:
  nodeName: k8s-worker-1
  hostNetwork: true
  containers:
  - name: fix
    image: busybox
    command: [mkdir, -p, /mnt/vault-data]
    volumeMounts:
    - name: host
      mountPath: /mnt
  volumes:
  - name: host
    hostPath:
      path: /mnt
EOF
```

### Vault Service Not Accessible

```bash
# Test within cluster
kubectl run -it --rm test --image=curlimages/curl /bin/sh
curl -sk https://vault.vault.svc.cluster.local:8200/v1/sys/health

# Port-forward for external access
kubectl port-forward -n vault svc/vault 8200:8200
# Then browse to: https://localhost:8200
```

### Initialization Output Not Saved

```bash
# Check if keys were created
kubectl logs -n vault vault-0 | grep -i "unseal\|root_token"

# Reinitialize if needed (loses all data!)
kubectl exec -it -n vault vault-0 -- vault operator init \
  -key-shares=3 \
  -key-threshold=2 \
  -format=json
```

---

## Next Steps

1. ✅ **Vault HA Deployment** - Current phase
2. ⏳ **Vault PKI Configuration** - Follow Phase 4 above
3. ⏳ **Istio-Vault Integration** - Follow Phase 5 above  
4. ⏳ **Trading Agent Deployment** - Follow Phase 6 above
5. ⏳ **Zero-Trust Networking** - AuthorizationPolicies
6. ⏳ **Observability Stack** - Kiali, Prometheus, Grafana

---

## References

- [Vault Operator Documentation](https://www.vaultproject.io/docs/commands/operator)
- [Vault PKI Secrets Engine](https://www.vaultproject.io/docs/secrets/pki)
- [Vault Kubernetes Auth](https://www.vaultproject.io/docs/auth/kubernetes)
- [Istio Certificate Authority Integration](https://istio.io/latest/docs/tasks/security/cert-management/vault-ca/)
- [Vault Agent Injector](https://www.vaultproject.io/docs/platform/k8s/injector)

