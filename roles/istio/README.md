# Istio Service Mesh Ansible Role

Deploy production-ready Istio service mesh for zero-trust networking, automatic mTLS, and advanced traffic management.

## Overview

This role automates the complete Istio service mesh deployment using Helm, following cloud-native best practices and optimized for Raspberry Pi resource constraints.

**Includes:**
- Istio base CRDs and webhooks
- istiod control plane (pilot, discoverer, configuration)
- Ingress gateway for external traffic
- Automatic sidecar injection webhooks
- Resource constraints for ARM64 nodes
- Vault PKI integration support

## Architecture

```
┌──────────────────────────────────────────┐
│      Istio Control Plane (istiod)        │
├──────────────────────────────────────────┤
│ • Pilot: Service discovery & routing     │
│ • Discoverer: Certificate distribution   │
│ • CA: mTLS certificate authority         │
└────────────┬─────────────────────────────┘
             │ Configuration
             │ Certificates
             │ Service Discovery
             │
        ┌────┴─────┐
        │           │
    ┌───▼───┐   ┌──▼────┐
    │ Envoy │   │ Envoy │  (Sidecars in pods)
    │ Proxy │   │ Proxy │   
    └───────┘   └───────┘
        │           │
    ┌───▼───────────▼───┐
    │   mTLS Encrypted  │
    │   Service-to-     │
    │   Service Comms   │
    └───────────────────┘
```

## Deployment Requirements

### Prerequisites
- Kubernetes cluster v1.20+ (tested on v1.31+)
- Helm v3 installed on control node
- At least 3 nodes Ready
- 2GB available memory on each node
- ArgoCD (recommended for application management)
- Vault HA (for PKI integration, optional for Phase 1)

### Resource Constraints
Configured for Raspberry Pi 4:
- Control plane: 100m/500m CPU, 128Mi/256Mi memory
- Sidecars: 50m/200m CPU, 128Mi/256Mi memory
- Ingress gateway: 100m/500m CPU, 128Mi/256Mi memory

## Default Configuration

```yaml
# Version
istio_version: "1.20.3"  # Stable ARM64 support

# Installation
istio_namespace: istio-system
istio_install_method: helm

# Components
istio_ingress_enabled: true
istio_egress_enabled: true
istio_pilot_replicas: 1

# Networking
istio_mtls_mode: STRICT  # Enforce mTLS everywhere

# Integration
vault_integration_enabled: false  # Enable after Vault PKI setup
```

## Deployment Instructions

### Quick Deploy

```bash
# Deploy Istio service mesh
cd /home/james/k8s_stuff/k8s_pi_cluster
ansible-playbook -i inventory.yml k8s-istio-deploy.yml
```

### What Gets Deployed

1. **Istio Base** - CRD webhooks and foundational resources
2. **istiod** - Control plane with pilot, discoverer, configuration
3. **Ingress Gateway** - External traffic entry point
4. **Sidecar Injector** - Auto-injects Envoy proxies into pods
5. **Trading Namespace** - Created with auto-sidecar injection enabled

### Verification

```bash
# Check pods
kubectl get pods -n istio-system

# Check services
kubectl get svc -n istio-system

# Verify CRDs
kubectl get crd | grep istio

# Check sidecar injector
kubectl get validatingwebhookconfigurations
```

## Post-Deployment Configuration

### 1. Enable Sidecar Injection for Namespaces

```bash
# Enable for trading namespace (already done by role)
kubectl label namespace trading istio-injection=enabled

# Enable for other namespaces
kubectl label namespace <namespace> istio-injection=enabled
```

### 2. Deploy Test Service with Sidecar

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-app
  namespace: trading
  labels:
    app: test
spec:
  containers:
  - name: app
    image: nginx
    ports:
    - containerPort: 80
```

Verify sidecars injected:
```bash
kubectl get pods -n trading test-app -o jsonpath='{.spec.containers[*].name}'
# Expected output includes: istio-proxy
```

### 3. Create Gateway & VirtualService for External Access

```yaml
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
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: trading-app
  namespace: trading
spec:
  hosts:
  - "*"
  gateways:
  - trading-gateway
  http:
  - route:
    - destination:
        host: trading-app-service
        port:
          number: 80
```

### 4. Enforce Zero-Trust with AuthorizationPolicy

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: trading-agent-policy
  namespace: trading
spec:
  selector:
    matchLabels:
      app: trading-agent
  action: ALLOW
  rules:
  # Allow traffic from ArgoCD namespace
  - from:
    - source:
        namespaces: ["argocd"]
  # Allow Prometheus scraping
  - from:
    - source:
        principals: ["cluster.local/ns/istio-system/sa/prometheus"]
    to:
    - operation:
        ports: ["8888"]  # metrics port
```

