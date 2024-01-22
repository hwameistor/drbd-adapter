# DRBD Adapter

## Overview

`entrypoint.adapter.sh` wraps around the official containerized DRBD kernel module loader script `entry.sh` to achieve the following goals:

1. Automatically adapt to the host operating system type;
2. Automatically adapt to the host operating system kernel version
3. For the host operating system kernel version supported by this system, drbd will be installed using the corresponding rpm/deb package in the code base.
4. For host operating system kernel versions that are not currently supported by this system, download the corresponding version from the drbd official warehouse and install drbd.
5. Use pre-built kernel modules for existing RHEL/CentOS hosts;
6. Use dynamically built kernel modules for non-stock RHEL/CentOS hosts and Ubuntu hosts;
7. Provide two deployment modes: Job (default) and DaemonSet

![flowchart](flowchart.drawio.svg)

* Yellow: LINBIT's logic
* Blue: DaoCloud's Logic

## Official DRBD Docker Images

LINBIT/drbd <https://github.com/LINBIT/drbd/tree/drbd-9.1/docker>

## DRBD Version

* kernel module v9.1.8 with utils v9.12.1
* (EXPERIMENTAL!) kernel module v9.1.11 with utils v9.21.4

## Arch Support

* x86_64
* aarch64

## OS Distro Support

x86

* CentOS 7.6/7.7/7.9
* Ubuntu 18.04/22.04

aarch64

* Kylin V10 

### Not Supported, but for test only

* Ubuntu 22 Jammy ( experimental: will always install DRBD v9.1.11 )

### Secure Boot

    NOT YET SUPPORTED

## Kubernetes Version

* 18+

## Guide

### Dependency

For dynamically built kernels, the host must have kernel source installed.

```console
# RHEL/CentOS
$ yum install -y kernel-devel-$(uname -r)

# Ubuntu
$ apt-get install -y linux-headers-$(uname -r)
```

> **Note:**
> 
> For major releases of stock RHEL/CentOS 7 and 8, `kernel-devel` is not needed

### OS Distros

By default, OS distros are auto-detected by helm `lookup` function.

However, in `DaemonSet` mode, it can be overridden by adding values to the array `distros: []` in `values.yaml`.

**Distros that are not supported will be ignored.**

For example:

```yaml
distros: 
- rhel7
- rhel8
- bionic
#- focal
```

### Deploy by Helm Charts

Deploy the below `DaemonSet`. It will bring up a pod on each kubernetes worker node to install DRBD modules and tools:

```console
$ helm repo add drbd-adapter https://hwameistor.io/drbd-adapter/

$ helm repo update drbd-adapter

$ helm pull drbd-adapter/drbd-adapter --untar

$ helm install drbd-adapter ./drbd-adapter -n hwameistor --create-namespace
```

Users in China may use daocloud.io/daocloud mirror to accelerate image pull:

```console
$ helm install drbd-adapter ./drbd-adapter \
    -n hwameistor --create-namespace \
    --set imagePullPolicy=Always \
    --set registry=daocloud.io/daocloud
```

#### Experiment DRBD v9.1.11

Only for Experiments!

```console
 $ helm install drbd-adapter ./drbd-adapter \
    -n hwameistor --create-namespace \
    --set imagePullPolicy=Always \
    --set registry=daocloud.io/daocloud \
    --set drbdVersion=v9.1.11
```

### Deployment Examples

#### Job

Set `DeployKind: job` in `values.yaml`, which is the default:

```console
$ kubectl get po -l app=drbd-adapter -o wide
NAME                                     READY   STATUS      RESTARTS   AGE   IP            NODE       
drbd-adapter-k8s-worker-1-rhel7-fqpfg    0/2     Completed   0          36m   10.1.44.70    k8s-worker-1
drbd-adapter-k8s-worker-2-rhel8-k45hp    0/2     Completed   0          36m   10.1.82.97    k8s-worker-2
drbd-adapter-k8s-worker-3-bionic-rr7bv   0/2     Completed   0          36m   10.1.15.220   k8s-worker-3
drbd-adapter-k8s-worker-4-focal-xcmnx    0/2     Completed   0          36m   10.1.57.106   k8s-worker-4
drbd-adapter-k8s-worker-5-jammy-7xf4g    0/2     Completed   0          36m   10.1.42.42    k8s-worker-5
```

#### DaemonSet

Set `DeployKind: daemonset` in `values.yaml`.

```console
$ kubectl -n hwameistor get po -l app=drbd-adapter -o wide
NAME                 READY   STATUS    RESTARTS   AGE   IP            NODE        
drbd-adapter-5w74s   1/1     Running   0          11m   10.6.254.23   k8s-worker-3
drbd-adapter-7766x   1/1     Running   0          11m   10.6.254.21   k8s-worker-1
drbd-adapter-cq52p   1/1     Running   0          11m   10.6.254.24   k8s-worker-4
drbd-adapter-hlpvc   1/1     Running   0          11m   10.6.254.22   k8s-worker-2
drbd-adapter-slm5z   1/1     Running   0          11m   10.6.254.25   k8s-worker-5
```

### Post-installation Check

On POD hosts

```console
$ cat /proc/drbd

$ modinfo drbd

$ lsmod | grep drbd

$ drbdadm --ver
```

### Cluster Expansion

After expanding Kubernetes cluster, to install DRBD on new nodes

#### DaemonSet

`DaemonSet` will automatically expand to the new nodes unless `affinity` and `tolerations` forbid it.

#### Job

Charts need to be reapplied for the helm `lookup` function to identify the new nodes.

```console
$ helm upgrade drbd-adapter ./drbd-adapter -n hwameistor
```

### Deploy on Kubernetes master nodes

By default, master nodes are avoided. To deploy on master nodes, modify `values.yaml` as below:

#### DaemonSet

Set in  `nodeAffinity: {}` in `values.yaml`

#### Job

Set `deployOnMasters: "yes"`

## Common Issues

### 1. Pods get stuck at `ContainerCreating`

Cause:
    A possible cause is that `/etc/drbd.conf` and `/etc/centos-release` get created as directories instead of files. This is a Kubernetes problem. You may find from `kubectl describe pod` that those two paths fail to mount.

Solution:
    Delete those two directories on hosts, and then uninstall chart release and re-install it.

### 2. `modprobe`: ERROR: could not insert `drbd`: Required key not available

Cause:
    Secure Boot is not supported yet

Solution:
    Future releases will handle kernel module signing.
