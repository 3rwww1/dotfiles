#!/usr/bin/env bash
# This file is sourced by install.sh - not intended to be run directly
set -euo pipefail

stow_dotfiles() {
	: "${1:?indent required}"; local indent="$1"
	: "${2:?repo_dir required}"; local repo_dir="$2"
	: "${3:?os_name required}"; local os_name="$3"
	local -a packages
	packages=(zsh vim nvim git starship editorconfig)
	if [ "$os_name" = "Darwin" ]
	then
		packages+=(cursor ghostty)
	fi
	local pkg
	for pkg in "${packages[@]}"
	do
		if [ -d "$repo_dir/$pkg" ]
		then
			if log_cmd "$indent" stow -v -t "$HOME" -d "$repo_dir" "$pkg"
			then
				log_pass "stowed $pkg" "$indent"
			else
				log_fail "stow failed for $pkg" "$indent"
			fi
		fi
	done
}

link_zsh_completions() {
	: "${1:?indent required}"; local indent="$1"
	local target_dir="$HOME/.zfunc"; mkdir -p "$target_dir"
	local -a src_dirs; src_dirs=()
	if command -v brew >/dev/null 2>&1
	then
		local brew_prefix
		brew_prefix="$(brew --prefix)"
		src_dirs+=("$brew_prefix/share/zsh/site-functions" "$brew_prefix/share/zsh-completions")
	fi
	src_dirs+=("/usr/share/zsh/site-functions" "/usr/share/zsh/vendor-completions" "/usr/local/share/zsh/site-functions" "$HOME/.local/share/zsh/site-functions" "$HOME/.zsh/completions")
	local dir
	for dir in "${src_dirs[@]}"
	do
		[ -d "$dir" ] || continue
		find "$dir" -maxdepth 1 -type f -name '_*' 2>/dev/null | while read -r f
		do
			local base
			base="$(basename "$f")"
			if [ -L "$target_dir/$base" ] && [ "$(readlink "$target_dir/$base")" = "$f" ]
			then
				continue
			fi
			ln -sf "$f" "$target_dir/$base"
		done
	done

	log_pass "linked completions into $target_dir" "$indent"
}

cursor_extensions_install() {
	: "${1:?indent required}"; local indent="$1"
	: "${2:?repo_dir required}"; local repo_dir="$2"
	if ! command -v cursor >/dev/null 2>&1
	then
		return 0
	fi
	local list_file="$repo_dir/cursor/extensions.txt"
	if [ ! -f "$list_file" ]
	then
		log_fail "No $list_file found. Run export first." "$indent"
		return 1
	fi
	local to_install; to_install="$(comm -23 <(sort -f "$list_file") <(cursor --list-extensions | sort -f))"
	if [ -z "$to_install" ]
	then
		log_pass "All Cursor extensions from list already installed." "$indent"
		return 0
	fi
	local count
	count="$(printf "%s\n" "$to_install" | sed '/^\s*$/d' | wc -l | tr -d ' ')"
	log_info "Installing $count Cursor extension(s)" "$indent"
	while IFS= read -r ext
	do
		if [ -z "$ext" ]
		then
			continue
		fi
		log_cmd "$indent" cursor --install-extension "$ext" || true
	done <<<"$to_install"
	log_pass "Cursor extensions installed." "$indent"
}

common_config() {
	: "${1:?indent required}"; local indent="$1"
	: "${2:?repo_dir required}"; local repo_dir="$2"
	: "${3:?os_name required}"; local os_name="$3"
	log_info "Deploying dotfiles with stow" "$indent"
	stow_dotfiles "$indent" "$repo_dir" "$os_name"
	log_info "Linking completions into ~/.zfunc" "$indent"
	link_zsh_completions "$indent"
	log_info "Ensuring Cursor extensions from repo are installed" "$indent"
	if cursor_extensions_install "$indent" "$repo_dir"
	then
		:
	else
		log_fail "cursor extension install failed" "$indent"
		exit 1
	fi
}
