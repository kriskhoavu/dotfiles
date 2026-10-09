#!/bin/bash
# One tmux window per git repo under a root, each a plain shell cd'd into it:
# a checked-out org as tabs (M-1..M-9 jump, M-h / M-l cycle). No git UI.
#
# Session is named after the root's basename; root defaults to $PWD (run-shell's
# cwd is the server's, hence the binding passes a path).
#
# Repos: <root>/*/.git, tested with -e so worktrees and submodules (.git is a
# file) count. Must match nvim/lua/org-git.lua.
#
# Re-running syncs: windows are matched by NAME (automatic-rename uses the cwd
# basename, so hand-opened shells match too), only missing ones are added,
# nothing is closed.
#
# Usage: tmux-org-tabs.sh [-n] [root]     -n is a dry run

set -uo pipefail

DRY=0
if [[ ${1:-} == "-n" ]]; then
    DRY=1
    shift
fi

ROOT=${1:-$PWD}
# The binding's single quotes leave a leading ~ literal.
ROOT=${ROOT/#\~/$HOME}

if [[ ! -d $ROOT ]]; then
    echo "tmux-org-tabs: not a directory: $ROOT" >&2
    exit 1
fi

# Absolute, so the session name is never "." or "".
ROOT=$(cd "$ROOT" && pwd)

# tmux splits targets on ':' and '.', and a leading '-' reads as a flag.
SESSION=$(basename "$ROOT" | tr ':.' '__')
SESSION=${SESSION#-}

repos=()
for gitdir in "$ROOT"/*/.git; do
    [[ -e $gitdir ]] || continue
    repos+=("$(dirname "$gitdir")")
done

if [[ ${#repos[@]} -eq 0 ]]; then
    echo "tmux-org-tabs: no repos found in $ROOT/*/" >&2
    exit 1
fi

run() {
    if [[ $DRY -eq 1 ]]; then
        printf '  would run  tmux %s\n' "$*"
    else
        tmux "$@"
    fi
}

# Window 1 (M-1) stays at the root for org-wide work; repos get 2 onward.
if tmux has-session -t="$SESSION" 2>/dev/null; then
    echo "── session $SESSION exists, syncing ──"
    existing=$(tmux list-windows -t="$SESSION" -F '#W')
else
    echo "── creating session $SESSION ──"
    run new-session -d -s "$SESSION" -n root -c "$ROOT"
    existing="root"
fi

added=0
for repo in "${repos[@]}"; do
    name=$(basename "$repo" | tr ':.' '__')
    if grep -qxF "$name" <<<"$existing"; then
        printf '  keep   %s\n' "$name"
        continue
    fi
    printf '  add    %-20s %s\n' "$name" "$repo"
    run new-window -d -t "$SESSION:" -n "$name" -c "$repo"
    ((added++))
done

echo "── $added window(s) added ──"

[[ $DRY -eq 1 ]] && exit 0

# run-shell inherits TMUX, so this covers the binding and a bare shell.
if [[ -n ${TMUX:-} ]]; then
    tmux switch-client -t "$SESSION:"
else
    tmux attach-session -t "$SESSION:"
fi
