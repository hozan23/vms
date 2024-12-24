#!/bin/bash

set -e

vms_path=$(realpath ~/vms)
config_path="${vms_path}/config"
version="0.1.0"

# Default configuration
declare -A config
config=()

# Default vm configuration
declare -A vm_config
vm_config=(
    [graphic]="yes"
    [audio]="no"
    [boot]="menu=on"
    [ram]="12G"
    [cpu]="host"
    [nocow]="off"
    [image_format]="raw"
    [smp]=$(nproc)
    [display]="sdl,grab-mod=rctrl"
    [ports]="10022:22 8080:80"
    [audiodevices]="intel-hda hda-duplex"
    [vgadevices]="VGA,vgamem_mb=64"
    [devices]=""
    [bios_path]="/usr/share/qemu/bios.bin"
    [net]="nic"
)

# Load config from a file
load_config() {
    local -n conf=$1
    local file="$2" value
    while read -r value; do
        # Check if the line contains an equals sign
        if [[ $value = *?=* ]]; then
            # skip if it's a comment
            if [[ "$value" == \#* ]]; then
                continue
            fi
            local key=${value%%=*}
            conf[$key]=${value#*=}
        fi
    done <"$file"
}

# Save config to a file
save_config() {
    local -n conf=$1
    local file="$2" key
    printf "### Default configuration\n" >"$file"
    for key in "${!conf[@]}"; do
        printf "# %s=%s\n" "$key" "${conf[$key]}" >>"$file"
    done
}

# Print the given config 
print_config() {
    local -n conf=$1
    for k in "${!conf[@]}"; do
        printf "$k=${conf[$k]}\n"
    done
}

# Print error message to stderr
printerr() { printf "%s\n" "$*" >&2; }

# Check if a file exists
file_exists() {
    if [ ! -f "$1" ]; then
        printerr "error: file $1 not exist"
        exit 1
    fi
}

# Check if the number of parameters is correct
check_params() {
    if [ "$1" -lt "$2" ]; then
        printerr "error: wrong parameters"
        exit 1
    fi
}
# Load vm config 
load_vm_config() {
    vm_conf_path="$vms_path/$1.conf"
    file_exists "$vm_conf_path"
    load_config vm_config "$vm_conf_path"
}

# Run QEMU 
run_qemu() {
    # Define the QEMU arguments
    local qemu_args=(
        --enable-kvm
        -bios "${vm_config[bios_path]}"
        -boot "${vm_config[boot]}"
        -m "${vm_config[ram]}"
        -cpu "${vm_config[cpu]}"
        -smp "${vm_config[smp]}" 
    )

    if [ -n "${vm_config[net]}" ]; then
        qemu_args+=(-net "${vm_config[net]}")
        local qemu_net_arg="user" ports
        for ports in ${vm_config[ports]}; do
            IFS=':' read -ra p <<<"$ports"
            if [ ${#p[@]} != 2 ]; then
                printerr "error: wrong port: ${p[*]}"
                exit 1
            fi
            qemu_net_arg+=",hostfwd=tcp::${p[0]}-:${p[1]}"
        done

        qemu_args+=(-net "$qemu_net_arg")
    fi

    local device

    if [ "${vm_config[graphic]}" = "yes" ]; then
        qemu_args+=(-display "${vm_config[display]}")
        for device in ${vm_config[vgadevices]}; do
            qemu_args+=(-device "${device}")
        done

        if [ "${vm_config[audio]}" = "yes" ]; then
            for device in ${vm_config[audiodevices]}; do
                qemu_args+=(-device "${device}")
            done
        fi
    else
        qemu_args+=(-nographic)
    fi

    for device in ${vm_config[devices]}; do
        qemu_args+=(-device "${device}")
    done

    qemu-system-x86_64 "${qemu_args[@]}" "${@:1}"
}

# Create a new vm
create_new_vm() {
    local qemu_img_args=()

    qemu_img_args+=(-f)
    if [ -z "${vm_config[image_format]}" ]; then 
        qemu_img_args+=(raw)
    else
        qemu_img_args+=("${vm_config[image_format]}")
    fi

    qemu_img_args+=(-o)

    if [ "${vm_config[nocow]}" = "on" ]; then 
        qemu_img_args+=(nocow=on)
    fi

    if [ "${qemu_img_args[-1]}" = "-o" ]; then
        unset 'qemu_img_args[-1]'
    fi

    qemu-img create "$vms_path/$1.img" "$2" "${qemu_img_args[@]}"
}

# Print help information
usage() {
    printf "Usage: vms COMMAND [ARGS...]\n\n"
    printf "vms - A simple virtual machine management tool\n\n"
    printf "vms path: %s\n" "$vms_path"
    printf "Commands:\n"
    printf "  run VM_NAME\n"
    printf "    Start an existing virtual machine by its name.\n"
    printf "    Example:\n"
    printf "      $ vms run arch\n"
    printf "\n"
    printf "  boot VM_NAME ISO_PATH\n"
    printf "    Boot a virtual machine from a specific ISO file.\n"
    printf "    Useful for installation or live sessions.\n"
    printf "    - VM_NAME: Name of the virtual machine to boot.\n"
    printf "    - ISO_PATH: Path to the ISO file to boot from.\n"
    printf "    Example:\n"
    printf "      $ vms boot arch /path/to/arch.iso\n"
    printf "\n"
    printf "  create VM_NAME SIZE_OF_IMAGE\n"
    printf "    Create a new virtual machine image.\n"
    printf "    - VM_NAME: Name of the new virtual machine.\n"
    printf "    - SIZE_OF_IMAGE: Size of the virtual disk image\n"
    printf "        (e.g., 50G for 50 gigabytes).\n"
    printf "    Example:\n"
    printf "      $ vms create arch 50G\n"
    printf "\n"
    printf "  config VM_NAME\n"
    printf "    Print the configuration file for a virtual machine.\n"
    printf "    - VM_NAME: Name of the virtual machine.\n"
    printf "    Example:\n"
    printf "      $ vms config arch\n"
    printf "\n"
    printf "    Additional Usages for config:\n"
    printf "      config default\n"
    printf "        Print the default configuration used for creating new\n"
    printf "        virtual machines.\n"
    printf "        Example:\n"
    printf "          $ vms config default\n"
    printf "      config\n"
    printf "        Print the general configuration for the vms.\n"
    printf "\n"
    printf "  list\n"
    printf "    List all available virtual machines along with their current\n" 
    printf "    status (e.g., running, stopped).\n"
    printf "    Example:\n"
    printf "      $ vms list\n"
    printf "\n"
    printf "Options:\n"
    printf "  -h, --help\n"
    printf "    Show this help message and exit.\n"
    printf "Notes:\n"
    printf "  For further documentation, check out: https://github.com/hozan23/vms\n"
    exit 1
}


# Create the vms directory if it doesn't exists
if [ ! -d "$vms_path" ]; then
    printf "Creating vms directory in %s\n" "$vms_path"
    mkdir -p "$vms_path"
fi
#
# Create the config file if it doesn't exists
if [ ! -f "$config_path" ]; then
    printf "Creating config file %s\n" "$config_path"
    save_config config "$config_path" 
fi


# Print usage information if no arguments are provided
if [ -z "$1" ]; then
    usage
fi

# Ensure required commands are available
for cmd in qemu-img qemu-system-x86_64; do
    if ! command -v "$cmd" &>/dev/null; then
        printerr "error: $cmd is not installed"
        exit 1
    fi
done

case "$1" in
"run")
    check_params $# 2

    img_path="$vms_path/$2.img"
    file_exists "$img_path"

    load_vm_config $2 

    img_args=(
        -drive "file=$img_path,format=${vm_config[image_format]}"
    )

    run_qemu "${img_args[@]}"
    ;;

"boot")
    check_params $# 3

    img_path="$vms_path/$2.img"
    iso_path=$(realpath "$3")

    file_exists "$img_path"
    file_exists "$iso_path"

    load_vm_config $2 

    img_args=(
        -drive "file=$img_path,format=${vm_config[image_format]}"
        -cdrom "$iso_path"
    )

    run_qemu "${img_args[@]}"
    ;;

"create")
    check_params $# 3

    vm_conf_path="$vms_path/$2.conf"
    if [ -f "$vm_conf_path" ]; then
        load_config vm_config "$vm_conf_path"
    else 
        save_config vm_config "$vm_conf_path"
    fi

    create_new_vm "$2" "$3"

    printf "Created %s Successfully!\n" "$2"
    printf "Please modify the config file: %s \n" "$vms_path/$2.conf"
    ;;

"config")
    if [ "$#" -eq 1 ]; then
        load_config config "$config_path"
        print_config config 
    elif [ "$#" -eq 2 ]; then
        if [ "$2" = "default" ]; then 
            print_config vm_config 
        else
            load_vm_config $2 
            print_config vm_config 
        fi
    else
        printerr "error: wrong parameters"
        exit 1
    fi
    ;;

"list")
    for img in "$vms_path"/*.img; do
        printf " - %s " "$(basename $img .img)"
        if pgrep -f "$img" > /dev/null; then
            printf "(running)\n"
        else
            printf "(stopped)\n"
        fi
    done
    ;;

"-h" | "--help")
    usage
    ;;

"--version")
    printf "%s\n" $version
    ;;

*)
    printerr "error: command $1 not found"
    ;;
esac
