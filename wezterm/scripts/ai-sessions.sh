#!/bin/bash
# Agents hub for Ctrl+Cmd+A (lua/ai_sessions.lua): a tab listing every running
# claude/opencode/codex session on the left, with a live view of the one under
# the cursor on the right. The view is a tmux client on a grouped session
# (_av_<session>): same windows, own current window, so the real client never
# moves. Agents outside tmux get a read-only mirror. Closing restores the tab
# you came from and removes the grouped sessions.
#
# Agents are found by walking each pane's process tree; status comes from the
# agents' own hooks, written to $STATE_DIR/<agent pid>.json (see agents/).
#
# Traps, each the cause of a bug once:
#  - Neovim 0.12 detaches its server (`nvim --embed`, ppid 1); nvim_edges()
#    asks each server for its TUI pid so the walk can continue through it.
#  - `ps -o comm=` is the resolved path, and claude resolves to
#    .../claude/versions/<ver>. Adding `args=` truncates comm to 16 chars.
#  - WEZTERM_EXECUTABLE inside a pane is wezterm-gui, which has no `cli`.
#  - tmux prints a tab in -F output as "_"; formats here use |.
#  - With grouped sessions `display-message -c` reports the wrong session.
#  - Hooks must never print: Claude reads their stdout as a decision.
#
# Usage: ai-sessions.sh [-n] list [compact]|hub|view <keyfile>|show <key>|jump <key>|hook-claude|hook-codex|gc
# Keys: wez:<pane_id>:<agent_pid> | tmux:<pane_id>:<agent_pid>

set -uo pipefail

# The GUI and hooks come with a minimal PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
WEZTERM=${WEZTERM_EXECUTABLE_DIR:-/Applications/WezTerm.app/Contents/MacOS}/wezterm
[[ -x $WEZTERM ]] || WEZTERM=/opt/homebrew/bin/wezterm
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ai-sessions"
VIEW_PREFIX=_av_               # grouped sessions that back the hub's view
LIST_PERCENT=22
REFRESH=3                      # seconds between list refreshes in the hub

DRY=0
[[ ${1:-} == "-n" ]] && { DRY=1; shift; }
cmd=${1:-hub}
shift || true

run() { if (( DRY )); then printf '  would run  %s\n' "$*"; else "$@"; fi; }

# ── agent matching ───────────────────────────────────────────────────────────

# agent_of <executable path> → claude|opencode|codex. Mirrored in walk_tree().
agent_of() {
    local p=$1 b=${1##*/}
    case $p in
        *"Application Support/Claude/claude-code/"*|*"ChatGPT.app"*) return 1 ;;
        */.local/share/claude/versions/*) echo claude; return 0 ;;
    esac
    case $b in
        claude|opencode|codex) echo "$b"; return 0 ;;
    esac
    return 1
}

# ── state registry ───────────────────────────────────────────────────────────

gc_state() {
    local f pid now
    [[ -d $STATE_DIR ]] || return 0
    now=$(date +%s)
    for f in "$STATE_DIR"/*.json; do
        [[ -e $f ]] || continue
        pid=${f##*/}; pid=${pid%.json}
        if ! kill -0 "$pid" 2>/dev/null; then rm -f "$f"; continue; fi
        # pids get reused; a day-old entry is stale
        if (( now - $(jq -r '.ts // 0' "$f" 2>/dev/null || echo 0) > 86400 )); then rm -f "$f"; fi
    done
}

# state_write <pid> <agent> <status> <cwd> <session_id>
state_write() {
    local pid=$1 agent=$2 status=$3 cwd=$4 sid=$5 tmp
    mkdir -p "$STATE_DIR"
    tmp=$(mktemp "$STATE_DIR/.$pid.XXXXXX") || return 1
    jq -nc --arg a "$agent" --arg s "$status" --arg c "$cwd" --arg i "$sid" \
        '{agent:$a, status:$s, ts:(now|floor), cwd:$c, session_id:$i}' > "$tmp" \
        && mv -f "$tmp" "$STATE_DIR/$pid.json"
}

