# Post-Configuration Steps

This document covers the essential steps to configure cluster access and validate your Kubernetes HA deployment after running the automated playbooks.

## Overview

After successful deployment with the automated playbooks (`k8s-node1-deploy.yml`, `k8s-ha-expand.yml`, and `k8s-post-config.yml`), you need to configure local access to your new Kubernetes HA cluster.

## 1. Configure Local kubectl Access

### Copy Cluster Configuration
```bash
# Copy the kubeconfig from any control plane node
scp -i ~/.ssh/id_rsa k8s_80@192.168.1.80:/home/k8s_80/.kube/config ~/.kube/config

# Backup your existing config (optional)
cp ~/.kube/config ~/.kube/config.backup
```

### Configure VIP Access (Recommended)
Update the kubeconfig to use the Virtual IP for true HA access:

```bash
# Update kubeconfig to use VIP instead of individual node
sed -i 's|https://192.168.1.80:6443|https://192.168.1.100:6443|g' ~/.kube/config

# Verify VIP access
kubectl cluster-info
```

**Expected Output:**
```
Kubernetes control plane is running at https://192.168.1.100:6443
CoreDNS is running at https://192.168.1.100:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

## 2. Cluster Validation Commands

### Basic Cluster Health
```bash
# Verify all nodes are Ready
kubectl get nodes -o wide

# Check system pods across all nodes
kubectl get pods -A -o wide

# Verify VIP failover functionality
kubectl --server=https://192.168.1.100:6443 get nodes
```

### Network Validation
```bash
# Check Flannel CNI pods
kubectl get pods -n kube-flannel

# Verify network connectivity with test workload
kubectl create deployment test-nginx --image=nginx:alpine --replicas=3
kubectl get pods -o wide

# Expose for both internal and browser access
kubectl expose deployment test-nginx --port=80 --type=ClusterIP --name=test-nginx-cluster
kubectl expose deployment test-nginx --port=80 --type=NodePort --name=test-nginx-browser

# Test internal service connectivity
kubectl run test-client --image=busybox --rm -i --restart=Never -- wget -qO- test-nginx-cluster.default.svc.cluster.local

# Get browser access details
kubectl get service test-nginx-browser -o wide
echo "Browser access: http://192.168.1.80:$(kubectl get service test-nginx-browser -o jsonpath='{.spec.ports[0].nodePort}')"

# Clean up test resources (optional)
kubectl delete deployment test-nginx
kubectl delete service test-nginx-cluster test-nginx-browser
```

### HA Control Plane Validation
```bash
# Verify etcd cluster health (on any node)
ssh -i ~/.ssh/id_rsa k8s_80@192.168.1.80 \
"sudo ETCDCTL_API=3 etcdctl --endpoints=127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
endpoint health"

# Check all control plane components
kubectl get pods -n kube-system -l tier=control-plane -o wide
```

## 3. Access Methods

### Method 1: Local kubectl (Recommended)
With proper kubeconfig setup, use kubectl directly:
```bash
kubectl get nodes
kubectl get pods -A
```

### Method 2: SSH Access to Nodes
Direct access to any control plane node:
```bash
# SSH to any node
ssh -i ~/.ssh/id_rsa k8s_80@192.168.1.80
ssh -i ~/.ssh/id_rsa k8s_81@192.168.1.81  
ssh -i ~/.ssh/id_rsa k8s_82@192.168.1.82

# Use kubectl on the node
kubectl get nodes
```

### Method 3: Multiple Contexts (Advanced)
Set up multiple contexts for different access patterns:
```bash
# Create context for direct node access (backup)
kubectl config set-cluster pi-cluster-direct \
  --server=https://192.168.1.80:6443 \
  --certificate-authority-data=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# Switch between contexts
kubectl config use-context kubernetes-admin@kubernetes  # VIP access
kubectl config get-contexts
```

## 4. Browser Access to Services

### NodePort Services for External Access
The post-config playbook creates browser-accessible services. After running `k8s-post-config.yml`, you can access the test nginx service via:

```bash
# Get the NodePort for browser access
kubectl get service test-nginx-nodeport -n test-workload

# Access via any node IP
# http://192.168.1.80:30080
# http://192.168.1.81:30080  
# http://192.168.1.82:30080
```

### Creating Your Own Browser-Accessible Services
```bash
# Deploy any application
kubectl create deployment my-app --image=nginx:alpine

# Expose as NodePort for browser access
kubectl expose deployment my-app --port=80 --type=NodePort

# Get the assigned port
kubectl get service my-app -o jsonpath='{.spec.ports[0].nodePort}'

# Access via browser: http://NODE_IP:NODE_PORT
```

### Load Balancer Alternative (Future)
For production, consider:
- **MetalLB**: Software load balancer for bare-metal clusters
- **Ingress Controller**: nginx-ingress or Traefik with hostname routing
- **Service Mesh**: Istio Gateway for advanced traffic management

## 5. Troubleshooting Common Issues

### Certificate Issues
If you encounter certificate errors:
```bash
# Re-copy kubeconfig from cluster
scp -i ~/.ssh/id_rsa k8s_80@192.168.1.80:/home/k8s_80/.kube/config ~/.kube/config

# Verify certificate authority data
kubectl config view --raw
```

### VIP Connection Issues
If VIP access fails:
```bash
# Test VIP connectivity
ping 192.168.1.100

# Check keepalived status on nodes
ssh -i ~/.ssh/id_rsa k8s_80@192.168.1.80 "sudo systemctl status keepalived"

# Fallback to direct node access
kubectl --server=https://192.168.1.80:6443 get nodes
```

### Node Communication Issues
If nodes show NotReady:
```bash
# Check kubelet status
ssh -i ~/.ssh/id_rsa k8s_80@192.168.1.80 "sudo systemctl status kubelet"

# Check CNI pods
kubectl get pods -n kube-flannel
kubectl describe pods -n kube-flannel
```

## 5. Next Steps

With cluster access configured, you're ready for:

1. **Service Mesh Deployment**: Deploy Istio for advanced traffic management
2. **GitOps Setup**: Install ArgoCD for continuous deployment
3. **Secrets Management**: Deploy Vault for PKI and secrets handling
4. **Application Deployment**: Deploy your workloads using the HA cluster

## 6. Cluster Configuration Summary

**Network Configuration:**
- Virtual IP: `192.168.1.100:6443`
- Node IPs: `192.168.1.80-82`
- Pod Network: `10.244.0.0/16` (Flannel)
- Service Network: `10.245.0.0/16`

**Access Credentials:**
- SSH Key: `~/.ssh/id_rsa`
- Users: `k8s_80`, `k8s_81`, `k8s_82`
- Kubeconfig: `~/.kube/config`

**HA Components:**
- 3x etcd members
- 3x API servers behind VIP
- 3x controller-managers (leader election)
- 3x schedulers (leader election)
- Keepalived VIP failover

The cluster is now fully operational and ready for production workloads with true high availability!