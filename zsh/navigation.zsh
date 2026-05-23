# Navigation shortcuts
# Sourced from .zshrc - project navigation, session pickers, and file openers

# Open file/directory in Chrome as file:// URL
chrome() {
  local target="${1:-.}"
  local abs_path
  abs_path="$(cd "$(dirname "$target")" 2>/dev/null && echo "$(pwd)/$(basename "$target")")" || {
    echo "chrome: cannot resolve path: $target" >&2
    return 1
  }
  open -a "Google Chrome" "file://$abs_path"
}

# Project groups: "name=path" format (order preserved)
PROJECT_GROUPS=(
    "discovery=$CC/1. Discovery"
    "discoverysap=$CC/4. CCSAP"
    "enterpricesap=$CC/2. EPSAP"
    "dotfiles=$HOME/Personal/01. happy-learning/Kris/dotfiles"
    "prepration=$HOME/Personal/01. happy-learning/Kris/preparation"
)

# Default roots (shown directly in fzf alongside groups)
DEFAULT_ROOTS=(
    "$HOME/Personal/01. happy-learning/Kris"
    "$HOME/Personal/"
    "$HOME/Documents/"
)

# Project Navigator (fzf-based)
function op() {
    local base choice selection
    local -a roots options

    # Build list: @group names + default roots
    for entry in "${PROJECT_GROUPS[@]}"; do
        options+=("@${entry%%=*}")
    done
    options+=("${DEFAULT_ROOTS[@]}")

    # Select from list
    selection=$(printf "%s\n" "${options[@]}" | fzf --prompt="Root/Group > " --reverse) || return

    if [[ "$selection" == @* ]]; then
        local name="${selection#@}"
        # Find matching entry
        for entry in "${PROJECT_GROUPS[@]}"; do
            if [[ "${entry%%=*}" == "$name" ]]; then
                local paths="${entry#*=}"
                roots=("${(@s/:/)paths}")
                break
            fi
        done

        if [[ ${#roots[@]} -eq 1 ]]; then
            base="${roots[1]}"
        else
            base=$(printf "%s\n" "${roots[@]}" | fzf --prompt="Root ($name) > " --reverse) || return
        fi
    else
        base="$selection"
    fi

    # Browse nested dirs (track depth for ".." option)
    base="${base%/}"  # normalize trailing slash
    local start_base="$base"
    while true; do
        local -a subdirs
        subdirs=("$base"/*(N/:))  # zsh glob: dirs and symlinks-to-dirs, null on empty
        subdirs=("${subdirs[@]##*/}")  # strip path prefix, keep only names

        local dirs=""
        dirs=$(printf '%s\n' "${subdirs[@]}" | sort -Vf)

        # Add ".." option if we're deeper than start
        if [[ "$base" != "$start_base" ]]; then
            dirs=$'..\n'"$dirs"
        fi

        choice="$(printf '%s\n' "$dirs" | fzf --prompt="In $(basename "$base") > " --reverse)" || break
        [[ -z "$choice" ]] && break
        
        if [[ "$choice" == ".." ]]; then
            base="${base%/*}"
            continue
        fi
        base="$base/$choice"
    done

    cd "$base" || return
}

# Tmux session picker
function itmux() {
  local sessions
  sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

  if [[ -z "$sessions" ]]; then
    tmux new-session
    return
  fi

  local selected
  selected=$(echo "$sessions" | fzf --prompt="tmux session: " --height=10 --reverse)

  [[ -z "$selected" ]] && return

  local target_path
  target_path=$(tmux display-message -p -t "$selected:" "#{pane_current_path}" 2>/dev/null)
  if [[ -n "$target_path" ]] && typeset -f _set_wezterm_tab_title >/dev/null; then
    _set_wezterm_tab_title "$target_path"
  fi

  tmux attach-session -t "$selected"
}
