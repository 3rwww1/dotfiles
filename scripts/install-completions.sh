#!/usr/bin/env bash
set -euo pipefail

# Symlink Homebrew-provided zsh completion files into ~/.zfunc
# so zsh can use a single secure directory without compaudit warnings.

TARGET_DIR="$HOME/.zfunc"
mkdir -p "$TARGET_DIR"

BREW_PREFIX="$(brew --prefix)"
SRC_DIRS=(
  "$BREW_PREFIX/share/zsh/site-functions"
  "$BREW_PREFIX/share/zsh-completions"
  "$HOME/.zsh/completions"
)

for dir in "${SRC_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  find "$dir" -maxdepth 1 -type f -name '_*' | while read -r f; do
    base="$(basename "$f")"
    # Skip if already a correct symlink
    if [ -L "$TARGET_DIR/$base" ] && [ "$(readlink "$TARGET_DIR/$base")" = "$f" ]; then
      continue
    fi
    ln -sf "$f" "$TARGET_DIR/$base"
  done
done

echo "Linked completions into $TARGET_DIR"
