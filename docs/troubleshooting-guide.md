# Troubleshooting Guide

Quick solutions for common issues with the HA Kubernetes cluster deployment.

## Pre-Deployment Issues

### Cloud-Init Problems

**SSH access fails after flashing SD cards:**
```bash
# Check if cloud-init files are properly named (no extensions)
ls /boot/  # Should show: user-data, meta-data, network-config

# Verify network config syntax
sudo cloud-init schema --config-file /boot/network-config
```

**Nodes don't get static IPs:**
```bash
# Check cloud-init status on the Pi
sudo cloud-init status
sudo journalctl -u cloud-init

# Manual IP assignment if needed
sudo ip addr add 192.168.1.80/24 dev eth0
```

### Connectivity Issues

**Ansible ping fails:**
```bash
# Test basic connectivity
ping 192.168.1.80

# Check SSH key access
ssh -i ~/.ssh/id_rsa k8s_80@192.168.1.80

# Update inventory if IPs changed
ansible-inventory -i inventory.yml --list
```

## Deployment Issues

### Phase 1: Single-Node Foundation

**kubeadm init fails:**
```bash
# Reset and retry
sudo kubeadm reset -f
ansible-playbook -i inventory.yml k8s-node1-deploy.yml

# Check specific failure
sudo journalctl -xeu kubelet
```

**CNI pods not ready:**
```bash
# Check Flannel deployment
kubectl get pods -n kube-flannel
kubectl describe pods -n kube-flannel

# Restart if needed
kubectl delete pods -n kube-flannel --all
```

### Phase 2: HA Expansion

**Node join failures:**
```bash
# Generate fresh token
kubeadm token create --print-join-command

# Check certificate issues
ls -la /etc/kubernetes/pki/

# Re-run HA expansion
ansible-playbook -i inventory.yml k8s-ha-expand.yml
```

**VIP not accessible:**
```bash
# Check keepalived status
sudo systemctl status keepalived
sudo journalctl -u keepalived

# Test VIP manually
ping 192.168.1.100
curl -k https://192.168.1.100:6443/healthz
```

### Phase 3: Post-Configuration

**Test workload fails:**
```bash
# Check namespace exists
kubectl get namespaces

# Recreate if needed
kubectl create namespace test-workload
ansible-playbook -i inventory.yml k8s-post-config.yml
```

## Cluster Operation Issues

### Node Problems

**Node shows NotReady:**
```bash
# Check kubelet
ssh k8s_80@192.168.1.80 "sudo systemctl status kubelet"

# Restart kubelet if needed
ssh k8s_80@192.168.1.80 "sudo systemctl restart kubelet"

# Check node conditions
kubectl describe node k8s-node-1
```

**Pod scheduling issues:**
```bash
# Check node taints
kubectl describe nodes | grep -A5 Taints

# Remove taints if needed
kubectl taint nodes k8s-node-1 node-role.kubernetes.io/control-plane:NoSchedule-
```

### Network Problems

**Pod-to-pod communication fails:**
```bash
# Test network connectivity
kubectl run test-pod --image=busybox --rm -i --restart=Never -- ping 10.244.1.1

# Check Flannel config
kubectl get configmap kube-flannel-cfg -n kube-flannel -o yaml
```

**Service DNS not working:**
```bash
# Test CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check service resolution
kubectl run test-dns --image=busybox --rm -i --restart=Never -- nslookup kubernetes.default
```

## Browser Access Issues

**NodePort not accessible:**
```bash
# Check service configuration
kubectl get service test-nginx-nodeport -n test-workload -o wide

# Test from cluster node
curl http://192.168.1.80:30080

# Check firewall (if needed)
sudo ufw status
```

## Complete Reset Procedures

### Reset Single Node
```bash
# On the node
sudo kubeadm reset -f
sudo systemctl stop kubelet
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/etcd/
```

### Reset Entire Cluster
```bash
# Use cleanup playbook
ansible-playbook -i inventory.yml playbooks/cleanup-cluster.yml

# Verify clean state
ansible -i inventory.yml all -m shell -a "sudo systemctl status kubelet"
```

### Fresh Deployment After Reset
```bash
# Complete 3-phase deployment
ansible-playbook -i inventory.yml k8s-node1-deploy.yml
ansible-playbook -i inventory.yml k8s-ha-expand.yml  
ansible-playbook -i inventory.yml k8s-post-config.yml
```

## Emergency Access

**kubectl access lost:**
```bash
# Re-copy kubeconfig
scp -i ~/.ssh/id_rsa k8s_80@192.168.1.80:/home/k8s_80/.kube/config ~/.kube/config

# Update for VIP
sed -i 's|192.168.1.80|192.168.1.100|g' ~/.kube/config
```

