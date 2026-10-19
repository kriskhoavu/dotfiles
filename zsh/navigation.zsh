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
# Paths missing on this machine are left out of op's list.
KODE_STREAM_PATH="$HOME/Personal/01. happy-learning/Kris/kompas/kode-stream"

PROJECT_GROUPS=(
    "discovery=$CC_ROOT/1. Discovery"
    "discoverysap=$CC_ROOT/4. CCSAP"
    "enterpricesap=$CC_ROOT/2. EPSAP"
    "dotfiles=${ZSHRC_DIR:h}"
    "kode-stream=$KODE_STREAM_PATH"
    "prepration=$HOME/Personal/01. happy-learning/Kris/preparation"
)

# Default roots (shown directly in fzf alongside groups)
DEFAULT_ROOTS=(
    "$HOME/Personal/01. happy-learning/Kris"
    "$HOME/Personal/"
    "$HOME/Documents/"
)

# User-added roots persist outside the dotfiles repository.
OP_ROOTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/op-roots"
OP_SAVED_ROOTS=()

function _op_load_roots() {
    local op_root

    [[ -r "$OP_ROOTS_FILE" ]] || return
    while IFS= read -r op_root; do
        [[ -d "$op_root" ]] && OP_SAVED_ROOTS+=("$op_root")
    done < "$OP_ROOTS_FILE"
}
_op_load_roots

# Save the current directory (or an optional directory) as an op root.
function op-add() {
    local target="${1:-$PWD}"
    local resolved

    resolved="${target:A}"
    [[ -d "$resolved" ]] || {
        echo "op-add: not a directory: $target" >&2
        return 1
    }

    mkdir -p "${OP_ROOTS_FILE:h}" || return

    if [[ -f "$OP_ROOTS_FILE" ]] && grep -Fqx -- "$resolved" "$OP_ROOTS_FILE"; then
        echo "op-add: already saved: $resolved"
        return 0
    fi

    print -r -- "$resolved" >> "$OP_ROOTS_FILE"
    OP_SAVED_ROOTS+=("$resolved")
    echo "op-add: saved: $resolved"
}

# Remove a saved op root. With no argument, pick one interactively.
function op-rmv() {
    local target resolved op_root temp_file
    local -a remaining_roots

    if (( $# )); then
        target="$1"
    else
        (( ${#OP_SAVED_ROOTS[@]} )) || {
            echo "op-rmv: no saved roots" >&2
            return 1
        }
        target="$(printf '%s\n' "${OP_SAVED_ROOTS[@]}" | fzf --prompt="Remove op root > " --reverse)" || return
    fi

    resolved="${target:A}"
    [[ -d "$resolved" ]] || {
        echo "op-rmv: not a directory: $target" >&2
        return 1
    }

    if [[ ! -f "$OP_ROOTS_FILE" ]] || ! grep -Fqx -- "$resolved" "$OP_ROOTS_FILE"; then
        echo "op-rmv: not a saved root: $resolved" >&2
        return 1
    fi

    temp_file="$(mktemp "${OP_ROOTS_FILE}.XXXXXX")" || return
    while IFS= read -r op_root; do
        [[ "$op_root" == "$resolved" ]] || print -r -- "$op_root"
    done < "$OP_ROOTS_FILE" > "$temp_file"
    mv "$temp_file" "$OP_ROOTS_FILE"

    for op_root in "${OP_SAVED_ROOTS[@]}"; do
        [[ "$op_root" == "$resolved" ]] || remaining_roots+=("$op_root")
    done
    OP_SAVED_ROOTS=("${remaining_roots[@]}")
    echo "op-rmv: removed: $resolved"
}

# Project Navigator (fzf-based)
function op() {
    local base choice selection
    local -a roots options

    # Build list: @group names + default roots, only those present here
    for entry in "${PROJECT_GROUPS[@]}"; do
        [[ -d "${entry#*=}" ]] && options+=("@${entry%%=*}")
    done
    for entry in "${DEFAULT_ROOTS[@]}"; do
        [[ -d "$entry" ]] && options+=("$entry")
    done
    options+=("${OP_SAVED_ROOTS[@]}")

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
