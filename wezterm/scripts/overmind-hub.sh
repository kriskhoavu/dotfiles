#!/bin/bash
# Overmind hub for Ctrl+Cmd+O (lua/hubs.lua): a tab listing every
# process of every running overmind on the left, with a live view of the one
# under the cursor on the right. The agents hub (ai-sessions.sh) with less to
# find: each overmind is a tmux server of its own, one window per process.
#
# The view is a tmux client on a grouped session (_ov_<session>) inside that
# server, so an `overmind connect` client never moves. Typing there goes to
# the process: Ctrl-C stops it. Closing removes the grouped sessions.
#
# Usage: overmind-hub.sh list|hub|view <keyfile>|show <key>|enter|restart <key>|stop <key>|ticker <port>
# Keys: <tmux socket>|<session>|<window index>, the index empty for a project
# row: the view then stays on the window it shows.

set -uo pipefail

# The GUI comes with a minimal PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
WEZTERM=${WEZTERM_EXECUTABLE_DIR:-/Applications/WezTerm.app/Contents/MacOS}/wezterm
[[ -x $WEZTERM ]] || WEZTERM=/opt/homebrew/bin/wezterm
SOCK_DIR="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/overmind-hub"
VIEW_PREFIX=_ov_
LIST_PERCENT=22
REFRESH=3

cmd=${1:-hub}
shift || true

# overmind names each socket overmind-<dir>-<random>; a stopped one leaves
# the file behind, and tmux answers "no server running" for it at once.
sockets() {
    local s
    for s in "$SOCK_DIR"/overmind-*; do [[ -S $s ]] && echo "$s"; done
}

# One line per overmind: tmux socket|session|daemon pid|root|control
# socket|Procfile|live or stale. The daemon is the parent of the server's
# control-mode client. Started twice on one control socket, the newer
# overmind takes the socket file over: the older one can no longer be told
# anything and is stale, as is a server whose daemon has gone.
projects() {
    local IFS=$' \t\n'   # callers may run this under IFS=| (read < <(...))
    local sock session root cpid dpid started ctl procfile w prev lstart args
    while read -r sock <&3; do
        IFS='|' read -r session root < <(tmux -S "$sock" list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null |
            grep -v "^$VIEW_PREFIX" | head -1)
        [[ -z $session ]] && continue
        cpid=$(tmux -S "$sock" list-clients -F '#{client_control_mode} #{client_pid}' 2>/dev/null | awk '$1 == 1 { print $2; exit }')
        dpid=""; started=0; ctl=.overmind.sock; procfile=Procfile
        [[ -n $cpid ]] && dpid=$(ps -o ppid= -p "$cpid" 2>/dev/null | tr -d ' ')
        if [[ -n $dpid ]]; then
            # lstart is a fixed 24 characters, then the command line
            lstart=$(LC_ALL=C ps -o lstart=,args= -p "$dpid")
            args=${lstart:25}; lstart=${lstart:0:24}
            started=$(LC_ALL=C date -j -f '%a %b %e %T %Y' "$lstart" +%s 2>/dev/null || echo 0)
            prev=""
            for w in $args; do
                case $prev in -s|--socket) ctl=$w ;; -f|--procfile) procfile=$w ;; esac
                prev=$w
            done
        fi
        [[ $ctl == /* ]] || ctl="$root/${ctl#./}"
        printf '%s|%s|%s|%s|%s|%s|%s\n' "$sock" "$session" "$dpid" "$started" "$root" "$ctl" "${procfile##*/}"
    done 3< <(sockets) | awk -F'|' -v OFS='|' '
        { line[NR] = $0; if ($3 != "" && $4 + 0 > newest[$6] + 0) newest[$6] = $4 }
        END {
            for (i = 1; i <= NR; i++) {
                split(line[i], f, "|")
                state = (f[3] != "" && f[4] == newest[f[6]]) ? "live" : "stale"
                print f[1], f[2], f[3], f[5], f[6], f[7], state
            }
        }'
}

# The projects() line for one tmux socket.
project_of() {
    projects | awk -F'|' -v s="$1" '$1 == s { print; exit }'
}

