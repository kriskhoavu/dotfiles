#!/bin/bash
# One tmux window per git repo under a root directory, each a plain shell already
# cd'd into that repo, so a folder full of sibling repos (a GitHub org checked out
# side by side) becomes tabs: M-1..M-9 to jump, M-h / M-l to cycle.
#
# The windows are workspaces, not a git UI -- nothing is launched in them. Reach
# for git however you normally would once you are in the tab.
#
# The root is an argument, not a constant -- the session is named after the root's
# basename, so several roots can be open at once as separate sessions. Called with
# no argument it uses $PWD, which is why the tmux binding passes
# #{pane_current_path}: run-shell's own cwd is the server's, not the pane's.
#
# Repos are found one level deep as <root>/*/.git, tested with -e rather than -d so
# worktrees and submodules -- where .git is a file holding a gitdir pointer -- are
# picked up too.
#
# Re-running is a sync, not a reset: an existing session is reused and windows that
# are already there are left alone, so whatever you have running in them survives.
# Only repos with no window of that name get one. Nothing is ever closed.
#
# A window counts as "already there" by NAME, not by directory: automatic-rename
# names windows after their cwd basename, so a shell sitting in a repo is matched
# and skipped even though this script did not create it.
#
# Usage: tmux-org-tabs.sh [-n] [root]     -n lists what it would do and changes nothing

set -uo pipefail

DRY=0
if [[ ${1:-} == "-n" ]]; then
    DRY=1
    shift
fi

ROOT=${1:-$PWD}
# The keybinding passes the prompt's text through single quotes, so a leading ~ is
# still literal by the time it lands here.
ROOT=${ROOT/#\~/$HOME}

if [[ ! -d $ROOT ]]; then
    echo "tmux-org-tabs: not a directory: $ROOT" >&2
    exit 1
fi

# Resolve so the session name never comes out as "." or "" for a relative root.
ROOT=$(cd "$ROOT" && pwd)

# tmux splits target names on ':' and '.', and treats a leading '-' as a flag.
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

# base-index is 1, so window 1 is what M-1 selects: keep it at the root, for greps
# and scripts that span every repo, and give the repos window 2 onward.
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

# run-shell inherits TMUX, so this covers both the keybinding and a bare shell.
if [[ -n ${TMUX:-} ]]; then
    tmux switch-client -t "$SESSION:"
else
    tmux attach-session -t "$SESSION:"
fi
