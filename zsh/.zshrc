### Runtime managers first
eval "$(direnv hook zsh)"
eval "$(mise activate zsh --shims)"
eval "$(mise direnv activate)"

# Bash completion system
autoload -Uz bashcompinit && bashcompinit
# Zsh completion system: use secure user dirs to avoid compaudit prompts
autoload -Uz compinit
fpath+=("$HOME/.zsh/completions")
fpath+=("$HOME/.zfunc")
compinit

# Use Emacs keybindings
bindkey -e

# Colors for nicer completion messages
autoload -Uz colors && colors

# Zsh options (sensible defaults)
setopt autocd              # cd into a directory by typing its name
setopt extendedglob        # advanced globbing (for scripts and fzf)
setopt correct             # spell-check commands before running
setopt no_beep             # disable terminal bell
setopt nocaseglob          # case-insensitive globbing

# Better completion UI with selectable menu (highlight current item)
zmodload zsh/complist
# Show a navigable menu with highlight; start menu on first Tab
zstyle ':completion:*' menu select=1
# Group results with colored section headers
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':completion:*:warnings'     format '%F{red}%d%f'
# Use LS_COLORS for list coloring when available
if [[ -n "${LS_COLORS:-}" ]]; then
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
fi
# Case-insensitive and partial/fuzzy-ish matching similar to oh-my-zsh
zstyle ':completion:*' matcher-list \
  'm:{a-z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'
# Cache completion results for speed
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zcompcache"

if command -v brew >/dev/null 2>&1; then
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
  # Debian/Ubuntu paths
  [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

eval "$(zoxide init zsh)"

eval "$(atuin init zsh --disable-up-arrow)"

# LS replacement (exa), paging (bat), search (rg), process viewer (htop)
alias ls='eza --group-directories-first --git --icons=always $@'
alias l='ls -l'
alias ll='l'
alias la='ls -la'
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
fi
alias cat='bat --style=snip,header --paging=never'
alias less='bat --style=snip,header --paging=always'
alias more='less'
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind'
fi
alias rg='rg --hidden --line-number --color=always'
alias top='sudo htop'
alias t='tmux'

# Git & GitHub shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias ghpr='gh pr status'

# Docker shortcuts
alias d='docker'
alias dc='docker-compose'

# Kubernetes & AWS
alias k='kubectl'
alias kns='kubectl config set-context --current --namespace'
alias awsls='aws s3 ls'

# Misc
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'

# Option/Alt + Arrow keys jump by word (macOS)
# Works in Terminal.app and iTerm2 when terminal sends ESC+f/b
bindkey '^[f' forward-word
bindkey '^[b' backward-word
bindkey '^[^[[C' forward-word
bindkey '^[^[[D' backward-word
bindkey '^[^[[1;3C' forward-word
bindkey '^[^[[1;3D' backward-word
bindkey '^[[Z' reverse-menu-complete

# Cursor helpers

# Git cherry-pick completion: show commits first, keep reverse-chronological order
zstyle ':completion:*:*:git-cherry-pick:*' tag-order 'commits' 'heads' 'tags' '*'
zstyle ':completion:*:*:git-cherry-pick:*' sort false

# Terraform completion (uses bash-style completion via bashcompinit)
if command -v terraform >/dev/null 2>&1; then
  complete -o nospace -C "$(command -v terraform)" terraform
fi

# Starship prompt should go last
eval "$(starship init zsh)"
