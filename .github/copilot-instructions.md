# Dotfiles Management Instructions

This repository contains Kris's personal dotfiles for development environment configuration.

## Repository Structure

- `nvim/` - Neovim configuration (Lua-based with lazy.nvim)
- `vim/` - Vim and IdeaVim configuration
- `zsh/.zshrc` - Zsh shell configuration
- `tmux/` - Tmux configuration with helper scripts
- `vscode/` - VSCode settings, keybindings, and extensions list
- `intellij/` - IntelliJ IDEA keymaps and plugins list
- `iterm2/` - iTerm2 preferences plist + profile exports (JSON, macOS)
- `install.sh` - Install/link dotfiles to system
- `sync.sh` - Sync app settings back to this repository
- `rollback.sh` - Rollback to previous backups

## How to Help Users

### Installing Dotfiles

When user wants to install or set up dotfiles on a new machine:

```bash
# Install everything
./install.sh --all

# Or selectively
./install.sh --nvim      # Neovim only
./install.sh --vim       # Vim and IdeaVim only
./install.sh --zsh       # Zsh only
./install.sh --tmux      # Tmux only
./install.sh --vscode    # VSCode only
./install.sh --intellij  # IntelliJ only
./install.sh --iterm2    # iTerm2 only (macOS)

# Interactive mode
./install.sh
```

**What install.sh does:**
- Creates symlinks for Neovim (`~/.config/nvim`), Zsh (`~/.zshrc`), Tmux (`~/.tmux.conf`), Vim (`~/.vimrc`), and IdeaVim (`~/.ideavimrc`)
- Installs TPM (Tmux Plugin Manager) if not present
- Symlinks VSCode settings and installs extensions
- Copies IntelliJ keymaps to the active IntelliJ version
- Copies iTerm2 plist to `~/Library/Preferences/` (restart iTerm2 after)
- Automatically backs up existing configs before replacing

### Syncing Changes Back

When user has made changes in applications and wants to save them to dotfiles:

```bash
# Sync everything
./sync.sh --all

# Or selectively
./sync.sh --vscode    # VSCode settings + extensions
./sync.sh --intellij  # IntelliJ keymaps + plugins
./sync.sh --tmux      # Tmux config + plugins list
./sync.sh --iterm2    # iTerm2 preferences
./sync.sh --nvim      # Neovim (usually symlinked)
./sync.sh --zsh       # Zsh (usually symlinked)
```

**After syncing, remind user to commit:**
```bash
git add -A && git commit -m "Sync dotfiles" && git push
```

### Auto-Synced vs Manual Sync

| Config | After Install | Sync Needed? |
|--------|---------------|--------------|
| Neovim | Symlinked | No - auto-synced |
| Vim/IdeaVim | Symlinked | No - auto-synced |
| Zsh | Symlinked | No - auto-synced |
| Tmux | Symlinked | No - auto-synced |
| iTerm2 | Plist copied | Yes - sync plist |
| VSCode | Symlinked | Yes - for extensions list |
| IntelliJ | Copied | Yes - always |

### Common Tasks

**User wants to add a new VSCode extension to dotfiles:**
```bash
# After installing extension in VSCode
./sync.sh --vscode
git add vscode/extensions.txt && git commit -m "Add new VSCode extension"
```

**User changed IntelliJ keymap:**
```bash
./sync.sh --intellij
git add intellij/ && git commit -m "Update IntelliJ keymap"
```

**User wants to set up on a new Mac:**
```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh --all
```

**User wants to see what will be installed:**
```bash
./install.sh --help
./sync.sh --help
```

## File Locations Reference

| App | System Location | Dotfiles Location |
|-----|-----------------|-------------------|
| Neovim | `~/.config/nvim/` | `nvim/` |
| Vim | `~/.vimrc` | `vim/.vimrc` |
| IdeaVim | `~/.ideavimrc` | `vim/.ideavimrc` |
| Zsh | `~/.zshrc` | `zsh/.zshrc` |
| Tmux | `~/.tmux.conf` | `tmux/.tmux.conf` |
| VSCode (macOS) | `~/Library/Application Support/Code/User/` | `vscode/` |
| VSCode (Linux) | `~/.config/Code/User/` | `vscode/` |
| IntelliJ (macOS) | `~/Library/Application Support/JetBrains/IntelliJIdea*/` | `intellij/` |
| iTerm2 | `~/Library/Preferences/com.googlecode.iterm2.plist` | `iterm2/com.googlecode.iterm2.plist` |

## Troubleshooting

- **VSCode extensions not installing:** Ensure `code` CLI is in PATH
- **IntelliJ keymap not found:** Check the correct IntelliJ version directory
- **iTerm2 settings not applying:** Restart iTerm2 after installation; for JSON profiles, import via Profiles → Other Actions → Import JSON Profiles
- **Permission denied:** Run `chmod +x install.sh sync.sh rollback.sh`

### Rolling Back Changes

When user wants to undo dotfiles installation and restore previous configs:

```bash
# List available backups first
./rollback.sh --list

# Rollback everything
./rollback.sh --all

# Or selectively
./rollback.sh --nvim      # Neovim only
./rollback.sh --vim       # Vim and IdeaVim only
./rollback.sh --zsh       # Zsh only
./rollback.sh --tmux      # Tmux only
./rollback.sh --vscode    # VSCode only
./rollback.sh --intellij  # IntelliJ only
./rollback.sh --iterm2    # iTerm2 only (macOS)

# Interactive mode
./rollback.sh
```

**What rollback.sh does:**
- Finds the most recent `.backup.<timestamp>` file for each config
- Removes the current symlink/config
- Restores the backup to its original location
- For iTerm2, restores the plist from backup (restart iTerm2 after)
