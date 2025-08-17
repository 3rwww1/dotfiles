#!/usr/bin/env bash
# This file is sourced by install.sh - not intended to be run directly
set -euo pipefail

self_test() {
	: "${1:?indent required}"
	local indent="$1"
	: "${2:?repo_dir required}"
	local repo_dir="$2"

	local pass=0
	local warn=0
	local fail=0

	_pass() {
		log_pass "$1" "$indent"
		pass=$((pass + 1))
	}

	_warn() {
		log_warn "$1" "$indent"
		warn=$((warn + 1))
	}

	_fail() {
		log_fail "$1" "$indent"
		fail=$((fail + 1))
	}

	# System prerequisites
	local c
  log_info "Checking system prerequisites" "$indent"
  indent=$((indent + 1))
	for c in zsh stow git; do
		if command -v "$c" >/dev/null 2>&1; then
			_pass "Command available: $c ($(command -v "$c"))"
		else
			_fail "Command missing: $c"
		fi
	done
  indent=$((indent - 1))

	# Dotfiles and shell symlinks
	local target
  log_info "Checking dotfiles and shell symlinks" "$indent"
  indent=$((indent + 1))
	for target in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zshenv" "$HOME/.config/starship.toml"; do
		if [ -L "$target" ]; then
			_pass "Symlink exists: $target -> $(readlink "$target")"
		elif [ -e "$target" ]; then
			_warn "Not a symlink (exists as file/dir): $target"
		else
			_fail "Missing expected symlink: $target"
		fi
	done
  indent=$((indent - 1))

  log_info "Checking zsh completions" "$indent"
  indent=$((indent + 1))
	# Zsh completions
	if ls "$HOME/.zfunc"/_* >/dev/null 2>&1; then
		_pass "Found completion files in ~/.zfunc"
	else
		_warn "No completion files found in ~/.zfunc (may be OK on fresh Linux)"
	fi
  indent=$((indent - 1))

  log_info "Checking Cursor extensions" "$indent"
  indent=$((indent + 1))
	# Cursor extensions
	if command -v cursor >/dev/null 2>&1; then
		local list_file
		list_file="$repo_dir/cursor/extensions.txt"
		if [ -f "$list_file" ]; then
			local installed
			local to_install
			installed="$(cursor --list-extensions | sort -f)"
			to_install="$(comm -23 <(sort -f "$list_file") <(printf "%s\n" "$installed"))"
			if [ -z "$to_install" ]; then
				_pass "Cursor extensions are up to date"
			else
				_warn "Cursor extensions missing; run extensions install"
			fi
		else
			_warn "No cursor/extensions.txt list found"
		fi
	else
		_warn "Cursor CLI not found; skipping Cursor extension check"
	fi
  indent=$((indent - 1))

  log_info "Checking favorite commands" "$indent"
  indent=$((indent + 1))
	# Favorite commands (optional)
	local fav_common=(rg fzf zoxide tmux htop jq shellcheck starship atuin gh kubectl aws gcloud docker podman kind k9s trivy mise bat fd node deno python3 pipx vim nvim direnv terraform ykman go cargo)
	local fav
	fav=("${fav_common[@]}")
	for c in "${fav[@]}"; do
		if command -v "$c" >/dev/null 2>&1; then
			_pass "Command available: $c"
		else
			_warn "Command missing (optional): $c"
		fi
	done
  indent=$((indent - 1))

  log_info "Checking mise tools" "$indent"
  indent=$((indent + 1))
  local -a mise_tools
  fill_array mise_tools print_mise_tools "${repo_dir}/scripts/config/software-list.json"
  for tool in "${mise_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      _pass "Mise tool available: $tool"
    else
      _warn "Mise tool missing: $tool"
    fi
  done
  indent=$((indent - 1))

	log_info "Self-test summary: ${pass} passed, ${warn} warnings, ${fail} failures" "$indent"
	if [ "$fail" -ne 0 ]; then
		return 1
	fi
}
