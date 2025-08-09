#!/usr/bin/env bash
# This file is sourced by install.sh - not intended to be run directly
set -euo pipefail

bootstrap() {
	: "${1:?indent required}"
	local indent="$1"
	: "${2:?repo_dir required}"
	local repo_dir="$2"
	: "${3:?os_name required}"
	local os_name="$3"

	case "$os_name" in
		Darwin)
			# shellcheck source=bootstrap/macos.sh
			source "$repo_dir/scripts/phases/bootstrap/macos.sh"
			if ! run_bootstrap_macos "$indent"; then
				log_fail "macOS bootstrap failed" "$indent"
				exit 1
			fi
			;;
		Linux)
			# shellcheck source=bootstrap/linux.sh
			source "$repo_dir/scripts/phases/bootstrap/linux.sh"
			if ! run_bootstrap_linux "$indent"; then
				log_fail "Linux bootstrap failed" "$indent"
				exit 1
			fi
			;;
		*)
			log_fail "Unsupported OS: $os_name" "$indent"
			exit 1
			;;
	esac
}
