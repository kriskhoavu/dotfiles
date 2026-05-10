#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

backup_if_exists() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warn "Backing up existing $target to $backup"
        mv "$target" "$backup"
    fi
}

# ============================================
# Git
# ============================================
install_git() {
    log_info "Installing Git config..."
    backup_if_exists "$HOME/.gitconfig"
    ln -sf "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"

    backup_if_exists "$HOME/.gitconfig-personal"
    ln -sf "$DOTFILES_DIR/git/.gitconfig-personal" "$HOME/.gitconfig-personal"

    log_info "Git configs linked!"
}

# ============================================
# Neovim
# ============================================
install_nvim() {
    log_info "Installing Neovim config..."
    backup_if_exists "$HOME/.config/nvim"
    mkdir -p "$HOME/.config"
    ln -sf "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
    log_info "Neovim config linked!"
}

# ============================================
# Zsh
# ============================================
install_zsh() {
    log_info "Installing Zsh config..."
    backup_if_exists "$HOME/.zshrc"
    ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    log_info "Zsh config linked!"
}

# ============================================
# Vim
# ============================================
install_vim() {
    log_info "Installing Vim config..."
    backup_if_exists "$HOME/.vimrc"
    ln -sf "$DOTFILES_DIR/vim/.vimrc" "$HOME/.vimrc"
    
    backup_if_exists "$HOME/.ideavimrc"
    ln -sf "$DOTFILES_DIR/vim/.ideavimrc" "$HOME/.ideavimrc"
    
    log_info "Vim and IdeaVim configs linked!"
}

# ============================================
# Tmux
# ============================================
install_tmux() {
    log_info "Installing Tmux config..."
    backup_if_exists "$HOME/.tmux.conf"
    ln -sf "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
    
    # Link tmux scripts directory
    mkdir -p "$HOME/.config/tmux"
    if [ -d "$DOTFILES_DIR/tmux/scripts" ]; then
        backup_if_exists "$HOME/.config/tmux/scripts"
        ln -sf "$DOTFILES_DIR/tmux/scripts" "$HOME/.config/tmux/scripts"
        log_info "Tmux scripts linked!"
    fi
    
    # Install TPM (Tmux Plugin Manager) if not present
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        log_info "Installing TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" 2>/dev/null || log_warn "Failed to install TPM"
    fi
    
    log_info "Tmux config linked!"
    log_warn "Run 'tmux source ~/.tmux.conf' and press prefix + I to install plugins"
}

# ============================================
# VSCode
# ============================================
install_vscode() {
    log_info "Installing VSCode config..."
    
    local vscode_user_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        vscode_user_dir="$HOME/Library/Application Support/Code/User"
    else
        vscode_user_dir="$HOME/.config/Code/User"
    fi
    
    mkdir -p "$vscode_user_dir"
    
    backup_if_exists "$vscode_user_dir/settings.json"
    backup_if_exists "$vscode_user_dir/keybindings.json"
    
    ln -sf "$DOTFILES_DIR/vscode/settings.json" "$vscode_user_dir/settings.json"
    ln -sf "$DOTFILES_DIR/vscode/keybindings.json" "$vscode_user_dir/keybindings.json"
    
    log_info "VSCode settings linked!"
    
    # Install extensions
    if command -v code &> /dev/null; then
        log_info "Installing VSCode extensions..."
        while IFS= read -r extension; do
            code --install-extension "$extension" --force 2>/dev/null || log_warn "Failed to install: $extension"
        done < "$DOTFILES_DIR/vscode/extensions.txt"
        log_info "VSCode extensions installed!"
    else
        log_warn "VSCode CLI not found. Extensions not installed."
        log_warn "Install extensions manually: cat $DOTFILES_DIR/vscode/extensions.txt | xargs -L 1 code --install-extension"
    fi
}

# ============================================
# IntelliJ IDEA
# ============================================
install_intellij() {
    log_info "Installing IntelliJ IDEA config..."
    
    local intellij_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Find the latest IntelliJ version
        intellij_dir=$(find "$HOME/Library/Application Support/JetBrains" -maxdepth 1 -type d -name "IntelliJIdea*" 2>/dev/null | sort -V | tail -1)
    else
        intellij_dir=$(find "$HOME/.config/JetBrains" -maxdepth 1 -type d -name "IntelliJIdea*" 2>/dev/null | sort -V | tail -1)
    fi
    
    if [ -z "$intellij_dir" ]; then
        log_warn "IntelliJ IDEA config directory not found. Skipping keymap installation."
        log_warn "Please copy keymaps manually after installing IntelliJ."
        return
    fi
    
    log_info "Found IntelliJ directory: $intellij_dir"
    
    # Install keymap
    mkdir -p "$intellij_dir/keymaps"
    cp "$DOTFILES_DIR/intellij/Kris.xml" "$intellij_dir/keymaps/"
    log_info "IntelliJ keymap installed!"
    
    log_info "IntelliJ plugins list available at: $DOTFILES_DIR/intellij/plugins.txt"
    log_warn "Note: IntelliJ plugins should be installed via Settings > Plugins"
}

