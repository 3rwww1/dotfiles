#!/usr/bin/env bash
set -euo pipefail

# Manage Cursor extensions from this repo.
# Usage:
#   scripts/cursor-extensions.sh export   # writes cursor/extensions.txt
#   scripts/cursor-extensions.sh install  # installs from cursor/extensions.txt
#   scripts/cursor-extensions.sh sync     # export, then install (idempotent)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIST_FILE="$ROOT_DIR/cursor/extensions.txt"

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }
}

export_list() {
  need cursor
  mkdir -p "$(dirname "$LIST_FILE")"
  cursor --list-extensions | sort -f > "$LIST_FILE"
  echo "Exported $(wc -l < "$LIST_FILE" | tr -d ' ') extensions to $LIST_FILE"
}

install_list() {
  need cursor
  if [[ ! -f "$LIST_FILE" ]]; then
    echo "No $LIST_FILE found. Run: scripts/cursor-extensions.sh export" >&2
    exit 1
  fi
  # Use comm instead of mapfile for compatibility with older bash
  tmp_current="$(mktemp)"; tmp_desired="$(mktemp)"
  trap 'rm -f "$tmp_current" "$tmp_desired"' EXIT
  cursor --list-extensions | sort -f > "$tmp_current"
  sort -f "$LIST_FILE" > "$tmp_desired"
  to_install="$(comm -23 "$tmp_desired" "$tmp_current")"
  if [[ -z "$to_install" ]]; then
    echo "All extensions from list are already installed."
    return 0
  fi
  count="$(printf "%s\n" "$to_install" | sed '/^\s*$/d' | wc -l | tr -d ' ')"
  printf 'Installing %d extension(s):\n' "$count"
  printf "%s\n" "$to_install" | while IFS= read -r ext; do
    [ -z "$ext" ] && continue
    echo "  -> $ext"
    cursor --install-extension "$ext" >/dev/null || true
  done
  echo "Done."
}

case "${1:-}" in
  export)  export_list ;;
  install) install_list ;;
  sync)    export_list; install_list ;;
  *) echo "Usage: $0 {export|install|sync}" >&2; exit 2 ;;
esac
