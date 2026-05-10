#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper around cp that skips when source and destination resolve to the same file
# (avoids "are the same file" errors when configs are symlinked back to dotfiles)
safe_cp() {
    local src="$1"
    local dst="$2"
    if [ "$(realpath "$src" 2>/dev/null)" = "$(realpath "$dst" 2>/dev/null)" ]; then
        return 0
    fi
    cp "$src" "$dst"
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================
# Git - Already symlinked, nothing to sync
# ============================================
sync_git() {
    log_info "Checking Git config..."

    if [ -L "$HOME/.gitconfig" ]; then
        log_info "  .gitconfig is symlinked - auto-synced!"
    else
        safe_cp "$HOME/.gitconfig" "$DOTFILES_DIR/git/.gitconfig"
        log_info "  ✓ .gitconfig synced"
    fi

    if [ -L "$HOME/.gitconfig-personal" ]; then
        log_info "  .gitconfig-personal is symlinked - auto-synced!"
    else
        safe_cp "$HOME/.gitconfig-personal" "$DOTFILES_DIR/git/.gitconfig-personal"
        log_info "  ✓ .gitconfig-personal synced"
    fi
}

# ============================================
# VSCode - Sync from app to dotfiles
# ============================================
sync_vscode() {
    log_info "Syncing VSCode settings..."
    
    local vscode_user_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        vscode_user_dir="$HOME/Library/Application Support/Code/User"
    else
        vscode_user_dir="$HOME/.config/Code/User"
    fi
    
    if [ -f "$vscode_user_dir/settings.json" ]; then
        safe_cp "$vscode_user_dir/settings.json" "$DOTFILES_DIR/vscode/settings.json"
        log_info "  ✓ settings.json synced"
    fi
    
    if [ -f "$vscode_user_dir/keybindings.json" ]; then
        safe_cp "$vscode_user_dir/keybindings.json" "$DOTFILES_DIR/vscode/keybindings.json"
        log_info "  ✓ keybindings.json synced"
    fi
    
    if command -v code &> /dev/null; then
        code --list-extensions > "$DOTFILES_DIR/vscode/extensions.txt"
        log_info "  ✓ extensions.txt synced ($(wc -l < "$DOTFILES_DIR/vscode/extensions.txt" | tr -d ' ') extensions)"
    fi
    
    log_info "VSCode sync complete!"
}

# ============================================
# IntelliJ - Sync from app to dotfiles
# ============================================
sync_intellij() {
    log_info "Syncing IntelliJ IDEA settings..."
    
    local intellij_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        intellij_dir=$(find "$HOME/Library/Application Support/JetBrains" -maxdepth 1 -type d -name "IntelliJIdea*" 2>/dev/null | sort -V | tail -1)
    else
        intellij_dir=$(find "$HOME/.config/JetBrains" -maxdepth 1 -type d -name "IntelliJIdea*" 2>/dev/null | sort -V | tail -1)
    fi
    
    if [ -z "$intellij_dir" ]; then
        log_warn "IntelliJ IDEA config directory not found. Skipping."
        return
    fi
    
    # Sync keymaps
    if [ -d "$intellij_dir/keymaps" ]; then
        for keymap in "$intellij_dir/keymaps"/*.xml; do
            if [ -f "$keymap" ]; then
                safe_cp "$keymap" "$DOTFILES_DIR/intellij/"
                log_info "  ✓ $(basename "$keymap") synced"
            fi
        done
    fi
    
    # Sync plugins list
    if [ -d "$intellij_dir/plugins" ]; then
        ls "$intellij_dir/plugins/" > "$DOTFILES_DIR/intellij/plugins.txt"
        log_info "  ✓ plugins.txt synced ($(wc -l < "$DOTFILES_DIR/intellij/plugins.txt" | tr -d ' ') plugins)"
    fi
    
    log_info "IntelliJ sync complete!"
}

# ============================================
# WezTerm - Already symlinked, nothing to sync
# ============================================
sync_wezterm() {
    log_info "Checking WezTerm config..."

    if [ -L "$HOME/.config/wezterm" ]; then
        log_info "  wezterm config is symlinked - auto-synced!"
    else
        rsync -av --exclude='.git' --exclude='.DS_Store' "$HOME/.config/wezterm/" "$DOTFILES_DIR/wezterm/"
        log_info "  ✓ wezterm config synced"
    fi
}

# ============================================
# iTerm2 - Sync from app to dotfiles (plist + JSON profile export)
# ============================================
sync_iterm2() {
    log_info "Syncing iTerm2 settings..."
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warn "iTerm2 is macOS only. Skipping."
        return
    fi
    
    local iterm2_plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    
    # Sync the plist file (full preferences) - convert to XML for git-friendliness
    if [ -f "$iterm2_plist" ]; then
        plutil -convert xml1 -o "$DOTFILES_DIR/iterm2/com.googlecode.iterm2.plist" "$iterm2_plist"
        log_info "  ✓ com.googlecode.iterm2.plist synced (converted to XML)"
    else
        log_warn "  iTerm2 plist not found at $iterm2_plist"
    fi
    
    # Also note about JSON profiles for manual export
    log_info ""
    log_info "  JSON profiles (for manual export):"
    log_info "    iTerm2 → Profiles → Other Actions → Save Profile as JSON"
    log_info "    Save to: $DOTFILES_DIR/iterm2/<ProfileName>.json"
    log_info ""
    log_info "  Existing files in dotfiles:"
    ls -1 "$DOTFILES_DIR/iterm2/"* 2>/dev/null | while read -r f; do
        log_info "    - $(basename "$f")"
    done || log_warn "    (none found)"
    
    log_info "iTerm2 sync complete!"
}

# ============================================
# Zsh - Already symlinked, nothing to sync
# ============================================
sync_zsh() {
    log_info "Checking Zsh config..."
    
    if [ -L "$HOME/.zshrc" ]; then
        log_info "  .zshrc is symlinked - auto-synced!"
    else
        safe_cp "$HOME/.zshrc" "$DOTFILES_DIR/zsh/.zshrc"
        log_info "  ✓ .zshrc synced"
    fi
}

# ============================================
# Vim - Already symlinked, nothing to sync
# ============================================
sync_vim() {
    log_info "Checking Vim config..."
    
    if [ -L "$HOME/.vimrc" ]; then
        log_info "  .vimrc is symlinked - auto-synced!"
    else
        safe_cp "$HOME/.vimrc" "$DOTFILES_DIR/vim/.vimrc"
        log_info "  ✓ .vimrc synced"
    fi
    
    if [ -L "$HOME/.ideavimrc" ]; then
        log_info "  .ideavimrc is symlinked - auto-synced!"
    else
        safe_cp "$HOME/.ideavimrc" "$DOTFILES_DIR/vim/.ideavimrc"
        log_info "  ✓ .ideavimrc synced"
    fi
}

# ============================================
# Tmux - Already symlinked, nothing to sync
# ============================================
sync_tmux() {
    log_info "Checking Tmux config..."
    
    if [ -L "$HOME/.tmux.conf" ]; then
        log_info "  .tmux.conf is symlinked - auto-synced!"
    else
        safe_cp "$HOME/.tmux.conf" "$DOTFILES_DIR/tmux/.tmux.conf"
        log_info "  ✓ .tmux.conf synced"
    fi
}

# ============================================
# Neovim - Already symlinked, nothing to sync
# ============================================
sync_nvim() {
    log_info "Checking Neovim config..."
    
    if [ -L "$HOME/.config/nvim" ]; then
        log_info "  nvim config is symlinked - auto-synced!"
    else
        rsync -av --exclude='.git' --exclude='.DS_Store' "$HOME/.config/nvim/" "$DOTFILES_DIR/nvim/"
        log_info "  ✓ nvim config synced"
    fi
}

# ============================================
# Main
# ============================================
show_help() {
    echo "Usage: ./sync.sh [OPTIONS]"
    echo ""
    echo "Sync application settings back to dotfiles repository."
    echo ""
    echo "Options:"
    echo "  --all       Sync all configurations"
    echo "  --nvim      Sync Neovim config"
    echo "  --vim       Sync Vim and IdeaVim config"
    echo "  --zsh       Sync Zsh config"
    echo "  --tmux      Sync Tmux config"
    echo "  --vscode    Sync VSCode settings and extensions"
    echo "  --intellij  Sync IntelliJ keymaps and plugins"
    echo "  --iterm2    Sync iTerm2 settings"
    echo "  --wezterm   Sync WezTerm config"
    echo "  --help      Show this help message"
    echo ""
    echo "After syncing, commit and push your changes:"
    echo "  git add -A && git commit -m 'Sync dotfiles' && git push"
}

sync_all() {
    echo "=========================================="
    echo "       Dotfiles Sync Script              "
    echo "=========================================="
    echo ""
    
    sync_git
    sync_nvim
    sync_vim
    sync_zsh
    sync_tmux
    sync_vscode
    sync_intellij
    sync_wezterm
    [[ "$OSTYPE" == "darwin"* ]] && sync_iterm2
    
    echo ""
    log_info "All synced! Don't forget to commit your changes."
}

# Parse arguments
if [ $# -eq 0 ]; then
    sync_all
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            sync_all
            shift
            ;;
        --git)
            sync_git
            shift
            ;;
        --nvim)
            sync_nvim
            shift
            ;;
        --vim)
            sync_vim
            shift
            ;;
        --zsh)
            sync_zsh
            shift
            ;;
        --tmux)
            sync_tmux
            shift
            ;;
        --vscode)
            sync_vscode
            shift
            ;;
        --intellij)
            sync_intellij
            shift
            ;;
        --iterm2)
            sync_iterm2
            shift
            ;;
        --wezterm)
            sync_wezterm
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done
