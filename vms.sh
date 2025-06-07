#!/bin/bash

set -e

vms_path=$(realpath ~/vms)
config_path="${vms_path}/config"

# Default configuration
declare -A config
config=()

# Default vm configuration
declare -A vm_config
vm_config=(
    [boot]="menu=on"
    [ram]="12G"
    [cpu]="host"
    [nocow]="off"
    [image_format]="raw"
    [smp]=$(nproc)
    [display]="sdl,grab-mod=rctrl"
    [monitor]="stdio"
    [serial]="none"
    [ports]="10022:22 8080:80"
    [daemonize]="off"
    [devices]="intel-hda hda-duplex VGA,vgamem_mb=64"
    [bios_path]="/usr/share/qemu/bios.bin"
    [net]="nic"
)

#
# BEGIN helper functions
#

initialize() {
    if [ ! -d "$vms_path" ]; then
        printf "Creating vms directory in %s\n" "$vms_path"
        mkdir -p "$vms_path"
    fi

    if [ ! -f "$config_path" ]; then
        printf "Creating config file %s\n" "$config_path"
        save_config config "$config_path" 
    fi

    for cmd in qemu-img qemu-system-x86_64; do
        if ! command -v "$cmd" &>/dev/null; then
            die "error: $cmd is not installed"
        fi
    done
}

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

save_config() {
    local -n conf=$1
    local file="$2" key
    printf "### Default configuration\n" >"$file"
    for key in "${!conf[@]}"; do
        printf "# %s=%s\n" "$key" "${conf[$key]}" >>"$file"
    done
}

print_config() {
    local -n conf=$1
    for k in "${!conf[@]}"; do
        printf "$k=${conf[$k]}\n"
    done
}

die() {
    echo "$@" >&2
    exit 1
}

file_exists() {
    if [ ! -f "$1" ]; then
        die "error: file $1 not exist"
    fi
}

check_params() {
    if [ "$1" -lt "$2" ]; then
        die "error: wrong parameters"
    fi
}

load_vm_config() {
    vm_conf_path="$vms_path/$1/config"
    file_exists "$vm_conf_path"
    load_config vm_config "$vm_conf_path"
}

