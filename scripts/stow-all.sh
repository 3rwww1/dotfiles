#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$REPO_DIR"

PACKAGES=(zsh vim nvim git starship editorconfig)
if [[ "$(uname -s)" == "Darwin" ]]; then
  PACKAGES+=(cursor ghostty)
fi

for pkg in "${PACKAGES[@]}"; do
  if [ -d "$pkg" ]; then
    echo "Stowing $pkg"
    stow -v -t "$HOME" "$pkg"
  fi
done
