#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_blue() { echo -e "${BLUE}[ROLLBACK]${NC} $1"; }

# Find most recent backup for a given path
find_latest_backup() {
    local target="$1"
    local backup_pattern="${target}.backup.*"
    
    # Find the most recent backup
    local latest
    latest=$(ls -t $backup_pattern 2>/dev/null | head -1)
    echo "$latest"
}

# Rollback a single config
rollback_config() {
    local target="$1"
    local name="$2"
    
    local latest_backup
    latest_backup=$(find_latest_backup "$target")
    
    if [ -z "$latest_backup" ]; then
        log_warn "No backup found for $name ($target)"
        return 1
    fi
    
    log_blue "Found backup: $latest_backup"
    
    # Remove current (which is likely a symlink to dotfiles)
    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -rf "$target"
    fi
    
    # Restore from backup
    mv "$latest_backup" "$target"
    log_info "✓ Restored $name from backup"
    return 0
}

# ============================================
# Git
# ============================================
rollback_git() {
    log_blue "Rolling back Git config..."
    rollback_config "$HOME/.gitconfig" ".gitconfig"
    rollback_config "$HOME/.gitconfig-personal" ".gitconfig-personal"
}

# ============================================
# Neovim
# ============================================
rollback_nvim() {
    log_blue "Rolling back Neovim config..."
    rollback_config "$HOME/.config/nvim" "Neovim"
}

# ============================================
# Zsh
# ============================================
rollback_zsh() {
    log_blue "Rolling back Zsh config..."
    rollback_config "$HOME/.zshrc" "Zsh"
}

# ============================================
# Vim
# ============================================
rollback_vim() {
    log_blue "Rolling back Vim config..."
    rollback_config "$HOME/.vimrc" "Vim"
    rollback_config "$HOME/.ideavimrc" "IdeaVim"
}

# ============================================
# Tmux
# ============================================
rollback_tmux() {
    log_blue "Rolling back Tmux config..."
    rollback_config "$HOME/.tmux.conf" "Tmux"
}

# ============================================
# VSCode
# ============================================
rollback_vscode() {
    log_blue "Rolling back VSCode config..."
    
    local vscode_user_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        vscode_user_dir="$HOME/Library/Application Support/Code/User"
    else
        vscode_user_dir="$HOME/.config/Code/User"
    fi
    
    local restored=0
    
    rollback_config "$vscode_user_dir/settings.json" "VSCode settings.json" && ((restored++)) || true
    rollback_config "$vscode_user_dir/keybindings.json" "VSCode keybindings.json" && ((restored++)) || true
    
    if [ $restored -eq 0 ]; then
        log_warn "No VSCode backups found"
    fi
}

