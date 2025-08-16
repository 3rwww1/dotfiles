#!/usr/bin/env bash
set -euo pipefail

#!/usr/bin/env bash
set -euo pipefail

# Link zsh completion files into ~/.zfunc so zsh uses a single user-owned dir
# and avoids compaudit prompts. Discover completions from common locations across OSes.

TARGET_DIR="$HOME/.zfunc"
mkdir -p "$TARGET_DIR"

SRC_DIRS=( )

# Homebrew locations (macOS or Linuxbrew if present)
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
  SRC_DIRS+=(
    "$BREW_PREFIX/share/zsh/site-functions"
    "$BREW_PREFIX/share/zsh-completions"
  )
fi

# Common Linux locations
SRC_DIRS+=(
  "/usr/share/zsh/site-functions"
  "/usr/share/zsh/vendor-completions"
  "/usr/local/share/zsh/site-functions"
  "$HOME/.local/share/zsh/site-functions"
  "$HOME/.zsh/completions"
)

for dir in "${SRC_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  # Files beginning with underscore are zsh functions/completions
  find "$dir" -maxdepth 1 -type f -name '_*' 2>/dev/null | while read -r f; do
    base="$(basename "$f")"
    # Skip if already a correct symlink
    if [ -L "$TARGET_DIR/$base" ] && [ "$(readlink "$TARGET_DIR/$base")" = "$f" ]; then
      continue
    fi
    ln -sf "$f" "$TARGET_DIR/$base"
  done
done

echo "Linked completions into $TARGET_DIR"
