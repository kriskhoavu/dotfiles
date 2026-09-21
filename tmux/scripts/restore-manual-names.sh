#!/bin/bash
# Put the hand-picked window names back after a tmux-resurrect restore.
#
# The name as well as the mark: resurrect restores nvim, and nvim renames the
# window to its first buffer before this hook runs. Matched on session and
# index, which survive a restore, rather than on the name, which is the thing
# that may have been clobbered. Run from @resurrect-hook-post-restore-all.

set -uo pipefail

dir=$(tmux show -gqv @resurrect-dir)
[[ -z $dir ]] && dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
file="$dir/kris-manual-names.txt"
[[ -f $file ]] || exit 0

while read -r line; do
    [[ -n $line ]] || continue
    # The fields were written with tmux's #{q:}, so they arrive shell-quoted.
    eval "set -- $line" || continue
    session=$1 index=$2 name=$3
    [[ -n $session && -n $index && -n $name ]] || continue
    tmux list-windows -t "=$session:$index" &>/dev/null || continue
    tmux rename-window -t "=$session:$index" -- "$name"
    tmux set -w -t "=$session:$index" @manual_name 1
done < "$file"
exit 0
