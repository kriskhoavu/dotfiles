# A shell in Neovim's :terminal is a child of Neovim, not of tmux, but inherits
# $TMUX anyway. Anything that checks it wraps clipboard writes in tmux's DCS
# passthrough form, which Neovim cannot decode -- the payload lands on screen as
# raw base64. Dropping $TMUX gets plain OSC 52 instead. `tmux` still reaches its
# server over the default socket.
if [[ -n "$NVIM" && -n "$TMUX" ]]; then
  unset TMUX TMUX_PANE
fi

# Performance optimizations 
ZSH_DISABLE_COMPFIX="true"
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"

# Normalize fpath before OMZ touches it. `brew shellenv` exports FPATH, so OMZ
# prepends its 7 dirs again per nesting level. OMZ fingerprints $fpath into the
# zcompdump and drops the dump when it changes, so login and nested shells kept
# invalidating each other at ~1-3s a time. Dedupe makes it shell-independent.
typeset -U fpath
fpath=(${(o)fpath})

# Oh My Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"

# Versioned dump avoids stale cache after zsh upgrades
ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump-${ZSH_VERSION}"

# Completion caching (must be set before compinit runs inside OMZ)
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# Intercept OMZ's compinit to use -C while the dump is fresh; OMZ deletes it
# when its version or fpath changes, so a full scan happens only then. ~1-3s.
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

# Spaceship settings
SPACESHIP_CHAR_SYMBOL="⭐️ "
SPACESHIP_TIME_SHOW=true
SPACESHIP_PROMPT_ASYNC=true
SPACESHIP_GIT_ASYNC=false
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_PROMPT_SEPARATE_LINE=false
SPACESHIP_RPROMPT_ADD_NEWLINE=true

# Minimal spaceship sections for performance
SPACESHIP_PROMPT_ORDER=(
  time
  user
  dir
  git
  char
)

# Order matters: history-substring-search after syntax-highlighting, per its
# README. Reversed, their zle-line-pre-redraw hooks recurse and zsh spins at 100%.
plugins=(
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)

# OMZ recompiles under a mkdir lock; a shell killed mid-recompile leaks it and
# OMZ silently skips the .zwc forever. Clear only once it is minutes old.
_zsh_stale_lock=( "${ZSH_COMPDUMP}.lock"(N/mm+5) )
(( $#_zsh_stale_lock )) && rmdir "${ZSH_COMPDUMP}.lock" 2>/dev/null
unset _zsh_stale_lock

source $ZSH/oh-my-zsh.sh

# Autosuggest performance settings
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"

# Up/Down search history for what is typed. Rebound after OMZ, which claims them.
# Literal escapes ([A/[B normal, OA/OB application) -- $terminfo can be empty.
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down

# Match words in order with gaps, so "git commit" finds "git -C repo commit".
HISTORY_SUBSTRING_SEARCH_FUZZY=1
# No hist_*_dups option is on, so dedupe matches here.
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

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

# Dynamically set WezTerm tab title to current directory
function _set_wezterm_tab_title() {
  # Skip inside Neovim's terminal — it doesn't support OSC 7
  [[ -n "$NVIM" ]] && return

  local osc7
  local target_path="${1:-$PWD}"

  # OSC 7: report cwd to WezTerm for the tab title and git status. Inside tmux
  # it needs the DCS passthrough wrapper, or tmux eats it.
  if [ -n "$TMUX" ]; then
    osc7=$'\ePtmux;\e\e]7;file://'"$HOST$target_path"$'\a\e\\'
  else
    osc7=$'\e]7;file://'"$HOST$target_path"$'\a'
  fi

  # Mark the terminal escape as zero-width so zsh doesn't move the edit buffer.
  print -rnP "%{${osc7}%}"
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _set_wezterm_tab_title
add-zsh-hook precmd _set_wezterm_tab_title  # also fire before every prompt, catches tmux attach
_set_wezterm_tab_title  # Set on shell startup

# Load machine-local credentials (not tracked in git)
[[ -f "$HOME/.creds.zsh" ]] && source "$HOME/.creds.zsh"
export PATH="$HOME/.local/bin:$PATH"

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/kdvu/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
