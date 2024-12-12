# vms

This script is a simple tool that uses QEMU to create, run, and manage virtual
machines.

It is a tool to simplify the management of multiple headless VMs without a
graphical interface, using tools like `ssh`, `sshfs`, and `rsync`. The script
uses minimal QEMU arguments to avoid excessive CPU usage. If you want to use 
`Spice` or other tools with QEMU, feel free to open a pull request to integrate
that into the configuration.

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
your home directory to store the images, and configs, for the VMs.

First, download the ISO image, for example, [arch linux](https://archlinux.org/download/). 

The following command will create a new image in `vms` direcotry using `qemu-img`
with the provided size, and create a config file.


```sh
$ vms create arch 50G 
```

Read/Modify the config file in: `/home/USER/vms/arch.conf`

Then you can boot from the ISO:

```sh
$ vms boot arch /home/USER/download/arch.iso
```

After installing, you can run this command whenever you want to run the VM:

```sh
$ vms run arch 
```

You can list all VMs by using this command:

```sh
$ vms list 
```

## Configuration

By default, the script uses the following configurations for the virtual
machines:

```sh
### Default vm configuration
# ram=12G
# cpu=host
# smp=$(nproc)
# graphic=yes
# audio=no
#
# Forward host port 10022 to guest port 22 and host port 8080 to guest port 80
# ports=10022:22 8080:80
#
# display=sdl,grab-mod=rctrl
# vgadevices=VGA,vgamem_mb=64
# audiodevices=intel-hda hda-duplex
# devices=
```

`display` and `vgadevices` values are added to QEMU arguments only if the
`graphic` are set to `yes`. Otherwise, the script will ignore them. By default,
the graphics are set to `yes` for the installation of the operating system. You
may disable it in the config file after the installation.

These default settings can be customized by modifying config files.
