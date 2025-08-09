# Homebrew PATH/env for all shells
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

export EDITOR=nvim
export VISUAL=nvim
export PATH="$HOME/.local/bin:$PATH"
export BASH_ENV="$HOME/.config/env/common.sh"
[ -r "$BASH_ENV" ] && source "$BASH_ENV"
