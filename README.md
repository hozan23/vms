# vms - simple headless VM manager

vms is a small bash script to manage multiple headless QEMU VMs
without a graphical interface. It uses minimal QEMU arguments to
avoid excessive CPU usage and is meant to be driven over ssh,
sshfs, and rsync.

## Requirements

`qemu-img` and `qemu-system-x86_64`.

Optional: `socat`, to use `vms monitor` and `vms console`.

## Installation

Enter the following command:

```sh
make PREFIX=~/.local install
```

## Usage

The first invocation creates `~/vms` to hold VM images and configs.

Create a new VM image:

```sh
vms create arch 50G
```

Extra arguments are passed straight to qemu-img, e.g. to use
qcow2 with nocow:

```sh
vms create arch 50G -f qcow2 -o nocow=on
```

Review or tweak the VM config in `$EDITOR` (or the global config
if no name is given), then boot from an ISO:

```sh
vms edit arch
vms boot arch ~/downloads/arch.iso
```

Once installed, start and stop:

```sh
vms start arch
vms stop arch
```

Extra arguments go to qemu, e.g. discard disk writes on exit:

```sh
vms start arch -snapshot
```

List all VMs, or just their port mappings:

```sh
vms list
vms ports
```

Attach to a running VM's QEMU monitor or serial console:

```sh
vms monitor arch
vms console arch
```

Clone a VM (copies both the disk image and the config):

```sh
vms clone arch arch2
```

## Sandboxes

A sandbox is a throwaway VM over a locked base. Lock a stopped
VM, then add sandboxes from it:

```sh
vms lock arch
vms sandbox add arch task1
vms start task1
vms stop task1
vms sandbox rm task1
vms sandbox list
```

A sandbox is a normal VM otherwise. Extra `sandbox add` arguments
go to qemu-img verbatim, e.g. `-o nocow=on`. `unlock` makes a base
an ordinary VM again once it has no sandboxes. Do not modify a
locked image by hand while sandboxes exist.

## Configuration

Each VM has a config file at `~/vms/NAME/config` containing
`key=value` lines. Default values:

```
smp=<nproc>
ram=12G
cpu=host
accel=kvm
sandbox=
image=image.img
image_format=raw
drive_opts=
ports=10022:22 8080:80
nic=user
netdev=
display=none
monitor=socket
serial=socket
boot=menu=on
bios=/usr/share/qemu/bios.bin
machine=
audiodev=
kernel=
initrd=
append=
objects=
fsdev=
chardev=
devices=
virtfs=
daemonize=on
role=
base=
```

`role` and `base` are set by lock, unlock and sandbox. `nic`, `netdev`
and `sandbox` go to QEMU verbatim; `ports` are appended to whichever
of `nic` or `netdev` is user-mode or passt.

## Port ranges

The `ports` field supports port ranges. Both sides must have the
same number of ports.

```
# single port mapping
ports=10022:22

# range mapping: host 10022-10025 -> guest 22-25
ports=10022-10025:22-25
```

## Network isolation

`nic=user` lets the guest reach the host and the internet.
`nic=user,restrict=on` blocks both. For internet without host access
from the guest use
[passt](https://www.qemu.org/docs/master/system/devices/net.html#using-passt-as-the-user-mode-network-stack).
`sandbox=on` enables QEMU's seccomp filter; it cannot be combined with
`netdev=passt`, since the filter kills the passt process QEMU spawns.

## Sharing a host directory

Export a directory over 9p and mount it in the guest by its tag:

```
virtfs=local,path=/home/x/projects,mount_tag=projects,security_model=none
```

On the guest VM:

```sh
mount -t 9p -o trans=virtio,version=9p2000.L projects /home/x/projects
```

Or permanently, in `/etc/fstab` on the guest:

```
projects  /home/x/projects  9p  trans=virtio,version=9p2000.L,nofail,_netdev  0  0
```

## Microvm

You can also enable [QEMU microvm](https://www.qemu.org/docs/master/system/i386/microvm.html).

## Monitor and console

`monitor=socket` and `serial=socket` create `~/vms/NAME/monitor.sock` and
`serial.sock`; `vms monitor` and `vms console` connect via socat. New
VMs have `display=none`; set `display=sdl` for a graphical installer.
