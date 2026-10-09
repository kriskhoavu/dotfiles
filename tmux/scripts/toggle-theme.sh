#!/bin/bash
# Flip this config between light and dark.
#
# State is ~/.config/kris-theme (anything but "light" is dark). Not macOS: tmux
# answers OSC 11 from a cache, a running nvim cannot be told, and WezTerm only
# re-reads on a file change. Each tool is then told its own way:
#   WezTerm  touch its config; it re-reads the state on reload
#   tmux     source the theme file
#   Neovim   :restart, the only way to pick up a new background
#
# Usage: toggle-theme.sh [light|dark] [-n]   (no arg flips; -n is a dry run)

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
    echo "  touching $WEZTERM_CONFIG"
    (( DRY )) || touch "$WEZTERM_CONFIG"
else
    echo "  (no config at $WEZTERM_CONFIG)"
fi

echo "── tmux ──"
if tmux info &>/dev/null; then
    # The theme file only: ~/.tmux.conf re-runs tpm and every plugin (~1.4s).
    echo "  sourcing themes/$TARGET.conf"
    (( DRY )) || tmux source-file "$HOME/.config/tmux/themes/$TARGET.conf"
else
    echo "  (no tmux server running)"
fi

# Socket is named for the `nvim --embed` pid. --remote-expr blocks forever on a
# busy instance, so cap every call.
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
    # A busy or prompt-blocked instance answers nothing and could not restart anyway.
    if [[ -z $(nvim_expr "$sock" '1') ]]; then
        printf '  skip    nvim %-8s busy or blocked -- :restart it by hand\n' "$pid"
        ((skipped++))
        continue
    fi
    printf '  restart nvim %-8s\n' "$pid"
    ((restarted++))
    # `wall` first: :restart's :qall refuses modified buffers. The restart kills
    # this socket, so empty output here is success, not the timeout.
    (( DRY )) || nvim_expr "$sock" "execute('silent! wall | restart')" >/dev/null
done

msg="theme: $TARGET -- nvim restarted: $restarted"
(( skipped )) && msg="$msg, skipped: $skipped (:restart those by hand)"
(( DRY )) && msg="dry run: nothing changed -- would be \"$msg\""
echo "$msg"
tmux info &>/dev/null && (( ! DRY )) && tmux display-message "$msg"
