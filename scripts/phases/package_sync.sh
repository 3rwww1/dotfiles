#!/usr/bin/env bash
# This file is sourced by install.sh - not intended to be run directly
set -euo pipefail

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
# Usage: remove_mise_shims_from_path <indent>
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
      PATH="${path_no_shims}"
      ;;
    esac
  fi
}

# Restore PATH from the provided value
restore_original_path() {
  : "${1:?indent required}"
  local indent="${1}"
  : "${2:?original_path required}"
  local original_path="${2}"
  if [ -n "${original_path}" ]; then
    PATH="${original_path}"
    log_info "Restored PATH (mise shims visible again)" "${indent}"
  fi
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

ensure_mise_apt_repo() {
  : "${1:?indent required}"
  local indent="${1}"
  local sudo_cmd="sudo"
  if [ "$(id -u)" -eq 0 ]; then
    sudo_cmd=""
  fi
  if [ -f "/etc/apt/sources.list.d/mise.list" ]; then
    return 0
  fi
  log_info "Adding mise upstream APT repository" "${indent}"
  log_cmd "${indent}" "${sudo_cmd} install -d -m 0755 /etc/apt/keyrings" || {
    log_fail "Failed to ensure /etc/apt/keyrings" "${indent}"
    exit 1
  }
  if ! command -v gpg >/dev/null 2>&1; then
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
  # Single apt-get update for the Linux phase
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

  # Ensure mise's APT repo is configured first
  ensure_mise_apt_repo "${indent}"

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
  if ! command -v mise >/dev/null 2>&1; then
    log_fail "mise is required for installing managed tools but was not found" "${indent}"
    exit 1
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
  if command -v corepack >/dev/null 2>&1; then
    log_info "Enabling corepack" "${indent}"
    log_cmd "${indent}" corepack enable || {
      log_fail "Failed to enable corepack" "${indent}"
      exit 1
    }
    indent=$((indent + 1))
    if command -v yarn >/dev/null 2>&1; then
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
  : "${1:?indent required}"
  local indent="${1}"
  log_info "Installing Ruby gems" "${indent}"
  indent=$((indent + 1))
  if command -v rubocop >/dev/null 2>&1; then
    log_info "rubocop is already installed" "${indent}"
  else
    if command -v mise >/dev/null 2>&1; then
      local ruby_root ruby_bin
      ruby_root="$(mise where ruby 2>/dev/null || true)"
      if [ -z "${ruby_root}" ]; then
        log_fail "mise Ruby not found; ensure 'ruby' is listed in JSON manifest and installed" "${indent}"
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

## install_jq removed; use install_pkg

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
  remove_mise_shims_from_path "${indent}"

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

  restore_original_path "${indent}" "${original_path}"

  install_mise_tools "${indent}" "${repo_dir}"
  setup_corepack_and_yarn "${indent}"
  install_ruby_gems "${indent}"

  log_pass "Package sync complete" "${indent}"
}
