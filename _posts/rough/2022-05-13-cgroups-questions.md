---
title: Cgroups Questions
layout: post
categories: [coding, rough]
tags: [linux, cgroups, questions]
---

This is a rough post to summarise a few open questions I have about Linux cgroups in the context of containers and running Systemd, following on from my [Cgroups Introduction post](/blog/coding/2022/05/13/cgroups-intro).

If anyone has any answers please get in touch!
My contact details can be found in the bottom-right of each page.


### Why are private cgroups mounted read-only in non-privileged containers?

As per [Introducing the problem](/blog/coding/2022/05/13/cgroups-intro/#introducing-the-problem) in my previous post.
I assume Podman does this mainly to mirror Docker's behaviour, so the real question is why Docker has this behaviour.

It would make sense in the case where the host's cgroups are available to the container, but in the isolated case (cgroups v1 with the 'pseudo private' cgroups under `--cgroupns=host`, or cgroups v1/v2 under `--cgroupns=private`) I'm not sure why this restriction is needed.

Taking a step back, a fundamental part of containers is the namespaces that are used.
- The filesystem chroot (the root directory `/` is owned by the container)
- The network namespace (all ports and IP addresses are available to the container unless host networking is used)
- PID namespace (containers have their own PID 1 init process)
- UID and GID namespaces (the `root` user is available in the container even if the container is not run by root)
- Cgroup namespace (only the container's cgroups are visible to the container by default, made available at `/sys/fs/cgroup/`)

In each case, the privileges *within the container* may be higher than on the host due to the isolation provided, e.g. writing to `/`, running applications on port 80, running as `root`.

**So why are the container's cgroups not made writable?**

Is it just that the original design of Docker didn't/doesn't cater for running anything more than a simple single-process app?


### Is it sound to override Docker's mounting of the private container cgroups under v1?

Under cgroups v1 (`--cgroupns=host` as per the default), `/sys/fs/cgroup/<subsystem>/docker/<container>/` on the host is mapped to `/sys/fs/cgroup/<subsystem>/` within the container.
This is achieved using bind mounts rather than cgroup namespaces (since cgroup namespaces didn't exist when this was first implemented).
When `--cgroupns=private` is used (the default on cgroups v2) the same mapping is set up, but it is achieved via true cgroup namespaces.

When running Systemd the cgroup mounts under `/sys/fs/cgroup/` (or at least `/sys/fs/cgroup/systemd`) are required to be mounted read-write (not read-only).
A common recommendation for achieving this with Docker is to pass  `-v /sys/fs/cgroup:/sys/fs/cgroup:ro`.
This setup ensures the container has full read-write access to the v1 cgroup subsystem mounts inside the `/sys/fs/cgroup` tmpfs.
Note that even if the `/sys/fs/cgroup` tmpfs mount is passed as read-only, Systemd requires the `SYS_ADMIN` capability which allows mounting, so inside the container it's possible to remount and make the mount writable.
Overall this approach involves giving the container a lot of control over the host's cgroup filesystem!

Note that when `-v /sys/fs/cgroup:/sys/fs/cgroup` is passed it's definitely a bad idea to use `--cgroupns=private` because the container would then be set up with a private cgroup namespace but actually have access to the full host cgroups at `/sys/fs/cgroup` (so none of the paths would be as expected).

When using this workaround the container has full write access to all of the host's cgroups, which is very bad in terms of isolation - it opens the door to many ways of *killing the host system* by restricting resources or otherwise.

**Are there any *other* concerns with this approach in terms of the container's view of its cgroups?**

Passing in `/sys/fs/cgroup` seems to certainly be against the way Docker was designed, considering Docker sets the cgroup filesystem up in its own way and this approach just blats over the top...

All we really want is a way to make the (private) cgroup mounts writable inside the container!
If you run '`mount -o remount,rw /sys/fs/cgroup/<subsystem>`' inside a container under cgroups v1 you get the message "mount point is busy".
Presumably this is because a Docker process (`containerd`?) owns the mount and exists outside of the container's namespaces?

It seems possible to manually set up the container's cgroup mounts inside the container, taking over Docker's responsibility of setting this up to workaround the write permissions.
Inside the container you could use an entrypoint that does something like the following to mirror Docker's 'host' cgroups on v1:
```bash
#!/bin/bash

# Move the host cgroups somewhere else.
mkdir /host-cgroups
mount --move /sys/fs/cgroup /host-cgroups
# Create the container cgroup tmpfs.
mount -t tmpfs cgroup /sys/fs/cgroup
# For each controller bind-mount from the host cgroups.
controllers=(memory cpu,cpuacct cpuset pids hugetlb freezer perf_event net_cls,net_prio blkio devices)
for ctrlr in "${controllers[@]}"; do
  mkdir "/sys/fs/cgroup/$ctrlr"
  cgroup_subpath=$(grep ":$ctrlr:/" /proc/1/cgroup | cut -d ':' -f 3)
  mount --bind "/host-cgroups/$ctrlr$cgroup_subpath" "/sys/fs/cgroup/$ctrlr"
done
# Clean up.
umount --recursive /host-cgroups
rmdir /host-cgroups

# Start systemd or other init system/entrypoint.
exec /sbin/init
```

Alternatively, the cgroup mounts set up by Docker inside the container could simply be unmounted and replaced with 'normal' cgroup mounts (instead of the pseudo-namespaced bind mounts that Systemd [explicitly states](https://systemd.io/CGROUP_DELEGATION/) they believe is *not* a valid approach).
Or perhaps it would even be possible to create a cgroup namespace from within the container (if the kernel supports it).

However, this is getting beyond the normal responsibilities of a container's init system, as this is supposed to all be set up by the container engine!

**Is modifying/replacing the cgroup mounts set up by the container engine a reasonable workaround, or could this be fragile?**


### What happens if you have two of the same cgroup mount?

TODO


### When is it valid to manually manipulate container cgroups?

TODO
