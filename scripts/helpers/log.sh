#!/usr/bin/env bash
set -u

if [ -t 1 ]; then
  LOG_IS_TTY=1
else
  LOG_IS_TTY=0
fi

text_bold() {
  local s="${1:?string required}"

  local bold=""
  local reset=""
  if [ "${LOG_IS_TTY}" -eq 1 ]; then
    bold="$(tput bold)"
    reset="$(tput sgr0)"
  fi
  printf "%s%s%s" "${bold}" "${s}" "${reset}"
}

indent_str() {
  : "${1:?indent required}"
  local indent_num="$1"

  local indent_size=2
  local total=$((indent_num * indent_size))
  printf '%*s' "${total}" ''
}

log_phase() {
  local bold="" color="" reset=""
  if [[ -t 1 ]]; then
    bold="$(tput bold)"
    color="$(tput setaf 4)"
    reset="$(tput sgr0)"
  fi
  printf "%s%s%s%s\n" "${bold}" "${color}" "${1}" "${reset}"
}

log_pass() {
  : "${2:?indent required}"
  local n="${2}"
  local color="" reset=""
  if [[ -t 1 ]]; then
    color="$(tput setaf 2)"
    reset="$(tput sgr0)"
  fi
  printf "%s%-6s%s%s%s\n" "${color}" "PASS:" "${reset}" "$(indent_str "${n}")" "${1}"
}

log_info() {
  : "${2:?indent required}"
  local n="${2}"
  local color="" reset=""
  if [[ -t 1 ]]; then
    color="$(tput setaf 6)"
    reset="$(tput sgr0)"
  fi
  printf "%s%-6s%s%s%s\n" "${color}" "INFO:" "${reset}" "$(indent_str "${n}")" "${1}"
}

log_warn() {
  : "${2:?indent required}"
  local n="${2}"
  local color="" reset=""
  if [[ -t 1 ]]; then
    color="$(tput setaf 3)"
    reset="$(tput sgr0)"
  fi
  printf "%s%-6s%s%s%s\n" "${color}" "WARN:" "${reset}" "$(indent_str "${n}")" "${1}"
}

log_fail() {
  : "${2:?indent required}"
  local n="${2}"
  local color="" reset=""
  if [[ -t 1 ]]; then
    color="$(tput setaf 1)"
    reset="$(tput sgr0)"
  fi
  printf "%s%-6s%s%s%s\n" "${color}" "FAIL:" "${reset}" "$(indent_str "${n}")" "${1}"
}

# Run command, indent output by current indent + 4, color magenta on success, red on error
log_cmd() {
  : "${1:?indent required}"
  : "${2:?command required}"
  local indent="${1}"
  local cmd="${*:2}"

  local out
  local color=""
  local reset=""
  local status

  out=$(bash -lc "${cmd}" 2>&1)
  status=$?
  # add 1 to indent for the command output
  indent=$((indent + 1))

  # dont print any output if it contains only whitespace
  if [[ "${out}" =~ ^[[:space:]]*$ ]]; then
    return "${status}"
  fi

  if [[ -t 1 ]]; then
    if [ "${status}" -eq 0 ]; then
      # magenta (all good)
      color="$(tput setaf 5)"
    else
      # red (error)
      color="$(tput setaf 1)"
    fi
    reset="$(tput sgr0)"
  fi


  while IFS= read -r line || [ -n "${line}" ]; do
    printf "%s%-6s%s%s%s\n" "${color}" "EXEC:" "$(indent_str "${indent}")" "${line}" "${reset}"
  done <<<"${out}"
  return "${status}"
}
