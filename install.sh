#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
# Ensure user-local bin is on PATH (for installer-provided tools like mise)
export PATH="${HOME}/.local/bin:${PATH}"
# Ensure mise-managed shims are on PATH for this installer run
export PATH="${HOME}/.local/share/mise/shims:${PATH}"
# shellcheck source=scripts/helpers/log.sh
source "$REPO_DIR/scripts/helpers/log.sh"
# shellcheck source=scripts/phases/environment_detection.sh
source "$REPO_DIR/scripts/phases/environment_detection.sh"
# shellcheck source=scripts/phases/bootstrap.sh
source "$REPO_DIR/scripts/phases/bootstrap.sh"
# shellcheck source=scripts/phases/package_sync.sh
source "$REPO_DIR/scripts/phases/package_sync.sh"
# shellcheck source=scripts/phases/common_config.sh
source "$REPO_DIR/scripts/phases/common_config.sh"
# shellcheck source=scripts/phases/self_test.sh
source "$REPO_DIR/scripts/phases/self_test.sh"
# shellcheck source=scripts/phases/finalization.sh
source "$REPO_DIR/scripts/phases/finalization.sh"

main() {
  local stamp_dir
  local stamp_file
  local os_name
  local arch_name
  local phase_idx
  local phase_total
  local indent
  # Compute OS and ARCH once
  os_name="$(uname -s)"
  arch_name="$(uname -m)"
  stamp_dir="$HOME/.config/dotfiles"
  stamp_file="$stamp_dir/install.stamp"
  phase_total=6
  indent=1

  mkdir -p "$stamp_dir"
  phase_idx=1
  log_phase "[${phase_idx}/${phase_total}] Environment detection"
  environment_detection "$indent" "$REPO_DIR" "$os_name" "$arch_name" "$stamp_dir" "$stamp_file"

  phase_idx=$((phase_idx + 1))
  log_phase "[${phase_idx}/${phase_total}] Bootstrap"
  bootstrap "$indent" "$REPO_DIR" "$os_name"

  phase_idx=$((phase_idx + 1))
  log_phase "[${phase_idx}/${phase_total}] Package sync"
  package_sync "$indent" "$REPO_DIR"

  phase_idx=$((phase_idx + 1))
  log_phase "[${phase_idx}/${phase_total}] Common config"
  common_config "$indent" "$REPO_DIR" "$os_name"

  phase_idx=$((phase_idx + 1))
  log_phase "[${phase_idx}/${phase_total}] Self-test"
  self_test "$indent" "$REPO_DIR"

  phase_idx=$((phase_idx + 1))
  log_phase "[${phase_idx}/${phase_total}] Finalization"
  finalization "$indent" "$REPO_DIR" "$os_name" "$stamp_dir" "$stamp_file"
}

main "$@"
