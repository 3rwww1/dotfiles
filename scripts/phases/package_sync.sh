#!/usr/bin/env bash
# This file is sourced by install.sh - not intended to be run directly
set -euo pipefail

read_list() { awk 'NF && $1 !~ /^#/' "$1" 2>/dev/null || true; }

read_yaml_list() {
  # Usage: read_yaml_list <yaml_file> <yq_query>
  # Example query: '.packages.common.present[]'
  : "${1:?yaml file required}"; local yaml_file="${1}"
  : "${2:?yq query required}"; local query="${2}"
  if command -v yq >/dev/null 2>&1
  then
    yq -r "${query}" "${yaml_file}" 2>/dev/null | awk 'NF' || true
  else
    # Minimal parser: extract simple top-level lists by section key
    # Not a full YAML parser; requires yq for complex merges.
    awk 'BEGIN{p=0} $0 ~ section {p=1; next} p && $1 ~ /^-/{gsub(/^-\s*/,"",$0); print $0} p && NF==0{p=0}' section="^" query="${query}" "${yaml_file}" 2>/dev/null || true
  fi
}

install_pkg() {
  : "${1:?indent required}"; local indent="${1}"
  : "${2:?package name required}"; local pkg="${2}"
  # This helper is used for Linux apt only; macOS uses Brewfile
  local uid sudo_cmd="sudo"
  uid="$(id -u)"
  if [ "${uid}" -eq 0 ]
  then
    sudo_cmd=""
  fi
  log_info "Installing ${pkg} via apt" "${indent}"
  log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get install -y '${pkg}'" || {
    log_fail "Failed to install ${pkg} via apt" "${indent}"
    exit 1
  }
  # Verify installation actually succeeded; surface a clear failure if not
  if ! dpkg -s "${pkg}" >/dev/null 2>&1
  then
    log_fail "${pkg} not present after apt install" "${indent}"
    exit 1
  fi
}

remove_pkg() {
  : "${1:?indent required}"; local indent="${1}"
  : "${2:?package name required}"; local pkg="${2}"
  # On macOS, prefer Brewfile cleanup; explicit absent list still uses brew uninstall
  if command -v brew >/dev/null 2>&1
  then
    if brew list --formula "${pkg}" >/dev/null 2>&1
    then
      log_cmd "${indent}" brew uninstall --ignore-dependencies "${pkg}" || {
        log_fail "Failed to uninstall ${pkg} via brew" "${indent}"
        exit 1
      }
    fi
    return 0
  fi
  # Linux apt removal
  local uid sudo_cmd="sudo"
  uid="$(id -u)"
  if [ "${uid}" -eq 0 ]
  then
    sudo_cmd=""
  fi
  log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get remove -y '${pkg}'" || {
    log_fail "apt-get remove ${pkg} failed" "${indent}"
    exit 1
  }
}

# Remove mise shims from PATH temporarily so package managers don't see them.
# Usage: remove_mise_shims_from_path <indent>
remove_mise_shims_from_path() {
  : "${1:?indent required}"; local indent="${1}"
  local shims_dir
  shims_dir="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims"
  if [ -d "${shims_dir}" ]
  then
    case ":${PATH}:" in
      *:"${shims_dir}":*)
        log_info "Temporarily removing mise shims from PATH for package-manager phase" "${indent}"
        local path_no_shims
        path_no_shims="$(printf "%s" ":${PATH}:" | sed "s#:${shims_dir}:#:#g" | sed 's#^:##; s#:$##')"
        PATH="${path_no_shims}"
        ;;
    esac
  fi
}

# Restore PATH from the provided value
restore_original_path() {
  : "${1:?indent required}"; local indent="${1}"
  : "${2:?original_path required}"; local original_path="${2}"
  if [ -n "${original_path}" ]
  then
    PATH="${original_path}"
    log_info "Restored PATH (mise shims visible again)" "${indent}"
  fi
}

# Read present/absent/mise lists into caller-provided array variables
# Usage: read_common_lists <indent> <root_dir> <present_out> <absent_out> <mise_tools_out>
read_common_lists() {
  : "${1:?indent required}"; local indent="${1}"
  : "${2:?root_dir required}"; local root_dir="${2}"
  : "${3:?present_out required}"; local present_out="${3}"
  : "${4:?absent_out required}"; local absent_out="${4}"
  : "${5:?mise_tools_out required}"; local mise_tools_out="${5}"

  eval "${present_out}=()"
  while IFS= read -r line
  do
    [ -z "${line}" ] && continue
    eval "${present_out}+=(\"$line\")"
  done < <(read_list "${root_dir}/packages/common/present.txt")

  eval "${absent_out}=()"
  while IFS= read -r line
  do
    [ -z "${line}" ] && continue
    eval "${absent_out}+=(\"$line\")"
  done < <(read_list "${root_dir}/packages/common/absent.txt")

  eval "${mise_tools_out}=()"
  while IFS= read -r line
  do
    [ -z "${line}" ] && continue
    eval "${mise_tools_out}+=(\"$line\")"
  done < <(read_list "${root_dir}/packages/common/present-mise.txt")
}