# The agent is an ancestor of the hook.
agent_pid_of_caller() {
    local pid=$PPID comm i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        [[ $pid -le 1 ]] && break
        comm=$(ps -o comm= -p "$pid" 2>/dev/null) || break
        if agent_of "$comm" >/dev/null; then echo "$pid"; return 0; fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ') || break
    done
    return 1
}

# Claude/Codex hook event on stdin → status file.
hook_from_stdin() {
    local agent=$1 json ev note status cwd sid pid
    json=$(cat)
    pid=$(agent_pid_of_caller) || exit 0
    # One jq per hook, not four: this runs on every tool call. \x1f, not a
    # tab, so an empty field does not collapse into the next.
    IFS=$'\x1f' read -r ev note cwd sid < <(jq -r '[.hook_event_name, (.notification_type // .matcher // .message), .cwd, .session_id]
        | map(. // "" | tostring | gsub("[\u001f\n]"; " ")) | join("\u001f")' <<<"$json")
    case $ev in
        SessionEnd)                              rm -f "$STATE_DIR/$pid.json"; exit 0 ;;
        SessionStart|Stop|Interrupt)             status=idle ;;
        UserPromptSubmit|PreToolUse|PostToolUse) status=working ;;
        PermissionRequest)                       status=blocked ;;
        Notification)
            case $note in
                *permission*|*needs_input*|*elicitation*) status=blocked ;;
                *agent_completed*)                        status=done ;;
                *idle*)                                   status=idle ;;
                *)                                        exit 0 ;;
            esac ;;
        *) exit 0 ;;
    esac
    state_write "$pid" "$agent" "$status" "$cwd" "$sid"
    exit 0
}

# ── discovery ────────────────────────────────────────────────────────────────

