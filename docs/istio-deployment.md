# Istio Service Mesh Deployment

## Prerequisites

Before deploying Istio, ensure:

✅ **Cluster Foundation** - All nodes Ready  
✅ **ArgoCD Deployed** - GitOps controller operational  
✅ **Vault HA Deployed** - Initialization and unsealing complete  
✅ **Vault PKI Configured** - Intermediate CA established  

## Architecture Overview

```
┌─────────────────────────────────────────┐
│     Istio Control Plane (Control Pi)    │
│  ├─ istiod (pilot, discoverer, auth)   │
│  └─ Ingress Gateway                    │
└────────────┬────────────────────────────┘
             │
         Sidecar Injection
             │
    ┌────────┼────────┐
    │        │        │
  Service┌─────────┐ Service
  Mesh   │ Raft DB │ Mesh
    │    └─────────┘ │
    │                │
 ┌──────┐       ┌──────┐
 │Pod   │       │Pod   │
 │Sidecar       │Sidecar
 └──────┘       └──────┘

Data Plane:
- Envoy sidecars injected into pods
- mTLS between all services
- Traffic routing via Istio VirtualServices
- Policy enforcement via AuthorizationPolicy
```

## Deployment Plan

### Phase 1: Istio Installation (Automated via Ansible)

**Requirements:**
- istio namespace creation
- Istio Helm chart deployment
- Sidecar injector webhook setup
- Gateway and VirtualService resources for ingress

**Automation:**
- `k8s-istio-deploy.yml` - Complete Istio HA deployment
- Handles prerequisites and configuration
- Integrates with Vault PKI (TLS certs)

### Phase 2: Vault-Istio Integration

**Certificate Chain:**
```
Vault Root CA
    ↓
Vault Intermediate CA (for Istio)
    ↓
Istio CA ↔ Workload Certificates (auto-rotated)
    ↓
Service-to-Service mTLS
```

**Setup:**
- Configure Vault intermediate CA for Istio
- Enable certificate auto-rotation
- Validate mTLS between test services

### Phase 3: Application deployment with Istio

**Trading Agent Integration:**
- Annotations for sidecar injection
- VirtualService for traffic management
- AuthorizationPolicy for access control
- Observability dashboards (metrics, tracing, logs)

## Manual Deployment (Until Automation Ready)

### 1. Install Istio CLI
```bash
curl -L https://istio.io/downloadIstio | sh -
export PATH="$PATH:$(pwd)/istio-1.20/bin"
istioctl version
```

### 2. Deploy Istio with Helm

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

helm install istio-base istio/base \
  --namespace istio-system \
  --create-namespace

helm install istiod istio/istiod \
  --namespace istio-system \
  --values - <<EOF
global:
  logAsJson: true
pilot:
  autoscalingEnabled: true
  replicaCount: 1  # Pi resource constraints
EOF
```

### 3. Enable Sidecar Injection

```bash
kubectl label namespace trading istio-injection=enabled
```

### 4. Create Ingress Gateway

```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: trading-gateway
  namespace: trading
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
EOF
```

### 5. Configure Traffic Routing

```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: trading-agent
  namespace: trading
spec:
  hosts:
  - "*"
  gateways:
  - trading-gateway
  http:
  - route:
    - destination:
        host: trading-agent-service
        port:
          number: 8080
EOF
```

## Verification

### Check Istio Installation
```bash
kubectl get pods -n istio-system
kubectl get crd | grep istio
```

### Verify Sidecar Injection
```bash
kubectl get pods -n trading -o jsonpath='{.items[*].spec.containers[*].name}'
# Should show: trading-agent-container istio-proxy
```

### Test mTLS
```bash
# From one pod to another (should succeed)
kubectl exec <pod> -c trading-agent -- curl https://trading-agent-service:8080

# Without sidecar (should fail - mTLS enforced)
kubectl run test-pod --image=curlimages/curl -- sleep 3600
kubectl exec test-pod -- curl http://trading-agent-service:8080  # Should timeout
```

### View Observability

**Metrics (Prometheus/Grafana):**
- Service mesh traffic visualization
- Request rates, latencies, error rates
- Pod resource usage

**Tracing (Jaeger):**
- Distributed trace collection
- Service dependency graphs
- Request flow visualization

**Dashboard (Kiali):**
- Real-time service mesh visualization
- Traffic flows and error analysis
- Configuration validation

## Next Steps

1. ✅ Ensure Vault is fully initialized and unsealed
2. ⏳ Create Ansible playbook for automated Istio deployment
3. ⏳ Configure Vault intermediate CA for Istio
4. ⏳ Deploy trading agent with Istio sidecars
5. ⏳ Set up zero-trust NetworkPolicies
6. ⏳ Deploy observability stack (Prometheus, Grafana, Jaeger, Kiali)

## Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio & Vault Integration](https://istio.io/latest/docs/ops/integrations/vault/)
- [mTLS Concepts](https://istio.io/latest/docs/concepts/security/#mutual-tls)
- [AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/)

## Current Status

🟡 **Planning** - Waiting for Vault HA stabilization  
⏳ **Automation Ready When:**
- Vault full initialization and unsealing complete
- PKI intermediate CA created and tested
- Istio-Vault integration validated

Estimated Timeline: After successful Vault deployment and initialization
