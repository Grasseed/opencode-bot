_openfox_completion() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"

  if [[ "$COMP_CWORD" -eq 1 ]]; then
    COMPREPLY=($(compgen -W 'start stop status configure uninstall help' -- "$cur"))
    return 0
  fi

  COMPREPLY=()
}

complete -F _openfox_completion openfox