# Nothing can restart a stale overmind, so one with nothing left running is
# removed on sight. So is a server whose overmind session has gone while a
# hub's grouped session kept its windows, and a socket file a minute old
# with no server behind it. $1 is projects() output; returns 1 when nothing
# was removed, so the caller can keep it.
gc() {
    local sock state sessions removed=1
    while read -r sock <&3; do
        if ! sessions=$(tmux -S "$sock" list-sessions -F '#{session_name}' 2>/dev/null); then
            [[ -n $(find "$sock" -mmin +1 2>/dev/null) ]] && rm -f "$sock"
        elif ! grep -qv "^$VIEW_PREFIX" <<<"$sessions"; then
            tmux -S "$sock" kill-server 2>/dev/null; rm -f "$sock"; removed=0
        fi
    done 3< <(sockets)
    while IFS='|' read -r sock _ _ _ _ _ state <&3; do
        [[ $state == stale ]] || continue
        tmux -S "$sock" list-panes -a -F '#{pane_dead}' 2>/dev/null | grep -q 0 && continue
        remove "$sock|"; removed=0
    done 3< <(printf '%s\n' "$1")
    return $removed
}

# key\tdisplay: a row per project (its key has no window), then its
# processes in Procfile order.
list() {
    local info sock
    info=$(projects)
    gc "$info" && info=$(projects)
    while read -r sock <&3; do
        tmux -S "$sock" list-windows -a \
            -F "$sock|#{session_name}|#{window_index}|#{window_name}|#{pane_dead}|#{pane_dead_status}" 2>/dev/null
    done 3< <(sockets) | INFO=$info awk -F'|' -v v="$VIEW_PREFIX" '
        BEGIN {
            n = split(ENVIRON["INFO"], lines, "\n")
            for (i = 1; i <= n; i++) {
                split(lines[i], f, "|")
                m = split(f[4], p, "/"); label = (m > 1 ? p[m - 1] "/" : "") p[m]
                if (f[6] != "Procfile") label = label " · " f[6]
                name[f[1]] = label; state[f[1]] = f[7]
            }
        }
        index($2, v) == 1 { next }      # grouped sessions repeat the windows
        {
            proj = $1 "|" $2 "|"
            if (!(proj in total)) { order[++np] = proj; sock[proj] = $1 }
            total[proj]++
            if ($5 != "1") up[proj]++
            mark = ($5 == "1") ? "\033[31m✕\033[0m" : "\033[32m●\033[0m"
            exit_code = ($5 == "1" && $6 != "") ? sprintf(" \033[31mexit %s\033[0m", $6) : ""
            rows[proj] = rows[proj] sprintf("%s%s\t  %s %s%s\n", proj, $3, mark, $4, exit_code)
        }
        END {
            for (i = 1; i <= np; i++) {
                k = order[i]; c = (up[k] == total[k]) ? "32" : "31"
                stale = (state[sock[k]] == "stale") ? " \033[2mstale · ^d\033[0m" : ""
                printf "%s\t\033[1m%s\033[0m \033[%sm%d/%d\033[0m%s\n", k, name[sock[k]], c, up[k] + 0, total[k], stale
                printf "%s", rows[k]
            }
        }'
}

# The grouped session for an overmind session, created on first use.
view_session() {
    local sock=$1 view="$VIEW_PREFIX$2"
    tmux -S "$sock" has-session -t "=$view" 2>/dev/null ||
        tmux -S "$sock" new-session -d -t "$2" -s "$view" || return 1
    echo "$view"
}

client_session() {
    tmux -S "$1" list-clients -F '#{client_tty}|#{client_session}' 2>/dev/null |
        awk -F'|' -v t="$OV_VIEW_TTY" '$1 == t { print $2; exit }'
}

# The right pane: a client on the grouped session of the process in the key
# file. show() detaches it to move to another overmind's server.
view() {
    local keyfile=$1 sock session win view
    printf '\e]2;overmind-view\e\\'
    while :; do
        IFS='|' read -r sock session win < "$keyfile"
        if view=$(view_session "$sock" "$session"); then
            printf '%s\n' "$sock" > "$keyfile.server"
            tmux -S "$sock" select-window -t "=$view:$win"
            tmux -S "$sock" attach-session -t "=$view"
            printf '\e[H\e[2J'
            sleep 0.3
        else
            sleep 1     # the project has gone; the list moves the key on
        fi
    done
}

