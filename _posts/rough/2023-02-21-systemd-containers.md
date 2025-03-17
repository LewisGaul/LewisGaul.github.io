---
title: The Reality of Running Systemd in Containers
layout: post
categories: [rough, coding]
tags: [containers, systemd, cgroups, podman, docker, linux, open-source]
---

RedHat states that podman supports running systemd, most recently in a [blog post from 2019](https://developers.redhat.com/blog/2019/04/24/how-to-run-systemd-in-a-container).
There is also a [oci-systemd-hook project](https://github.com/projectatomic/oci-systemd-hook) that provides similar support for any OCI-compatible container runtime such as runc, typically used by docker.
Finally, systemd [customises some behaviour](https://github.com/systemd/systemd/search?q=detect_container) for running inside containers.
So it should all work fine... right??


## Preamble

I previously wrote a [Cgroup Introduction post](/blog/coding/2022/05/13/cgroups-intro), which has lots of detail about points that will be very relevant in this post:
- cgroup basics and the `/sys/fs/cgroup/` filesystem
- cgroup versions: v1 (legacy) and v2 (unified) cgroups, as well as systemd's 'hybrid' mode
- how cgroups are set up for containers
- systemd cgroup setup when running inside containers

I would recommend reading that post and/or referring back if anything is unclear.

I also wrote a supplementary [Cgroups Questions post](/blog/coding/rough/2022/05/20/cgroups-questions) with a bunch of open questions - some of these remain unanswered and will resurface in the rest of this post!

The Linux distros I'm most familiar with are Ubuntu, CentOS and Alpine, so these will be used as examples in this post.
Ubuntu and CentOS use systemd as the init system, whereas Alpine does not (it uses OpenRC), making it an interesting case-study alongside the more popular distros.

One foundational stance I'll be taking in this post is: **any valid container payload should be able to run on any suitably set up Linux host, where the required host setup should be minimal to none.**
This is one of the fundamental goals with containers, so I hope this isn't controversial!
In particular, this should include the statement **systemd containers should be able to run on hosts that don't use systemd**, otherwise there's a lack of support *somewhere* (whether in the container runtime, systemd, or the Linux host's setup).


## Linux Container Setup Fundamentals

Containers are set up using Linux kernel features to achieve isolation from the host and separate resource control/monitoring.
This includes the following (as the default):
- isolated filesystem (`chroot`)
- system namespaces (PID, user, group), such that the container has its own 'root' user/group and PID 1
- mount namespaces (separate mount table, namespaced `procfs`)
- isolated networking (network namespace)
- resource restrictions/monitoring via cgroups (memory, CPU, PIDs, ...)
- restricted capabilities/access to devices

Combining all of the above means it's possible to run normal Linux commands inside containers and get the same results as if running natively on the host.
Some examples below.

```
$ docker run --rm -it ubuntu:22.04 ls /
bin   dev  home  lib32  libx32  mnt  proc  run   srv  tmp  var
boot  etc  lib   lib64  media   opt  root  sbin  sys  usr

$ docker run --rm -it ubuntu:22.04 whoami
root

$ docker run --rm -it ubuntu:22.04 ps avx
  PID TTY      STAT   TIME  MAJFL   TRS   DRS   RSS %MEM COMMAND
    1 pts/0    Rs+    0:00      0    50  7005  1648  0.0 ps avx

$ docker run --rm -it --memory 100M alpine ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
3: sit0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN qlen 1000
    link/sit 0.0.0.0 brd 0.0.0.0
49: eth0@if50: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue state UP
    link/ether 02:42:ac:14:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.20.0.2/16 brd 172.20.255.255 scope global eth0
       valid_lft forever preferred_lft forever
```

However, not everything is fully integrated.
For example, if there's a limit imposed on the container via cgroups then this is not reflected by standard tools:

```
$ docker run --rm -it --memory 100M ubuntu:22.04 free -h
               total        used        free      shared  buff/cache   available
Mem:            12Gi       250Mi        11Gi       0.0Ki       551Mi        11Gi
Swap:          4.0Gi          0B       4.0Gi

$ docker run --rm -it --cpus 2 --cpuset-cpus 0-1 ubuntu:22.04 lscpu | grep 'CPU(s)'
CPU(s):                  8
  On-line CPU(s) list:   0-7
```

There is a solution to this used in LXC, called [LXCFS](https://github.com/lxc/lxcfs), which is a filesystem based on `libfuse` that provides cgroup-aware values via files bind mounted over `/proc/`.
It also provides a cgroupfs alternative that is more appropriate for a container, with one of the main original motivations being to support systemd containers.
See the introduction at <https://linuxcontainers.org/lxcfs/>.
