#!/usr/bin/env bash
# Portable stdin-to-array helper compatible with Bash 3.2 (macOS)
set -euo pipefail

# Usage:
#   mapfile_compat ARRAY_NAME
#   producer | mapfile_compat arr
mapfile_compat() {
  : "${1:?array name required}"
  local __name
  __name="${1}"
  local __line
  local -a __arr
  __arr=()
  while IFS= read -r __line; do
    __arr+=("${__line}")
  done
  # shellcheck disable=SC2086
  eval ${__name}'=("${__arr[@]}")'
}

mapfile_safe() {
  : "${1:?array name required}"
  if command -v mapfile >/dev/null 2>&1; then
    mapfile -t "$1"
  else
    mapfile_compat "$1"
  fi
}

# Fill array from a command without using a pipeline (avoids subshell scope)
# Usage: fill_array ARRAY_NAME cmd arg...
fill_array() {
  : "${1:?array name required}"
  local __name
  __name="${1}"
  shift
  local __line
  local -a __arr
  __arr=()
  while IFS= read -r __line; do
    __arr+=("${__line}")
  done < <("$@")
  # shellcheck disable=SC2086
  eval ${__name}'=("${__arr[@]}")'
}
