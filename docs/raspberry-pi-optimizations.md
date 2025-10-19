# Raspberry Pi Optimizations for Kubernetes

This document outlines the optimizations applied to the Raspberry Pi nodes running Ubuntu 24.04 minimal to ensure optimal performance for Kubernetes.

## System Information

### OS Version

The cluster runs on **Ubuntu 24.04.2 LTS (Noble Numbat)** for optimal performance and compatibility with Kubernetes v1.34.x.

### Hardware Configuration

- **Raspberry Pi 4 Model B**
- **Memory**: 8GB RAM
- **Storage**: SD cards with adequate storage for the OS and Kubernetes components
- **Network**: Gigabit Ethernet
- **Cooling**: Adequate cooling solutions to prevent thermal throttling

## Kernel Module Optimizations

The following kernel modules are automatically loaded through the common Ansible role:

```yaml
kernel_modules:
  - overlay             # Required for container overlayfs storage drivers
  - br_netfilter        # Required for container network traffic to traverse iptables
```

### Verification

You can verify these modules are properly loaded with:

```bash
lsmod | grep -E 'overlay|br_netfilter'
```

Expected output:
```
br_netfilter           32768  0
bridge                372736  1 br_netfilter
overlay               192512  16
```

## Sysctl Parameter Optimizations

The following sysctl parameters are configured for optimal Kubernetes performance:

```yaml
sysctl_settings:
  - { name: 'kernel.panic', value: '10' }                     # Automatically reboot after kernel panic
  - { name: 'kernel.panic_on_oops', value: '1' }              # Panic on kernel oops
  - { name: 'vm.overcommit_memory', value: '1' }              # Allow memory overcommit
  - { name: 'vm.panic_on_oom', value: '0' }                   # Don't panic on OOM
  - { name: 'net.ipv4.tcp_slow_start_after_idle', value: '0' } # TCP performance optimization
  - { name: 'net.core.somaxconn', value: '32768' }            # Increase connection queue size
  - { name: 'net.ipv4.tcp_max_syn_backlog', value: '8096' }   # Increase SYN backlog
  - { name: 'fs.inotify.max_user_watches', value: '524288' }  # Increase file watch limit
  - { name: 'fs.file-max', value: '1000000' }                # Increase file descriptor limit
  - { name: 'vm.swappiness', value: '1' }                    # Minimize swapping
  - { name: 'net.bridge.bridge-nf-call-iptables', value: '1' } # Enable iptables to see bridged traffic
  - { name: 'net.bridge.bridge-nf-call-ip6tables', value: '1' } # Enable ip6tables for bridged traffic
  - { name: 'net.ipv4.ip_forward', value: '1' }              # Enable IP forwarding
```

### Verification

You can verify these settings are properly applied with:

```bash
sudo sysctl -a 2>/dev/null | grep -E 'bridge.bridge-nf-call-ip|vm.swappiness|net.ipv4.ip_forward'
```

Expected output:
```
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.ipv4.ip_forward_update_priority = 1
net.ipv4.ip_forward_use_pmtu = 0
vm.swappiness = 1
```

These optimized settings have been verified on the running cluster and ensure optimal network performance, memory management, and container functionality.

## Raspberry Pi Specific Optimizations

### GPU Memory Split

The GPU memory is limited to provide more RAM to the system:

```yaml
raspberry_pi_gpu_mem: 16  # Set GPU memory to minimum (16MB)
```

This configuration is applied to `/boot/firmware/config.txt`.

### Container Runtime Configuration

Containerd is configured with specific resource limits and optimizations for ARM64 architecture:

- Reduced garbage collection threshold
- Optimized snapshot driver settings
- Native overlay support enabled

### Minimizing Resource Usage

1. All unnecessary services are disabled to free up resources
2. Only the minimal packages are installed
3. UFW firewall is configured to allow only necessary traffic

## Memory Management

Given the limited memory on Raspberry Pi boards (typically 4GB or 8GB), the following memory conservation techniques are employed:

1. Kubelet configuration to reserve minimal resources for system processes
2. Limit etcd memory usage by reducing DB quota (default is 8GB)
3. Optimized pod scheduling to distribute memory load
4. Swap completely disabled to improve performance and prevent unpredictable behavior
5. Low swappiness value (1) to minimize any potential swap usage

### Verification

Current memory usage on control plane node:

```bash
$ free -h
               total        used        free      shared  buff/cache   available
Mem:           7.6Gi       1.0Gi       2.4Gi       5.5Mi       4.5Gi       6.6Gi
Swap:             0B          0B          0B
```

The memory optimization techniques have been very effective, with approximately 6.6GB of memory still available on the control plane node even after running all Kubernetes components.

## Load and Performance

The system maintains good performance under load, with moderate average load (typically below 1.5 on a control plane node):

```bash
$ uptime
 12:38:44 up 62 days, 16:28,  1 user,  load average: 1.42, 0.80, 0.76
```

System uptime shows excellent stability with over 62 days of continuous operation.

These optimizations ensure that Kubernetes runs efficiently on the Raspberry Pi hardware while maintaining stability and performance over extended periods.

## Kubernetes Component Configuration

The cluster is running Kubernetes v1.34.1 with the following components properly configured:

### Control Plane Components

All control plane components run as pods in the `kube-system` namespace rather than systemd services:

- **etcd**: Running as pods (one per control plane node)
- **kube-apiserver**: Running on all control plane nodes
- **kube-controller-manager**: Running on all control plane nodes
- **kube-scheduler**: Running on all control plane nodes

### Networking

- **CNI Plugin**: Flannel
- **Pod Network CIDR**: 10.244.0.0/16
- **Service Network CIDR**: 10.245.0.0/16

Flannel pods run on each node in the `kube-flannel` namespace:

```bash
$ kubectl get pods -n kube-flannel
NAME                    READY   STATUS    RESTARTS      AGE
kube-flannel-ds-92vgv   1/1     Running   2 (62d ago)   63d
kube-flannel-ds-9v5jb   1/1     Running   1 (62d ago)   65d
kube-flannel-ds-sxtgm   1/1     Running   3 (62d ago)   63d
```

### Cluster Health Verification

The cluster health can be verified with:

```bash
# Check node status
kubectl get nodes

# Expected output
NAME         STATUS   ROLES           AGE   VERSION
k8s-node-1   Ready    control-plane   66d   v1.34.1
k8s-node-2   Ready    control-plane   63d   v1.34.1
k8s-node-3   Ready    control-plane   63d   v1.34.1

# Check control plane components
kubectl get pods -n kube-system | grep -E 'etcd|kube-apiserver|kube-controller|kube-scheduler'
```

The cluster has demonstrated excellent stability with minimal restarts of key components over a 60+ day period.

## Testing and Verification

The optimizations described in this document have been verified on a running cluster. You can use the `pi-cluster-test.sh` script in this repository to test these configurations when deploying a new cluster.
