#!/bin/bash
# Komanda tik skaidoma: eval ir joje nurodyti vykdomieji failai nepaleidžiami.

statusline_words() {
  local input="$1" word="" quote="" escaped=false started=false ch i
  pom_words=()
  for ((i=0; i<${#input}; i++)); do
    ch="${input:i:1}"
    if $escaped; then
      if [ "$quote" = '"' ]; then
        case "$ch" in '"'|'\'|'$'|'`') ;; *) word+='\' ;; esac
      fi
      word+="$ch"; escaped=false; started=true
    elif [ "$ch" = '\' ] && [ "$quote" != "'" ]; then
      escaped=true; started=true
    elif [ -n "$quote" ]; then
      if [ "$ch" = "$quote" ]; then quote=""
      else
        if [ "$quote" = '"' ]; then
          case "$ch" in '$'|'`') return 1 ;; esac
        fi
        word+="$ch"
      fi
    else
      case "$ch" in
        '"'|"'") quote="$ch"; started=true ;;
        ' '|$'\t'|$'\n'|$'\r')
          if $started; then pom_words+=("$word"); word=""; started=false; fi ;;
        ';'|'|'|'&'|'<'|'>'|'$'|'`'|'('|')'|'{'|'}'|'*'|'?'|'['|']'|'#') return 1 ;;
        *) word+="$ch"; started=true ;;
      esac
    fi
  done
  [ -z "$quote" ] && ! $escaped || return 1
  if $started; then pom_words+=("$word"); fi
  [ "${#pom_words[@]}" -gt 0 ]
}

statusline_path() {
  local command="$1" base="${2:-$HOME}" i=0 option candidate
  statusline_words "$command" || return 1
  if [ "${pom_words[0]##*/}" = env ]; then
    i=1
    while [ "$i" -lt "${#pom_words[@]}" ] && [[ "${pom_words[i]}" == *=* ]]; do
      i=$((i + 1))
    done
  fi
  [ "$i" -lt "${#pom_words[@]}" ] || return 1
  case "${pom_words[i]##*/}" in
    bash|sh|zsh|dash|ksh)
      i=$((i + 1))
      while [ "$i" -lt "${#pom_words[@]}" ] && [[ "${pom_words[i]}" == -* ]]; do
        option="${pom_words[i]}"
        if [ "$option" = -- ]; then i=$((i + 1)); break; fi
        case "$option" in --*|*c*|*s*|*o*|*O*) return 1 ;; esac
        i=$((i + 1))
      done ;;
  esac
  [ "$i" -lt "${#pom_words[@]}" ] || return 1
  candidate="${pom_words[i]}"
  case "$candidate" in
    /*) printf '%s' "$candidate" ;;
    '~/'*) printf '%s/%s' "$base" "${candidate#\~/}" ;;
    *) return 1 ;;
  esac
}

resolve_script() {
  local path
  path=$(statusline_path "$1" "${pom_home:-$HOME}") || return 1
  [ -f "$path" ] || return 1
  printf '%s' "$path"
}

single_path() {
  # Kuriame tik vienu keliu nurodytą trūkstamą scenarijų.
  statusline_words "$1" || return 1
  [ "${#pom_words[@]}" -eq 1 ] || return 1
  statusline_path "$1" "${pom_home:-$HOME}"
}
