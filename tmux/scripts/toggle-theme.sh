#!/bin/bash
# Flip this config between light and dark.
#
# The theme is our own state, in ~/.config/kris-theme, not macOS's. None of the
# three tools can follow the system appearance by itself: tmux answers an OSC 11
# query from a value it cached when its client attached, nothing can tell a
# running Neovim the desktop changed, and WezTerm only re-reads its config when
# a config file changes. Since a script has to exist either way, it owns the
# state rather than mirroring macOS into three places.
#
# Anything but "light" in that file is dark, so a missing file is dark.
#
# Each tool is then told in the way it accepts:
#   WezTerm  touch its config -- it watches for that and re-reads the state
#   tmux     re-source, which re-runs the if-shell in .tmux.conf
#   Neovim   restart, the only way an editor picks up a new background
#
# Usage: toggle-theme.sh [light|dark] [-n]
#        no argument flips to the opposite of the current theme
#        -n  shows what would happen and changes nothing

set -uo pipefail

STATE="$HOME/.config/kris-theme"
WEZTERM_CONFIG="$HOME/.config/wezterm/wezterm.lua"

DRY=0
TARGET=""
for arg in "$@"; do
    case "$arg" in
        -n) DRY=1 ;;
        light|dark) TARGET="$arg" ;;
        *) echo "usage: ${0##*/} [light|dark] [-n]" >&2; exit 2 ;;
    esac
done

current=dark
[[ $(cat "$STATE" 2>/dev/null) == light ]] && current=light
[[ -z $TARGET ]] && { [[ $current == dark ]] && TARGET=light || TARGET=dark; }

echo "$current -> $TARGET"

if (( ! DRY )); then
    mkdir -p "${STATE%/*}"
    printf '%s\n' "$TARGET" > "$STATE"
fi

echo "── WezTerm ──"
if [[ -e $WEZTERM_CONFIG ]]; then
    # WezTerm reloads when a config file changes, and re-reads the state file on
    # the way through. Nothing else here can reach a running GUI.
    echo "  touching $WEZTERM_CONFIG"
    (( DRY )) || touch "$WEZTERM_CONFIG"
else
    echo "  (no config at $WEZTERM_CONFIG)"
fi

echo "── tmux ──"
if tmux info &>/dev/null; then
    # Just the theme file, not ~/.tmux.conf: sourcing the whole config re-runs
    # tpm and every plugin with it, measured at ~1.4s -- the bulk of what the
    # keypress used to cost. The theme file is self-contained now: it sets the
    # pane-chrome options, the two border styles, mode-style and the popup
    # styles outright, so sourcing it is the whole job. (It used to need a
    # second call to re-apply mode-style, which catppuccin claimed at tpm time.)
    # Everything the status bar draws with is identical in both themes.
    echo "  sourcing themes/$TARGET.conf"
    (( DRY )) || tmux source-file "$HOME/.config/tmux/themes/$TARGET.conf"
else
    echo "  (no tmux server running)"
fi

# Neovim runs the editor as `nvim --embed` behind the TUI, and its socket is
# named for that pid. --remote-expr blocks forever against an instance that is
# busy or waiting on a prompt, so cap every call. (Same guard as
# reload-shells.sh, for the same reason.)
nvim_expr() {
    perl -e 'alarm 4; exec @ARGV' nvim --server "$1" --remote-expr "$2" 2>/dev/null
}

echo "── Neovim ──"
restarted=0
skipped=0
shopt -s nullglob
socks=("${TMPDIR:-/tmp/}nvim.${USER}"/*/nvim.*.0)
(( ${#socks[@]} == 0 )) && echo "  (none found)"
for sock in "${socks[@]}"; do
    pid=${sock##*/nvim.}; pid=${pid%.0}
    ps -p "$pid" &>/dev/null || continue   # stale socket
    # A busy or prompt-blocked instance answers nothing, and there is no point
    # restarting one that cannot hear the request anyway.
    if [[ -z $(nvim_expr "$sock" '1') ]]; then
        printf '  skip    nvim %-8s busy or blocked -- :restart it by hand\n' "$pid"
        ((skipped++))
        continue
    fi
    printf '  restart nvim %-8s\n' "$pid"
    ((restarted++))
    # `wall` first: plain :restart quits with :qall, which refuses to leave a
    # modified buffer behind. Writing everything first matches what this config
    # already does on BufLeave and FocusLost.
    #
    # The restart tears down this very socket, so the call is expected to return
    # nothing -- that is success, not the timeout above.
    (( DRY )) || nvim_expr "$sock" "execute('silent! wall | restart')" >/dev/null
done

msg="theme: $TARGET -- nvim restarted: $restarted"
(( skipped )) && msg="$msg, skipped: $skipped (:restart those by hand)"
(( DRY )) && msg="dry run: nothing changed -- would be \"$msg\""
echo "$msg"
tmux info &>/dev/null && (( ! DRY )) && tmux display-message "$msg"
