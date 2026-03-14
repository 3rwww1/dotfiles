#!/usr/bin/env bash
# This file is sourced by install.sh - not intended to be run directly
set -euo pipefail

stow_dotfiles() {
	: "${1:?indent required}"; local indent="$1"
	: "${2:?repo_dir required}"; local repo_dir="$2"
	: "${3:?os_name required}"; local os_name="$3"
	local -a packages
	packages=(zsh vim nvim git starship editorconfig hl claude aws-sso tmux)
	if [ "$os_name" = "Darwin" ]
	then
		packages+=(cursor ghostty)
	fi

	# Backup helper for conflicting dotfiles before stowing
	backup_conflict() {
		: "${1:?target path required}"; local target="$1"
		local backup_root backup_dir base
		backup_root="$HOME/.config/dotfiles/backups"
		base="$(basename "$target")"
		backup_dir="$backup_root/stow-$(date +%Y%m%d%H%M%S)"
		mkdir -p "$backup_dir"
		if [ -e "$target" ] && [ ! -L "$target" ]
		then
			mv "$target" "$backup_dir/$base"
			log_info "Backed up $target to $backup_dir/$base" "$indent"
		fi
	}

	# If the repo was moved, existing stow symlinks point to the old location.
	# Detect that old stow dir from a sampled symlink and unstow from it first.
	unstow_from_old_dir() {
		: "${1:?pkg required}"; local pkg="$1"
		local pkg_dir="$repo_dir/$pkg"
		[ -d "$pkg_dir" ] || return 0
		local old_stow_dir=""
		local f rel dest target candidate
		while IFS= read -r f
		do
			rel="${f#"$pkg_dir/"}"
			dest="$HOME/$rel"
			[ -L "$dest" ] || continue
			target="$(readlink "$dest")"
			case "$target" in
				/*) ;;
				*)  target="$(cd "$(dirname "$dest")" && pwd)/$target" ;;
			esac
			case "$target" in
				"$repo_dir"/*) continue ;;
			esac
			# target should be <old_stow_dir>/<pkg>/<rel> — strip suffix to get old dir
			candidate="${target%"/$pkg/$rel"}"
			[ -d "$candidate" ] && old_stow_dir="$candidate" && break
		done < <(find "$pkg_dir" -mindepth 1)
		if [ -n "$old_stow_dir" ]
		then
			stow -d "$old_stow_dir" -t "$HOME" --delete "$pkg" 2>/dev/null || true
		fi
	}

	local pkg
	for pkg in "${packages[@]}"
	do
		if [ -d "$repo_dir/$pkg" ]
		then
			# Unstow from old repo location if the repo has been moved
			unstow_from_old_dir "$pkg"
			# Proactively back up common conflicts per package
			if [ "$pkg" = "zsh" ]
			then
				backup_conflict "$HOME/.zshrc"
				backup_conflict "$HOME/.zprofile"
				backup_conflict "$HOME/.zshenv"
			fi
			if [ "$pkg" = "claude" ]
			then
				# Ensure ~/.claude is a real directory so stow never folds it
				mkdir -p "$HOME/.claude"
				backup_conflict "$HOME/.claude/settings.json"
			fi
			if [ "$pkg" = "aws-sso" ]
			then
				mkdir -p "$HOME/.config/aws-sso"
			fi
			if [ "$pkg" = "cursor" ]
			then
				# Prevent stow from folding Cursor's app support dir
				mkdir -p "$HOME/Library/Application Support/Cursor/User"
			fi
			if [ "$pkg" = "ghostty" ]
			then
				mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
			fi
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
