# Kubernetes Certificate Architecture

## Overview

This document explains the certificate trust chain and distribution strategy used in the hybrid Kubernetes cluster (3x Raspberry Pi control plane + 3x Proxmox worker nodes).

## Certificate Hierarchy

```
Kubernetes Cluster CA (generated during kubeadm init)
├── API Server Certificate
│   └── SANs (Subject Alternative Names) - CRITICAL FOR TRUST
│       ├── 192.168.1.100 (VIP for HA control plane)
│       ├── 192.168.1.80-82 (Control plane node IPs)
│       ├── 192.168.1.83-85 (Worker node IPs)
│       ├── k8s-node-1/2/3 (Control plane hostnames)
│       ├── k8s-worker-1/2/3 (Worker hostnames)
│       └── kubernetes DNS names
├── Service Account Certificates (sa.pub, sa.key)
├── Front Proxy CA Certificates
├── Kubelet Certificates (per node)
└── etcd Certificates
    ├── etcd server certs
    ├── etcd peer certs
    └── etcd healthcheck certs
```

## Why Certificate SANs Matter

Kubernetes uses TLS certificate validation to authenticate:

1. **Control Plane → API Server**: kubectl commands, kubelet registration
2. **Control Plane → Kubelet**: `kubectl exec`, `kubectl logs`, pod management
3. **Kubelet → API Server**: kubelet startup, pod status updates
4. **Node-to-Node Communication**: flanneld, service mesh (Istio)

**Without proper SANs**, the control plane cannot:
- Execute commands on worker nodes (`kubectl exec`)
- Query kubelet logs (`kubectl logs`)
- Access pod metrics
- Properly manage workloads on worker nodes

## Certificate Distribution Strategy

### For Control Plane Nodes (k8s-ha-expand.yml)

The **direct certificate copy approach** ensures HA control plane nodes trust each other:

```yaml
# Phase 4: Secondary control plane node joining
- Fetch CA certificates from primary node:
  - /etc/kubernetes/pki/ca.crt (cluster CA)
  - /etc/kubernetes/pki/ca.key (CA private key)
  - /etc/kubernetes/pki/sa.pub/.key (service account)
  - /etc/kubernetes/pki/front-proxy-ca.* (proxy certificates)
  - /etc/kubernetes/pki/etcd/ca.* (etcd certificates)

- Copy to secondary node before kubeadm join
- This ensures all control plane nodes have the same CA
- Kubelet certificates are auto-generated during kubeadm join
- All certificates signed with the same CA = mutual trust
```

### For Worker Nodes (k8s-workers-join.yml)

Worker nodes require the **same certificate distribution** as control plane nodes:

```yaml
# Phase 3: Certificate distribution to worker nodes
- Fetch the same CA certificates from control plane:
  - /etc/kubernetes/pki/ca.crt
  - /etc/kubernetes/pki/ca.key
  - /etc/kubernetes/pki/sa.pub/.key
  - /etc/kubernetes/pki/front-proxy-ca.*
  - /etc/kubernetes/pki/etcd/ca.*

- Copy to worker node
- kubeadm join generates:
  - /etc/kubernetes/kubelet.conf (kubeconfig for kubelet)
  - /var/lib/kubelet/pki/kubelet-client-current.pem (kubelet cert pair)
  - Both signed with the cluster's CA

- Result: Control plane trusts worker node kubelets
```

## Deployment Workflow

### Phase 1: Initial Control Plane (k8s-node1-deploy.yml)

```
kubeadm init
├── Generates cluster CA in /etc/kubernetes/pki/
├── API Server cert with SANs (control plane + worker IPs/hostnames)
├── Service account, front-proxy, etcd CAs
└── Result: Single-node cluster with proper SANs
```

### Phase 2: HA Expansion (k8s-ha-expand.yml)

```
[1] Certificate regeneration on primary node:
├── API Server cert with extended SANs
├── Includes all 3 control plane + 3 worker node addresses
└── Results in new cert with full trust chain

[2] Secondary control plane node joining:
├── Certificates distributed from primary
├── kubeadm join with same CA certificates
└── Secondary nodes trust primary node kubelets

[3] Result: 3-node HA control plane with mutual trust
```

### Phase 3: Worker Node Joining (k8s-workers-join.yml)

