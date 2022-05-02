---
title: Cgroups Introduction
layout: post
categories: [coding, rough]
tags: [linux, cgroups, informational]
---

I've been working with Linux containers for the last year (primarily using Docker and Podman) and have recently had reason to care about some of the finer details, especially cgroups.
This post aims to share some of the knowledge I've accumulated!


## Basics

This line from [the manpages](https://man7.org/linux/man-pages/man7/cgroups.7.html) is a good concise summary of what cgroups are:

> Control groups, usually referred to as cgroups, are a Linux kernel feature which allow processes to be organized into hierarchical groups whose usage of various types of resources can then be limited and monitored.

This idea of 'hierarchical groups' corresponds to the fact that cgroups can have child cgroups, and certain properties are inherited from their parent (a bit like how Linux processes inherit some characteristics from their parents).

The manual goes on to define some terminology:

> The kernel's cgroup interface is provided through a pseudo-filesystem called *cgroupfs*.
> 
> A *cgroup* is a collection of processes that are bound to a set of limits or parameters defined via the cgroup filesystem.
> 
> A *subsystem* is a kernel component that modifies the behavior of the processes in a cgroup.
> [...] Subsystems are sometimes also known as *resource controllers* (or simply, controllers).

There are a number of supported controllers, some examples being:
- 'memory' for controlling/monitoring memory usage
- 'cpu' for controlling/monitoring CPU usage
- 'cpuset' for controlling which CPUs may be used
- 'pids' for controlling/monitoring the number of allowed child PIDs
- 'devices' for controlling which devices may be created/accessed


### Cgroup versions

The initial release of cgroups was in Linux kernel v2.6.24 (2008).
A reworked implementation was officially released in kernel v4.5 (2016) and is gradually becoming more widely adopted, and even the default in certain Linux distributions (such as the recent Ubuntu v22.04 LTS release).

The original implementation (known as 'v1' or 'legacy') is still supported, and will be indefinitely for backwards compatibility.
The new implementation makes some significant changes, the biggest being the unification of the cgroup hierarchy across all subsystems, meaning this implementation is often described as 'unified hierarchy' as well as simply 'v2'.

There is also a 'hybrid' mode (for using some v2 features while maintaining v1 compatibility), but more on that later.


### Cgroup filesystem

The cgroup filesystem is a pseudo-filesystem, similar to `sysfs` or `procfs`.
It provides a UI for interacting with cgroups (Linux kernel feature) from Linux userspace.
The filesystem contains 'files', providing a read/write API for checking/modifying cgroup restrictions or usage stats.
Cgroups (for containing groups of processes) can be manually created/deleted in the hierarchy using `mkdir` or `rmdir`.

The standard place for the cgroup filesystem to be mounted is at `/sys/fs/cgroup`.
The mount setup differs between v1 and v2, but in either case you should see some mounts under this path of type 'cgroup' and/or 'cgroup2'.

Based on [this Debian email thread](https://lists.debian.org/debian-devel/2009/02/msg00037.html) it seems that back in 2009 there was no standard place for the filesystem to be mounted, and the most popular path might have been `/dev/cgroup`.
The Linux world seems to have no standardised on `/sys/fs/cgroup`, although I'm not sure exactly how/when this was decided (perhaps Systemd played a big part in this, since it seems to take responsibility for setting up these mounts).


## Cgroup Versions (in more depth)

As mentioned in the section above there are two supported cgroup implementations: 'legacy' (v1) and 'unified hierarchy' (v2).
It's also possible to configure Linux to run in a hybrid mode.

The Linux kernel supports both versions, but it's Systemd that sets up the cgroup filesystem, and therefore decides which cgroup setup to use.
The 'hybrid mode' is a mode supported by Systemd.

As an illustration of cgroups v2 adoption, here's the status of some popular Linux distros:
- Fedora: v2 by default from v31, 2019 [[ref](https://fedoraproject.org/wiki/Releases/31/ChangeSet#Modify_Fedora_31_to_use_CgroupsV2_by_default)]
- Debian: v2 by default from v11, 2021 [[ref](https://www.debian.org/releases/stable/amd64/release-notes/ch-whats-new.en.html#cgroupv2)]
- Ubuntu: v2 by default from v21.10, 2021 [[ref](https://wiki.ubuntu.com/ImpishIndri/ReleaseNotes)] (v22.04 as the first LTS release)
- RHEL/CentOS: still v1 by default in v8 (based on Fedora v28), planned to be v2 by default in v9, 2022? (based on Fedora v34) [[ref](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9-beta/html-single/considerations_in_adopting_rhel_9/index#ref_changes-to-kernel_assembly_kernel)]

This section goes into some more detail about the main differences, how to check which version is in use, and how to switch between versions.


### Cgroups v1

Cgroups v1, the original implementation of the new 'control cgroups' feature, was released in Linux kernel v2.6.24, 2008.

Under v1, the `/sys/fs/cgroup` mount is a `tmpfs` mount used to contain the per-subsystem `cgroup` type mounts.
An example can be seen below:
```
root@ubuntu:~# findmnt -R /sys/fs/cgroup/
TARGET                            SOURCE FSTYPE OPTIONS
/sys/fs/cgroup                    tmpfs  tmpfs  ro,nosuid,nodev,noexec,mode=755
|-/sys/fs/cgroup/systemd          cgroup cgroup rw,nosuid,nodev,noexec,relatime,xattr,release_agent=/usr/lib/systemd/systemd-cgroups-agent,name=systemd
|-/sys/fs/cgroup/memory           cgroup cgroup rw,nosuid,nodev,noexec,relatime,memory
|-/sys/fs/cgroup/cpu,cpuacct      cgroup cgroup rw,nosuid,nodev,noexec,relatime,cpuacct,cpu
|-/sys/fs/cgroup/cpuset           cgroup cgroup rw,nosuid,nodev,noexec,relatime,cpuset
|-/sys/fs/cgroup/pids             cgroup cgroup rw,nosuid,nodev,noexec,relatime,pids
|-/sys/fs/cgroup/hugetlb          cgroup cgroup rw,nosuid,nodev,noexec,relatime,hugetlb
|-/sys/fs/cgroup/freezer          cgroup cgroup rw,nosuid,nodev,noexec,relatime,freezer
|-/sys/fs/cgroup/perf_event       cgroup cgroup rw,nosuid,nodev,noexec,relatime,perf_event
|-/sys/fs/cgroup/net_cls,net_prio cgroup cgroup rw,nosuid,nodev,noexec,relatime,net_prio,net_cls
|-/sys/fs/cgroup/blkio            cgroup cgroup rw,nosuid,nodev,noexec,relatime,blkio
`-/sys/fs/cgroup/devices          cgroup cgroup rw,nosuid,nodev,noexec,relatime,devices
```

Each cgroup subsystem (as seen above) contains its own hierarchy, as represented by the filesystem hierarchy.

These mounts are normally set up by Systemd when Linux boots, however, it is possible to manually set up the cgroup filesystem using commands like the below (untested).
```bash
mkdir -p /sys/fs/cgroup
mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup
for sys in memory cpu,cpuacct cpuset pids hugetlb freezer perf_event net_cls,net_prio blkio devices; do
  mount -n -t cgroup -o $sys cgroup /sys/fs/cgroup/$sys
done
```

It is also possible to create arbitrary named subsystems (which aren't strictly speaking *controllers*) such as the one Systemd creates.
This is relevant to a later section!
```bash
mount -n -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
```


### Cgroups v2

Discussions around a reimplementation of cgroups were started as early as 2012, and cgroups v2 was released in kernel v4.5 (2016).
Adoption is just now starting to become more mainstream as more Linux distros switch the default to be v2.

An explanation of the differences and motivations for cgroups v2 is [given in the manpages](https://man7.org/linux/man-pages/man7/cgroups.7.html#CGROUPS_VERSION_2).
The reasoning is summarised as:
>  In cgroups v1, the ability to mount different controllers against
different hierarchies was intended to allow great flexibility for
application design.  In practice, though, the flexibility turned
out to be less useful than expected, and in many cases added
complexity.

Under v2, the `/sys/fs/cgroup` mount is a single `cgroup2` mount that is used to manage all enabled controllers.
```
root@ubuntu:~# findmnt -R /sys/fs/cgroup
TARGET         SOURCE  FSTYPE  OPTIONS
/sys/fs/cgroup cgroup2 cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot
```

The enabled controllers can be checked by reading the `/proc/cgroups` file, or the active controllers in a given cgroup using the `cgroup.controllers` file:
```
root@ubuntu:~# cat /sys/fs/cgroup/cgroup.controllers
cpuset cpu io memory hugetlb pids rdma misc
```


### Differences between v1 and v2

The differences are [explained in the manpages](https://man7.org/linux/man-pages/man7/cgroups.7.html#CGROUPS_VERSION_2) (as previously linked), but as a quick summary, v2 brings the following changes:
- A unified hierarchy (as shown above)
- Processes may only be assigned to 'leaf nodes' in the hierarchy, i.e. cgroups that do not have their own child cgroups
- Active controllers must be specified via the `cgroup.controllers` and `cgroup.subtree_control` files inside the cgroup filesystem
- All threads of a process must be inside the same cgroup (unless '[thread mode](https://man7.org/linux/man-pages/man7/cgroups.7.html#CGROUPS_VERSION_2_THREAD_MODE)' is enabled)
- Some filename changes, e.g. `cpuset.effective_cpus` versus `cpuset.cpus.effective`


### Hybrid mode

TODO


### Determining active cgroup mode

TODO


### Switching cgroup mode

TODO


## Cgroups and Containers

TODO


## Manual Cgroup Manipulation

TODO

### Systemd cgroup ownership

TODO
