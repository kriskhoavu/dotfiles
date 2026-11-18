#!/usr/bin/env bash
# Tell the outer terminal (WezTerm) the active pane's folder with OSC 7.
# zsh sends OSC 7 only from its prompt. Switching session, window or pane in
# tmux prints no prompt, so tmux hooks call this script instead.
# Usage: osc7-sync.sh <session_id>
session=$1
[ -n "$session" ] || exit 0
path=$(tmux display-message -p -t "$session" '#{pane_current_path}') || exit 0
[ -n "$path" ] || exit 0
host=$(hostname)
# Write to each client tty that shows this session. Writing to the tty goes
# straight to WezTerm, so tmux passthrough is not needed.
tmux list-clients -t "$session" -F '#{client_tty}' | while read -r tty; do
  [ -w "$tty" ] && printf '\033]7;file://%s%s\033\\' "$host" "$path" > "$tty"
done
