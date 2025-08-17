#!/usr/bin/env bash
# This file is sourced by install.sh - not intended to be run directly
set -euo pipefail

# Add official Kubernetes apt repo for kubectl
ensure_apt_repository() {
  : "${1:?indent required}"
  : "${2:?repo_name required}"
  : "${3:?manifest_path required}"
  local indent="${1}"
  local repo_name="${2}"
  local manifest="${3}"

  # Only relevant on Debian/Ubuntu with apt
  if ! command -v apt-get >/dev/null 2>&1; then
    return 0
  fi

  local sudo_cmd="sudo"
  if [ "$(id -u)" -eq 0 ]; then
    sudo_cmd=""
  fi

  # Extract repository config from JSON
  local name keyring_path key_url source_line list_file
  name=$(jq -r ".apt_repositories.${repo_name}.name // empty" "${manifest}")
  keyring_path=$(jq -r ".apt_repositories.${repo_name}.keyring_path // empty" "${manifest}")
  key_url=$(jq -r ".apt_repositories.${repo_name}.key_url // empty" "${manifest}")
  source_line=$(jq -r ".apt_repositories.${repo_name}.source_line // empty" "${manifest}")
  list_file=$(jq -r ".apt_repositories.${repo_name}.list_file // empty" "${manifest}")

  if [ -z "${name}" ] || [ -z "${keyring_path}" ] || [ -z "${key_url}" ] || [ -z "${source_line}" ] || [ -z "${list_file}" ]; then
    log_fail "Invalid APT repository configuration for '${repo_name}'" "${indent}"
    exit 1
  fi

  # Check if already configured
  if [ -f "${keyring_path}" ] && [ -f "${list_file}" ]; then
    return 0
  fi

  log_info "Adding upstream APT repository for ${name}" "${indent}"

  # Ensure keyrings directory exists
  log_cmd "${indent}" "${sudo_cmd} install -d -m 0755 /etc/apt/keyrings" || {
    log_fail "Failed to ensure /etc/apt/keyrings" "${indent}"
    exit 1
  }

  # Ensure gpg is available
  if ! command -v gpg >/dev/null 2>&1; then
    log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get update" || true
    log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get install -y gnupg ca-certificates wget" || {
      log_fail "Failed to install gnupg/ca-certificates required for ${name} repo" "${indent}"
      exit 1
    }
  fi

  # Add GPG key
  log_cmd "${indent}" "wget -qO- ${key_url} | gpg --dearmor | ${sudo_cmd} tee ${keyring_path} >/dev/null" || {
    log_fail "Failed to add ${name} GPG key" "${indent}"
    exit 1
  }

  # Add source list
  log_cmd "${indent}" "echo '${source_line}' | ${sudo_cmd} tee ${list_file} >/dev/null" || {
    log_fail "Failed to add ${name} APT source" "${indent}"
    exit 1
  }

  # Set permissions
  log_cmd "${indent}" "${sudo_cmd} chmod 0644 ${keyring_path} ${list_file}" || true
}



read_json_list() {
  # Usage: read_json_list <json_file> <jq_query>
  # Example query: '.packages.common.present[]'
  : "${1:?json file required}"
  local json_file="${1}"
  : "${2:?jq query required}"
  local query="${2}"
  if command -v jq >/dev/null 2>&1; then
    jq -r "${query}" "${json_file}" 2>/dev/null | awk 'NF' || true
  else
    printf "" || true
  fi
}

print_present_packages() {
  : "${1:?manifest required}"
  local manifest="${1}"
  jq -r '.packages.common.present[], .packages.linux.present[]' "${manifest}" 2>/dev/null | sort -u || true
}

print_absent_packages() {
  : "${1:?manifest required}"
  local manifest="${1}"
  jq -r '.packages.common.absent[]' "${manifest}" 2>/dev/null | sort -u || true
}

print_mise_tools() {
  : "${1:?manifest required}"
  local manifest="${1}"
  jq -r '.packages.common.mise[]' "${manifest}" 2>/dev/null | sort -u || true
}

