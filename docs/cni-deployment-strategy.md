# CNI Strategy Reference

*Main implementation details are in the [Deployment Guide](deployment-guide.md).*

## Current: Flannel

**Why Flannel:**
- Simple, reliable overlay network
- Minimal resource overhead on Pi hardware  
- No external dependencies
- Proven stability in edge environments

**Configuration:**
```yaml
Network: 10.244.0.0/16
Backend: vxlan (default)
Management: DaemonSet
```

## Alternative Options

| CNI | Pros | Cons | Pi Suitability |
|-----|------|------|----------------|
| Flannel | Simple, stable | Basic features | ✅ Excellent |
| Calico | Rich policies | Higher overhead | ⚠️ Acceptable |
| Cilium | eBPF features | Resource heavy | ❌ Too heavy |

## Deployment Notes

- Applied after cluster initialization
- Uses kube-flannel namespace
- Automatic during k8s-node1-deploy.yml
- Validated in post-config phase

This document outlines the strategy for deploying the Container Network Interface (CNI) plugin in our Kubernetes cluster.

## Overview

The Container Network Interface (CNI) is a crucial component of Kubernetes networking. It provides pod-to-pod networking across multiple nodes and enables services to communicate. Our cluster uses Flannel as the CNI plugin because it's:

1. Lightweight and simple to deploy
2. Well-tested on Raspberry Pi hardware
3. Easy to troubleshoot
4. Doesn't require additional external dependencies

## Deployment Process

Our `cni-plugin.yml` playbook handles the deployment of Flannel CNI with these key steps:

### 1. Pre-Deployment Verification

Before deploying the CNI plugin, we verify:
- API server is healthy and responding
- kubeconfig files are correctly configured with proper port (6443)
- Control plane nodes are registered and Ready (without CNI)

### 2. Configuration Consistency

We ensure consistent port configurations:
- All kubeconfig files use the virtual IP (192.168.1.100) and port 6443
- The API server is correctly bound to port 6443
- All component manifests are synchronized

### 3. Flannel Deployment

We download and apply the Flannel manifest with these modifications:
- Update the pod CIDR to match our cluster configuration (10.244.0.0/16)
- Apply with retry logic to handle temporary API server issues
- Wait for Flannel pods to reach Running state

### 4. Network Verification

After deployment, we verify network connectivity by:
- Checking that kube-dns/CoreDNS pods are Running
- Creating a test pod to verify pod network connectivity
- Testing internet access from within the pod

## Troubleshooting

Common issues with CNI deployment and their solutions:

### Flannel Pods Not Starting

**Symptoms:**
- Pods stuck in ContainerCreating
- Nodes NotReady
- `kubectl describe pod` shows network-related errors

**Solutions:**
1. Verify consistent pod CIDR config:
   ```bash
   kubectl describe node <node-name> | grep PodCIDR
   ```
2. Check kubelet logs:
   ```bash
   journalctl -u kubelet -f
   ```
3. Inspect Flannel logs:
   ```bash
   kubectl logs -n kube-flannel daemonset/kube-flannel-ds
   ```

### Pod-to-Pod Communication Failures

**Symptoms:**
- Pods can't communicate across nodes
- Services not accessible from other nodes

**Solutions:**
1. Check node-to-node connectivity:
   ```bash
   ping <other-node-ip>
   ```
2. Verify no firewall rules blocking 8472/UDP (VXLAN)
   ```bash
   sudo iptables -L | grep 8472
   ```
3. Check flannel.1 interface exists:
   ```bash
   ip addr show flannel.1
   ```

## Alternative CNI Options

While Flannel is our default, the playbook can be extended to support:

1. **Calico**: Better policy support, more features, but more complex
2. **Weave Net**: Simple, works well without external dependencies
3. **Cilium**: Advanced features like eBPF, but higher resource requirements

## Post-Deployment Steps

After CNI deployment:
1. Control plane node taints are removed to allow pod scheduling
2. Network connectivity testing validates proper operation
3. DNS service is verified to be functional

## References

- [Flannel GitHub Repository](https://github.com/flannel-io/flannel)
- [Kubernetes Networking Documentation](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [CNI Specification](https://github.com/containernetworking/cni/blob/master/SPEC.md)
