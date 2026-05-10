# Performance optimizations 
ZSH_DISABLE_COMPFIX="true"
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"

# Oh My Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"

# Versioned dump avoids stale cache after zsh upgrades
ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump-${ZSH_VERSION}"

# Completion caching (must be set before compinit runs inside OMZ)
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# Speed up compinit: intercept OMZ's call to use -C (cached dump) when dump is fresh.
# OMZ deletes the dump when its version or fpath changes, so we fall back to a full
# scan only then. This alone saves ~1-3s per shell startup.
function compinit() {
  unfunction compinit
  autoload -Uz compinit
  if [[ -s "$ZSH_COMPDUMP" ]]; then
    compinit -C -d "$ZSH_COMPDUMP"  # dump is fresh: skip directory scan
  else
    compinit -d "$ZSH_COMPDUMP"     # no dump (first run or OMZ invalidated it)
  fi
}

ZSH_THEME="spaceship-prompt/spaceship"

# Spaceship settings - async for performance
SPACESHIP_CHAR_SYMBOL="⭐️ "
SPACESHIP_TIME_SHOW=true
SPACESHIP_PROMPT_ASYNC=true
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_PROMPT_SEPARATE_LINE=false

# Minimal spaceship sections for performance
SPACESHIP_PROMPT_ORDER=(
  time
  user
  dir
  git
  char
)

# Plugins - syntax highlighting must be last
plugins=(
    zsh-history-substring-search
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Recompile zcompdump in background if it was regenerated (keeps .zwc fresh)
[[ ! "${ZSH_COMPDUMP}.zwc" -nt "$ZSH_COMPDUMP" ]] && zcompile "$ZSH_COMPDUMP" &!

# Autosuggest performance settings
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"

# PATH Configuration
export DEFAULT_USER="$USER"
export DOCKER_MIN_API_VERSION=1.24
export PATH="/opt/homebrew/opt/node@22/bin:$PATH"
export JAVA_HOME=/Users/kdvu/Library/Java/JavaVirtualMachines/temurin-21.0.4/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
export PDF_GENERATOR_EXECUTABLE="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"

# Source Development Configuration (lazy-loaded where possible)
ZSHRC_DIR="${${(%):-%x}:A:h}"
[[ -f "$ZSHRC_DIR/development.zsh" ]] && source "$ZSHRC_DIR/development.zsh"
[[ -f "$ZSHRC_DIR/git-stuff.zsh" ]] && source "$ZSHRC_DIR/git-stuff.zsh"
[[ -f "$ZSHRC_DIR/navigation.zsh" ]] && source "$ZSHRC_DIR/navigation.zsh"

# Dynamically set iTerm2 tab title to current directory name
function _set_iterm_tab_title() {
  # OSC 1: iTerm2 tab title (current dir name)
  echo -ne "\e]1;${PWD##*/}\a"

  # OSC 7: report cwd to WezTerm so tab title + git status work
  # Inside tmux the sequence must be wrapped in a DCS passthrough,
  # otherwise tmux intercepts it and WezTerm never sees it.
  if [ -n "$TMUX" ]; then
    printf "\ePtmux;\e\e]7;file://%s%s\a\e\\" "$HOST" "$PWD"
  else
    printf "\e]7;file://%s%s\a" "$HOST" "$PWD"
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _set_iterm_tab_title
add-zsh-hook precmd _set_iterm_tab_title  # also fire before every prompt, catches tmux attach
_set_iterm_tab_title  # Set on shell startup

# Load machine-local credentials (not tracked in git)
[[ -f "$HOME/.creds.zsh" ]] && source "$HOME/.creds.zsh"