install_pkg() {
  : "${1:?indent required}"
  local indent="${1}"
  : "${2:?package name required}"
  local pkg="${2}"
  # Prefer apt on Linux; fallback to Homebrew when available
  if command -v apt-get >/dev/null 2>&1; then
    local uid sudo_cmd="sudo"
    uid="$(id -u)"
    if [ "${uid}" -eq 0 ]; then
      sudo_cmd=""
    fi
    if [ "${pkg}" = "eza" ]; then
      local codename
      codename="$(get_debian_codename)"
      if [ -n "${codename}" ]; then
        log_info "Installing ${pkg} via apt from ${codename}-backports" "${indent}"
        log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get install -y -t ${codename}-backports '${pkg}'" || {
          log_fail "Failed to install ${pkg} via apt from backports" "${indent}"
          exit 1
        }
        if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
          log_fail "${pkg} not present after apt install from backports" "${indent}"
          exit 1
        fi
        return 0
      fi
    fi
    log_info "Installing ${pkg} via apt" "${indent}"
    log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get install -y '${pkg}'" || {
      log_fail "Failed to install ${pkg} via apt" "${indent}"
      exit 1
    }
    if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
      log_fail "${pkg} not present after apt install" "${indent}"
      exit 1
    fi
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    if brew list --formula "${pkg}" >/dev/null 2>&1; then
      log_info "${pkg} already installed via brew" "${indent}"
      return 0
    fi
    log_info "Installing ${pkg} via brew" "${indent}"
    log_cmd "${indent}" brew install "${pkg}" || {
      log_fail "Failed to install ${pkg} via brew" "${indent}"
      exit 1
    }
    if ! brew list --formula "${pkg}" >/dev/null 2>&1 && ! command -v "${pkg}" >/dev/null 2>&1; then
      log_fail "${pkg} not present after brew install" "${indent}"
      exit 1
    fi
    return 0
  fi

  log_fail "No supported package manager found to install ${pkg}" "${indent}"
  exit 1
}

remove_pkg() {
  : "${1:?indent required}"
  local indent="${1}"
  : "${2:?package name required}"
  local pkg="${2}"
  # On macOS, prefer Brewfile cleanup; explicit absent list still uses brew uninstall
  if command -v brew >/dev/null 2>&1; then
    if brew list --formula "${pkg}" >/dev/null 2>&1; then
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
  if [ "${uid}" -eq 0 ]; then
    sudo_cmd=""
  fi
  log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get remove -y '${pkg}'" || {
    log_fail "apt-get remove ${pkg} failed" "${indent}"
    exit 1
  }
}

# Remove mise shims from PATH temporarily so package managers don't see them.
# Usage: path_no_shims=$(remove_mise_shims_from_path <indent>)
remove_mise_shims_from_path() {
  : "${1:?indent required}"
  local indent="${1}"
  local shims_dir
  shims_dir="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims"
  if [ -d "${shims_dir}" ]; then
    case ":${PATH}:" in
    *:"${shims_dir}":*)
      log_info "Temporarily removing mise shims from PATH for package-manager phase" "${indent}"
      local path_no_shims
      path_no_shims="$(printf "%s" ":${PATH}:" | sed "s#:${shims_dir}:#:#g" | sed 's#^:##; s#:$##')"
      printf "%s" "${path_no_shims}"
      return 0
      ;;
    esac
  fi
  # If no shims to remove, return original PATH
  printf "%s" "${PATH}"
}

apply_macos_brew() {
  : "${1:?indent required}"
  local indent="${1}"
  : "${2:?root_dir required}"
  local root_dir="${2}"
  if ! command -v brew >/dev/null 2>&1; then
    log_fail "Homebrew not found on macOS" "${indent}"
    exit 1
  fi
  log_info "Applying Brewfile (brew bundle)" "${indent}"
  log_cmd "${indent}" brew bundle --file "${root_dir}/scripts/config/brewfile.rb" || {
    log_fail "Failed to apply Brewfile (brew bundle)" "${indent}"
    exit 1
  }
}

apt_pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }

get_debian_codename() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    printf "%s" "${VERSION_CODENAME:-}"
  else
    printf ""
  fi
}

ensure_debian_backports() {
  : "${1:?indent required}"
  local indent="${1}"
  local sudo_cmd="sudo"
  if [ "$(id -u)" -eq 0 ]; then
    sudo_cmd=""
  fi
  local codename
  codename="$(get_debian_codename)"
  if [ -z "${codename}" ]; then
    return 0
  fi
  local list_file
  list_file="/etc/apt/sources.list.d/${codename}-backports.list"
  if [ ! -f "${list_file}" ]; then
    log_info "Adding Debian backports repository (${codename}-backports)" "${indent}"
    log_cmd "${indent}" "echo 'deb http://deb.debian.org/debian ${codename}-backports main contrib non-free non-free-firmware' | ${sudo_cmd} tee ${list_file} >/dev/null" || {
      log_fail "Failed to add Debian backports repo" "${indent}"
      exit 1
    }
  fi
}





