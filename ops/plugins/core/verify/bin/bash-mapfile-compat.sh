#!/usr/bin/env bash
# Bash 3 compatibility shim for mapfile/readarray users.

set +u
if [[ -n "${SPINE_MAPFILE_COMPAT_CHAIN:-}" && -f "${SPINE_MAPFILE_COMPAT_CHAIN}" && "${SPINE_MAPFILE_COMPAT_CHAIN}" != "${BASH_SOURCE[0]}" ]]; then
  # shellcheck disable=SC1090
  source "${SPINE_MAPFILE_COMPAT_CHAIN}" || true
fi
set -u

if [[ "$(type -t mapfile 2>/dev/null || true)" == "" ]]; then
  mapfile() {
    local strip_newline=0
    if [[ "${1:-}" == "-t" ]]; then
      strip_newline=1
      shift
    fi

    local array_name="${1:-}"
    if [[ -z "$array_name" ]]; then
      echo "mapfile compat: missing target array name" >&2
      return 2
    fi

    local line
    local -a tmp=()
    while IFS= read -r line; do
      if [[ "$strip_newline" -eq 1 ]]; then
        tmp+=("$line")
      else
        tmp+=("${line}"$'\n')
      fi
    done

    eval "$array_name=()"
    local i quoted
    for ((i = 0; i < ${#tmp[@]}; i++)); do
      printf -v quoted '%q' "${tmp[$i]}"
      eval "$array_name[$i]=$quoted"
    done
  }
fi
