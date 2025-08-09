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
# If tfenv is installed and owning terraform shim, unlink it to avoid link conflicts
if command -v brew >/dev/null 2>&1 && brew list --formula tfenv >/dev/null 2>&1; then
  if [ -L "$(brew --prefix)/bin/terraform" ] && readlink "$(brew --prefix)/bin/terraform" | grep -q tfenv; then
    echo "Unlinking tfenv to avoid terraform link conflict..."
    brew unlink tfenv || true
  fi
fi
brew bundle --file "$REPO_DIR/brew/Brewfile"
# Ensure terraform binary is linked if installed
if command -v brew >/dev/null 2>&1 && brew list --formula terraform >/dev/null 2>&1; then
  brew link --overwrite terraform || true
fi

# Default shell change instructions (no automatic chsh)
if command -v brew >/dev/null 2>&1; then
  BREW_ZSH="$(brew --prefix)/bin/zsh"
  if [ -x "$BREW_ZSH" ]; then
    echo ""
    echo "To set Homebrew zsh as your default shell, run:" 
    echo "  BREW_ZSH=\"$BREW_ZSH\""
    echo "  grep -qxF \"$BREW_ZSH\" /etc/shells || echo \"$BREW_ZSH\" | sudo tee -a /etc/shells >/dev/null"
    echo "  chsh -s \"$BREW_ZSH\""
    echo ""
  fi
fi

echo "macOS bootstrap complete. Proceeding with common steps in installer..."