apply_linux_packages() {
  : "${1:?indent required}"
  local indent="${1}"
  : "${2:?root_dir required}"
  local root_dir="${2}"
  # Load present/absent directly from manifest
  local manifest
  manifest="${root_dir}/scripts/config/software-list.json"
  local -a present
  fill_array present print_present_packages "${manifest}"
  if ! command -v apt-get >/dev/null 2>&1; then
    log_fail "apt-get not found on Linux" "${indent}"
    exit 1
  fi
  # Ensure Debian backports before apt-get update (for newer packages like eza)
  ensure_debian_backports "${indent}"
  # Ensure external APT repositories
  ensure_apt_repository "${indent}" "mise" "${manifest}"
  ensure_apt_repository "${indent}" "eza" "${manifest}"
  ensure_apt_repository "${indent}" "kubernetes" "${manifest}"

  local uid sudo_cmd
  uid="$(id -u)"
  sudo_cmd="sudo"
  if [ "${uid}" -eq 0 ]; then
    sudo_cmd=""
  fi
  log_cmd "${indent}" "DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get update" || {
    log_fail "apt-get update failed" "${indent}"
    exit 1
  }

  # Apply
  local pkg
  for pkg in "${present[@]}"; do
    if apt_pkg_installed "${pkg}"; then
      log_info "${pkg} is already installed" "${indent}"
    else
      install_pkg "${indent}" "${pkg}"
    fi
  done
}

install_mise_tools() {
  : "${1:?indent required}"
  local indent="${1}"
  : "${2:?root_dir required}"
  local root_dir="${2}"
  # Load mise tools directly from manifest
  local manifest
  manifest="${root_dir}/scripts/config/software-list.json"
  local -a mise_tools
  fill_array mise_tools print_mise_tools "${manifest}"
  if [ "${#mise_tools[@]}" -eq 0 ]; then
    return 0
  fi

  log_info "Installing mise-managed tools" "${indent}"
  indent=$((indent + 1))
  local t
  for t in "${mise_tools[@]}"; do
    if mise list 2>/dev/null | grep -q "^${t}\\b"; then
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
  : "${1:?indent required}"
  local indent="${1}"
  log_info "Enabling corepack" "${indent}"
  log_cmd "${indent}" corepack enable || {
    log_fail "corepack enable failed" "${indent}"
    exit 1
  }
  if command -v yarn >/dev/null 2>&1; then
    log_info "yarn is already installed (corepack)" "${indent}"
  else
    log_info "Installing yarn via corepack (stable)" "${indent}"
    log_cmd "${indent}" corepack prepare yarn@stable --activate || {
      log_fail "Failed to install yarn via corepack" "${indent}"
      exit 1
    }
  fi
}

install_ruby_gems() {
  : "${1:?indent required}"
  local indent="${1}"

  log_info "Installing Ruby gems" "${indent}"
  indent=$((indent + 1))
  if command -v rubocop >/dev/null 2>&1; then
    log_info "rubocop is already installed" "${indent}"
  else
    log_info "Installing rubocop via gem" "${indent}"
    log_cmd "${indent}" gem install --no-document --user-install --bindir "${HOME}/.local/bin" rubocop || {
      log_fail "Failed to install rubocop via gem" "${indent}"
      exit 1
    }
  fi
}

package_sync() {
  : "${1:?indent required}"
  : "${2:?repo_dir required}"
  : "${3:?os_name required}"
  local indent="${1}"
  local repo_dir="${2}"
  local os_name="${3}"

  # Ensure jq is present for JSON parsing
  if ! command -v jq >/dev/null 2>&1; then
    install_pkg "${indent}" jq || {
      log_fail "jq is required to parse scripts/config/software-list.json" "${indent}"
      exit 1
    }
  fi

  # Temporarily remove mise shims from PATH so package-manager checks/install
  # do not see mise-provided binaries
  local original_path
  original_path="${PATH}"

  local path_no_shims
  path_no_shims=$(remove_mise_shims_from_path "${indent}")
  export PATH="${path_no_shims}"

  log_info "Removing absent packages" "${indent}"
  local -a absent
  absent=()
  fill_array absent print_absent_packages "${repo_dir}/scripts/config/software-list.json"
  indent=$((indent + 1))
  for pkg in "${absent[@]}"; do
    if apt_pkg_installed "${pkg}"; then
      log_info "Removing ${pkg} as per policy" "${indent}"
      remove_pkg "${indent}" "${pkg}"
    else
      log_info "${pkg} is already absent" "${indent}"
    fi
  done
  indent=$((indent - 1))

  export PATH="${original_path}"

  case "${os_name}" in
  Darwin)
    apply_macos_brew "${indent}" "${repo_dir}"
    ;;
  Linux)
    apply_linux_packages "${indent}" "${repo_dir}"
    ;;
  *)
    log_fail "Unsupported OS: ${os_name}" "${indent}"
    exit 1
    ;;
  esac

  install_mise_tools "${indent}" "${repo_dir}"
  setup_corepack_and_yarn "${indent}"
  install_ruby_gems "${indent}"

  log_pass "Package sync complete" "${indent}"
}
