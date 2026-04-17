_vms() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local subcommands="start stop boot create clone list ls ports monitor edit help version"

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

    case "$subcmd" in
        start|stop|clone|monitor)
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
    esac
}
complete -F _vms vms
