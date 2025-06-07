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
$ vms create arch 50G 
```

Read/Modify the config file in: `/home/USER/vms/arch/config`

Then you can boot from the ISO:

```sh
$ vms boot arch /home/USER/download/arch.iso
```

After installing, you can run this command whenever you want to run the VM:

```sh
$ vms run arch 
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
cpu=host
smp=22
ram=12G
image_format=raw
bios_path=/usr/share/qemu/bios.bin
ports=10022:22 8080:80
net=nic
boot=menu=on
serial=none
monitor=stdio 
daemonize=off
display=sdl,grab-mod=rctrl
devices=intel-hda hda-duplex VGA,vgamem_mb=64

```

These default configurations can be customized by modifying the config files for each vm.
