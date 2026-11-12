# _vms_names: names of all VMs
_vms_names() {
    local names="" d
    for d in "$HOME"/vms/*/; do
        [ -f "${d}config" ] && names+=" $(basename "$d")"
    done
    printf '%s' "$names"
}

# _vms_by_role ROLE: names of VMs whose config has role=ROLE
_vms_by_role() {
    local names="" d
    for d in "$HOME"/vms/*/; do
        grep -qx "role=$1" "${d}config" 2>/dev/null && names+=" $(basename "$d")"
    done
    printf '%s' "$names"
}

_vms() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local subcommands="start stop status log boot create clone list ls ports monitor console edit lock unlock sandbox help version"
    local sandbox_cmds="add rm list ls"

    if [ "$COMP_CWORD" -eq 1 ]; then
        mapfile -t COMPREPLY < <(compgen -W "$subcommands" -- "$cur")
        return
    fi

    local subcmd="${COMP_WORDS[1]}"

    case "$subcmd" in
        stop)
            if [ "$COMP_CWORD" -eq 2 ]; then
                mapfile -t COMPREPLY < <(compgen -W "-f $(_vms_names)" -- "$cur")
            elif [ "$COMP_CWORD" -eq 3 ] && [ "$prev" = "-f" ]; then
                mapfile -t COMPREPLY < <(compgen -W "$(_vms_names)" -- "$cur")
            fi
            ;;
        start|status|log|clone|monitor|console|lock|unlock)
            if [ "$COMP_CWORD" -eq 2 ]; then
                mapfile -t COMPREPLY < <(compgen -W "$(_vms_names)" -- "$cur")
            fi
            ;;
        boot)
            if [ "$COMP_CWORD" -eq 2 ]; then
                mapfile -t COMPREPLY < <(compgen -W "$(_vms_names)" -- "$cur")
            elif [ "$COMP_CWORD" -eq 3 ]; then
                # -X drops directories too, so add them back to walk into them
                compopt -o filenames
                mapfile -t COMPREPLY < <(compgen -f -X '!*.iso' -- "$cur"; compgen -d -- "$cur")
            fi
            ;;
        edit)
            if [ "$COMP_CWORD" -eq 2 ]; then
                mapfile -t COMPREPLY < <(compgen -W "$(_vms_names)" -- "$cur")
            fi
            ;;
        sandbox)
            if [ "$COMP_CWORD" -eq 2 ]; then
                mapfile -t COMPREPLY < <(compgen -W "$sandbox_cmds" -- "$cur")
            elif [ "$COMP_CWORD" -eq 3 ]; then
                case "${COMP_WORDS[2]}" in
                    add) mapfile -t COMPREPLY < <(compgen -W "$(_vms_by_role base)" -- "$cur") ;;
                    rm) mapfile -t COMPREPLY < <(compgen -W "$(_vms_by_role sandbox)" -- "$cur") ;;
                esac
            fi
            ;;
    esac
}
complete -F _vms vms
