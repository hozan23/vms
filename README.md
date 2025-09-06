# vms

A simple script to manage headless VMs

It is a tool to simplify the management of multiple headless VMs without a
graphical interface, using tools like `ssh`, `sshfs`, and `rsync`. The script
uses minimal QEMU arguments to avoid excessive CPU usage. If you want to use 
`Spice` or other tools with QEMU, feel free to open a pull request to integrate
that into the script.

## Prerequisites

Ensure you have the following commands installed:

- `qemu-img`
- `qemu-system-x86_64`

## Installation

Run:

```sh
$ make PREFIX=/home/USER/.local install  
```

## Usage

The first time you run `vms` command, it will create a `vms` directory under
your home directory to store vm images and config files.

First, download the ISO image, for example, [arch linux](https://archlinux.org/download/). 

The following command will create a new image in the `vms` direcotry using `qemu-img`
with the specified size and generate a config file.


```sh
$ vms create arch 50G -f qcow2 -o nocow=on 
```

Read/Modify the config file in: `/home/USER/vms/arch/config`

Then you can boot from the ISO file:

```sh
$ vms boot arch /home/USER/download/arch.iso
```

After installing, you can run this command whenever you want to start the VM:

```sh
$ vms start arch 
```

To stop the VM:

```sh
$ vms stop arch 
```

To list all VMs:

```sh
$ vms list 
```

## Configuration

By default, the script applies the following configurations to each new VM.

```sh
### Default vm configuration
smp=22
devices=
ram=12G
image_format=raw
nic=user
daemonize=off
cpu=host
ports=10022:22 8080:80
machine=
serial=none
bios=/usr/share/qemu/bios.bin
boot=menu=on
audiodev=
monitor=stdio
display=sdl
accel=kvm

```

These default configurations can be customized by modifying the config files for each vm.
