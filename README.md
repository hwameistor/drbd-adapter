# DRBD Adapter

## Overview

`entrypoint.adapter.sh` wraps around the official containerized DRBD kernel module loader script `entry.sh` to achieve the following goals:

1. Adapt host OS type automatically;
2. Drop drbd kernel modules and drbd-utils to the host;
3. Use pre-built kernel modules for stock RHEL/CentOS hosts;
4. Use dynamically built kernel modules for un-stock RHEL/CentOS hosts and Ubuntu hosts.

## Official DRBD Docker Images

LINBIT/drbd <https://github.com/LINBIT/drbd/tree/drbd-9.1/docker>

## Arch Support

* x86_64

## OS Support

* RHEL/CentOS 7
* RHEL/CentOS 7
* Kylin
* Ubuntu 18 Bionic
* Ubuntu 20 Focal
* Ubuntu 22 Jammy

## Kubernetes Version

* 18+

## DRBD Version:
* v9.1.8

## Guide

### Dependency
For dynamically built kernels, the host must have kernel source installed.
```
# RHEL/CentOS
$ yum install -y kernel-devel-$(uname -r)

# Ubuntu
$ apt-get install -y linux-headers-$(uname -r)
```

### Yaml
Deploy the below `DaemonSet`. It will bring up a pod on each kubernetes worker node to install DRBD modules and tools:

```
$ helm install drbd-adapter helm/drbd-adapter
```
