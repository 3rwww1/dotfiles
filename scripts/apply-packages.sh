#!/usr/bin/env bash
set -euo pipefail

# Define OS-specific package present/absent policy and enforce it.
# Keep this script simple and idempotent (DRY, YAGNI, KISS).

OS="$(uname -s)"

# Load lists from files
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
read_list() { awk 'NF && $1 !~ /^#/' "$1" 2>/dev/null || true; }

present=( $(read_list "$ROOT_DIR/packages/common/present.txt") )
absent=( $(read_list "$ROOT_DIR/packages/common/absent.txt") )

if [[ "$OS" == "Darwin" ]]; then
  # Prefer Brewfile for macOS present packages
  if command -v brew >/dev/null 2>&1; then
    echo "Applying Brewfile packages..."
    brew bundle --file "$ROOT_DIR/packages/macos/Brewfile"
  fi
  absent+=( $(read_list "$ROOT_DIR/packages/macos/absent.txt") )
elif [[ "$OS" == "Linux" ]]; then
  present+=( $(read_list "$ROOT_DIR/packages/linux/present.txt") )
  absent+=( $(read_list "$ROOT_DIR/packages/linux/absent.txt") )
fi

# Helper: check command availability
need() { command -v "$1" >/dev/null 2>&1; }

# Install missing present packages using available manager (brew or apt)
install_pkg() {
  local pkg="$1"
  if need brew; then
    brew list --formula "$pkg" >/dev/null 2>&1 || brew install "$pkg" || true
  elif need apt-get; then
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get update -y || true
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$pkg" || true
  fi
}

# Uninstall unwanted packages
remove_pkg() {
  local pkg="$1"
  if need brew && brew list --formula "$pkg" >/dev/null 2>&1; then
    brew uninstall --ignore-dependencies "$pkg" || true
  elif need npm && npm ls -g "$pkg" >/dev/null 2>&1; then
    npm uninstall -g "$pkg" || true
  elif need apt-get; then
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get remove -y "$pkg" || true
  fi
}

for pkg in "${present[@]}"; do
  need "$pkg" || install_pkg "$pkg"
done

for pkg in "${absent[@]}"; do
  if need "$pkg"; then
    echo "Removing $pkg as per policy..."
    remove_pkg "$pkg"
  fi
done

# Special: ensure corepack is enabled if present
if need corepack; then
  corepack enable || true
fi
