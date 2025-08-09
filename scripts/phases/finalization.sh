#!/usr/bin/env bash
# This file is sourced by install.sh - not intended to be run directly
set -euo pipefail

finalization() {
	: "${1:?indent required}"; local indent="${1}"
	: "${2:?repo_dir required}"; local repo_dir="${2}"
	: "${3:?os_name required}"; local os_name="${3}"
	: "${4:?stamp_dir required}"; local stamp_dir="${4}"
	: "${5:?stamp_file required}"; local stamp_file="${5}"

	local now_iso now_local
	now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	mkdir -p "${stamp_dir}"
	echo "${now_iso} repo=$(cd "${repo_dir}" && git rev-parse --short HEAD 2>/dev/null || echo unknown)" >"${stamp_file}"
	case "${os_name}" in
		Darwin)
			now_local="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${now_iso}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || printf "%s" "${now_iso}")"
			log_info "Run this script as sudo to finish install:" "${indent}"
			indent_next=$((indent + 2))
			log_info "$(text_bold "sudo ${repo_dir}/scripts/post-install-privileged.sh")" "${indent_next}"
			;;
		*)
			now_local="$(date -d "${now_iso}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || printf "%s" "${now_iso}")"
			;;
	esac
	log_pass "Install complete at $(text_bold "${now_local}")" "${indent}"
}
