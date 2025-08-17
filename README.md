# Dotfiles managed with GNU Stow

## Supported platforms

- macOS (arm64, Intel)
- Debian/Ubuntu Linux

## Prerequisites

- Git and Bash available on PATH
- Internet access; sudo for package installs

## Install

```bash
./install.sh
```

## Package management policy

- macOS: managed via Homebrew and `scripts/config/brewfile.rb`.
- Debian/Ubuntu: managed via apt using `scripts/config/software-list.json`.
- Debian backports are enabled automatically on Debian to install newer packages (e.g., `eza`).