apply_macos_brew() {
  : "${1:?indent required}"; local indent="${1}"
  : "${2:?root_dir required}"; local root_dir="${2}"
  if ! command -v brew >/dev/null 2>&1
  then
    log_fail "Homebrew not found on macOS" "${indent}"
    exit 1
  fi
  log_info "Applying Brewfile (brew bundle)" "${indent}"
  log_cmd "${indent}" brew bundle --file "${root_dir}/packages/macos/Brewfile" || {
    log_fail "Failed to apply Brewfile (brew bundle)" "${indent}"
    exit 1
  }

  # Optional removals from macOS absent list
  local -a mac_absent
  mac_absent=()
  while IFS= read -r line
  do
    [ -z "${line}" ] && continue
    mac_absent+=("${line}")
  done < <(read_list "${root_dir}/packages/macos/absent.txt")
  local pkg
  for pkg in "${mac_absent[@]}"
  do
    remove_pkg "${indent}" "${pkg}"
  done
}

apt_pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }

ensure_mise_apt_repo() {
  : "${1:?indent required}"; local indent="${1}"
  local sudo_cmd="sudo"
  if [ "$(id -u)" -eq 0 ]
  then
    sudo_cmd=""
  fi
  if grep -R "mise.jdx.dev" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | grep -q "mise.jdx.dev"
  then
    return 0
  fi
  log_info "Adding mise upstream APT repository" "${indent}"
  log_cmd "${indent}" "${sudo_cmd} install -d -m 0755 /etc/apt/keyrings" || {
    log_fail "Failed to ensure /etc/apt/keyrings" "${indent}"
    exit 1
  }
  if ! command -v gpg >/dev/null 2>&1
  then
    log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get update" || true
    log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get install -y gnupg ca-certificates" || {
      log_fail "Failed to install gnupg/ca-certificates required for mise repo" "${indent}"
      exit 1
    }
  fi
  log_cmd "${indent}" "curl -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | ${sudo_cmd} tee /etc/apt/keyrings/mise-archive-keyring.gpg >/dev/null" || {
    log_fail "Failed to add mise GPG key" "${indent}"
    exit 1
  }
  log_cmd "${indent}" "echo 'deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg] https://mise.jdx.dev/deb stable main' | ${sudo_cmd} tee /etc/apt/sources.list.d/mise.list >/dev/null" || {
    log_fail "Failed to add mise APT source" "${indent}"
    exit 1
  }
  log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get update" || {
    log_fail "apt-get update failed after adding mise repo" "${indent}"
    exit 1
  }
}