# walk_tree <roots> <edges>. roots: kind\tid\tpid\ttty per pane (a wez pane
# has no pid; the oldest process on its tty is used). edges: extra parent
# links. Prints kind\tid\tagent_pid\tagent\tpids, pids being the agent and
# its descendants (a status file may belong to a forked child).
walk_tree() {
    local roots=$1 edges=$2
    ps -axo pid=,ppid=,tty=,comm= | awk -v roots="$roots" -v edges="$edges" '
    function agent_of(c,   n, parts, b) {
        if (c ~ /Application Support\/Claude\/claude-code\// || c ~ /ChatGPT\.app/) return ""
        if (c ~ /\/\.local\/share\/claude\/versions\//) return "claude"
        n = split(c, parts, "/"); b = parts[n]
        if (b == "claude" || b == "opencode" || b == "codex") return b
        return ""
    }
    function descendants(pid,   n, kids, i, out) {
        n = split(children[pid], kids, " ")
        out = ""
        for (i = 1; i <= n; i++) out = out "," kids[i] descendants(kids[i])
        return out
    }
    function walk(kind, id, pid,   a, n, kids, i) {
        a = agent_of(cm[pid])
        if (a != "") { print kind "\t" id "\t" pid "\t" a "\t" pid descendants(pid); return }
        n = split(children[pid], kids, " ")
        for (i = 1; i <= n; i++) walk(kind, id, kids[i])
    }
    BEGIN {
        FS = "\t"
        while ((getline l < roots) > 0) {
            split(l, r, "\t"); nr++
            rk[nr] = r[1]; ri[nr] = r[2]; rp[nr] = r[3]; rt[nr] = r[4]
        }
        while ((getline l < edges) > 0) { split(l, e, " "); adopt[e[1]] = e[2] }
        FS = " "
    }
    {
        line = $0; sub(/^ +/, "", line)
        match(line, /^[0-9]+ +[0-9]+ +[^ ]+ +/)
        pid = $1; ppid = (pid in adopt) ? adopt[pid] : $2
        pp[pid] = ppid; tty[pid] = $3; cm[pid] = substr(line, RLENGTH + 1)
        children[ppid] = children[ppid] " " pid
    }
    END {
        for (i = 1; i <= nr; i++) {
            pid = rp[i]
            if (pid == "") {
                t = rt[i]; sub(/^\/dev\//, "", t); best = ""
                for (p in tty) if (tty[p] == t && tty[pp[p]] != t && (best == "" || p + 0 < best + 0)) best = p
                pid = best
            }
            if (pid != "") walk(rk[i], ri[i], pid)
        }
    }'
}

short_path() {
    local rel=${1#"$HOME"} leaf parent
    rel=${rel#/}
    [[ -z $rel ]] && { echo "~"; return; }
    if [[ $rel == */* ]]; then
        leaf=${rel##*/}; parent=${rel%/*}; parent=${parent##*/}
        echo "$parent/$leaf"
    else
        echo "~/$rel"
    fi
}

url_to_path() {
    local s=${1#file://}; s=${s#*/}; s=/$s
    printf '%b' "${s//%/\\x}"
}

# COMPACT=1 is the narrow hub row.
format_row() {
    local status=$1 agent=$2 cwd=$3 branch=$4 loc=$5 c
    case $status in
        blocked) c=$'\e[31m' ;; working) c=$'\e[33m' ;; idle) c=$'\e[90m' ;; done) c=$'\e[32m' ;; *) c=$'\e[2m' ;;
    esac
    if [[ ${COMPACT:-0} == 1 ]]; then
        printf '%s%s %-7s%s %-8s %s %s%s%s' \
            "$c" "●" "$status" $'\e[0m' "$agent" "$cwd" $'\e[2m' "$loc" $'\e[0m'
        return
    fi
    printf '%s%s %-8s%s · %-9s %-28s %s%-18s%s %s' \
        "$c" "●" "$status" $'\e[0m' "$agent" "$cwd" $'\e[36m' "$branch" $'\e[0m' "$loc"
}

# "<server pid> <tui pid>" for each detached nvim server, cached in
# $STATE_DIR/nvim-ui.map. The RPC is capped: a server in a prompt never answers.
nvim_edges() {
    local cache="$STATE_DIR/nvim-ui.map" pid tui sock keep=""
    mkdir -p "$STATE_DIR"; touch "$cache"
    while read -r pid; do
        tui=$(awk -v p="$pid" '$1 == p { print $2; exit }' "$cache")
        if [[ -z $tui ]] || ! kill -0 "$tui" 2>/dev/null; then
            sock=$(ls "${TMPDIR:-/tmp}/nvim.$USER"/*/"nvim.$pid.0" 2>/dev/null | head -1)
            [[ -z $sock ]] && continue
            tui=$(perl -e 'alarm 2; exec @ARGV' nvim --server "$sock" \
                --remote-expr 'nvim_get_chan_info(nvim_list_uis()[0].chan).client.attributes.pid' 2>/dev/null)
            [[ $tui =~ ^[0-9]+$ ]] || continue
        fi
        keep+="$pid $tui"$'\n'
    done < <(ps -axo pid=,ppid=,args= | awk '$2 == 1 && $3 ~ /nvim$/ && $4 == "--embed" { print $1 }')
    printf '%s' "$keep" | tee "$cache"
}

# key\tsortkey\tdisplay, blocked first.
list_agents() {
    local tmp roots wezp tmuxp clients states edges
    tmp=$(mktemp -d) || exit 1
    roots=$tmp/roots; wezp=$tmp/wez; tmuxp=$tmp/tmux; clients=$tmp/clients; states=$tmp/states; edges=$tmp/edges
    : > "$roots"; : > "$tmuxp"; : > "$clients"; : > "$states"
    gc_state
    nvim_edges > "$edges"

    if tmux info &>/dev/null; then
        tmux list-clients -F '#{client_tty}|#{session_name}' > "$clients"
        # grouped _av_ sessions repeat the real windows
        tmux list-panes -a -F '#{pane_tty}|#{pane_id}|#{session_name}:#{window_index}.#{pane_index}|#{pane_pid}|#{pane_current_path}' \
            | grep -v "^[^|]*|[^|]*|$VIEW_PREFIX" > "$tmuxp"
        while IFS='|' read -r _ id _ pid _; do
            printf 'tmux\t%s\t%s\t\n' "${id#%}" "$pid" >> "$roots"
        done < "$tmuxp"
    fi

    # window_id tab_id pane_id tty cwd tab_index window_count
    "$WEZTERM" cli list --format json 2>/dev/null | jq -r '
        . as $all
        | ($all | map(.window_id) | unique | length) as $nw
        | $all[] | . as $p
        | ([$all[] | select(.window_id == $p.window_id) | .tab_id]
           | reduce .[] as $t ([]; if index($t) == null then . + [$t] else . end)
           | index($p.tab_id) + 1) as $ti
        | [$p.window_id, $p.tab_id, $p.pane_id, $p.tty_name, ($p.cwd // ""), $ti, $nw] | @tsv' > "$wezp"
    while IFS=$'\t' read -r _ _ pane tty _ _ _; do
        [[ $pane == "${WEZTERM_PANE:-}" ]] && continue          # the hub itself
        grep -q "^$tty|" "$clients" && continue                  # a tmux client; its panes come via tmux
        printf 'wez\t%s\t\t%s\n' "$pane" "$tty" >> "$roots"
    done < "$wezp"

    if (( DRY )); then
        echo "── roots ──"; cat "$roots"
        echo "── nvim server → tui ──"; cat "$edges"
        echo "── agents (kind id agent_pid agent pids) ──"
        walk_tree "$roots" "$edges"
        rm -rf "$tmp"; return
    fi

    # pid\tstatus\tcwd
    # One jq for every state file, not one each.
    jq -r '[(input_filename | sub(".*/"; "") | sub("\\.json$"; "")), .status // "unknown", .cwd // ""] | @tsv' \
        "$STATE_DIR"/*.json 2>/dev/null > "$states"

    local kind id apid agent pids status cwd hcwd branch loc sortk win ti nw hit
    local -a rows=()
    while IFS=$'\t' read -r kind id apid agent pids; do
        status=unknown; hcwd=""
        hit=$(awk -F'\t' -v pids=",$pids," 'index(pids, "," $1 ",") { print; exit }' "$states")
        [[ -n $hit ]] && IFS=$'\t' read -r _ status hcwd <<<"$hit"
        if [[ $kind == tmux ]]; then
            IFS='|' read -r _ _ loc _ cwd < <(awk -F'|' -v id="%$id" '$2 == id' "$tmuxp")
        else
            IFS=$'\t' read -r win _ _ _ cwd ti nw < <(awk -F'\t' -v id="$id" '$3 == id' "$wezp")
            cwd=$(url_to_path "$cwd")
            loc="tab $ti"; [[ ${nw:-1} -gt 1 ]] && loc="w$win $loc"
        fi
        [[ -n $hcwd ]] && cwd=$hcwd
        branch=""   # the compact hub row has no branch column
        [[ ${COMPACT:-0} == 1 ]] || branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
        case $status in blocked) sortk=0 ;; working) sortk=1 ;; idle) sortk=2 ;; done) sortk=3 ;; *) sortk=4 ;; esac
        rows+=("$(printf '%s:%s:%s\t%s %s %s\t%s' "$kind" "$id" "$apid" "$sortk" "$agent" "$loc" \
            "$(format_row "$status" "$agent" "$(short_path "$cwd")" "$branch" "$loc")")")
    done < <(walk_tree "$roots" "$edges")
    rm -rf "$tmp"
    (( ${#rows[@]} )) && printf '%s\n' "${rows[@]}" | sort -t$'\t' -k2,2
}

# ── hub ──────────────────────────────────────────────────────────────────────

tab_of() {
    "$WEZTERM" cli list --format json | jq -r --argjson p "$1" '.[] | select(.pane_id == $p) | .tab_id'
}

# The grouped session for a tmux pane, created on first use.
view_session() {
    local session view
    session=$(tmux display-message -p -t "%$1" '#{session_name}') || return 1
    session=${session#"$VIEW_PREFIX"}   # a shared pane may report the grouped session
    view="$VIEW_PREFIX$session"
    tmux has-session -t "=$view" 2>/dev/null || tmux new-session -d -t "$session" -s "$view" || return 1
    echo "$view"
}

# Put the agent under the cursor into the view pane. tmux agents switch the
# viewer's client; anything else detaches it so view() mirrors text instead.
show() {
    local key=$1 kind id view
    IFS=: read -r kind id _ <<<"$key"
    [[ -z ${AI_SESSIONS_VIEW_KEY:-} ]] && return 0
    printf '%s\n' "$key" > "$AI_SESSIONS_VIEW_KEY"
    if [[ $kind != tmux ]]; then
        [[ -n $(client_session "$AI_SESSIONS_VIEW_TTY") ]] && tmux detach-client -t "$AI_SESSIONS_VIEW_TTY"
        return 0
    fi
    view=$(view_session "$id") || return 1
    # current window is per session; active pane is shared, so left alone
    tmux select-window -t "$view:$(tmux display-message -p -t "%$id" '#{window_index}')"
    case $(client_session "$AI_SESSIONS_VIEW_TTY") in
        "$view") ;;
        "")      ;;   # view() attaches on its next pass
        *)       tmux switch-client -c "$AI_SESSIONS_VIEW_TTY" -t "$view" ;;
    esac
}