run_qemu() {
    local vm_path=$1
    shift
    # Define the QEMU arguments
    local qemu_args=(
        --enable-kvm
        -bios "${vm_config[bios_path]}"
        -boot "${vm_config[boot]}"
        -m "${vm_config[ram]}"
        -cpu "${vm_config[cpu]}"
        -smp "${vm_config[smp]}" 
        -pidfile "$vm_path/pid"
        -monitor "${vm_config[monitor]}"
    )

    if [ -n "${vm_config[net]}" ]; then
        qemu_args+=(-net "${vm_config[net]}")
        local qemu_net_arg="user" ports
        for ports in ${vm_config[ports]}; do
            IFS=':' read -ra p <<<"$ports"
            if [ ${#p[@]} != 2 ]; then
                die "error: wrong port: ${p[*]}"
            fi
            qemu_net_arg+=",hostfwd=tcp::${p[0]}-:${p[1]}"
        done

        qemu_args+=(-net "$qemu_net_arg")
    fi

    local device

    qemu_args+=(-display "${vm_config[display]}")

    if [ "${vm_config[daemonize]}" = "on" ]; then
        qemu_args+=(-daemonize)
    fi

    for device in ${vm_config[devices]}; do
        qemu_args+=(-device "${device}")
    done

    qemu-system-x86_64 "${qemu_args[@]}" "${@:1}" 
}

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

    qemu-img create "$vms_path/$1/$1.img" "$2" "${qemu_img_args[@]}"
}


#
# END helper functions
#

# 
# BEGIN command functions
#

cmd_start() {
    check_params $# 1

    local vm_path="$vms_path/$1"
    local img_path="$vm_path/$1.img"
    file_exists "$img_path"

    load_vm_config $1

    local img_args=(
        -drive "file=$img_path,format=${vm_config[image_format]}"
    )

    run_qemu $vm_path "${img_args[@]}"
}

cmd_stop() {
    check_params $# 1

    local pid_path="$vms_path/$1/pid"
    if [ -f $pid_path ]; then
        kill "$(cat $pid_path)"
    else
        die "$1 is not running"
    fi
}


cmd_boot() {
    check_params $# 2

    local vm_path="$vms_path/$1"
    local img_path="$vm_path/$1.img"
    local iso_path=$(realpath "$2")

    file_exists "$img_path"
    file_exists "$iso_path"

    load_vm_config $1

    local img_args=(
        -drive "file=$img_path,format=${vm_config[image_format]}"
        -cdrom "$iso_path"
    )

    run_qemu $vm_path "${img_args[@]}"
}

cmd_create() {
    check_params $# 2

    local vm_path="$vms_path/$1"
    mkdir -p $vm_path 

    local vm_conf_path="$vm_path/config"
    if [ -f "$vm_conf_path" ]; then
        load_config vm_config "$vm_conf_path"
    else 
        save_config vm_config "$vm_conf_path"
    fi

    create_new_vm "$1" "$2"

    printf "Created %s Successfully!\n" "$1"
    printf "Please modify the config file: %s \n" "$vm_path/config"

}

cmd_config() {
    if [ "$#" -eq 0 ]; then
        load_config config "$config_path"
        print_config config 
    elif [ "$#" -eq 1 ]; then
        if [ "$1" = "default" ]; then 
            print_config vm_config 
        else
            load_vm_config $1 
            print_config vm_config 
        fi
    else
        die "error: wrong parameters"
    fi
}

cmd_list() {
    for img in "$vms_path"/*/*.img; do
        local vm_path=$(dirname $img)
        local vm_name=$(basename $img .img)
        local vm_status=""
        if [ -f "$vm_path/pid" ] && [ -d "/proc/$(cat "$vm_path/pid")" ]; then
            local vm_status="(running PID: $(cat "$vm_path/pid"))"
        fi
        printf " - %s %s\n" "$vm_name" "$vm_status"
    done
}

cmd_usage() {
    echo
	cat <<-_EOF
	Usage: vms COMMAND [ARGS...]
	vms path:  $vms_path
	Commands:
	  vms start VM_NAME
	    Start an existing virtual machine.
	  vms stop VM_NAME
	    Stop a running virtual machine.
	  vms boot VM_NAME ISO_PATH
	    Boot a virtual machine from a specific ISO file.
	    - ISO_PATH: Path to the ISO file to boot from.
	  vms create VM_NAME SIZE_OF_IMAGE
	    Create a new virtual machine image.
	    - SIZE_OF_IMAGE: Size of the virtual disk image
	        (e.g., 50G for 50 gigabytes).
	  vms config VM_NAME
	    Print the configuration file for a virtual machine.
	    Additional Usages:
	      config default
	        Print the default configuration used for creating new
	        virtual machines.
	      config
	        Print the global configuration for the vms.
	  vms list
	    List all available virtual machines along with their current 
	    status (e.g., running, stopped).
	  vms version 
	    Show version information.
	Options:
	  -h, --help
	    Show this help message and exit.
	_EOF
}

cmd_version() {
	cat <<-_EOF
	===========================================
	vms: a simple script to manage headless VMs
	
	                 v0.2.0
	
	                 hozan23
	          hozan23@karyontech.net
	      https://github.com/hozan23/vms
	===========================================
	_EOF
}

# 
# END command functions
#
if [ -z "$1" ]; then
    cmd_usage
fi

case "$1" in
    start|boot|create|list|config|monitor) initialize ;;
esac

case "$1" in
start) shift;                   cmd_start "$@" ;; 
stop) shift;                    cmd_stop "$@" ;; 
boot) shift;                    cmd_boot "$@" ;; 
create) shift;                  cmd_create "$@" ;; 
list) shift;                    cmd_list "$@" ;; 
config) shift;                  cmd_config "$@" ;; 
help|-h|--help) shift;          cmd_usage "$@" ;;
version|-v|--version) shift;    cmd_version "$@" ;;
*)                              die "error: command $1 not found" ;;
esac
exit 0
