#!/usr/bin/env bash
# Sourced by phases/bootstrap.sh
set -euo pipefail

run_bootstrap_macos() {
	: "${1:?indent required}"; local indent="$1"
	local brew_source="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
	if ! xcode-select -p >/dev/null 2>&1; then
		log_info "Installing Xcode Command Line Tools" "$indent"
		log_cmd "$indent" xcode-select --install || { log_fail "Xcode Command Line Tools installation failed" "$indent"; exit 1; }
		log_pass "Xcode Command Line Tools installed" "$indent"
	else
		log_pass "Xcode Command Line Tools present" "$indent"
	fi
	if ! command -v brew >/dev/null 2>&1; then
		log_info "Installing Homebrew" "$indent"
		log_cmd "$indent" /bin/bash -c "$(curl -fsSL ${brew_source})" || { log_fail "Homebrew installer failed" "$indent"; exit 1; }
		log_pass "Homebrew installed" "$indent"
	else
		log_pass "Homebrew present" "$indent"
	fi
	log_info "macOS bootstrap complete" "$indent"
}