client_session() {
    tmux list-clients -F '#{client_tty}|#{client_session}' 2>/dev/null | awk -F'|' -v t="$1" '$1 == t { print $2; exit }'
}

# The right pane: attached to a grouped session until show() detaches it,
# otherwise a read-only mirror polled twice a second, repainted on change.
view() {
    local keyfile=$1 key kind id view lines out frame prev=""
    printf '\e]2;ai-sessions-view\e\\'
    while :; do
        key=$(cat "$keyfile" 2>/dev/null)
        IFS=: read -r kind id _ <<<"$key"
        if [[ $kind == tmux ]]; then
            view=$(view_session "$id") && tmux attach-session -t "=$view"
            printf '\e[H\e[2J'
            prev=""
        elif [[ $kind == wez ]]; then
            lines=$(tput lines 2>/dev/null || echo 40)
            out=$("$WEZTERM" cli get-text --escapes --pane-id "$id" 2>/dev/null | tail -n $((lines - 2)))
            frame="$key $lines"$'\n'"$out"
            if [[ $frame != "$prev" ]]; then
                printf '\e[H\e[2m  read-only mirror · Enter in the list jumps to the real pane\e[0m\n\n'
                printf '%s\n\e[J' "$out"
                prev=$frame
            fi
        fi
        sleep 0.5
    done
}