# Put the process under the cursor into the view pane.
show() {
    local key=$1 sock session win view server
    IFS='|' read -r sock session win <<<"$key"
    printf '%s\n' "$key" > "$OV_VIEW_KEY"
    server=$(cat "$OV_VIEW_KEY.server" 2>/dev/null)
    if [[ -n $server && $server != "$sock" ]]; then
        # another tmux server: view() re-attaches from the key file
        tmux -S "$server" detach-client -t "$OV_VIEW_TTY" 2>/dev/null
        return 0
    fi
    view=$(view_session "$sock" "$session") || return 1
    tmux -S "$sock" select-window -t "=$view:$win"
    case $(client_session "$sock") in
        "$view"|"") ;;
        *) tmux -S "$sock" switch-client -c "$OV_VIEW_TTY" -t "$view" ;;
    esac
}

# Ctrl-X: `overmind restart` through the project's own control socket, given
# relative: a socket path over 104 bytes fails on macOS. On a
# project row (no window) it names no process, which restarts them all. A
# stale overmind cannot hear it.
restart() {
    local sock session win name="" ctl state info
    IFS='|' read -r sock session win <<<"$1"
    info=$(project_of "$sock")
    IFS='|' read -r _ _ _ _ ctl _ state <<<"$info"
    [[ $state == live ]] || return 0
    if [[ -n $win ]]; then
        name=$(tmux -S "$sock" display-message -p -t "=$session:$win" '#{window_name}') || return 1
    fi
    (cd "${ctl%/*}" && overmind restart -s "./${ctl##*/}" ${name:+"$name"}) >/dev/null 2>&1
}

# Remove an overmind and its tmux server. A live one is told to quit and
# given up to 15s to stop its processes. A stale one gets SIGKILL after its
# tmux server is gone: a clean exit unlinks its socket path, which the newer
# one owns.
remove() {
    local sock dpid ctl state info i
    IFS='|' read -r sock _ <<<"$1"
    info=$(project_of "$sock")
    IFS='|' read -r _ _ dpid _ ctl _ state <<<"$info"
    if [[ $state == live ]]; then
        (cd "${ctl%/*}" && overmind quit -s "./${ctl##*/}") >/dev/null 2>&1
        for i in $(seq 30); do kill -0 "$dpid" 2>/dev/null || break; sleep 0.5; done
    fi
    tmux -S "$sock" kill-server 2>/dev/null
    [[ $state == stale && -n $dpid ]] && kill -KILL "$dpid" 2>/dev/null
    rm -f "$sock"
}

# Ctrl-D. On a process row, `overmind stop` for that process; Ctrl-X starts
# it again. On a project row, remove the project: a stale one or one with
# nothing running at once, a running one after a y/N here (fzf's execute
# hands this the terminal).
stop() {
    local sock session win info ctl state name running answer
    IFS='|' read -r sock session win <<<"$1"
    info=$(project_of "$sock")
    IFS='|' read -r _ _ _ _ ctl _ state <<<"$info"
    if [[ -n $win ]]; then
        [[ $state == live ]] || return 0
        name=$(tmux -S "$sock" display-message -p -t "=$session:$win" '#{window_name}') || return 1
        (cd "${ctl%/*}" && overmind stop -s "./${ctl##*/}" "$name") >/dev/null 2>&1
        return 0
    fi
    running=$(tmux -S "$sock" list-panes -s -t "=$session" -F '#{pane_dead}' 2>/dev/null | grep -c 0)
    if [[ $state == live && $running -gt 0 ]]; then
        printf '\e[H\e[2J\n  quit %s?\n  %d running\n\n  [y/N] ' "$session" "$running"
        read -r -n1 answer </dev/tty
        [[ $answer == [yY] ]] || return 0
        printf '\n\n  quitting…'
    fi
    remove "$sock|"
}

# Reloads the list until fzf is gone.
ticker() {
    local port=$1
    while curl -s -o /dev/null -XPOST "localhost:$port" -d "reload('$SELF' list)"; do
        sleep "$REFRESH"
    done
}

