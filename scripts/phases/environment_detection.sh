#!/usr/bin/env bash
# This file is sourced by install.sh - not intended to be run directly
set -euo pipefail

environment_detection() {
	: "${1:?indent required}"
	local indent="$1"
	: "${2:?repo_dir required}"
	local repo_dir="$2"
	: "${3:?os_name required}"
	local os_name="$3"
	: "${4:?arch_name required}"
	local arch_name="$4"
	: "${6:?stamp_file required}"
	local stamp_file="$6"

	local prev_desc="" human_prev=""
	if [[ -f "$stamp_file" ]]; then
		local stamp_line prev_iso prev_sha
		stamp_line="$(cat "$stamp_file" 2>/dev/null || true)"
		prev_iso="${stamp_line%% *}"
		prev_sha="${stamp_line##*repo=}"
		case "$os_name" in
			Darwin) human_prev="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$prev_iso" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || printf "%s" "$prev_iso")" ;;
			*) human_prev="$(date -d "$prev_iso" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || printf "%s" "$prev_iso")" ;;
		esac
		log_info "Last install time: $(text_bold "$human_prev")" "$indent"
		prev_desc="$(git -C "$repo_dir" describe --always "$prev_sha" 2>/dev/null || printf "%s" "$prev_sha")"
	fi

	# Platform in golang style: os/arch
	local goos goarch
	if command -v go >/dev/null 2>&1; then
		goos="$(go env GOOS 2>/dev/null || true)"
		goarch="$(go env GOARCH 2>/dev/null || true)"
	else
		goos="$(printf '%s' "$os_name" | tr '[:upper:]' '[:lower:]')"
		case "$arch_name" in
			x86_64 | amd64) goarch="amd64" ;;
			aarch64 | arm64) goarch="arm64" ;;
			armv7l) goarch="arm" ;;
			*) goarch="$(printf '%s' "$arch_name" | tr '[:upper:]' '[:lower:]')" ;;
		esac
	fi
	log_info "Platform: $(text_bold "${goos}/${goarch}")" "$indent"

	local curr_desc
	curr_desc="$(git -C "$repo_dir" describe --dirty --always 2>/dev/null || git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
	if [[ -n "$prev_desc" ]]; then
		log_info "Git metadata: previous [$(text_bold "$prev_desc")], current [$(text_bold "$curr_desc")]" "$indent"
	else
		log_info "Git metadata: current [$(text_bold "$curr_desc")]" "$indent"
	fi
}
