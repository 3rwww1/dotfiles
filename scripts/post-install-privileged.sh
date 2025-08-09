#!/usr/bin/env bash
set -euo pipefail

# This script performs privileged setup steps. Run it manually with sudo:
#   sudo scripts/post-install-privileged.sh

OS="$(uname -s)"
ARCH="$(uname -m)"

if [[ "$OS" != "Darwin" ]]; then
  echo "This script is only for macOS." >&2
  exit 1
fi

# 1) Rosetta 2 (Apple Silicon only)
if [[ "$ARCH" == "arm64" ]]; then
  if ! pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
    echo "Installing Rosetta 2..."
    softwareupdate --install-rosetta --agree-to-license || true
  else
    echo "Rosetta 2 already installed."
  fi
fi

# 2) Set Homebrew zsh as default shell
if command -v brew >/dev/null 2>&1; then
  BREW_ZSH="$(brew --prefix)/bin/zsh"
  if [ -x "$BREW_ZSH" ]; then
    if ! grep -qxF "$BREW_ZSH" /etc/shells; then
      echo "Adding $BREW_ZSH to /etc/shells..."
      echo "$BREW_ZSH" >>/etc/shells
    fi
    if [ "${SHELL:-}" != "$BREW_ZSH" ]; then
      echo "Changing default shell to $BREW_ZSH..."
      chsh -s "$BREW_ZSH" "$SUDO_USER"
    fi
  fi
fi

# 3) sudo Touch ID (auth_tid.so)
# Enable Touch ID for sudo by ensuring pam_tid.so is present in pam config.
PAM_SUDO_FILE="/etc/pam.d/sudo"
if [ -f "$PAM_SUDO_FILE" ] && ! grep -qE '^auth\s+sufficient\s+pam_tid\.so' "$PAM_SUDO_FILE"; then
  echo "Enabling Touch ID for sudo (adding pam_tid.so)..."
  # Insert at the top for precedence
  printf '%s
%s
' 'auth       sufficient     pam_tid.so' "$(cat "$PAM_SUDO_FILE")" >"$PAM_SUDO_FILE"
else
  echo "Touch ID for sudo already enabled or pam file missing."
fi

echo "Privileged setup complete."
