#!/bin/bash

set -e

vms_path=$(realpath ~/vms)
config_path="${vms_path}/config"

# Default configuration
declare -A config=()

# Default vm configuration
declare -A vm_config=(
    [accel]="kvm"
    [boot]="menu=on"
    [ram]="12G"
    [cpu]="host"
    [image]="image.img"
    [image_format]="raw"
    [drive_opts]=""
    [smp]=$(nproc)
    [display]="sdl"
    [monitor]="stdio"
    [serial]="none"
    [ports]="10022:22 8080:80"
    [daemonize]="off"
    [devices]=
    [bios]="/usr/share/qemu/bios.bin"
    [nic]="user"
    [machine]=""
    [audiodev]=""
)

declare -A qemu_flags=(
    [boot]=-boot
    [ram]=-m
    [cpu]=-cpu
    [smp]=-smp
    [monitor]=-monitor
    [accel]=-accel
    [bios]=-bios
    [machine]=-machine
    [audiodev]=-audiodev
    [display]=-display
    [serial]=-serial
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
    while read -r value || [ -n "$value" ]; do
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
        printf "%s=%s\n" "$key" "${conf[$key]}" >>"$file"
    done
}

print_config() {
    local -n conf=$1
    for k in "${!conf[@]}"; do
        printf "%s=%s\n" "$k" "${conf[$k]}"
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

check_vm_name() {
    case "$1" in
        ""|.|..|*/*) die "error: invalid VM name '$1'" ;;
    esac
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
        -pidfile "$vm_path/pid"
    )

    local key
    for key in "${!qemu_flags[@]}"; do
        if [ -n "${vm_config[$key]}" ]; then
            local val="${vm_config[$key]}"
            if [ "$key" = "monitor" ] && [ "$val" = "socket" ]; then
                val="unix:$vm_path/monitor.sock,server,nowait"
            fi
            qemu_args+=("${qemu_flags[$key]}" "$val")
        fi
    done

    if [ "${vm_config[daemonize]}" = "on" ]; then
        qemu_args+=(-daemonize)
    fi

    if [ -n "${vm_config[nic]}" ]; then
        local qemu_net_arg="${vm_config[nic]}"
        local ports p
        for ports in ${vm_config[ports]}; do
            IFS=':' read -ra p <<<"$ports"
            if [ ${#p[@]} != 2 ]; then
                die "error: wrong port: ${p[*]}"
            fi

            local host="${p[0]}"
            local guest="${p[1]}"

            if [[ "$host" == *-* || "$guest" == *-* ]]; then
                if [[ "$host" != *-* || "$guest" != *-* ]]; then
                    die "error: port range must be specified on both sides: $ports"
                fi

                local host_start=${host%-*}
                local host_end=${host#*-}
                local guest_start=${guest%-*}
                local guest_end=${guest#*-}

                if [ "$host_end" -lt "$host_start" ] || [ "$guest_end" -lt "$guest_start" ]; then
                    die "error: port range end before start: $ports"
                fi

                local host_count=$((host_end - host_start))
                local guest_count=$((guest_end - guest_start))

                if [ "$host_count" != "$guest_count" ]; then
                    die "error: port range mismatch: $ports"
                fi

                local i
                for ((i = 0; i <= host_count; i++)); do
                    qemu_net_arg+=",hostfwd=tcp::$((host_start + i))-:$((guest_start + i))"
                done
            else
                qemu_net_arg+=",hostfwd=tcp::${host}-:${guest}"
            fi
        done

        qemu_args+=(-nic "$qemu_net_arg")
    fi

    local device
    for device in ${vm_config[devices]}; do
        qemu_args+=(-device "${device}")
    done

    qemu-system-x86_64 "${qemu_args[@]}" "${@:1}"
}

create_new_vm() {
    local vm_name="$1"
    local image_size="$2"
    shift 2

    local qemu_img_args=()
    local format_set=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f)
                if [[ -n "$2" ]]; then
                    qemu_img_args+=(-f "$2")
                    vm_config[image_format]=$2
                    format_set=1
                    shift 2
                else
                    die "error: -f requires an argument"
                fi
                ;;
            -o)
                if [[ -n "$2" ]]; then
                    qemu_img_args+=(-o "$2")
                    shift 2
                else
                    die "error: -o requires an argument"
                fi
                ;;
            *)
                die "error: unknown option '$1'"
                ;;
        esac
    done

    mkdir -p "$vms_path/$vm_name"
    qemu-img create "${qemu_img_args[@]}" "$vms_path/$vm_name/${vm_config[image]}" "$image_size"
}


#
# END helper functions
#

# 
# BEGIN command functions
#

cmd_start() {
    check_params $# 1
    check_vm_name "$1"

    local vm_name=$1
    local vm_path="$vms_path/$vm_name"

    load_vm_config "$vm_name"

    local img_path="$vm_path/${vm_config[image]}"
    file_exists "$img_path"

    local img_args=(
        -drive "file=$img_path,format=${vm_config[image_format]}${vm_config[drive_opts]:+,${vm_config[drive_opts]}}"
    )

    run_qemu "$vm_path" "${img_args[@]}"
}

cmd_stop() {
    check_params $# 1
    check_vm_name "$1"

    local vm_name=$1
    local pid_path="$vms_path/$vm_name/pid"

    if [ -f "$pid_path" ]; then
        kill "$(cat "$pid_path")"
    else
        die "$vm_name is not running"
    fi
}


cmd_boot() {
    check_params $# 2
    check_vm_name "$1"

    local vm_name=$1
    local iso_path=$(realpath "$2")
    local vm_path="$vms_path/$vm_name"

    load_vm_config "$vm_name"

    local img_path="$vm_path/${vm_config[image]}"
    file_exists "$img_path"
    file_exists "$iso_path"

    local img_args=(
        -drive "file=$img_path,format=${vm_config[image_format]}${vm_config[drive_opts]:+,${vm_config[drive_opts]}}"
        -cdrom "$iso_path"
    )

    run_qemu "$vm_path" "${img_args[@]}"
}

cmd_create() {
    check_params $# 2
    check_vm_name "$1"
    local vm_name=$1
    local vm_path="$vms_path/$vm_name"
    local vm_conf_path="$vm_path/config"

    if [ -d "$vm_path" ]; then
        die "error:  VM '$vm_name'  already exists"
    fi

    if ! create_new_vm "$@"; then
        rm -rf "$vm_path"
        die "error: failed to create disk image"
    fi

    save_config vm_config "$vm_conf_path"

    printf "Created %s Successfully!\n" "$vm_name"
    printf "Please modify the config file: %s \n" "$vm_path/config"
    printf "\nVM Configuration:\n"
    printf "=================\n"
    print_config vm_config


}

cmd_clone() {
    check_params $# 2
    check_vm_name "$1"
    check_vm_name "$2"

    local source_vm_name=$1
    local target_vm_name=$2
    local source_vm_path="$vms_path/$source_vm_name"
    local target_vm_path="$vms_path/$target_vm_name"
    local source_config_path="$source_vm_path/config"
    local target_config_path="$target_vm_path/config"

    if [ ! -d "$source_vm_path" ]; then
        die "error: source VM '$source_vm_name' does not exist"
    fi

    file_exists "$source_config_path"

    if [ -d "$target_vm_path" ]; then
        die "error: target VM '$target_vm_name' already exists"
    fi

    load_vm_config "$source_vm_name"
    local source_format="${vm_config[image_format]}"
    local source_img_path="$source_vm_path/${vm_config[image]}"
    local target_img_path="$target_vm_path/${vm_config[image]}"

    file_exists "$source_img_path"

    printf "Cloning VM '%s' to '%s'...\n" "$source_vm_name" "$target_vm_name"

    mkdir -p "$target_vm_path"

    printf "Copying disk image (format: %s)...\n" "$source_format"
    if ! qemu-img convert -f "$source_format" -O "$source_format" "$source_img_path" "$target_img_path"; then
        # Clean up on failure
        rm -rf "$target_vm_path"
        die "error: failed to clone disk image"
    fi

    printf "Copying configuration...\n"
    if ! cp "$source_config_path" "$target_config_path"; then
        # Clean up on failure
        rm -rf "$target_vm_path"
        die "error: failed to copy configuration file"
    fi

    printf "Successfully cloned VM '%s' to '%s'\n" "$source_vm_name" "$target_vm_name"
    printf "You can now modify the config file: %s\n" "$target_config_path"
    printf "Note: You may want to update port mappings to avoid conflicts\n"
}

cmd_edit() {
    local editor="${EDITOR:-vi}"
    if [ "$#" -eq 0 ]; then
        exec "$editor" "$config_path"
    elif [ "$#" -eq 1 ]; then
        check_vm_name "$1"
        local vm_conf_path="$vms_path/$1/config"
        file_exists "$vm_conf_path"
        exec "$editor" "$vm_conf_path"
    else
        die "error: wrong parameters"
    fi
}

cmd_list() {
    for conf in "$vms_path"/*/config; do
        [ -f "$conf" ] || continue
        local vm_path=$(dirname "$conf")
        local vm_name=$(basename "$vm_path")
        local vm_status=""
        local pid_file="$vm_path/pid"
        if [ -f "$pid_file" ] && [ -d "/proc/$(cat "$pid_file" )" ]; then
            local pid=$(cat "$pid_file")
            local uptime=""
            if [ -f "/proc/$pid/stat" ]; then
                local starttime=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null)
                local boot_time=$(awk '/btime/ {print $2}' /proc/stat 2>/dev/null)
                if [ -n "$starttime" ] && [ -n "$boot_time" ]; then
                    local start_seconds=$((boot_time + starttime / 100))
                    local current_seconds=$(date +%s)
                    local uptime_seconds=$((current_seconds - start_seconds))

                    local days=$((uptime_seconds/86400))
                    local hours=$((uptime_seconds%86400/3600))
                    local minutes=$((uptime_seconds%3600/60))
                    local seconds=$((uptime_seconds%60))

                    uptime=$(printf "%dd %02d:%02d:%02d" "$days" "$hours" "$minutes" "$seconds")

                fi
            fi
            vm_status="RUNNING   PID: $pid - Uptime: ${uptime:-unknown}"
        fi
        printf " - %s %s\n" "$vm_name" "$vm_status"
    done
}

