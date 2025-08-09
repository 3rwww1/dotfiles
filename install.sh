#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"
ARCH="$(uname -m)"
STAMP_DIR="$HOME/.config/dotfiles"
STAMP_FILE="$STAMP_DIR/install.stamp"
mkdir -p "$STAMP_DIR"
if [[ -f "$STAMP_FILE" ]]; then
  echo "Previous install: $(cat "$STAMP_FILE" 2>/dev/null || true)"
fi

echo "Detected platform: ${OS} ${ARCH}"

case "$OS" in
  Darwin)
    echo "Running macOS bootstrap..."
    "$REPO_DIR/scripts/bootstrap-macos.sh"
    ;;
  Linux)
    echo "Running Linux bootstrap..."
    "$REPO_DIR/scripts/bootstrap-linux.sh"
    ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

echo "Deploying dotfiles with stow..."
"$REPO_DIR/scripts/stow-all.sh"
echo "Linking completions into ~/.zfunc..."
"$REPO_DIR/scripts/install-completions.sh" || true

if command -v cursor >/dev/null 2>&1; then
  echo "Ensuring Cursor extensions from repo are installed..."
  "$REPO_DIR/scripts/cursor-extensions.sh" install || true
fi

echo "Install complete."
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) repo=$(cd "$REPO_DIR" && git rev-parse --short HEAD 2>/dev/null || echo unknown)" > "$STAMP_FILE"
"$REPO_DIR/scripts/self-test.sh" || true

if [[ "$OS" == "Darwin" ]]; then
  echo ""
  echo "To finish privileged steps (Rosetta, default shell, sudo Touch ID), run:"
  echo "  sudo $REPO_DIR/scripts/post-install-privileged.sh"
fi

# Enable Corepack for Node package managers and remove global Yarn if present
if command -v corepack >/dev/null 2>&1; then
  corepack enable || true
fi
if command -v yarn >/dev/null 2>&1; then
  echo "Detected Yarn on PATH. Ensuring Corepack manages yarn..."
  # Remove only if actually installed by npm/brew; avoid errors when yarn is just a Corepack shim
  if command -v npm >/dev/null 2>&1 && npm ls -g yarn >/dev/null 2>&1; then
    npm uninstall -g yarn || true
  fi
  if command -v brew >/dev/null 2>&1 && brew list --formula yarn >/dev/null 2>&1; then
    brew uninstall --ignore-dependencies yarn || true
  fi
fi

exit 0
