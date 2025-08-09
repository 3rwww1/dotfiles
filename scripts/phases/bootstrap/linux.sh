#!/usr/bin/env bash
# Sourced by phases/bootstrap.sh
set -euo pipefail

run_bootstrap_linux() {
	: "${1:?indent required}"; local indent="$1"
	if command -v apt-get >/dev/null 2>&1; then
		local sudo_cmd="sudo"; if [ "$(id -u)" -eq 0 ]; then sudo_cmd=""; fi
		log_info "apt-get update" "$indent"
		log_cmd "$indent" $sudo_cmd apt-get update -y || log_fail "apt-get update failed" "$indent"
	fi
	log_info "Linux bootstrap complete" "$indent"
}
