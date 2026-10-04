#!/bin/bash
# Save the window names the user chose by hand, for tmux-resurrect.
#
# prefix+C and prefix+, set @manual_name, which nvim checks before renaming a
# window (nvim/lua/vim-window.lua). resurrect saves no user options, so without
# this every restored window looked automatic again. Post-save-all hook.

set -uo pipefail

dir=$(tmux show -gqv @resurrect-dir)
[[ -z $dir ]] && dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
mkdir -p "$dir"

# #{q:} shell-quotes each field, so a name with spaces survives and the reader
# can just eval the line. Not tab-separated: tmux prints a tab in -F output as
# an underscore, which silently turned every record into one field.
fmt='#{?@manual_name,#{q:session_name} #{window_index} #{q:window_name},}'
tmux list-windows -a -F "$fmt" | grep -v '^$' > "$dir/kris-manual-names.txt"
exit 0