# ============================================
# WezTerm
# ============================================
install_wezterm() {
    log_info "Installing WezTerm config..."
    backup_if_exists "$HOME/.config/wezterm"
    mkdir -p "$HOME/.config"
    ln -sf "$DOTFILES_DIR/wezterm" "$HOME/.config/wezterm"
    log_info "WezTerm config linked!"
}

# ============================================
# iTerm2 (plist + JSON profile import)
# ============================================
install_iterm2() {
    log_info "Installing iTerm2 config..."
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warn "iTerm2 is macOS only. Skipping."
        return
    fi
    
    local iterm2_plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    local dotfiles_plist="$DOTFILES_DIR/iterm2/com.googlecode.iterm2.plist"
    
    # Install plist file (full preferences)
    if [ -f "$dotfiles_plist" ]; then
        backup_if_exists "$iterm2_plist"
        cp "$dotfiles_plist" "$iterm2_plist"
        log_info "  ✓ com.googlecode.iterm2.plist installed"
        log_info "  Restart iTerm2 for changes to take effect"
    else
        log_warn "  No plist file found in $DOTFILES_DIR/iterm2/"
    fi
    
    # Check for JSON profile files
    local json_files=("$DOTFILES_DIR/iterm2/"*.json)
    
    if [ -e "${json_files[0]}" ]; then
        log_info ""
        log_info "Found iTerm2 JSON profiles:"
        for f in "${json_files[@]}"; do
            log_info "  - $(basename "$f")"
        done
        
        log_warn ""
        log_warn "To import JSON profiles (optional):"
        log_info "  1. Open iTerm2 → Profiles"
        log_info "  2. Other Actions → Import JSON Profiles"
        log_info "  3. Select files from: $DOTFILES_DIR/iterm2/"
        log_info "  4. Set your preferred profile as Default"
    fi
}

# ============================================
# Main
# ============================================
show_help() {
    echo "Usage: ./install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all       Install all configurations"
    echo "  --nvim      Install Neovim config"
    echo "  --vim       Install Vim and IdeaVim config"
    echo "  --zsh       Install Zsh config"
    echo "  --tmux      Install Tmux config"
    echo "  --vscode    Install VSCode config and extensions"
    echo "  --intellij  Install IntelliJ keymap"
    echo "  --iterm2    Install iTerm2 config (macOS only)"
    echo "  --wezterm   Install WezTerm config"
    echo "  --help      Show this help message"
    echo ""
    echo "If no options provided, interactive mode will be used."
}

interactive_install() {
    echo "=========================================="
    echo "       Dotfiles Installation Script      "
    echo "=========================================="
    echo ""
    
    read -p "Install Git config? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        install_git
    fi

    read -p "Install Neovim config? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        install_nvim
    fi
    
    read -p "Install Zsh config? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        install_zsh
    fi
    
    read -p "Install Vim/IdeaVim config? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        install_vim
    fi
    
    read -p "Install Tmux config? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        install_tmux
    fi
    
    read -p "Install VSCode config? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        install_vscode
    fi
    
    read -p "Install IntelliJ config? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        install_intellij
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        read -p "Install iTerm2 config? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            install_iterm2
        fi
    fi

    read -p "Install WezTerm config? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        install_wezterm
    fi

    echo ""
    log_info "Installation complete!"
}

# Parse arguments
if [ $# -eq 0 ]; then
    interactive_install
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            install_git
            install_nvim
            install_vim
            install_zsh
            install_tmux
            install_vscode
            install_intellij
            install_iterm2
            install_wezterm
            shift
            ;;
        --git)
            install_git
            shift
            ;;
        --nvim)
            install_nvim
            shift
            ;;
        --vim)
            install_vim
            shift
            ;;
        --zsh)
            install_zsh
            shift
            ;;
        --tmux)
            install_tmux
            shift
            ;;
        --vscode)
            install_vscode
            shift
            ;;
        --intellij)
            install_intellij
            shift
            ;;
        --iterm2)
            install_iterm2
            shift
            ;;
        --wezterm)
            install_wezterm
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

log_info "Installation complete!"