# ============================================
# IntelliJ
# ============================================
rollback_intellij() {
    log_blue "Rolling back IntelliJ config..."
    
    local intellij_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        intellij_dir=$(find "$HOME/Library/Application Support/JetBrains" -maxdepth 1 -type d -name "IntelliJIdea*" 2>/dev/null | sort -V | tail -1)
    else
        intellij_dir=$(find "$HOME/.config/JetBrains" -maxdepth 1 -type d -name "IntelliJIdea*" 2>/dev/null | sort -V | tail -1)
    fi
    
    if [ -z "$intellij_dir" ]; then
        log_warn "IntelliJ IDEA config directory not found"
        return
    fi
    
    # Find and rollback keymap backups
    local restored=0
    for backup in "$intellij_dir/keymaps"/*.xml.backup.*; do
        if [ -f "$backup" ]; then
            local original="${backup%.backup.*}"
            if [ -f "$original" ]; then
                rm "$original"
            fi
            mv "$backup" "$original"
            log_info "✓ Restored $(basename "$original")"
            ((restored++))
        fi
    done
    
    if [ $restored -eq 0 ]; then
        log_warn "No IntelliJ keymap backups found"
    fi
}

# ============================================
# WezTerm
# ============================================
rollback_wezterm() {
    log_blue "Rolling back WezTerm config..."
    rollback_config "$HOME/.config/wezterm" "WezTerm"
}

# ============================================
# iTerm2 (plist + JSON profile)
# ============================================
rollback_iterm2() {
    log_blue "Rolling back iTerm2 config..."
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warn "iTerm2 is macOS only. Skipping."
        return
    fi
    
    local iterm2_plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    
    # Try to rollback plist from backup
    if rollback_config "$iterm2_plist" "iTerm2 plist"; then
        log_info "Restart iTerm2 for changes to take effect"
    else
        # Clear any old plist custom folder settings
        defaults delete com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || true
        defaults delete com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null || true
        
        log_info "To remove imported profiles:"
        log_info "  1. Open iTerm2 → Profiles"
        log_info "  2. Select the profile to remove"
        log_info "  3. Click '-' button to delete"
        log_warn "Restart iTerm2 for changes to take effect"
    fi
}

# ============================================
# List available backups
# ============================================
list_backups() {
    echo "=========================================="
    echo "       Available Backups                 "
    echo "=========================================="
    echo ""
    
    local found=0
    
    # Git
    for backup in "$HOME/.gitconfig.backup."*; do
        if [ -e "$backup" ]; then
            echo "Git:      $backup"
            ((found++))
        fi
    done
    for backup in "$HOME/.gitconfig-personal.backup."*; do
        if [ -e "$backup" ]; then
            echo "Git(per): $backup"
            ((found++))
        fi
    done

    # Neovim
    for backup in "$HOME/.config/nvim.backup."*; do
        if [ -e "$backup" ]; then
            echo "Neovim:   $backup"
            ((found++))
        fi
    done
    
    # Zsh
    for backup in "$HOME/.zshrc.backup."*; do
        if [ -e "$backup" ]; then
            echo "Zsh:      $backup"
            ((found++))
        fi
    done
    
    # Tmux
    for backup in "$HOME/.tmux.conf.backup."*; do
        if [ -e "$backup" ]; then
            echo "Tmux:     $backup"
            ((found++))
        fi
    done
    
    # Vim
    for backup in "$HOME/.vimrc.backup."*; do
        if [ -e "$backup" ]; then
            echo "Vim:      $backup"
            ((found++))
        fi
    done
    for backup in "$HOME/.ideavimrc.backup."*; do
        if [ -e "$backup" ]; then
            echo "IdeaVim:  $backup"
            ((found++))
        fi
    done
    
    # VSCode
    local vscode_user_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        vscode_user_dir="$HOME/Library/Application Support/Code/User"
    else
        vscode_user_dir="$HOME/.config/Code/User"
    fi
    
    for backup in "$vscode_user_dir"/*.backup.*; do
        if [ -e "$backup" ]; then
            echo "VSCode:   $backup"
            ((found++))
        fi
    done
    
    # IntelliJ
    local intellij_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        intellij_dir=$(find "$HOME/Library/Application Support/JetBrains" -maxdepth 1 -type d -name "IntelliJIdea*" 2>/dev/null | sort -V | tail -1)
    else
        intellij_dir=$(find "$HOME/.config/JetBrains" -maxdepth 1 -type d -name "IntelliJIdea*" 2>/dev/null | sort -V | tail -1)
    fi
    
    if [ -n "$intellij_dir" ]; then
        for backup in "$intellij_dir/keymaps"/*.backup.*; do
            if [ -e "$backup" ]; then
                echo "IntelliJ: $backup"
                ((found++))
            fi
        done
    fi
    
    # WezTerm
    for backup in "$HOME/.config/wezterm.backup."*; do
        if [ -e "$backup" ]; then
            echo "WezTerm:  $backup"
            ((found++))
        fi
    done

    # iTerm2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        for backup in "$HOME/Library/Preferences/com.googlecode.iterm2.plist.backup."*; do
            if [ -e "$backup" ]; then
                echo "iTerm2:   $backup"
                ((found++))
            fi
        done
    fi
    
    echo ""
    if [ $found -eq 0 ]; then
        log_warn "No backups found. Backups are created when running install.sh"
    else
        log_info "Found $found backup(s)"
    fi
}

# ============================================
# Main
# ============================================
show_help() {
    echo "Usage: ./rollback.sh [OPTIONS]"
    echo ""
    echo "Rollback to the most recent backup of your configurations."
    echo "Backups are created automatically by install.sh before replacing configs."
    echo ""
    echo "Options:"
    echo "  --all       Rollback all configurations"
    echo "  --git       Rollback Git config"
    echo "  --nvim      Rollback Neovim config"
    echo "  --vim       Rollback Vim and IdeaVim config"
    echo "  --zsh       Rollback Zsh config"
    echo "  --tmux      Rollback Tmux config"
    echo "  --vscode    Rollback VSCode config"
    echo "  --intellij  Rollback IntelliJ config"
    echo "  --iterm2    Rollback iTerm2 config (macOS only)"
    echo "  --wezterm   Rollback WezTerm config"
    echo "  --list      List all available backups"
    echo "  --help      Show this help message"
}

interactive_rollback() {
    echo "=========================================="
    echo "       Dotfiles Rollback Script          "
    echo "=========================================="
    echo ""
    log_warn "This will restore your previous configs from backups."
    echo ""
    
    read -p "Rollback Git config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rollback_git
    fi

    read -p "Rollback Neovim config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rollback_nvim
    fi
    
    read -p "Rollback Vim/IdeaVim config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rollback_vim
    fi
    
    read -p "Rollback Zsh config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rollback_zsh
    fi
    
    read -p "Rollback Tmux config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rollback_tmux
    fi
    
    read -p "Rollback VSCode config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rollback_vscode
    fi
    
    read -p "Rollback IntelliJ config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rollback_intellij
    fi
    
    read -p "Rollback WezTerm config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rollback_wezterm
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        read -p "Rollback iTerm2 config? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rollback_iterm2
        fi
    fi
    
    echo ""
    log_info "Rollback complete!"
}

# Parse arguments
if [ $# -eq 0 ]; then
    interactive_rollback
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            rollback_git
            rollback_nvim
            rollback_vim
            rollback_zsh
            rollback_tmux
            rollback_vscode
            rollback_intellij
            rollback_wezterm
            [[ "$OSTYPE" == "darwin"* ]] && rollback_iterm2
            shift
            ;;
        --git)
            rollback_git
            shift
            ;;
        --nvim)
            rollback_nvim
            shift
            ;;
        --vim)
            rollback_vim
            shift
            ;;
        --zsh)
            rollback_zsh
            shift
            ;;
        --tmux)
            rollback_tmux
            shift
            ;;
        --vscode)
            rollback_vscode
            shift
            ;;
        --intellij)
            rollback_intellij
            shift
            ;;
        --iterm2)
            rollback_iterm2
            shift
            ;;
        --wezterm)
            rollback_wezterm
            shift
            ;;
        --list)
            list_backups
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
