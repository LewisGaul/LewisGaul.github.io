---
title: Cgroups Introduction
layout: post
categories: [coding]
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

There's a really good conference talk "Mixing cgroupfs v1 & cgroupfs v2: finding solutions for container runtimes" by Christian Brauner that I used to fill in some of the gaps (video available on YouTube).


### Cgroups v1

Cgroups v1, the original implementation of the new 'control cgroups' feature, was released in Linux kernel v2.6.24, 2008.

As well as the manpages, another useful set of documentation is the [Linux kernel docs](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v1/index.html).

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

It is also possible to create arbitrary named subsystems (which aren't strictly speaking *controllers*) such as the one Systemd creates for its internal tracking.
This will become relevant in a later section!
```bash
mount -n -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
```

The list of enabled controllers can be checked by reading the `/proc/cgroups` file.

Note that (apparently) it is actually possibly to mount multiple v1 cgroup controllers at the *same path*, such that they would share the same hierarchy.


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

There are also [kernel docs for v2](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html).

Under v2, the `/sys/fs/cgroup` mount is a single `cgroup2` mount that is used to manage all enabled controllers.
```
root@ubuntu:~# findmnt -R /sys/fs/cgroup
TARGET         SOURCE  FSTYPE  OPTIONS
/sys/fs/cgroup cgroup2 cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot
```

The active controllers in a given cgroup using the `cgroup.controllers` file:
```
root@ubuntu:~# cat /sys/fs/cgroup/cgroup.controllers
cpuset cpu io memory hugetlb pids rdma misc
```


### Differences between v1 and v2

The differences are explained in the [manpages](https://man7.org/linux/man-pages/man7/cgroups.7.html#CGROUPS_VERSION_2) and the [kernel docs](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html#deprecated-v1-core-features) (both previously linked).

As a quick summary, v2 brings the following changes:
- A unified hierarchy (as shown above)
- Processes may only be assigned to 'leaf nodes' in the hierarchy, i.e. cgroups that do not have their own child cgroups
  - The intention here seems to be to make it more explicit/obvious how resources are shared out.
- Active controllers must be specified via the `cgroup.controllers` and `cgroup.subtree_control` files inside the cgroup filesystem
- All threads of a process must be inside the same cgroup (unless '[thread mode](https://man7.org/linux/man-pages/man7/cgroups.7.html#CGROUPS_VERSION_2_THREAD_MODE)' is enabled)
  - For some controllers it doesn't make sense for different threads of the same process to be in different cgroups, most notably the 'memory' controller since threads of the same process share the same memory space. For others (e.g. 'cpu'/'cpuset') it can make sense.
- Some filename changes, e.g. `cpuset.effective_cpus` changed to `cpuset.cpus.effective`
- Certain controllers removed, e.g. 'devices', since this relates to *access* management rather than *resource* management


### Hybrid mode and Systemd

[Disclaimer: The below reflects my understanding, which may contain inaccuracies. I'll include links to justify my claims where possible!]

The Linux kernel simultaneously supports v1 and v2 cgroups.
The restriction is detailed in the manpages:
> A cgroup v2 controller is available only if it is not currently in use via a mount against a cgroup v1 hierarchy.
> Or, to put things another way, it is not possible to employ the same controller against both a v1 hierarchy and the unified v2 hierarchy.

What this means is that it's possible to have cgroup v1 mounts at the same time as having a cgroup v2 mount (recall that the mount point doesn't *have* to be `/sys/fs/cgroup`, so two different locations can be used).
In theory it is possible to have some controllers managed by v1 and others managed by v2 (but not for the same controller to be managed by both at the same time).

On systems that boot with Systemd (the majority of the most popular distros these days), it is Systemd that sets up the cgroup mounts.
In the transition from cgroups v1 to v2, Systemd made a 'hybrid' mode the default before switching to v2 as the default.

Taking a step back to take a look at Systemd's support for cgroups v2 (as per [the `NEWS` file](https://github.com/systemd/systemd/blob/main/NEWS)):
- v226 (2015) adds provisional support for cgroups v2 via kernel command-line option `systemd.unified_cgroup_hierarchy=1`
- v230 (2016) makes cgroups v2 support official with kernel version v4.5
- v231 (2016) adds support for the 'memory' controller under cgroups v2
- v232 (2016) adds support for the 'cpu' controller under cgroups v2
- v233 (2017):
  - the hybrid mode that Systemd uses by default is modified for better compatibility with v1
  - adds ability to use full legacy mode via kernel command-line option `systemd.legacy_systemd_cgroup_controller=1`
  - adds compile-time configure option `--with-default-hierarchy` that makes v2 the default, options are 'legacy', 'unified', or 'hybrid' (default)
- v243 (2019) makes cgroups v2 the default
- v244 (2019) adds support for the 'cpuset' controller under cgroups v2

It's not made completely clear when the initial 'hybrid' mode was introduced and became the default, but I think it was v232.
It's also not clear what this initial hybrid setup was, although I would think it was a v2 cgroup mount at `/sys/fs/cgroup/systemd` instead of the named v1 subsystem.

It seems that perhaps hybrid was intended to be an internal detail that users wouldn't need to care about while still using cgroups v1.
However, clearly there were issues with compatibility [[relevant PR](https://github.com/systemd/systemd/pull/4628)], and v233 subsequently made changes to the hybrid mode that warranted a mention in the `NEWS` file, as well as adding options to force pure cgroups v1 mode.

The 'fixed' hybrid mode introduced in v233 is set up with all controllers still using v1, but with there also being a v2 cgroup mount at `/sys/fs/cgroup/unified` that Systemd uses for its own internal tracking (instead of the v1 named subsystem).

This looks something like this (note the second mount, of type `cgroup2`):
```
root@ubuntu:~# findmnt -R /sys/fs/cgroup
TARGET                            SOURCE FSTYPE  OPTIONS
/sys/fs/cgroup                    tmpfs  tmpfs   ro,nosuid,nodev,noexec,mode=755
|-/sys/fs/cgroup/unified          cgroup cgroup2 rw,nosuid,nodev,noexec,relatime
|-/sys/fs/cgroup/systemd          cgroup cgroup  rw,nosuid,nodev,noexec,relatime,xattr,release_agent=/lib/systemd/systemd-cgroups-agent,name=systemd
|-/sys/fs/cgroup/pids             cgroup cgroup  rw,nosuid,nodev,noexec,relatime,pids
|-/sys/fs/cgroup/cpu,cpuacct      cgroup cgroup  rw,nosuid,nodev,noexec,relatime,cpu,cpuacct
|-/sys/fs/cgroup/devices          cgroup cgroup  rw,nosuid,nodev,noexec,relatime,devices
|-/sys/fs/cgroup/net_cls,net_prio cgroup cgroup  rw,nosuid,nodev,noexec,relatime,net_cls,net_prio
|-/sys/fs/cgroup/memory           cgroup cgroup  rw,nosuid,nodev,noexec,relatime,memory
|-/sys/fs/cgroup/hugetlb          cgroup cgroup  rw,nosuid,nodev,noexec,relatime,hugetlb
|-/sys/fs/cgroup/rdma             cgroup cgroup  rw,nosuid,nodev,noexec,relatime,rdma
|-/sys/fs/cgroup/blkio            cgroup cgroup  rw,nosuid,nodev,noexec,relatime,blkio
|-/sys/fs/cgroup/freezer          cgroup cgroup  rw,nosuid,nodev,noexec,relatime,freezer
|-/sys/fs/cgroup/cpuset           cgroup cgroup  rw,nosuid,nodev,noexec,relatime,cpuset
`-/sys/fs/cgroup/perf_event       cgroup cgroup  rw,nosuid,nodev,noexec,relatime,perf_event
```

If you check the contents of `/sys/fs/cgroup/unified/cgroup.controllers` you should see that there are no controllers enabled under cgroups v2.
The named 'systemd' v1 subsystem is included for compatibility with v1, where I believe Systemd actually uses the v2 mount for its tracking in this hybrid mode.

The different Systemd cgroup modes are discussed in [this email thread](https://lists.freedesktop.org/archives/systemd-devel/2017-November/039754.html) involving Lennart Poettering:
> hybrid means that v2 is used only for tracking services (which is a
good thing, since it provides safe notification of when a cgroup
exits), but not for any of the controllers. That means hybrid mode is
mostly compatible with pure v1, except that there's yet another
hierarchy (the v2 one) and systemd uses it for its own purposes.

The different modes are also described and explained at <https://systemd.io/CGROUP_DELEGATION/>.

Finally, another point of interest is Lennart's comment in 2018 on [this issue](https://github.com/systemd/systemd/issues/10107#issuecomment-424028793):
> Quite frankly at this point I think doing "hybrid" is a stopgap we should never have added... It blurs the road forward. People should either use full cgroupsv1 or full cgroupsv2 but anything in between is just a maintainance burden.


### Determining the active cgroup mode

Hopefully the above makes it clear that determining which cgroup version is in use is not as simple as you might initially think!

The main complication comes from the fact that different controllers can be enabled on different cgroup versions, plus there's no fixed path for the cgroup mount.
In practice, though, it should generally be safe to assume the path is `/sys/fs/cgroup`, and in many cases Systemd will be in charge of setting up cgroups and all controllers will be enabled on one or the other of v1 or v2.

The most robust way to check the cgroup version used by different controllers would seem to be by finding all mounts of type `cgroup` or `cgroup2` (e.g. with the `mount` command).
Cgroup v1 controllers will have their own `cgroup` mounts (as indicated in 'options'), while a `cgroup2` mount indicates the use of cgroups v2, and the `cgroup.controllers` file inside the mount directory can be used to check active v2 controllers.

A simpler, more practical approach in some cases might be to assume Systemd's three modes (legacy, hybrid and unified) cover all possible cases, and just to check the type of the `/sys/fs/cgroup` mount using `stat` (as recommended in <https://systemd.io/CGROUP_DELEGATION/>).
The hybrid case can be detected by checking for `/sys/fs/cgroup/unified`, although in general this setup should simply behave the same as v1.

Some other sources of information relating to cgroup version:
- '`systemd --version`' shows `default-hierarchy={legacy,hybrid,unified}`
- `/proc/cmdline` shows the kernel command-line args, e.g. used to override the default Systemd behaviour
- `/proc/1/cgroup` shows cgroup hierarchies for PID 1, e.g. `6:memory:/` for the v1 'memory' controller, `0::/init.scope` for the v2 unified hierarchy


### Switching cgroup mode

The kernel is not responsible for creating the cgroup mounts in userspace.
The init system may perform this setup (in the case of Systemd), or perhaps some user setup scripts.

As mentioned above, Systemd provides boot parameters to control which cgroup version it should use:
- `systemd.unified_cgroup_hierarchy=1` to use v2
- `systemd.legacy_systemd_cgroup_controller=1` to use pure v1 (not hybrid)

In addition, the kernel provides a `cgroup_no_v1` parameter to prevent controllers being enabled as v1 (e.g. set to '`all`' to disable all controllers on v1). Taken from the [kernel docs](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html#mounting):
> During transition to v2, system management software might still automount the v1 cgroup filesystem and so hijack all controllers during boot, before manual intervention is possible.
> To make testing and experimenting easier, the kernel parameter `cgroup_no_v1=` allows disabling controllers in v1 and make them always available in v2.


## Cgroups and Containers

Cgroups are fundamental to Linux containers, serving the following purposes:
- Resource limiting/sharing (memory, PIDs, CPUs, ...)
- Resource monitoring
- Controlling the group of processes (e.g. for stopping a container)

An extreme simplification of the container creation flow is:
- Create namespaces (PID namespace, UID/GID namespace, network namespace, ...)
- Create cgroup for the container's processes
- Chroot to the container's overlay filesystem

The Docker and Podman container orchestrators (or more likely their underlying container runtimes, `runc` and `crun`) set up the `/sys/fs/cgroup` mount inside the container, passing through [a subset of] the host's cgroup filesystem.

What I mean by this is that on the host there will be a cgroup corresponding to the container's processes, e.g. at `/sys/fs/cgroup/.../ctr1/`, and that this may be made to appear as the 'root' cgroup within the container at `/sys/fs/cgroup/` (conceptually like the cgroups have been namespaced, although there's some nuance to this discussed below).

In this section I'm going to focus on the how the cgroup filesystem is set up within containers and how this maps onto the host's cgroup filesystem.
I will go into detail around how this differs depending on variables such as the host's cgroup version and different container manager options.


### Containers and cgroups v2

First, for a bit of context, here's a timeline for cgroups v2 support in the Linux container ecosystem.
- Linux kernel v4.5 (2016) releases official support for cgroups v2
- Linux kernel v5.2 (2019) adds support for the 'freezer' controller, used for stopping containers
- Podman v1.6.4 and Crun (2019) adds support for cgroups v2 in Fedora v31 [[blog post](https://podman.io/blogs/2019/10/29/podman-crun-f31.html)]
- Docker v20.10 (2020) adds support for cgroups v2 (see [notes in the Docker docs](https://docs.docker.com/config/containers/runmetrics/#running-docker-on-cgroup-v2))

The Docker project uses a label to identify issues related to cgroups v2, which may be of interest to see the issues that have needed fixing and their timelines: [Docker `area/cgroup2` label](https://github.com/moby/moby/issues?q=label%3Aarea%2Fcgroup2+).


### Docker/Podman cgroup setup

Docker and Podman provide a few options to control how cgroups are set up.
The Podman options are listed [here](https://docs.podman.io/en/latest/markdown/podman-run.1.html#cgroup-conf-key-value).
There are also resource limiting options such as `--cpu-period=<limit>`, `--pids-limit=<limit>`, `--memory=<limit>` that are enforced using cgroups.

The variables I'm going to focus on are the following:
- Host cgroup version (v1 or v2)
- `--cgroupns` option ('host' or 'private' cgroup namespace)
- [`--cgroup-manager` Podman option](https://docs.podman.io/en/latest/markdown/podman.1.html#cgroup-manager-manager), or similarly [Docker's `cgroupdriver` daemon config](https://stackoverflow.com/questions/43794169/docker-change-cgroup-driver-to-systemd/65870152#65870152)

As far as I can tell, the behaviour under different combinations of these variables has been influenced by historical choices and backwards compatibility.
The situation is mostly the same between Docker and Podman, simply because Podman aims to closely mirror the Docker UI such that it can easily be dropped in as a replacement.


#### Cgroup namespace options

When Docker started out, cgroup namespaces did not exist as a kernel feature (added in v4.6, 2016), so they did the "next best thing" of just mounting the container's cgroup hierarchy (from the perspective of the host) as if it was the root inside the container.
For example, a container's cgroup file such as `/sys/fs/cgroup/cpuset/.../ctr1/cpuset.cpus` on the host would present itself at `/sys/fs/cgroup/cpuset/cpuset.cpus` inside the container.
This is desirable because the container has access to only its own cgroups (namespacing), but bad because the kernel is unaware of this pseudo-namespacing and therefore the `/proc/$PID/cgroup` mapping is broken.

Then cgroup namespaces as a kernel feature came along to address the problem, but Docker was unable to break backwards compatibility.
Instead, they kept the above behaviour by default and offered a `--cgroupns=private` option when creating a container to set up cgroup namespacing properly (fixing the issue with `/proc/$PID/cgroup`).

When cgroups v2 came along docker was able to start afresh and fix this behaviour.
So with cgroups v2 `--cgroupns=private` is the default (which behaves the same way as on cgroups v1), whereas `--cgroupns=host` now gives you access to the full host's cgroup mount inside the container.
Overall this seems like a much nicer position to be in than the cgroups v1 behaviour.


#### Cgroup driver options

The cgroup manager/driver appears to relate to how a container's cgroup is created and managed.
With Podman this can be controlled with the `--cgroup-manager` option [[docs](https://docs.podman.io/en/latest/markdown/podman.1.html#cgroup-manager-manager)], while with Docker it seems somewhat hidden and requires editing the `daemon.json` daemon config file.

There are two accepted values for this option: 'systemd' and 'cgroupfs'.
As far as I can tell, with 'systemd' the Systemd API will be used to set up cgroups, whereas with 'cgroupfs' the operations will be done by directly interacting with the filesystem.

The choice of cgroup driver affects where the container's cgroups appear in the host's cgroup hierarchy.
For example, for Podman, container cgroups are either placed under `machine.slice/libpod-<ctr>.scope/container/` (systemd) or `libpod_parent/libpod-<ctr>/` (cgroupfs), which makes sense if you're familiar with Systemd's 'slices' and 'scopes'.

There is some discussion of the options in the Kubernetes docs, where 'systemd' is recommended: <https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cgroup-drivers>.

To provide a bit of history, Docker originally used a mixture of Systemd APIs and direct cgroupfs access.
However, they had difficulty keeping up with Systemd API changes and so introduced the daemon flag in 2015, defaulting to 'cgroupfs' [[PR](https://github.com/moby/moby/pull/17704)].
Support for the 'systemd' option was added in Runc in 2016 [[PR](https://github.com/opencontainers/runc/pull/667)].
Under cgroups v2 Docker switched the default to 'systemd', and it seems Podman has always used this as the default.

Docker and Podman also have a related option `--cgroup-parent` for specifying the cgroup path to create the container cgroups under.


### Running Systemd inside a container

There are hard-line arguments for and against running Systemd inside containers.
The situation was summarised quite nicely in a [blog post](https://developers.redhat.com/blog/2016/09/13/running-systemd-in-a-non-privileged-container) written by Dan Walsh (RedHat) in 2016.

I'm not going to go into details around the debate here, but in short:
- the Docker community seems to disagree with some of Systemd's design and/or the idea that it's ever correct to use Systemd inside a container ("containers should do one thing")
- there are reasons to want a proper init system as PID 1 (hence the inception of simple init systems like [tini](https://github.com/krallin/tini))
- there are reasons to want the init system to be Systemd (e.g. to manage a long-running process such as a web server or simulate a larger system inside a container)

This section goes into detail about the technical side of getting Systemd running inside containers.


#### Introducing the problem

Inside a Docker/Podman container the `/sys/fs/cgroup` mount is automatically set up (presumably by the container runtime).
As explained above, this may represent the full host's cgroups or be a sub-hierarchy corresponding to the container's cgroups depending on the `--cgroupns` option and the cgroups version.
This may be in contrast to the host, where I believe the init system is responsible for creating the cgroup mounts.

When Systemd is started inside a container it detects its environment and tweaks certain elements of its behaviour based on it being inside a container virtualisation.
Most of these differences in behaviour are small, and include things like having a different shutdown behaviour.

Systemd is happy to start in an already-mounted cgroup setup, and it will then take ownership of the cgroup it finds itself in, creating further child cgroups for other system processes it manages.
As far as I'm aware this behaviour is no different inside a container to outside a container, except that inside a container it may actually be started in a non-root cgroup (where the host's root cgroup is treated as special under cgroups v2).

The main problem arises from the fact that Systemd expects to take ownership of the container's cgroups (including creating and modifying cgroups), and therefore write access to the cgroup mount(s) is required.
However, in non-privileged mode Docker sets up the mounts as read-only for the container.
I'm not exactly sure why the cgroup mounts are mounted read-only, at least in the cases where the container only has a view of its own cgroups...

(Note that in cgroups v1 it's the cgroup subsystem mounts that need to be writable - the containing tmpfs would only need to be writable to allow creating new cgroup mounts inside it, which is not something Systemd will generally need to do.)


#### Systemd inside Docker containers

There are a number of discussions on StackOverflow and issue trackers on the topic of running Systemd inside Docker containers [[1](https://github.com/moby/moby/issues/18796), [2](https://devops.stackexchange.com/questions/1635/is-there-any-concrete-and-acceptable-solution-for-running-systemd-inside-the-doc), [3](https://github.com/moby/moby/issues/30723), [4](https://github.com/systemd/systemd/issues/1224)].
The general recommendation (as per Systemd's declaration of the '[container interface](https://systemd.io/CONTAINER_INTERFACE/)') is to:
1. Explicitly mount the host's full cgroup filesystem into the container
2. Ensure `/run` is mounted as tmpfs
3. Provide the `SYS_ADMIN` capability
4. Specify the stop signal to be `SIGRTMIN+3`

Point 1 is required to override the container runtime's setup and allow write access to the subsystem mounts - by default Docker creates the cgroup mounts as read-only.
The arguments to pass in to achieve this are '`-v /sys/fs/cgroup:/sys/fs/cgroup:ro`' (or '`rw`' under cgroups v2).
Note that this can only be expected to work when using `--cgroupns=host`, otherwise the container will be set up as if it has a private cgroup namespace but the explicit mount will give the host's cgroups (see [Lennart's comment](https://github.com/systemd/systemd/issues/19245#issuecomment-815954506)), and that 'private' is the default under cgroups v2.

The downside of this is that the entirety of the host's cgroup filesystem is then available to the container, and the cgroup mounts are even writable!
This means the container can easily modify resource limits, including its own, which is far from ideal.

Points 2, 3 and 4 can be satisfied by passing '`--tmpfs /run --cap-add SYS_ADMIN --stop-signal SIGRTMIN+3`'.
Of course, it's not ideal to have to specify this extra capability, but Systemd requires it to create mounts private to the container.

Note that there is one alternative solution: to have a custom shell script entrypoint to perform some setup before calling '`exec /sbin/init`' to let Systemd take over as PID 1.
The setup that can be done is:
- ensure `/run` is mounted as a tmpfs, e.g. with '`mount tmpfs /run -t tmpfs`'
- remount the cgroupfs as read-write, e.g. with '`mount /sys/fs/cgroup -o remount,rw`' (*only works with cgroups v2*)

This removes the need to pass '`--tmpfs /run`' and '`-v /sys/fs/cgroup:/sys/fs/cgroup --cgroupns host`', with the biggest benefit being that a private cgroup namespace can be used, giving proper isolation within the container.


#### Podman's support for Systemd

Podman emulates Docker's behaviour by default, but also provides a `--systemd={false,true,always}` option to support setting up the container to be suitable for Systemd to run.
This was [introduced in 2019](https://developers.redhat.com/blog/2019/04/24/how-to-run-systemd-in-a-container#enter_podman).

The behaviour is as follows [[docs](https://docs.podman.io/en/latest/markdown/podman-run.1.html?highlight=systemd%3Dalways#systemd-true-false-always)]:
- `--systemd=false`: match Docker's behaviour
- `--systemd=true` (default): detect whether Systemd is the entrypoint and set up the container for Systemd to run
- `--systemd=always`: set up the container for Systemd to run regardless of the entrypoint


## Manual Cgroup Manipulation

As stated in the introduction, taken from the Linux manpages, the cgroup filesystem provides an interface to control cgroups via reading from/writing to special files.
Similarly, cgroups can be created/removed in the hierarchy using `mkdir` and `rmdir`.

For example, to restrict a process to run on a specific CPU this can be achieved as follows (on cgroups v1):
```bash
#!/bin/bash

cpuset_cgroup_path="/sys/fs/cgroup/cpuset"
# Create a new cgroup.
my_cgroup_path="$cpuset_cgroup_path/my-cgroup"
mkdir "$my_cgroup_path"
# Restrict to CPU 0 (also set the memory nodes).
echo 0 > "$my_cgroup_path/cpuset.cpus"
cat "$cpuset_cgroup_path/cpuset.mems" > "$my_cgroup_path/cpuset.mems"
# Start a process and move it to the custom cgroup.
sleep 100 &
echo $! > "$my_cgroup_path/cgroup.procs"
```

On cgroups v2 this is complicated slightly by the fact that leaf nodes (cgroups containing processes) cannot host child leaf nodes, and that the set of enabled controllers is managed by the parent cgroup.
Therefore, the equivalent to the above would be something like:
```bash
#!/bin/bash

root_cgroup_path="/sys/fs/cgroup"
# Enable the cpuset controller in child cgroups.
echo +cpuset > "$root_cgroup_path/cgroup.subtree_control"
# Create a new cgroup.
my_cgroup_path="$root_cgroup_path/my-cgroup"
mkdir "$my_cgroup_path"
# Restrict to CPU 0 (also set the memory nodes).
echo 0 > "$my_cgroup_path/cpuset.cpus"
cat "$cpuset_cgroup_path/cpuset.mems" > "$my_cgroup_path/cpuset.mems"
# Create another new cgroup to move all existing processes into.
mkdir "$root_cgroup_path/leaf"
while read line; do
  echo "$line" > "$root_cgroup_path/leaf/cgroup.procs"
done < "$root_cgroup_path/cgroup.procs"
# Start a process and move it to the custom cgroup.
sleep 100 &
echo $! > "$my_cgroup_path/cgroup.procs"
```

### Systemd cgroup ownership

Systemd's [Control Group APIs and Delegation](https://systemd.io/CGROUP_DELEGATION/) document describes the cgroups interface defined by the Systemd project.
As noted at the top, the intended audience is "hackers working on userspace subsystems that require direct cgroup access, such as container managers and similar".
In general the considerations in this document should be taken care of by the container manager (e.g Docker/Podman), however for cases where the container payload represents a 'system' itself this can become relevant.

The key point I want to focus on is the following:
> The single-writer rule: this means that each cgroup only has a single writer, i.e. a single process managing it.
> It's OK if different cgroups have different processes managing them.
> However, only a single process should own a specific cgroup, and when it does that ownership is exclusive, and nothing else should manipulate it at the same time.
> This rule ensures that various pieces of software don't step on each other's toes constantly.

This seems like a reasonably sensible concept, although it should be noted that this is an agreement that's been asserted by Systemd and not something that's been agreed more widely in the Linux community (as far as I'm aware).
That being said, if you're using Systemd as your init system then you should probably care about the API contracts Systemd provides!

By default Systemd (running as PID 1) will see itself as owning all cgroups.
The recommended mechanism for taking ownership of parts of the cgroup hierarchy is by using Systemd's *delegation*, primarily via `Delegate=` in scope/service files.

The document goes on to talk about running Systemd inside a container, where it states:
> systemd unconditionally needs write access to the cgroup tree however, hence you need to delegate a sub-tree to it.
> Note that there's nothing too special you have to do beyond that: just invoke systemd as PID 1 inside the root of the delegated cgroup sub-tree,  it will figure out the rest: it will determine the cgroup it is running in and take possession of it.
> It won't interfere with any cgroup outside of the sub-tree it was invoked in.

Bringing out some points/corollaries from the above explicitly:
- Container managers should be appropriately delegating container cgroups on Systemd systems such that the container manager (or the container itself) can take ownership of them.
  - This may be the purpose of using 'systemd' as the cgroupfs manager/driver, I'm not entirely sure.
- Containers should be able to 'own' the cgroup they exist in, since if Systemd is the payload then it expects to be able to take ownership!
- Systemd explicitly states that it will not interfere with cgroups above the cgroup it is invoked in.