# Enter: keyboard to the view, or jump for an agent outside tmux.
enter() {
    local key=$1
    if [[ $key == tmux:* && -n ${AI_SESSIONS_VIEW_PANE:-} ]]; then
        "$WEZTERM" cli activate-pane --pane-id "$AI_SESSIONS_VIEW_PANE"
    else
        jump "$key"
    fi
}

# Reloads the list until fzf is gone.
ticker() {
    local port=$1
    while curl -s -o /dev/null -XPOST "localhost:$port" -d "reload($SELF list compact)"; do
        sleep "$REFRESH"
    done
}

kill_views() {
    local s
    for s in $(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^$VIEW_PREFIX"); do
        tmux kill-session -t "=$s"
    done
}

hub_cleanup() {
    [[ -n ${AI_SESSIONS_VIEW_PANE:-} ]] && "$WEZTERM" cli kill-pane --pane-id "$AI_SESSIONS_VIEW_PANE" 2>/dev/null
    rm -f "${AI_SESSIONS_VIEW_KEY:-}"
    kill_views
}

# The list pane. AI_SESSIONS_RETURN_TAB (from Lua) is activated before this
# tab closes: closing the active tab makes WezTerm pick a neighbour.
hub() {
    printf '\e]2;ai-sessions\e\\'      # pane title; the Lua toggle looks for it
    export COMPACT=1
    kill_views            # leftovers from a hub that died with WezTerm

    local rows
    rows=$("$SELF" list compact)
    if [[ -z $rows ]]; then
        printf '\n  no AI agent is running in any pane\n\n  press any key\n'
        read -r -n1 -s
        [[ -n ${AI_SESSIONS_RETURN_TAB:-} ]] && "$WEZTERM" cli activate-tab --tab-id "$AI_SESSIONS_RETURN_TAB"
        return
    fi

    export AI_SESSIONS_VIEW_KEY AI_SESSIONS_VIEW_PANE AI_SESSIONS_VIEW_TTY
    AI_SESSIONS_VIEW_KEY="$STATE_DIR/view.$WEZTERM_PANE"
    printf '%s\n' "$rows" | head -1 | cut -f1 > "$AI_SESSIONS_VIEW_KEY"
    AI_SESSIONS_VIEW_PANE=$("$WEZTERM" cli split-pane --right --percent $((100 - LIST_PERCENT)) \
        --pane-id "$WEZTERM_PANE" -- "$SELF" view "$AI_SESSIONS_VIEW_KEY")
    AI_SESSIONS_VIEW_TTY=$("$WEZTERM" cli list --format json | jq -r --argjson p "$AI_SESSIONS_VIEW_PANE" '.[] | select(.pane_id == $p) | .tty_name')
    "$WEZTERM" cli activate-pane --pane-id "$WEZTERM_PANE"
    trap hub_cleanup EXIT HUP

    # fzf's own scheme is dark: its grey cursor row swallowed the dim status
    # text on the light ground. Light: ink on WezTerm's selection colour.
    local colors='header:dim'
    [[ $(cat "$HOME/.config/kris-theme" 2>/dev/null) == light ]] &&
        colors='light,bg+:#d3a184,fg+:#111110,hl:#5d2713,hl+:#5d2713,gutter:-1,pointer:#7a2318,prompt:#5d2713,header:#3d3d3c,info:#3d3d3c,separator:#bbb0a1'

    # --track: a refresh may reorder rows; the cursor stays on its agent
    printf '%s\n' "$rows" | fzf --ansi --delimiter $'\t' --with-nth 3.. --no-sort --track --layout reverse --info hidden \
        --prompt '› ' --header 'enter → agent · esc close' --listen 0 --color "$colors" \
        --bind "start:execute-silent(nohup $SELF ticker \$FZF_PORT >/dev/null 2>&1 &)+pos(1)" \
        --bind "focus:execute-silent($SELF show {1})" \
        --bind "enter:execute-silent($SELF enter {1})" \
        --bind "ctrl-r:reload($SELF list compact)" >/dev/null

    [[ -n ${AI_SESSIONS_RETURN_TAB:-} ]] && "$WEZTERM" cli activate-tab --tab-id "$AI_SESSIONS_RETURN_TAB"
}

# ── jump ─────────────────────────────────────────────────────────────────────

# Activate the agent's real WezTerm pane (and tmux window/pane).
jump() {
    local key=$1 kind id session client pane tab
    IFS=: read -r kind id _ <<<"$key"
    if [[ $kind == tmux ]]; then
        session=$(tmux display-message -p -t "%$id" '#{session_name}') || return 1
        run tmux select-window -t "%$id"
        run tmux select-pane -t "%$id"
        client=$(tmux list-clients -F '#{client_activity}|#{client_tty}|#{session_name}' | sort -rn \
            | awk -F'|' -v s="$session" '$3 == s { print $2; exit }')
        if [[ -z $client ]]; then
            client=$(tmux list-clients -F '#{client_activity}|#{client_tty}|#{session_name}' | sort -rn \
                | awk -F'|' -v v="$VIEW_PREFIX" 'index($3, v) != 1 { print $2; exit }')
            [[ -z $client ]] && { run "$WEZTERM" cli spawn -- tmux attach -t "$session"; return; }
            run tmux switch-client -c "$client" -t "$session"
        fi
        pane=$("$WEZTERM" cli list --format json | jq -r --arg t "$client" '.[] | select(.tty_name == $t) | .pane_id')
    else
        pane=$id
    fi
    [[ -z $pane ]] && return 1
    tab=$(tab_of "$pane")
    [[ -n $tab ]] && run "$WEZTERM" cli activate-tab --tab-id "$tab"
    run "$WEZTERM" cli activate-pane --pane-id "$pane"
}

case $cmd in
    list)        [[ ${1:-} == compact ]] && export COMPACT=1; list_agents ;;
    hub)         hub ;;
    view)        view "${1:?keyfile}" ;;
    show)        show "${1:?key}" ;;
    enter)       enter "${1:?key}" ;;
    ticker)      ticker "${1:?port}" ;;
    jump)        jump "${1:?key}" ;;
    hook-claude) hook_from_stdin claude ;;
    hook-codex)  hook_from_stdin codex ;;
    gc)          gc_state ;;
    *) echo "usage: ai-sessions.sh [-n] list [compact]|hub|show <key>|jump <key>|hook-claude|hook-codex|gc" >&2; exit 2 ;;
esac
