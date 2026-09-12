#!/bin/bash
# Re-exec every idle zsh so it picks up a changed ~/.zshrc: tmux panes across all
# sessions, plus the terminal buffers inside running Neovim instances.
#
# Uses `exec zsh`, not `source ~/.zshrc`. Re-sourcing leaves the old plugin state
# in place and zsh-autosuggestions re-wraps every widget, adding ~16 wrapper
# functions per run. exec replaces the shell image, keeping the pid and cwd.
#
# Only shells sitting at a prompt are touched. A shell is idle when it owns its
# tty's foreground process group; if something else does (nvim, ssh, a build),
# sending keys would type into that program, so the shell is skipped and listed.
#
# Usage: reload-shells.sh [-n]     -n lists what it would do and changes nothing

set -uo pipefail

DRY=0
[[ ${1:-} == "-n" ]] && DRY=1

reloaded=0
skipped=0

# Idle when the shell's own process group is the tty's foreground group.
is_idle() {
    local pid=$1 pgid tpgid
    read -r pgid tpgid < <(ps -o pgid=,tpgid= -p "$pid" 2>/dev/null)
    [[ -n ${pgid:-} && $pgid == "${tpgid:-}" ]]
}

# Neovim runs the editor as `nvim --embed` behind the TUI, and its socket is named
# for that pid. --remote-expr blocks forever against an instance that is busy or
# waiting on a prompt, so cap every call.
nvim_expr() {
    local sock=$1 expr=$2 out
    out=$(perl -e 'alarm 4; exec @ARGV' nvim --server "$sock" --remote-expr "$expr" 2>/dev/null)
    printf '%s' "$out"
}

echo "── tmux panes ──"
if tmux info &>/dev/null; then
    while IFS='|' read -r loc id cmd pid; do
        [[ -z ${id:-} ]] && continue
        if [[ $cmd != zsh ]]; then
            printf '  skip   %-24s running %s\n' "$loc" "$cmd"
            ((skipped++))
            continue
        fi
        if ! is_idle "$pid"; then
            printf '  skip   %-24s zsh is busy\n' "$loc"
            ((skipped++))
            continue
        fi
        printf '  reload %-24s pid %s\n' "$loc" "$pid"
        if (( ! DRY )); then
            tmux send-keys -t "$id" 'exec zsh' Enter
        fi
        ((reloaded++))
    done < <(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_pid}' 2>/dev/null)
else
    echo "  (no tmux server running)"
fi

echo "── Neovim terminal buffers ──"
shopt -s nullglob
socks=("${TMPDIR:-/tmp/}nvim.${USER}"/*/nvim.*.0)
if (( ${#socks[@]} == 0 )); then
    echo "  (none found)"
fi
for sock in "${socks[@]}"; do
    nvim_pid=${sock##*/nvim.}
    nvim_pid=${nvim_pid%.0}
    if ! ps -p "$nvim_pid" &>/dev/null; then
        printf '  skip   nvim %-19s stale socket\n' "$nvim_pid"
        continue
    fi
    # buffer:jobid:jobpid for every terminal buffer
    terms=$(nvim_expr "$sock" 'join(map(filter(getbufinfo(), {_,b -> getbufvar(b.bufnr,"terminal_job_pid",0) > 0}), {_,b -> b.bufnr.":".getbufvar(b.bufnr,"terminal_job_id",0).":".getbufvar(b.bufnr,"terminal_job_pid",0)}), " ")')
    if [[ -z $terms ]]; then
        printf '  skip   nvim %-19s no terminal buffer, or busy/blocked\n' "$nvim_pid"
        ((skipped++))
        continue
    fi
    for t in $terms; do
        IFS=: read -r buf job jobpid <<< "$t"
        if ! is_idle "$jobpid"; then
            printf '  skip   nvim %s buf %-11s shell is busy\n' "$nvim_pid" "$buf"
            ((skipped++))
            continue
        fi
        printf '  reload nvim %s buf %-11s pid %s\n' "$nvim_pid" "$buf" "$jobpid"
        if (( ! DRY )); then
            nvim_expr "$sock" "chansend($job, \"exec zsh\\n\")" >/dev/null
        fi
        ((reloaded++))
    done
done

echo
if (( DRY )); then
    echo "dry run: would reload $reloaded, skip $skipped"
else
    echo "reloaded $reloaded, skipped $skipped"
fi
