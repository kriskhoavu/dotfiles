# Kris's Dotfiles

Personal configuration files for development environment.

## Contents

```text
dotfiles/
├── nvim/           # Neovim configuration (Lua-based)
├── vim/            # Vim and IdeaVim configuration
│   ├── .vimrc
│   └── .ideavimrc
├── zsh/            # Zsh configuration
│   └── .zshrc
├── tmux/           # Tmux configuration
│   └── .tmux.conf
├── vscode/         # VSCode configuration
│   ├── settings.json
│   ├── keybindings.json
│   └── extensions.txt
├── intellij/       # IntelliJ IDEA configuration
│   ├── Kris.xml    # Custom keymap
│   └── plugins.txt # List of installed plugins
├── iterm2/         # iTerm2 configuration (macOS)
│   ├── com.googlecode.iterm2.plist  # Full preferences
│   └── *.json      # Profile exports (optional)
├── install.sh      # Installation script
├── sync.sh         # Sync app settings back to dotfiles
├── rollback.sh     # Rollback to previous backups
└── README.md
```

## Quick Install

```bash
# Clone this repository
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles

# Make scripts executable
chmod +x install.sh sync.sh

# Install all configurations
./install.sh --all

# Or run interactively
./install.sh
```

## Shortcut Help

See [SHORTCUTS.md](SHORTCUTS.md) for the custom shortcut help center covering Neovim, Tmux, Git aliases, Zsh helpers, WezTerm, VSCode, and IntelliJ/IdeaVim.

## Sync Changes Back to Dotfiles

When you edit settings directly in apps (VSCode, IntelliJ, etc.), sync them back:

```bash
./sync.sh --all       # Sync everything
./sync.sh --vscode    # Only VSCode
./sync.sh --intellij  # Only IntelliJ

# Then commit your changes
git add -A && git commit -m "Sync dotfiles" && git push
```

**Note:** Symlinked configs (Neovim, Zsh, Tmux, Vim) auto-sync - no action needed!

## Selective Installation

```bash
./install.sh --nvim      # Only Neovim
./install.sh --vim       # Only Vim/IdeaVim
./install.sh --zsh       # Only Zsh
./install.sh --tmux      # Only Tmux
./install.sh --vscode    # Only VSCode
./install.sh --intellij  # Only IntelliJ
./install.sh --iterm2    # Only iTerm2 (macOS)
```

## What Gets Installed

### Neovim

- Symlinks `~/.config/nvim` → `dotfiles/nvim`
- Lua-based configuration with lazy.nvim plugin manager

### Vim / IdeaVim

- Symlinks `~/.vimrc` → `dotfiles/vim/.vimrc`
- Symlinks `~/.ideavimrc` → `dotfiles/vim/.ideavimrc`
- Shared keybindings for Vim and IntelliJ IdeaVim plugin

### Zsh

- Symlinks `~/.zshrc` → `dotfiles/zsh/.zshrc`

### Tmux

- Symlinks `~/.tmux.conf` → `dotfiles/tmux/.tmux.conf`
- Installs TPM (Tmux Plugin Manager) if not present
- Catppuccin theme with custom status bar

### VSCode

- Symlinks `settings.json` and `keybindings.json`
- Installs all extensions from `extensions.txt`

### IntelliJ IDEA

- Copies `Kris.xml` keymap to IntelliJ keymaps directory
- Plugins list provided for manual installation via Settings > Plugins

### iTerm2 (macOS only)

- Copies `com.googlecode.iterm2.plist` to `~/Library/Preferences/` (full settings)
- Optional: JSON profile exports for manual import
- Restart iTerm2 after installation for changes to take effect
- Sync with `./sync.sh --iterm2` to save changes back to dotfiles

## Backup

The install script automatically backs up existing files before creating symlinks.
Backups are named with timestamp: `<filename>.backup.<timestamp>`

## Rollback

If something goes wrong, rollback to your previous configs:

```bash
./rollback.sh --list      # See available backups
./rollback.sh --all       # Rollback everything
./rollback.sh --vscode    # Rollback just VSCode
./rollback.sh             # Interactive mode
```

## Manual VSCode Extension Install

If the install script couldn't install extensions:

```bash
cat vscode/extensions.txt | xargs -L 1 code --install-extension
```

## Manual Export (Update Dotfiles)

```bash
# Export VSCode extensions
code --list-extensions > vscode/extensions.txt

# Copy latest IntelliJ keymap
cp ~/Library/Application\ Support/JetBrains/IntelliJIdea*/keymaps/Kris.xml intellij/
```

## Requirements

- **Neovim** 0.9+ (for Lua config support)
- **Zsh** (usually pre-installed on macOS)
- **VSCode** with `code` CLI in PATH
- **IntelliJ IDEA** (any edition)
