# Development tools and work-specific configuration
# Sourced from .zshrc - keep heavy items lazy-loaded where possible

export CC="$HOME/Documents/0. CC"

# Kubernetes & Docker
alias k="kubectl"
alias kd="kubectl describe"
alias kjava="pkill -9 java"

# ---------- K8S Namespace Helpers ----------
# Pattern used by kns when no arg given — override in ~/.creds.zsh if needed
KUBE_NS_PATTERN="${KUBE_NS_PATTERN:-chefsculinar-discoverysap}"

# kns [pattern]: fuzzy-pick a namespace matching pattern, set as kubectl default
function kns() {
  local ns
  ns=$(kubectl get ns --no-headers -o custom-columns=":metadata.name" \
    | grep "${1:-$KUBE_NS_PATTERN}" \
    | fzf --prompt="namespace> " --height=40% --reverse --select-1)
  [[ -z "$ns" ]] && return 1
  kubectl config set-context --current --namespace="$ns"
  echo "→ namespace: $ns"
}

# kp: list pods in current namespace (pass extra kubectl flags freely)
function kp() { kubectl get pods -o wide "$@"; }

# kl: fuzzy-pick a pod by name+status, then stream its logs
function kl() {
  local pod
  pod=$(kubectl get pods --no-headers \
    | awk '{printf "%-55s %s\n", $1, $3}' \
    | fzf --prompt="logs> " --height=40% --reverse \
    | awk '{print $1}')
  [[ -z "$pod" ]] && return 1
  kubectl logs -f --tail=200 "$pod" "$@"
}

# ke: fuzzy-pick a pod, exec a shell into it (default: sh)
function ke() {
  local pod
  pod=$(kubectl get pods --no-headers \
    | awk '{printf "%-55s %s\n", $1, $3}' \
    | fzf --prompt="exec> " --height=40% --reverse \
    | awk '{print $1}')
  [[ -z "$pod" ]] && return 1
  kubectl exec -it "$pod" -- "${@:-sh}"
}

function kdocker() { 
    docker rm -vf $(docker ps -a -q)
}

function kport() {
    local PORT=$1
    local PIDS=$(lsof -t -i :"$PORT")
    kill -9 $PIDS && echo "Port $PORT is now free."
}

# ---------- Copilot Helpers ----------
# Auto approve within workspace
alias copilot-god="copilot --allow-all-tools --allow-all-paths"
# Resume + Auto approve within workspace
alias copilot-god-r="copilot --allow-all-tools --allow-all-paths --resume"

# Shortcuts for passing args to copilot with auto-approvals
function qcopilot() { copilot --allow-all-tools --allow-all-paths --silent -p "$@" }
# Shortcuts for passing args to copilot with auto-approvals + interactive mode
function icopilot() { copilot --allow-all-tools --allow-all-paths ${1:+-i} "$@" }

# ---------- Claude Helpers ----------
# Auto approve within workspace
alias claude-god="claude --dangerously-skip-permissions"
# Resume + Auto approve within workspace
alias claude-god-r="claude --dangerously-skip-permissions --resume"

# Shortcuts for passing args to claude with auto-approvals
function qclaude() { claude --dangerously-skip-permissions --print -p "$@" }
# Shortcuts for passing args to claude with auto-approvals + interactive mode
function iclaude() { claude --dangerously-skip-permissions ${1:+-i} "$@" }

# ---------- Codex Helpers ----------
# Auto approve within workspace
alias codex-god="codex run --dangerously-bypass-approvals-and-sandbox"
# Resume + Auto approve within workspace
alias codex-god-r="codex run resume --dangerously-bypass-approvals-and-sandbox"

# Project shortcuts
alias x="exit"
alias hc="history -c"
alias hg="history | grep "

## CDE environment aliases
# export SEU_HOME=/Users/kdvu/Development/cde
# export GROOVY_HOME=/opt/homebrew/opt/groovy/libexec
# alias env17='source ~/Development/cde/myenv-common.sh 17 18 -7.4.2 6'
# alias env11c='source ~/Development/cde/myenv-common.sh 11 14 6 6'
# alias env11='source ~/Development/cde/myenv11.sh'
# alias env8='source ~/Development/cde/myenv18.sh'

# ---------- Serena Helpers ----------
alias serena-ps='echo "=== Serena MCP Sessions ===" && ps aux | grep "serena.*start-mcp-server" | grep -v grep; echo "=== JDTLS Language Servers ===" && ps aux | grep ".serena/language_servers" | grep -v grep'
alias serena-kill='ps aux | grep ".serena/language_servers" | grep -v grep | awk "{print \$2}" | xargs -r kill 2>/dev/null; echo "Killed orphaned JDTLS processes"'
