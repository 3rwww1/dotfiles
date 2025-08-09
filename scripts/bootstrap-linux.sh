#!/usr/bin/env bash
set -euo pipefail

# Linux-specific bootstrap (Ubuntu/Debian best-effort)

if command -v apt-get >/dev/null 2>&1; then
  echo "Ensuring base packages are present via apt..."
  # Use sudo when not root; run directly when root (e.g., CI containers)
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
  $SUDO apt-get update -y || true
  # Install common tools; ignore missing packages on older releases
  for pkg in git stow zsh curl ca-certificates ripgrep bat fd-find fzf zoxide tmux htop jq shellcheck eza nodejs npm golang rustc cargo python3-pip; do
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$pkg" || true
  done
  # Create convenience shims if Debian-style names are used
  if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin" && ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    echo "Added bat shim at ~/.local/bin/bat"
    export PATH="$HOME/.local/bin:$PATH"
  fi
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin" && ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    echo "Added fd shim at ~/.local/bin/fd"
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi

echo "Linux bootstrap complete. Proceeding with common steps in installer..."
