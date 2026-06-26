#!/usr/bin/env bash
# Open WebUI RAG - 대화형 메뉴 유틸리티

select_menu() {
  local __resultvar=$1
  shift
  local options=("$@")
  local i=1

  for option in "${options[@]}"; do
    printf "  %d) %s\n" "$i" "$option"
    i=$((i + 1))
  done

  printf "선택 [1]: "
  read -r choice
  choice=${choice:-1}

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#options[@]}" ]; then
    choice=1
  fi

  printf -v "$__resultvar" '%s' "$choice"
}