apply_linux_packages() {
  : "${1:?indent required}"; local indent="${1}"
  : "${2:?root_dir required}"; local root_dir="${2}"
  shift 2
  # Parse arrays: present until --, then absent
  local -a present_absent_args present absent
  present_absent_args=("$@")
  local i
  for (( i=0; i<${#present_absent_args[@]}; i++ ))
  do
    if [ "${present_absent_args[$i]}" = "--" ]
    then
      break
    fi
    present+=("${present_absent_args[$i]}")
  done
  local j=$((i+1))
  for (( ; j<${#present_absent_args[@]}; j++ ))
  do
    absent+=("${present_absent_args[$j]}")
  done
  if ! command -v apt-get >/dev/null 2>&1
  then
    log_fail "apt-get not found on Linux" "${indent}"
    exit 1
  fi
  local -a tmp lin_present lin_absent
  tmp=()
  while IFS= read -r line
  do
    [ -z "${line}" ] && continue
    tmp+=("${line}")
  done < <(read_list "${root_dir}/packages/linux/present.txt")
  lin_present=("${present[@]}" "${tmp[@]}")
  tmp=()
  while IFS= read -r line
  do
    [ -z "${line}" ] && continue
    tmp+=("${line}")
  done < <(read_list "${root_dir}/packages/linux/absent.txt")
  lin_absent=("${absent[@]}" "${tmp[@]}")

  # Dedup
  local -A seen
  local -a uniq_present uniq_absent
  local p
  for p in "${lin_present[@]}"
  do
    if [[ -n "${seen[$p]+x}" ]]
    then
      continue
    fi
    seen[$p]=1
    uniq_present+=("${p}")
  done
  unset seen
  declare -A seen
  for p in "${lin_absent[@]}"
  do
    if [[ -n "${seen[$p]+x}" ]]
    then
      continue
    fi
    seen[$p]=1
    uniq_absent+=("${p}")
  done

  # Apply
  local pkg
  # If 'mise' is requested, ensure its APT repo is configured first
  local p
  for p in "${uniq_present[@]}"
  do
    if [ "${p}" = "mise" ]
    then
      ensure_mise_apt_repo "${indent}"
      break
    fi
  done
  for pkg in "${uniq_present[@]}"
  do
    if apt_pkg_installed "${pkg}"
    then
      log_info "${pkg} is already installed" "${indent}"
    else
      install_pkg "${indent}" "${pkg}"
    fi
  done
  for pkg in "${uniq_absent[@]}"
  do
    if apt_pkg_installed "${pkg}"
    then
      log_info "Removing ${pkg} as per policy" "${indent}"
      remove_pkg "${indent}" "${pkg}"
    else
      log_info "${pkg} is already absent" "${indent}"
    fi
  done
}

install_mise_tools() {
  : "${1:?indent required}"; local indent="${1}"
  shift 1
  local -a mise_tools
  mise_tools=("$@")
  if [ "${#mise_tools[@]}" -eq 0 ]
  then
    return 0
  fi
  if ! command -v mise >/dev/null 2>&1
  then
    log_fail "mise is required for installing managed tools but was not found" "${indent}"
    exit 1
  fi
  log_info "Installing mise-managed tools" "${indent}"
  indent=$((indent + 1))
  local t
  for t in "${mise_tools[@]}"
  do
    if mise list 2>/dev/null | grep -q "^${t}\\b"
    then
      log_info "${t} is already installed (mise)" "${indent}"
    else
      log_info "Installing ${t} via mise" "${indent}"
      log_cmd "${indent}" mise install "${t}" || {
        log_fail "Failed to install ${t} via mise" "${indent}"
        exit 1
      }
    fi
    log_info "Setting ${t} as global via mise" "${indent}"
    log_cmd "${indent}" mise use -g "${t}" || {
      log_fail "Failed to set ${t} as global via mise" "${indent}"
      exit 1
    }
  done
  indent=$((indent - 1))
  log_info "Regenerating shims via mise" "${indent}"
  log_cmd "${indent}" mise reshim || {
    log_fail "Failed to reshim via mise" "${indent}"
    exit 1
  }
}

setup_corepack_and_yarn() {
  : "${1:?indent required}"; local indent="${1}"
  if command -v corepack >/dev/null 2>&1
  then
    log_info "Enabling corepack" "${indent}"
    log_cmd "${indent}" corepack enable || {
      log_fail "Failed to enable corepack" "${indent}"
      exit 1
    }
    indent=$((indent + 1))
    if command -v yarn >/dev/null 2>&1
    then
      log_info "yarn is already installed" "${indent}"
    else
      log_info "Installing yarn via corepack (stable)" "${indent}"
      log_cmd "${indent}" corepack prepare yarn@stable --activate || {
        log_fail "Failed to install yarn via corepack" "${indent}"
        exit 1
      }
    fi
    indent=$((indent - 1))
  else
    log_fail "corepack is required to manage yarn but was not found" "${indent}"
    exit 1
  fi
}

install_ruby_gems() {
  : "${1:?indent required}"; local indent="${1}"
  log_info "Installing Ruby gems" "${indent}"
  indent=$((indent + 1))
  if command -v rubocop >/dev/null 2>&1
  then
    log_info "rubocop is already installed" "${indent}"
  else
    if command -v mise >/dev/null 2>&1
    then
      local ruby_root ruby_bin
      ruby_root="$(mise where ruby 2>/dev/null || true)"
      if [ -z "${ruby_root}" ]
      then
        log_fail "mise Ruby not found; ensure 'ruby' is listed in present-mise.txt and installed" "${indent}"
        exit 1
      fi
      ruby_bin="${ruby_root}/bin/ruby"
      log_info "Installing rubocop via mise Ruby at ${ruby_bin}" "${indent}"
      log_cmd "${indent}" "${ruby_bin}" -S gem install --no-document --user-install --bindir "${HOME}/.local/bin" rubocop || {
        log_fail "Failed to install rubocop via mise Ruby" "${indent}"
        exit 1
      }
    else
      log_fail "mise not found; cannot install rubocop" "${indent}"
      exit 1
    fi
  fi
  indent=$((indent - 1))
}

package_sync() {
  : "${1:?indent required}"; local indent="${1}"
  local repo_dir="${2}"

  local os_name
  if [ -n "${OS+x}" ]
  then
    os_name="${OS}"
  else
    os_name="$(uname -s)"
  fi
  local root_dir="${repo_dir}"

  # Read common lists
  local -a present absent mise_tools
  read_common_lists "${indent}" "${root_dir}" present absent mise_tools

  # Temporarily remove mise shims from PATH so package-manager checks/install
  # do not see mise-provided binaries
  local original_path
  original_path="${PATH}"
  remove_mise_shims_from_path "${indent}"

  case "${os_name}" in
    Darwin)
      apply_macos_brew "${indent}" "${root_dir}"
      ;;
    Linux)
      apply_linux_packages "${indent}" "${root_dir}" "${present[@]}" -- "${absent[@]}"
      ;;
    *)
      log_fail "Unsupported OS: ${os_name}" "${indent}"
      exit 1
      ;;
  esac

  # Restore PATH before running mise
  restore_original_path "${indent}" "${original_path}"
  install_mise_tools "${indent}" "${mise_tools[@]}"

  # Corepack-based tools (e.g., Yarn)
  setup_corepack_and_yarn "${indent}"

  install_ruby_gems "${indent}"

  log_pass "Package sync complete" "${indent}"
}