```
[1] Worker node preparation:
├── Reset any previous configuration
├── Install kubeadm/kubelet/kubectl
└── Create necessary directories

[2] Certificate distribution:
├── Copy CA certificates from control plane
├── Ensures worker trusts control plane API server
└── Ensures control plane trusts worker kubelets

[3] kubeadm join:
├── Generates worker node's kubelet certificates
├── All signed with cluster CA
└── Registers with API server via VIP

[4] Verification:
├── kubectl exec works (proves control plane → kubelet trust)
├── kubectl get nodes shows Ready status
└── All system pods can reach worker nodes
```

## Troubleshooting Certificate Issues

### Symptom: "kubectl exec" fails with TLS error

```
error: Internal error occurred: error sending request: 
Post "https://192.168.1.85:10250/exec/": 
remote error: tls: internal error
```

**Root Cause**: Control plane API server certificate doesn't include worker node IP in SANs

**Solution**:
1. Regenerate API server certificate with `k8s-ha-expand.yml`
2. Ensure SANs include all worker node IPs and hostnames
3. Restart kubelet on all nodes
4. Verify with: `openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep -A5 "Subject Alternative Name"`

### Symptom: Worker node stays in NotReady state

**Possible Causes**:
1. **Bad CA certificate**: Worker doesn't trust control plane
2. **Wrong kubeconfig**: Worker pointing to wrong API server address
3. **Kubelet can't reach API server**: Network or certificate validation failure

**Diagnosis**:
```bash
# On worker node:
kubectl get nodes  # Should show all nodes as Ready
journalctl -u kubelet | tail -50  # Check kubelet logs
cat /etc/kubernetes/kubelet.conf  # Verify API server URL points to VIP

# On control plane:
kubectl describe node k8s-worker-1  # Check conditions
```

### Symptom: kubelet starts but API server rejects it

**Root Cause**: Worker's kubelet certificate not signed with cluster CA

**Solution**:
1. Ensure worker has correct `/etc/kubernetes/pki/ca.crt` from control plane
2. Run `kubeadm reset -f` on worker
3. Re-run `k8s-workers-join.yml` to redistribute certificates
4. Verify: `openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -text -noout | grep -i issued`

## Certificate Rotation and Renewal

### Automatic Kubelet Certificate Rotation

Kubernetes automatically rotates kubelet client certificates:

```yaml
kubeletConfiguration:
  rotateCertificates: true
  serverTLSBootstrap: true
```

This happens automatically - no manual intervention needed.

### Manual CA Certificate Rotation (Future)

If CA certificate expires or needs rotation:

1. **Generate new CA** on primary control plane
2. **Distribute new CA** to all nodes via certificate copy approach
3. **Rotate all component certificates** with new CA
4. **Restart all components** in sequence (etcd, API server, kubelets)

This is a complex operation - refer to Kubernetes documentation for details.

## Certificate Validation Commands

```bash
# Check API server certificate SANs
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep -A10 "Subject Alternative Name"

# Verify API server certificate is valid
openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt

# Check kubelet certificate on a node
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -text -noout

# Test API server connectivity from a pod
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  sh -c "wget -q -O- https://kubernetes/api/v1/namespaces"

# Verify kubelet is trusted by control plane
kubectl debug node/k8s-worker-1 -it --image=busybox -- \
  chroot /host cat /var/lib/kubelet/pki/kubelet-client-current.pem
```

## Key Takeaways

1. **SANs are critical**: Without proper Subject Alternative Names in API server certificate, kubectl operations fail
2. **CA must be shared**: All nodes must have the same CA to form a trust chain
3. **Distribution matters**: Use certificate copy approach (not just kubeadm join) to ensure proper trust
4. **Verification is essential**: Always validate certificates after deployment
5. **Early planning**: Include all node IPs/hostnames in SANs during initial cluster setup (don't regenerate later if possible)

## References

- [Kubernetes Certificate Management](https://kubernetes.io/docs/tasks/administer-cluster/certificates/)
- [kubeadm Certificate Management](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
- [TLS Bootstrapping in Kubernetes](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-tls-bootstrapping/)
- [PKI Certificates and Requirements](https://kubernetes.io/docs/setup/best-practices/certificates/)
