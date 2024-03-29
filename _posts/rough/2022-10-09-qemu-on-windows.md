---
title: QEMU on Windows
layout: post
categories: [rough, coding]
tags: [qemu, virtualisation, windows]
---

This post goes through some basics of getting VMs running using QEMU on Windows.

## Basic Setup

It's easy enough to get QEMU running on Windows - simply find the QEMU download page and follow the link!
<https://www.qemu.org/download/#windows>

For convenience, I add the QEMU installation dir to my `PATH` (search 'Edit the systemd environment variables'), which is `C:\Program Files\qemu` for me (this is the directory containing the executables such as `qemu-img`).

The basic steps are then:
- Download a Linux ISO, e.g. from <https://ubuntu.com/download/desktop>
- Create a HDD file to install to: `qemu-img create -f qcow2 hdd.qcow2 50G`
- Run QEMU: `qemu-system-x86_64 -cdrom ubuntu-22.04.1-desktop-amd64.iso -drive file=hdd.qcow2`

The last step above should open up a window giving a graphical display for the VM, which will guide through steps to install from the ISO to the harddisk (`hdd.qcow`).
Once the installation is completed, the VM can be shut down, and subsequently started without the ISO file, e.g. with `qemu-system-x86_64 -drive file=hdd.qcow2`.


## Acceleration

On Linux [KVM](https://www.linux-kvm.org/) (a kernel virtualisation module) is generally used for acceleration.
On Windows [HAXM](https://github.com/intel/haxm/) must be used, as detailed at <https://www.qemu.org/2017/11/22/haxm-usage-windows/>.
You should see this listed as 'hax' if you run `qemu-system-x86_64 -accel help`.
If you run `qemu-system-x86_64 -accel hax` it should indicate whether HAXM is correctly set up (likely not by default!).

As per <https://github.com/intel/haxm/blob/master/docs/manual-windows.md#one-time-setup>, Hyper-V must be disabled since it makes exclusive use of the VT-x virtualisation.
This can be done by searching for 'Turn Windows features on or off', deselecting Hyper-V, and restarting.

Running `systeminfo` in Command Prompt should show a list of requirements under 'Hyper-V Requirements' at the bottom of the output.
However, I found that it instead shows "A hypervisor has been detected. Features required for Hyper-V will not be displayed.", which indicates Hyper-V has not been successfully disabled.
As per the HAXM docs linked above, the fix was to run `bcdedit /set hypervisorlaunchtype off` from Command Prompt run as admin.
Restart and check the output of `systeminfo` to confirm things are correctly set up.

HAXM can then be installed by downloading from their [releases page](https://github.com/intel/haxm/releases), unzipping, and running the setup executable.
This will check everything is set up correctly before installing.

If this all succeeds you can add `-accel hax` to your QEMU commands for your VMs to run much faster!
