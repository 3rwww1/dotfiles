Dotfiles managed via GNU Stow.

## Install (macOS arm64)

Prereqs: macOS on Apple Silicon. Other platforms: not supported by the installer yet.

1) Run installer

```
./install.sh
```

This will:
- Install Homebrew deps (via Brewfile)
- Install Rosetta 2 if needed (arm64)
- Set Homebrew zsh as default shell (prompts for password)
- Stow all dotfiles into $HOME
- Link all Homebrew/user completions into `~/.zfunc`
- Install Cursor extensions from `cursor/extensions.txt` (managed in-repo; not stowed into `$HOME`)

2) Manual steps (one-time)

- Rosetta (if not already installed):
  ````
  sudo softwareupdate --install-rosetta --agree-to-license
  ````
- Default shell (if not already set):
  ````
  BREW_ZSH="$(brew --prefix)/bin/zsh"
  grep -qxF "$BREW_ZSH" /etc/shells || echo "$BREW_ZSH" | sudo tee -a /etc/shells >/dev/null
  chsh -s "$BREW_ZSH"
  ```

## Usage

- Export Cursor extensions: `cext` (writes `cursor/extensions.txt`; file remains in repo)
- Manage Cursor extensions: `scripts/cursor-extensions.sh {export|install|sync}`
- Refresh completions: `scripts/install-completions.sh`

## Vale (prose linter)

- Installed via Brewfile (`vale`).
- Global config at `~/.vale.ini` (example):
  ```
  StylesPath = ~/.vale/styles
  Packages = Google
  MinAlertLevel = warning

  [*]
  BasedOnStyles = Google
  Ignored = node_modules, vendor, dist, build, .git, .terraform, .cache
  ```
- Sync styles: `vale sync`
- Global pre-commit: wrapper runs repo hooks first (if present) then global `~/.config/pre-commit/global.yaml` (Vale).
  - Global config filters to common prose types and excludes build dirs.

## Devcontainers

- A minimal Debian devcontainer is provided under `docker/Dockerfile` for CI/local testing.
- To build and run locally:
  ```
  docker build -t dotfiles-dev -f docker/Dockerfile .
  docker run --rm -it dotfiles-dev
  ```
- If you prefer the official Node devcontainer image instead of Debian, use:
  ```json
  {
    "image": "mcr.microsoft.com/devcontainers/javascript-node:0-20-bookworm"
  }
  ```
  Or keep Ubuntu and add the Node feature:
  ```json
  {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": { "ghcr.io/devcontainers/features/node:1": { "version": "20" } }
  }
  ```

## Behavior highlights

- Zsh
  - Emacs keybindings (Ctrl-A/E/U/K), Alt+Arrows jump by word
  - Oh-my-zsh-like completion UX with highlight, groups, colors, caching
  - Secure completion directories: `~/.zfunc`, `~/.zsh/completions`
- Prompt: Starship
- History: Atuin (Ctrl-R search; Up Arrow classic)
- Editor: Cursor settings/keybindings tracked and stowed (extensions list is repo-local)
- Terminal: Ghostty font set to JetBrainsMono Nerd Font
- Env activation: direnv hook enabled
  - Python: activate venv in project if present
  - Ruby/Node: use your version manager (mise/rbenv/nodenv) if configured
- Terraform: tfenv installed and defaults to latest (`tfenv install/use latest`); completion via `complete -C`

## Layout
- zsh -> ~/.zshrc, ~/.zprofile, ~/.zshenv
- starship -> ~/.config/starship.toml
- vim -> ~/.vimrc
- nvim -> ~/.config/nvim/init.vim
- git -> ~/.gitconfig, ~/.gitignore_global
- cursor -> ~/Library/Application Support/Cursor/User/{settings.json,keybindings.json}
- ghostty -> ~/Library/Application Support/com.mitchellh.ghostty/config