**API server unreachable:**
```bash
# Check from any control plane node
ssh k8s_80@192.168.1.80 "kubectl get nodes"

# Direct API server access
curl -k https://192.168.1.80:6443/healthz
```

For persistent issues, check the full deployment logs and ensure all prerequisites are met as described in the [Quick Start Guide](quick-start.md).

### 1. SSH Authentication Failures

**Symptoms:**
- Ansible fails with SSH authentication errors

**Solutions:**
- Verify SSH key was correctly generated and added by cloud-init
- Check ansible_user values in inventory.yml match cloud-init configurations
- Try manual SSH to diagnose specific authentication issues

### 2. Container Runtime Issues

**Symptoms:**
- Tasks related to containerd fail
- Errors about container runtime not being available

**Solutions:**
- Check if containerd service is running: `systemctl status containerd`
- Verify containerd configuration: `/etc/containerd/config.toml`
- Ensure proper modules are loaded: `lsmod | grep overlay` and `lsmod | grep br_netfilter`

### 3. etcd Cluster Formation Problems

**Symptoms:**
- etcd pods don't start properly
- Logs show peer connection issues

**Solutions:**
- Verify network connectivity between nodes on ports 2379 and 2380
- Check certificate paths in etcd configuration
- Ensure proper hostnames and IPs in etcd configuration
- If needed, reset etcd data: `rm -rf /var/lib/etcd/*`

### 4. Control Plane Join Failures

**Symptoms:**
- Secondary control plane nodes fail to join
- Errors about certificate issues or API server connectivity

**Solutions:**
- Use the fix-control-plane.yml playbook:
  ```bash
  ansible-playbook -i inventory.yml playbooks/fix-control-plane.yml -e "target_nodes=k8s-node-2,k8s-node-3"
  ```
- Check logs: `journalctl -xeu kubelet`
- Verify the Virtual IP (VIP) is working correctly

### 5. API Server Not Starting

**Symptoms:**
- kube-apiserver pods fail to start
- Errors in logs about etcd connection or certificate issues

**Solutions:**
- Verify etcd is functional: `ETCDCTL_API=3 etcdctl endpoint health`
- Check API server certificate paths
- Ensure proper etcd client certificates are configured
- Look for specific errors: `kubectl logs -n kube-system kube-apiserver-<node-name>`

## CNI (Networking) Issues

### 1. Pod Network Problems

**Symptoms:**
- Pods stuck in ContainerCreating state
- Network plugin-related errors in events

**Solutions:**
- Verify Flannel pods are running: `kubectl get pods -n kube-flannel`
- Check Flannel logs: `kubectl logs -n kube-flannel <flannel-pod-name>`
- Ensure pod CIDR configuration is consistent

### 2. CoreDNS Issues

**Symptoms:**
- CoreDNS pods not running or crashlooping
- DNS resolution not working in pods

**Solutions:**
- Check CoreDNS pods: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
- Verify CNI is working properly (Flannel pods running)
- Check CoreDNS logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`

## Infrastructure Component Issues

### 1. ArgoCD Deployment Failures

**Symptoms:**
- ArgoCD pods not running
- Error messages in the deployment logs

**Solutions:**
- Check namespace creation: `kubectl get namespace argocd`
- Verify RBAC is set up correctly
- Check pod logs: `kubectl logs -n argocd <pod-name>`

### 2. Ingress Controller Issues

**Symptoms:**
- Traefik pods not running
- Services not accessible externally

**Solutions:**
- Check if Traefik namespace exists: `kubectl get namespace traefik`
- Verify Traefik pods status: `kubectl get pods -n traefik`
- Check Traefik logs: `kubectl logs -n traefik <traefik-pod-name>`

### 3. Cert-Manager Problems

**Symptoms:**
- cert-manager pods not running
- Certificate issuance fails

**Solutions:**
- Verify namespace created: `kubectl get namespace cert-manager`
- Check pod status: `kubectl get pods -n cert-manager`
- Look for errors in logs: `kubectl logs -n cert-manager <cert-manager-pod>`

## Hardware and Performance Issues

### 1. Node Not Ready Due to Memory Pressure

**Symptoms:**
- Nodes show NotReady status
- Memory pressure condition present

**Solutions:**
- Reduce resource requests/limits in pod specifications
- Add swap (generally not recommended for Kubernetes, but may be necessary for Raspberry Pi)
- Consider adding more RAM if possible

### 2. Overheating Issues

**Symptoms:**
- Random node failures
- CPU throttling messages in system logs

**Solutions:**
- Ensure adequate cooling for Raspberry Pis
- Consider adding heatsinks or fans
- Check CPU temperature: `vcgencmd measure_temp`

## Complete Cluster Reset

If you need to start over completely:

```bash
ansible-playbook -i inventory.yml playbooks/cleanup-cluster.yml
```

This will reset all nodes to a clean state, allowing you to restart the deployment process.
