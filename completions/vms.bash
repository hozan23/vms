_vms() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local subcommands="start stop boot create clone list ls ports monitor console edit lock unlock sandbox help version"
    local sandbox_cmds="add rm list ls"

    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
        return
    fi

    local subcmd="${COMP_WORDS[1]}"
    local vms_dir="${HOME}/vms"

    _vms_names() {
        local names="" d
        for d in "$vms_dir"/*/; do
            [ -f "${d}config" ] && names+=" $(basename "$d")"
        done
        printf '%s' "$names"
    }

    # _vms_by_role ROLE: names of VMs whose config has role=ROLE
    _vms_by_role() {
        local names="" d
        for d in "$vms_dir"/*/; do
            grep -qx "role=$1" "${d}config" 2>/dev/null && names+=" $(basename "$d")"
        done
        printf '%s' "$names"
    }

    case "$subcmd" in
        start|stop|clone|monitor|console|lock|unlock)
            if [ "$COMP_CWORD" -eq 2 ]; then
                COMPREPLY=($(compgen -W "$(_vms_names)" -- "$cur"))
            fi
            ;;
        boot)
            if [ "$COMP_CWORD" -eq 2 ]; then
                COMPREPLY=($(compgen -W "$(_vms_names)" -- "$cur"))
            elif [ "$COMP_CWORD" -eq 3 ]; then
                COMPREPLY=($(compgen -f -X '!*.iso' -- "$cur"))
            fi
            ;;
        edit)
            if [ "$COMP_CWORD" -eq 2 ]; then
                COMPREPLY=($(compgen -W "$(_vms_names)" -- "$cur"))
            fi
            ;;
        sandbox)
            if [ "$COMP_CWORD" -eq 2 ]; then
                COMPREPLY=($(compgen -W "$sandbox_cmds" -- "$cur"))
            elif [ "$COMP_CWORD" -eq 3 ]; then
                case "${COMP_WORDS[2]}" in
                    add) COMPREPLY=($(compgen -W "$(_vms_by_role base)" -- "$cur")) ;;
                    rm) COMPREPLY=($(compgen -W "$(_vms_by_role sandbox)" -- "$cur")) ;;
                esac
            fi
            ;;
    esac
}
complete -F _vms vms
