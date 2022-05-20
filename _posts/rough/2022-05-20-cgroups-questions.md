---
title: Cgroups Questions
layout: post
categories: [coding, rough]
tags: [linux, cgroups, questions]
---

This is a rough post to summarise a few open questions I have about Linux cgroups in the context of containers and running Systemd, following on from my [Cgroups Introduction post](/blog/coding/2022/05/13/cgroups-intro).

If anyone has any answers please get in touch!
My contact details can be found in the bottom-right of each page.


## Why are private cgroups mounted read-only in non-privileged containers?

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


## Is it sound to override Docker's mounting of the private container cgroups under v1?

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
Or perhaps it would even be possible to create a cgroup namespace from within the container (if the kernel supports it)?

However, this is getting beyond the normal responsibilities of a container's init system, as this is supposed to all be set up by the container engine!

**Is modifying/replacing the cgroup mounts set up by the container engine a reasonable workaround, or could this be fragile?**


## When is it valid to manually manipulate container cgroups?

This relates to the two questions above - in the case where we have a private cgroup namespace with the cgroups writable inside the container, can the container 'own' this part of the cgroup hierarchy?
From the setup described it seems like the answer should certainly be 'yes', but in practice it seems it could be a bit more nuanced based on some statements made in Systemd documentation.

On a host running Systemd as its init system (PID 1), Systemd 'owns' all cgroups by default.
Whenever another process wants to modify/create cgroups the expectation is that a part of the hierarchy is 'delegated' using a Systemd API or config file (e.g. `Delegate=true`), as explained under 'Delegation' at <https://systemd.io/CGROUP_DELEGATION/>.
As made clear in the linked document, cgroup managers (such as Docker) are expected to tell Systemd that they wish to own a part of the cgroup hierarchy to avoid "treading on each other's toes" when new cgroups are created for each container.

Assuming this is respected by the container manager (if it isn't then any problems can partially be blamed on the Systemd/container manager API!), the container's cgroups should not be managed by the host's Systemd.
This means that as long as the container manager allows it, the container (or more specifically the processes running inside the container namespace) should be safe to make modifications.

**Do container managers such as Docker and Podman correctly delegate cgroups on hosts running Systemd?**

**Are these container managers happy for the container to take ownership of the container's cgroup?**

In the case where Systemd is run inside the container, surely it wants to take ownership of the the hierarchy from the point it finds itself in (as discussed in the [Systemd cgroup ownership](/blog/coding/2022/05/13/cgroups-intro/#systemd-cgroup-ownership) section of my previous post).
Therefore, if running Systemd inside a container is considered 'valid', then surely it's also valid for a container to modify its cgroups instead of/before running Systemd?


## Why are the container's cgroup limits not set on a parent cgroup under Docker/Podman?

There are some Docker/Podman options for enforcing a limit via a cgroup controller.
For example '`docker run --memory 10000000`' where a memory limit is applied to the container via the memory cgroup controller.
This seems to be achieved by setting the limit with the `/sys/fs/cgroup/memory/docker/<ctr>/memory.limit_in_bytes` cgroup file.
This maps to `/sys/fs/cgroup/memory/memory.limit_in_bytes` inside the container, i.e. the container can see the limit that's been applied in its root cgroup directory.

A consequence of this is that the container can see (and modify if it has write permissions) the limit that's been imposed!
This feels like a mild situation of 'container break-out', where the container isolation is broken.

**Why doesn't Docker use another layer of indirection in the cgroup hiearchy such that the limit is applied in the parent cgroup to the container?**

That is, wouldn't it be better for there to be a cgroup `/sys/fs/cgroup/<ctrlr>/docker/<ctr>/container/` that maps to `/sys/fs/cgroup/<ctrlr>/` inside the container, with any resource limits set on the `/sys/fs/cgroup/<ctrlr>/docker/<ctr>/` cgroup?


## What happens if you have two of the same cgroup mount?

Cgroup mounts can be created anywhere, although the standard location is under `/sys/fs/cgroup`.
It's fairly easy to check what happens when you create further cgroup mounts (e.g. in addition to the standard `/sys/fs/cgroup` ones), simply by running something like '`mkdir /cgroups && mount -t cgroup /sys/fs/cgroup cgroup /cgroups -o <ctrlr>`'.

It appears that all cgroup mounts (of the same type) will share the same contents, which makes sense if you consider the cgroupfs simply reflects what's been configured via the kernel (it's effectively just an interface onto kernel configuration).

Presumably the same thing is true inside a container (and experimentally this seems to be the case - there's no reason for it to be different that I can think of!).
By default (on cgroups v1, with `--cgroupns=host`) Docker sets up the cgroup bind mounts to give the illusion of a private cgroup namespace.
However, as long as the container has `CAP_SYS_ADMIN` it is possible to simply mount the cgroupfs and get read-write access to the full host's cgroups.

The container case is one of the main cases I can think of where you might want multiple copies of cgroup mounts (albeit in separate mount namespaces).

**Is the understanding above correct, and are there any gotchas/concerns around manipulating cgroups via multiple mount points?**


## What's the correct way to check which controllers are enabled?

It's possible for there to be no mount for a v1 controller that shows up in `/proc/$PID/cgroup` - you can see this by unmounting one of the cgroup mounts in `/sys/fs/cgroup/`.

**What is it that determines which controllers are *enabled*? Is it kernel configuration applied at boot?**

On cgroups v2 it seems the `/sys/fs/cgroup/cgroup.controllers` file lists the enabled controllers (although can this be modified at system runtime?).

A related question is when controllers can be enabled for cgroups v1/v2 in combination:

**Is it the case that there can only be *any controllers* enabled for v1 or v2 at any one time, or is it the case that *each controller* can only be enabled for v1 or v2?**
