# 🚀 Git Productivity Aliases

# 🔎 STATUS

alias gs='git status -sb'                 # Short status (clean + branch info)

# ➕ ADD / COMMIT

alias ga='git add'                        # Add specific file
alias gaa='git add .'                     # Add all changes
alias gcm='git commit -m'                 # Commit with message
alias gca='git commit --amend'            # Amend last commit

# Amend into any recent commit (interactive pick via fzf)
# Usage: gcap (stage changes first with ga/gaa)
function gcap() {
  if ! git diff --cached --quiet --exit-code 2>/dev/null; then
    : # staged changes exist
  else
    echo "No staged changes. Stage something first (ga / gaa)."
    return 1
  fi

  local commit
  commit=$(git log --oneline -20 | fzf --height=12 --reverse --prompt="Amend into > " | awk '{print $1}')

  if [[ -z "$commit" ]]; then
    echo "Cancelled."
    return 0
  fi

  git commit --fixup="$commit" && \
  GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash "${commit}~1"
}

function gca-now() {
  local now="$(date)"
  if [ "$#" -gt 0 ]; then
    local msg="$*"
    GIT_COMMITTER_DATE="$now" git commit --amend -m "$msg" --date="$now"
  else
    GIT_COMMITTER_DATE="$now" git commit --amend --no-edit --date="$now"
  fi
}

# 🔄 PUSH / PULL

alias gP='git push'                       # Push current branch
alias gp='git pull --rebase --autostash'  # Pull with rebase (clean history)
alias gf='git fetch --all --prune'        # Fetch all + remove deleted branches

# 🌿 BRANCH

alias gb='git branch'                     # List local branches
alias gba='git branch -a'                 # List all branches
alias gbd='git branch -d'                 # Delete branch (safe)
alias gbD='git branch -D'                 # Force delete branch
alias gc='git checkout'                  # Checkout branch
alias gcb='git checkout -b'               # Create + checkout new branch
alias gmaster='git checkout master && git pull --rebase'   # Switch to master and update

# 📜 LOG

alias gl='git log --graph --decorate --pretty=oneline --abbrev-commit --name-status'          # Pretty log (current branch)
alias gla='git log --graph --decorate --pretty=oneline --abbrev-commit --name-status --all'

# Show remote commits not in local
alias gnew='git fetch && git log HEAD..origin/$(git branch --show-current) --oneline'

# Show local commits not pushed yet
alias gmine='git fetch && git log origin/$(git branch --show-current)..HEAD --oneline'

# ⚔️ REBASE / CONFLICT

alias gconf='git diff --name-only --diff-filter=U'   # List files in conflict
alias grc='git rebase --continue'                    # Continue rebase
alias gra='git rebase --abort'                       # Abort rebase
alias grshow='git rebase --show-current-patch'       # Show current patch during rebase

# Compare local vs remote (before pull)
alias gdiff='git fetch && git diff HEAD origin/$(git branch --show-current)'

# 🏷 TAGS

alias glast='git tag --sort=-taggerdate | head -1'   # Latest tag
alias gnight='git tag --list "nightly*" --sort=-taggerdate | head -1'  # Latest nightly tag
alias glastc='git rev-parse "$(git tag --sort=-taggerdate | head -1)^{}"'  # Commit of latest tag

# 📦 STASH

alias gst='git stash'            # Stash changes
alias gstp='git stash pop'       # Apply + remove stash
alias gstd='git stash drop'      # Drop stash
alias gstl='git stash list'      # List stashes

# ⏪ RESET
#
# Usage:
#   gro                                      -> reset --soft origin/current-branch
#   gro {--option} eg: --hard --mixed --keep -> reset --hard origin/current-branch
function gro() {
    local mode="${1:---soft}"
    local branch
    branch="$(git branch --show-current)"
    if [[ -z "$branch" ]]; then
        echo "Not on a branch"
        return 1
    fi
    git fetch origin &&
    git reset "$mode" "origin/$branch"
}

# 🚢 DEPLOY (tag-based)

function deploy {
    if [[ -z "${1}" ]]; then
        echo "missing command, like create"
        return 1
    fi

    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    TAG_MESSAGE="${1} @ ${TIMESTAMP}"

    git tag -m "${TAG_MESSAGE}" "${1}"
    git push origin "${1}"
}

function delete_tag {
    TAG="${1}"
    git push origin :refs/tags/${TAG}
    git tag -d ${TAG}
    git fetch
}

function redeploy {
    if [[ -z "${1}" ]]; then
        echo "missing command, like create"
        return 1
    fi

    delete_tag "${1}"
    sleep 15
    deploy "${1}"
}

# cd to git repo root
function cdr {
    cd "$(git rev-parse --show-toplevel 2>/dev/null)"
}

