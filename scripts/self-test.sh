#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OS="$(uname -s)"
ARCH="$(uname -m)"

pass=0
fail=0
warn=0
note() { printf "[NOTE] %s\n" "$*"; }
ok() { printf "[ OK ] %s\n" "$*"; pass=$((pass+1)); }
ko() { printf "[FAIL] %s\n" "$*"; fail=$((fail+1)); }
wn() { printf "[WARN] %s\n" "$*"; warn=$((warn+1)); }

check_link() {
  local target="$1"
  if [ -L "$target" ]; then
    ok "Symlink exists: $target -> $(readlink "$target")"
  else
    if [ -e "$target" ]; then
      wn "Not a symlink (exists as file/dir): $target"
    else
      ko "Missing expected symlink: $target"
    fi
  fi
}

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "Command available: $cmd ($(command -v "$cmd"))"
  else
    ko "Command missing: $cmd"
  fi
}

printf "Running dotfiles self-test on %s %s\n" "$OS" "$ARCH"

# Basic commands (required)
for c in zsh stow git; do check_cmd "$c"; done

# Symlinks from stow
check_link "$HOME/.zshrc"
check_link "$HOME/.zprofile"
check_link "$HOME/.zshenv"
check_link "$HOME/.config/starship.toml"

# Completions presence
if ls "$HOME/.zfunc"/_* >/dev/null 2>&1; then
  ok "Found completion files in ~/.zfunc"
else
  wn "No completion files found in ~/.zfunc (this may be OK on fresh Linux)"
fi

# Cursor extensions (optional)
if command -v cursor >/dev/null 2>&1; then
  if "$REPO_DIR/scripts/cursor-extensions.sh" install; then
    ok "Cursor extensions installed from repo list"
  else
    wn "Cursor extension install reported issues"
  fi
else
  note "Cursor CLI not found; skipping Cursor extension check"
fi

# Optional favorites (warn if missing)
# Adjust list by OS to avoid noisy warnings (e.g., batcat/fdfind on macOS)
fav_common=(
  rg fzf zoxide tmux htop jq shellcheck starship atuin \
  gh kubectl aws gcloud docker podman kind k9s trivy mise \
  node deno python3 pipx vim nvim direnv terraform ykman go cargo
)
fav_macos=( bat fd )
fav_linux=( bat batcat fd fdfind )

fav=( "${fav_common[@]}" )
case "$OS" in
  Darwin)
    fav+=( "${fav_macos[@]}" )
    ;;
  Linux)
    fav+=( "${fav_linux[@]}" )
    ;;
esac
for c in "${fav[@]}"; do
  if command -v "$c" >/dev/null 2>&1; then
    ok "Command available: $c"
  else
    wn "Command missing (optional): $c"
  fi
done

# Print next steps for macOS privileged items
if [[ "$OS" == "Darwin" ]]; then
  printf "\nNext (manual, may require sudo):\n"
  printf "  sudo %s/scripts/post-install-privileged.sh\n" "$REPO_DIR"
fi

printf "\nSelf-test summary: %d ok, %d warn, %d fail\n" "$pass" "$warn" "$fail"
# Do not fail the run; provide exit code reflecting failures for CI if desired
exit 0
