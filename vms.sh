#!/bin/bash

set -e

vms_path=$(realpath ~/vms)

# Default vm configuration
# Declare an associative array
declare -A config
config=(
    [graphic]="yes"
    [audio]="no"
    [boot]="menu=on"
    [ram]="12G"
    [cpu]="host"
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
    local file="$1" value
    while read -r value; do
        # Check if the line contains an equals sign
        if [[ $value = *?=* ]]; then
            # skip if it's a comment
            if [[ "$value" == \#* ]]; then
                continue
            fi
            local key=${value%%=*}
            config[$key]=${value#*=}
        fi
    done <"$file"
}

# Save config to a file
save_config() {
    local file="$1" key
    printf "### Default vm configuration\n" >"$file"
    for key in "${!config[@]}"; do
        printf "# %s=%s\n" "$key" "${config[$key]}" >>"$file"
    done
}

# Print the current config 
print_config() {
    local key
    for key in "${!config[@]}"; do
        printf "# %s=%s\n" "$key" "${config[$key]}"
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

# Print help information
usage() {
    printf "vms:
  vms path: %s 
  commands:
    $ vms run IMAGE_NAME
      $ vms run arch
    $ vms boot IMAGE_NAME ISO_PATH
      $ vms boot arch /path/to/arch.iso
    $ vms create IMAGE_NAME SIZE_OF_IMAGE
      $ vms create arch 50G
    $ vms list\n" "$vms_path"
    exit 1
}

# Run QEMU 
run_qemu() {

    load_config "$1"

    # Define the QEMU arguments
    local qemu_args=(
        --enable-kvm
        -bios "${config[bios_path]}"
        -boot "${config[boot]}"
        -m "${config[ram]}"
        -cpu "${config[cpu]}"
    )

    if [ -n "${config[net]}" ]; then
        qemu_args+=(-net "${config[net]}")
        local qemu_net_arg="user" ports
        for ports in ${config[ports]}; do
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

    if [[ "${config[graphic]}" == "yes" ]]; then
        qemu_args+=(-display "${config[display]}")
        for device in ${config[vgadevices]}; do
            qemu_args+=(-device "${device}")
        done

        if [[ "${config[audio]}" == "yes" ]]; then
            for device in ${config[audiodevices]}; do
                qemu_args+=(-device "${device}")
            done
        fi
    else
        qemu_args+=(-nographic)
    fi

    for device in ${config[devices]}; do
        qemu_args+=(-device "${device}")
    done

    qemu-system-x86_64 "${qemu_args[@]}" "${@:2}"
}

# Create a new vm
create_new_vm() {
    qemu-img create "$vms_path/$1.img" "$2"
}

# Create the vms directory if it doesn't exists
if [ ! -d "$vms_path" ]; then
    printf "Creating vms directory in %s\n" "$vms_path"
    mkdir -p "$vms_path"
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
    conf_path="$vms_path/$2.conf"

    file_exists "$img_path"
    file_exists "$conf_path"

    img_args=(
        -drive "file=$img_path,format=raw"
    )

    run_qemu "$conf_path" "${img_args[@]}"
    ;;

"boot")
    check_params $# 3

    img_path="$vms_path/$2.img"
    conf_path="$vms_path/$2.conf"
    iso_path=$(realpath "$3")

    file_exists "$img_path"
    file_exists "$iso_path"
    file_exists "$conf_path"

    img_args=(
        -drive "file=$img_path,format=raw"
        -cdrom "$iso_path"
    )

    run_qemu "$conf_path" "${img_args[@]}"
    ;;

"create")
    check_params $# 3

    iso_path="$vms_path/$2.iso"

    create_new_vm "$2" "$3"

    save_config "$vms_path/$2.conf"

    printf "Created %s Successfully!\n" "$2"
    printf "Please modify the config file: %s \n" "$vms_path/$2.conf"
    ;;

"list")
    for img in "$vms_path"/*.img; do
        printf " - %s\n" "$(basename "$img" .img)"
    done
    ;;

"help")
    usage
    ;;

*)
    printerr "error: command $1 not found"
    usage
    ;;
esac