kill_views() {
    local sock s
    while read -r sock <&3; do
        for s in $(tmux -S "$sock" list-sessions -F '#{session_name}' 2>/dev/null | grep "^$VIEW_PREFIX"); do
            tmux -S "$sock" kill-session -t "=$s"
        done
    done 3< <(sockets)
}

hub_cleanup() {
    [[ -n ${OV_VIEW_PANE:-} ]] && "$WEZTERM" cli kill-pane --pane-id "$OV_VIEW_PANE" 2>/dev/null
    rm -f "${OV_VIEW_KEY:-}" "${OV_VIEW_KEY:-}.server"
    kill_views
}

# The list pane. HUB_RETURN_TAB (from Lua) is activated before this tab
# closes: closing the active tab makes WezTerm pick a neighbour.
hub() {
    printf '\e]2;overmind\e\\'      # pane title; the Lua toggle looks for it
    kill_views            # leftovers from a hub that died with WezTerm

    local rows
    rows=$(list)
    if [[ -z $rows ]]; then
        printf '\n  no overmind is running\n\n  press any key\n'
        read -r -n1 -s
        [[ -n ${HUB_RETURN_TAB:-} ]] && "$WEZTERM" cli activate-tab --tab-id "$HUB_RETURN_TAB"
        return
    fi

    mkdir -p "$STATE_DIR"
    export OV_VIEW_KEY OV_VIEW_PANE OV_VIEW_TTY
    OV_VIEW_KEY="$STATE_DIR/view.$WEZTERM_PANE"
    printf '%s\n' "$rows" | head -1 | cut -f1 > "$OV_VIEW_KEY"
    OV_VIEW_PANE=$("$WEZTERM" cli split-pane --right --percent $((100 - LIST_PERCENT)) \
        --pane-id "$WEZTERM_PANE" -- "$SELF" view "$OV_VIEW_KEY")
    OV_VIEW_TTY=$("$WEZTERM" cli list --format json | jq -r --argjson p "$OV_VIEW_PANE" '.[] | select(.pane_id == $p) | .tty_name')
    "$WEZTERM" cli activate-pane --pane-id "$WEZTERM_PANE"
    trap hub_cleanup EXIT HUP

    # Same colours as the agents hub: fzf's own scheme is dark.
    local colors='header:dim'
    [[ $(cat "$HOME/.config/kris-theme" 2>/dev/null) == light ]] &&
        colors='light,bg+:#d3a184,fg+:#111110,hl:#5d2713,hl+:#5d2713,gutter:-1,pointer:#7a2318,prompt:#5d2713,header:#3d3d3c,info:#3d3d3c,separator:#bbb0a1'

    # --track: a refresh may reorder rows; the cursor stays on its process
    printf '%s\n' "$rows" | fzf --ansi --delimiter $'\t' --with-nth 2.. --no-sort --track --layout reverse --info hidden \
        --prompt '› ' --header 'enter → process · ^x restart · ^d stop · esc close' --listen 0 --color "$colors" \
        --bind "start:execute-silent(nohup '$SELF' ticker \$FZF_PORT >/dev/null 2>&1 &)+pos(1)" \
        --bind "focus:execute-silent('$SELF' show {1})" \
        --bind "enter:execute-silent('$SELF' enter)" \
        --bind "ctrl-x:execute-silent('$SELF' restart {1})+reload('$SELF' list)" \
        --bind "ctrl-d:execute('$SELF' stop {1})+reload('$SELF' list)" \
        --bind "ctrl-r:reload('$SELF' list)" >/dev/null

    [[ -n ${HUB_RETURN_TAB:-} ]] && "$WEZTERM" cli activate-tab --tab-id "$HUB_RETURN_TAB"
}

case $cmd in
    list)    list ;;
    hub)     hub ;;
    view)    view "${1:?keyfile}" ;;
    show)    show "${1:?key}" ;;
    enter)   "$WEZTERM" cli activate-pane --pane-id "$OV_VIEW_PANE" ;;
    restart) restart "${1:?key}" ;;
    stop)    stop "${1:?key}" ;;
    ticker)  ticker "${1:?port}" ;;
    *) echo "usage: overmind-hub.sh list|hub|view <keyfile>|show <key>|enter|restart <key>|stop <key>|ticker <port>" >&2; exit 2 ;;
esac
