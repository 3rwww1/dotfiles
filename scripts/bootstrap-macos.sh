#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

if ! command -v xcode-select >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install || true
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Rosetta 2: skipped here to avoid requiring sudo. Run the privileged post-install script if needed.

echo "Running Brew Bundle..."
brew bundle --file "$REPO_DIR/brew/Brewfile"

# Initialize tfenv and default to latest terraform
if command -v tfenv >/dev/null 2>&1; then
  echo "Ensuring latest Terraform with tfenv..."
  tfenv install latest || true
  tfenv use latest || true
fi

echo "macOS bootstrap complete. Proceeding with common steps in installer..."