## mTLS Configuration

### Default Behavior (Post-Deployment)

By default, Istio uses **STRICT mTLS** everywhere:
- All service-to-service traffic encrypted with mTLS
- Certificates automatically generated by Istio CA
- Certificates rotated hourly (default)
- Mutual authentication required

### Check mTLS Status

```bash
# See PeerAuthentication resources
kubectl get peerauthentication -n <namespace>

# View certificate details
kubectl exec <pod> -c istio-proxy -- openssl s_client -connect <service>:443

# Monitor with Kiali (after deployment)
kubectl port-forward -n istio-system svc/kiali 20000:20000
# Visit: http://localhost:20000
```

### Disable mTLS for Specific Services (if needed)

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: legacy-service-permissive
  namespace: trading
spec:
  selector:
    matchLabels:
      legacy: "true"
  mtls:
    mode: PERMISSIVE
```

## Vault PKI Integration

### When Ready (After Vault Initialization)

1. Create Vault intermediate CA for Istio:
```bash
# In Vault pod
vault secrets enable pki_int
vault write pki_int/intermediate/generate/internal \
  common_name="Istio Intermediate CA" \
  ttl=8760h
```

2. Enable integration in defaults:
```yaml
vault_integration_enabled: true
vault_namespace: vault
```

3. Redeploy:
```bash
ansible-playbook -i inventory.yml k8s-istio-deploy.yml
```

## Troubleshooting

### Pods not getting sidecars injected

```bash
# Check namespace label
kubectl get namespace trading --show-labels
# Should show: istio-injection=enabled

# Check webhook
kubectl get validatingwebhookconfigurations
kubectl describe validatingwebhookconfigurations istiod-istio-system

# Check webhook logs
kubectl logs -n istio-system -l app=istiod -c discovery --tail=50
```

### High CPU/Memory usage

The Istio defaults in this role are optimized for Raspberry Pi:
- Pilot replicas: 1
- Resource requests/limits set low (100m/500m CPU, 128/256Mi memory)
- If experiencing issues, consider:
  - Increasing timeouts
  - Reducing number of sidecar injector replicas
  - Scaling back to 1 control plane pod

### mTLS errors between services

```bash
# Verify both services have sidecars
kubectl get pods -n trading -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Check AuthorizationPolicy
kubectl get authorizationpolicies -n trading
kubectl describe authorizationpolicies -n trading <name>

# Verify mutual authentication works
kubectl get peerauthentications -n trading
```

### Gateway not receiving traffic

```bash
# Check gateway service
kubectl get svc -n istio-system istio-ingressgateway
# Note the EXTERNAL-IP (if any) or use port-forward

# Test with port-forward
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
curl http://localhost:8080/

# Verify VirtualService
kubectl get virtualservices -n trading
kubectl describe virtualservice -n trading <name>
```

## Observability (Next Steps)

After Istio is running, deploy observability stack:

```bash
# Kiali - Service mesh visualization
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# Prometheus - Metrics collection
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

# Grafana - Metrics dashboards
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml

# Jaeger - Distributed tracing
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
```

Access dashboards:
```bash
# Kiali
kubectl port-forward -n istio-system svc/kiali 20000:20000
# http://localhost:20000

# Grafana
kubectl port-forward -n istio-system svc/grafana 3000:3000
# http://localhost:3000 (admin/admin)

# Jaeger
kubectl port-forward -n istio-system svc/jaeger 16686:16686
# http://localhost:16686
```

## Advanced Configuration

### Enable Egress Gateway (for external services)

```bash
# In role defaults
istio_egress_enabled: true

# Then redeploy
ansible-playbook -i inventory.yml k8s-istio-deploy.yml
```

### Circuit Breaking

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: circuit-breaker
  namespace: trading
spec:
  host: trading-agent-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 100
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```

### Request Routing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: trading-canary
  namespace: trading
spec:
  hosts:
  - trading-agent-service
  http:
  - match:
    - uri:
        prefix: /api/v2
    route:
    - destination:
        host: trading-agent-service
        subset: v2
  - route:
    - destination:
        host: trading-agent-service
        subset: v1
      weight: 90
    - destination:
        host: trading-agent-service
        subset: v2
      weight: 10
```

## Links

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Architecture](https://istio.io/latest/docs/ops/deployment/architecture/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Service Mesh Interface (SMI)](https://smi-spec.io/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

## Support

For issues or questions:
1. Check [Istio documentation](https://istio.io)
2. Review cluster logs: `kubectl logs -n istio-system -l app=istiod`
3. Use `istioctl analyze` for configuration validation
4. Check [Troubleshooting Guide](../troubleshooting-guide.md)