cmd_monitor() {
    check_params $# 1
    check_vm_name "$1"

    local vm_name=$1
    local sock="$vms_path/$vm_name/monitor.sock"

    if [ ! -S "$sock" ]; then
        die "error: monitor socket not found at $sock (is the VM running with monitor=socket?)"
    fi

    if ! command -v socat &>/dev/null; then
        die "error: socat is required for 'vms monitor' (install socat)"
    fi
    exec socat -,echo=0,icanon=0 "UNIX-CONNECT:$sock"
}

cmd_ports() {
    for conf in "$vms_path"/*/config; do
        [ -f "$conf" ] || continue
        local vm_path=$(dirname "$conf")
        local vm_name=$(basename "$vm_path")
        local -A conf_data=()
        load_config conf_data "$conf"
        printf " - %-20s %s\n" "$vm_name" "${conf_data[ports]:-(none)}"
    done
}

cmd_usage() {
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
	    Create a new virtual machine with SIZE (e.g., 50G).
	    Optional flags -f and -o will be passed directly to 'qemu-img create'
	    to specify image format and additional options.
	  vms clone SOURCE_VM_NAME TARGET_VM_NAME
	    clone an existing virtual machine to create a new one.
	    this copies both the disk image and configuration file.
	  vms list
	    List all available virtual machines along with their current
	    status (e.g., running, stopped).
	  vms ports
	    List all virtual machines along with their configured port mappings.
	  vms monitor VM_NAME
	    Attach to a VM's QEMU monitor socket.
	    Requires monitor=socket in the VM config and socat installed.
	  vms edit [VM_NAME]
	    Open the VM's config in \$EDITOR. If no VM_NAME is given,
	    opens the global vms config instead.
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
	
	                 v0.5.1
	
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
    exit 0
fi

case "$1" in
    start|boot|create|list|ports|monitor|edit) initialize ;;
esac

case "$1" in
start) shift;                   cmd_start "$@" ;;
stop) shift;                    cmd_stop "$@" ;;
boot) shift;                    cmd_boot "$@" ;;
create) shift;                  cmd_create "$@" ;;
clone) shift;                   cmd_clone "$@" ;;
list | ls) shift;               cmd_list "$@" ;;
ports) shift;                   cmd_ports "$@" ;;
monitor) shift;                 cmd_monitor "$@" ;;
edit) shift;                    cmd_edit "$@" ;;
help|-h|--help) shift;          cmd_usage "$@" ;;
version|-v|--version) shift;    cmd_version "$@" ;;
*)                              die "error: command $1 not found" ;;
esac
exit 0
