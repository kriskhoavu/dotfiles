# Shortcut Help Center

Leader key: `\` unless a tool says otherwise.

Use this as the human reference for custom shortcuts in this dotfiles repo. It focuses on shortcuts and aliases that were added here, not every default binding from each tool.

## Neovim

Source: `nvim/lua/**`

### Help And Discovery

| Shortcut | Mode | What it does | How to use it |
| --- | --- | --- | --- |
| `\?` | Normal | Open this shortcut help center in a floating window. | Press from anywhere in Neovim. Press `q` to close. |
| `:ShortcutHelp` | Command | Open this shortcut help center. | Run as an Ex command. |

### Terminal And Floating Tools

| Shortcut | Mode | What it does | How to use it |
| --- | --- | --- | --- |
| `\9` | Normal, Terminal | Toggle the floating terminal. | Opens or hides the reusable floating terminal. |
| `\tt` | Normal | Open a real terminal buffer tab. | Creates a new terminal buffer and enters insert mode. |
| `Esc` | Terminal | Leave terminal insert mode. | Use before normal-mode commands like `q`. |
| `Ctrl-]` | Terminal | Send a real Escape key to the terminal app. | Useful inside CLI apps such as Codex, Claude, or other agent UIs. |
| `\3` | Normal, Terminal | Toggle lazygit in a floating terminal. | Press again to hide, or quit lazygit with `q`. |

### Markdown

| Shortcut | Mode | What it does | How to use it |
| --- | --- | --- | --- |
| `\mr` | Normal, Markdown | Run the shell code block under the cursor. | Put cursor inside a fenced `sh`, `bash`, or `shell` block, then press `\mr`. |
| `q` | Normal, runner window | Close the runner float. | Press `Esc` first if the terminal is still in insert mode. The process keeps running in the background. |
| `\ml` | Normal, Markdown | List markdown runner background tasks. | Reopen running or finished task output. |
| `\mp` | Normal, Markdown | Toggle Markdown Preview. | Opens/stops browser preview. |
| `\mr` | Normal, global | Toggle Render Markdown. | In Markdown buffers, the runner mapping is buffer-local and takes priority. |

### Files, Search, Buffers

| Shortcut | Mode | What it does | How to use it |
| --- | --- | --- | --- |
| `\1` | Normal | Toggle Neo-tree file explorer. | Opens or closes the left explorer. |
| `\f.` | Normal | Reveal current file in Neo-tree. | Useful when you are deep in buffers. |
| `gf` | Neo-tree | Open Finder at current node's directory. | Press inside Neo-tree on any file or folder. |
| `\ff` | Normal | Find files with fzf-lua. | Uses the Neo-tree directory when possible. |
| `\fg` | Normal | Find Git-tracked files. | Searches files tracked by Git. |
| `\fG` | Normal | Find all files including hidden files. | Excludes `.git`. |
| `\ft` | Normal | Live grep with fzf-lua. | Search text in the project. |
| `\fb` | Normal | List buffers. | Switch between open buffers. |
| `\fh` | Normal | Search help tags. | Opens Neovim help picker. |
| `\fs` | Normal | Search document symbols. | Uses LSP symbols when available. |
| `⌥h` / `⌥l` | Normal, Insert, Terminal | Previous / next buffer. | Works in all modes including terminal buffers. |
| `\x` | Normal | Close current buffer or special diff window. | Keeps terminal buffers handled specially. |
| `\X` | Normal | Close other buffers. | Keeps terminal buffers. |

### Editing And Clipboard

| Shortcut | Mode | What it does | How to use it |
| --- | --- | --- | --- |
| `K` / `J` | Visual | Move selected lines up / down. | Select lines, press `K` or `J`. |
| `\p` | Visual | Paste over selection without replacing yank. | Keeps the original copied text available. |
| `d`, `D`, `c`, `C`, `s`, `S` | Normal, Visual | Delete/change/substitute without using clipboard. | Uses the black-hole register by default. |
| `\p` | Normal | Paste files copied from Finder into Neo-tree. | Focus Neo-tree on target dir, copy file in Finder (Cmd+C), then press `\p`. |
| `\ce` | Normal | Copy diagnostic message to clipboard. | Put cursor on a diagnostic first. |
| `\ob` | Normal | Open current buffer in browser (works in Neo-tree). | Useful for local HTML and generated files. |

### Windows And Navigation

| Shortcut | Mode | What it does | How to use it |
| --- | --- | --- | --- |
| `Ctrl-h/j/k/l` | Normal | Move between Neovim/tmux panes. | Works with vim-tmux-navigator. |
| `Ctrl-h/j/k/l` | Terminal | Exit terminal mode, then move pane. | Useful from terminal buffers. |
| `\wr` | Normal | Toggle resize mode. | Then use `h/j/k/l`; press `Esc` or `\wr` to stop. |
| `\sd` | Normal | Split or move editor to the right. | Also triggered by WezTerm `Cmd+Shift+D`. |
| `\vt` | Normal | Show directory tree in a floating window. | Runs `tree -L 4`. |
| `\tt` | Normal | Toggle theme. | Note: this conflicts with terminal tab mapping in `floating-terminal.lua`; check which one wins in your current runtime. |

### Git In Neovim

| Shortcut | Mode | What it does | How to use it |
| --- | --- | --- | --- |
| `]h` / `[h` | Normal | Next / previous Git hunk. | Requires gitsigns on a Git file. |
| `\hs` | Normal, Visual | Stage hunk or selected hunk. | Stage current hunk or visual selection. |
| `\hr` | Normal, Visual | Reset hunk or selected hunk. | Discards the selected/current hunk. |
| `\hS` | Normal | Stage whole buffer. | Adds all changes in the file. |
| `\hR` | Normal | Reset whole buffer. | Discards all file changes. |
| `\hu` | Normal | Undo stage hunk. | Unstages the current hunk. |
| `\hb` | Normal | Show blame for current line. | Opens blame info. |
| `\hB` | Normal | Toggle current-line blame. | Persistent inline blame toggle. |
| `\hp` | Normal | Preview hunk. | Shows current hunk diff. |
| `\hd` | Normal | Toggle diff against index. | Opens/closes gitsigns diff view. |
| `\hD` | Normal | Toggle diff against last commit. | Opens/closes gitsigns diff view. |
| `ih` | Operator, Visual | Select Git hunk. | Text object from gitsigns. |
| `\2` | Normal | Toggle Diffview. | Opens or closes Git diff view. |
| `\<Down>` | Normal | Open current file from Diffview and close it. | Similar to VSCode `git.openFile`. |

### LSP And Code

| Shortcut | Mode | What it does | How to use it |
| --- | --- | --- | --- |
| `K` | Normal | Hover documentation. | On a symbol with LSP attached. |
| `gd` / `gD` | Normal | Go to definition / declaration. | LSP navigation. |
| `gi` | Normal | Go to implementation. | LSP navigation. |
| `gr` | Normal | References. | LSP navigation. |
| `gs` | Normal | Signature help. | Shows call signature. |
| `\rn` | Normal | Rename symbol. | LSP rename. |
| `\ca` | Normal, Visual | Code action. | LSP code actions. |
| `[d` / `]d` | Normal | Previous / next diagnostic. | Navigate diagnostics. |
| `\e` | Normal | Open diagnostic float. | Shows diagnostic at cursor. |
| `\q` | Normal | Populate location list with diagnostics. | Useful for reviewing all errors. |
| `\fm` | Normal | Format buffer. | Uses configured formatter/LSP. |
| `\gf` | Normal, Visual | Format with none-ls. | Uses configured none-ls sources. |
| `\co` | Normal, Java | Organize imports. | JDTLS only. |
| `\crv` | Normal, Java | Extract variable. | JDTLS only. |
| `\crc` | Normal, Java | Extract constant. | JDTLS only. |
| `\crm` | Visual, Java | Extract method. | Select code first. |

## Tmux

Source: `tmux/.tmux.conf`

Prefix key: `Ctrl-a`.

| Shortcut | What it does | How to use it |
| --- | --- | --- |
| `Ctrl-a Ctrl-a` | Send prefix to nested tmux. | Useful inside nested sessions. |
| `Ctrl-a \` | Split pane horizontally. | Opens split in current pane path. |
| `Ctrl-a -` | Split pane vertically. | Opens split in current pane path. |
| `Ctrl-a r` | Reload tmux config. | Sources `~/.tmux.conf`. |
| `Ctrl-a h/j/k/l` | Resize pane left/down/up/right. | Repeatable; moves by 5 cells. |
| `Ctrl-a m` | Zoom/unzoom current pane. | Toggle full-pane zoom. |
| `Ctrl-a [` then `v` | Begin copy selection. | Copy mode uses vi keys. |
| `Ctrl-a [` then `y` | Copy selection. | Copies from tmux copy mode. |
| `Ctrl-a L` | Clear screen and scrollback. | In nested tmux, use `Ctrl-a Ctrl-a L`. |
| `Ctrl-a Left/Right` | Previous / next tmux window. | Also works with `Ctrl-a Ctrl-Left/Right`. |
| `Ctrl-a c` | New tmux window. | Starts in current pane path. |
| `Ctrl-a e` | Open an hourly scratch note. | Splits right and opens `notes_YYMMDDHH.md`. |
| `Ctrl-a o` | Open today's todo note. | Splits right and opens `todo_YYMMDD.md`. |
| `Ctrl-a v` | Open Neovim in a right split. | Starts from current pane path. |
| `Ctrl-a Ctrl-s` | Save tmux session. | From tmux-resurrect plugin. |
| `Ctrl-a Ctrl-r` | Restore tmux session. | From tmux-resurrect plugin. |

## Zsh Navigation

Source: `zsh/navigation.zsh`

| Command | What it does | How to use it |
| --- | --- | --- |
| `op` | Fuzzy project navigator. | Pick a root/group, drill into folders, then `cd` there. |
| `itmux` | Fuzzy tmux session picker. | Select an existing session or create one if none exists. |
| `chrome [path]` | Open a file or directory in Chrome with `file://`. | Defaults to current directory. |

## Git Stuff

Source: `zsh/git-stuff.zsh`, `git/.gitconfig`

### Daily Flow

| Command | Expands to / does | How to use it |
| --- | --- | --- |
| `gs` | `git status -sb` | Compact status. |
| `ga <file>` | `git add <file>` | Stage selected files. |
| `gaa` | `git add .` | Stage all changes under current directory. |
| `gcm "msg"` | `git commit -m "msg"` | Commit with a message. |
| `gca` | `git commit --amend` | Amend previous commit. |
| `gca-now [msg]` | Amend while updating author/committer date. | Pass a message or omit to keep the old message. |
| `gcap` | Fixup into a picked recent commit, then autosquash. | Stage changes first, run `gcap`, pick commit in fzf. |
| `gP` | `git push` | Push current branch. |
| `gp` | `git pull --rebase --autostash` | Pull cleanly while preserving local work. |
| `gf` | `git fetch --all --prune` | Fetch and prune deleted remote refs. |
| `git root` | `git rev-parse --show-toplevel` | Print repo root. |
| `cdr` | `cd` to Git repo root. | Use inside any Git worktree. |

### Branches, Logs, Rebase

| Command | Expands to / does | How to use it |
| --- | --- | --- |
| `gb` / `gba` | List local / all branches. | Branch inspection. |
| `gbd <branch>` | Safe delete branch. | Uses `git branch -d`. |
| `gbD <branch>` | Force delete branch. | Uses `git branch -D`. |
| `gc <branch>` | Checkout branch. | Alias for `git checkout`. |
| `gcb <branch>` | Create and checkout branch. | Alias for `git checkout -b`. |
| `gmaster` | Checkout master and pull rebase. | Updates local master. |
| `gl` / `gla` | Pretty graph log current branch / all branches. | Includes changed file names. |
| `gnew` | Show remote commits not in local. | Fetches first. |
| `gmine` | Show local commits not pushed. | Fetches first. |
| `gconf` | List conflicted files. | During merge/rebase conflicts. |
| `grc` / `gra` | Rebase continue / abort. | Rebase recovery. |
| `grshow` | Show current rebase patch. | Inspect failed patch. |
| `gdiff` | Diff local branch against origin branch. | Fetches first. |

### Tags, Stash, Reset

| Command | Expands to / does | How to use it |
| --- | --- | --- |
| `glast` | Latest tag name. | Sorts by tagger date. |
| `gnight` | Latest `nightly*` tag. | Nightly release helper. |
| `glastc` | Commit of latest tag. | Dereferences annotated tags. |
| `gst` / `gstp` | Stash / stash pop. | Save and restore local work. |
| `gstd` / `gstl` | Drop stash / list stashes. | Stash management. |
| `gro` | Reset current branch to `origin/current` with `--soft`. | Use `gro --hard` only when you really want to discard local changes. |
| `deploy <tag>` | Create annotated tag and push it. | Tag message includes timestamp. |
| `delete_tag <tag>` | Delete local and remote tag. | Removes remote ref then local tag. |
| `redeploy <tag>` | Delete tag, wait, recreate and push. | Release helper. |

## Development And AI CLI Helpers

Source: `zsh/development.zsh`

### Kubernetes And Docker

| Command | What it does | How to use it |
| --- | --- | --- |
| `k ...` | Run `kubectl` and print current namespace in color first. | Use like `k get pods`. |
| `kd ...` | `kubectl describe ...` | Describe resources. |
| `kns [pattern]` | Fuzzy-pick namespace and set it as current. | Defaults to `KUBE_NS_PATTERN`. |
| `kns-add <namespace>` | Save namespace in local list. | Adds to `~/.kube/my-namespaces`. |
| `kns-remove [namespace]` | Remove namespace from local list. | Pass name or pick with fzf. |
| `kns-ls` | List saved namespaces. | Shows the namespace cache. |
| `kp ...` | `kubectl get pods -o wide ...` | List pods. |
| `kl ...` | Pick a pod and stream logs. | Uses fzf, tails 200 lines. |
| `ke [shell]` | Pick a pod and exec into it. | Defaults to `sh`. |
| `kdocker` | Remove all Docker containers. | Runs `docker rm -vf $(docker ps -a -q)`. |
| `kport <port>` | Kill processes listening on a port. | Uses `lsof` then `kill -9`. |
| `kjava` | Kill Java processes. | Runs `pkill -9 java`. |

### AI CLI

| Command | What it does | How to use it |
| --- | --- | --- |
| `copilot-god` | Copilot CLI with all tools/paths allowed. | Use for trusted workspaces. |
| `copilot-god-r` | Resume Copilot CLI with all tools/paths allowed. | Continue previous session. |
| `qcopilot "prompt"` | One-shot Copilot prompt. | Silent print mode. |
| `icopilot ...` | Interactive Copilot helper. | Pass args to enter interactive mode. |
| `claude-god` | Claude CLI skipping permissions. | Use for trusted workspaces. |
| `claude-god-r` | Resume Claude CLI skipping permissions. | Continue previous session. |
| `qclaude "prompt"` | One-shot Claude prompt. | Uses `--print -p`. |
| `iclaude ...` | Interactive Claude helper. | Pass args to enter interactive mode. |
| `codex-god` | Codex CLI bypassing approvals and sandbox. | Use for trusted workspaces. |
| `codex-god-r` | Resume Codex CLI bypassing approvals and sandbox. | Continue previous session. |
| `serena-ps` | Show Serena MCP and JDTLS processes. | Debug orphaned language servers. |
| `serena-kill` | Kill orphaned Serena JDTLS processes. | Cleanup helper. |

### Shell

| Command | What it does | How to use it |
| --- | --- | --- |
| `x` | Exit shell. | Alias for `exit`. |
| `hc` | Clear shell history. | Alias for `history -c`. |
| `hg <pattern>` | Search shell history. | Alias for `history | grep`. |

## WezTerm

Source: `wezterm/lua/keys.lua`

| Shortcut | What it does | How to use it |
| --- | --- | --- |
| `Option-Left` | Send Alt-b. | Move one word back in shells/editors that support readline. |
| `Option-Right` | Send Alt-f. | Move one word forward. |
| `Option-Enter` | Send Alt-Enter. | Useful for CLIs that bind Alt-Enter. |
| `Cmd-Shift-D` | Send `\sd` to the terminal. | Triggers Neovim split/move-right mapping when focused in Neovim. |
| `Cmd-T` | Open a new WezTerm tab at home. | Starts in `$HOME`. |
| `Ctrl-C` | Copy if text is selected; otherwise send Ctrl-C. | Smart terminal copy/interrupt behavior. |

## VSCode

Source: `vscode/keybindings.json`

Leader key in VSCode Vim bindings: `\`.

| Shortcut | What it does | How to use it |
| --- | --- | --- |
| `Cmd-1` | Toggle/focus Explorer. | Opens Explorer, or hides sidebar if Explorer is focused. |
| `Cmd-2` | Toggle/focus Source Control. | Opens SCM, or hides sidebar if SCM is focused. |
| `Cmd-3` | Open Git Graph. | Requires Git Graph extension. |
| `Cmd-4` | Open Debug view. | Replaces default Shift-Cmd-D debug shortcut. |
| `Cmd-7` | Open Gradle view. | Requires Gradle extension. |
| `Cmd-9` | Toggle integrated terminal. | Terminal must be active. |
| `Ctrl-t` | Open in integrated terminal. | Uses `openInIntegratedTerminal`. |
| `Ctrl-h/j/k/l` | Navigate editor groups/views. | Vim-style focus movement. |
| `\e` | Toggle Explorer and focus it / return to editor. | Normal mode. |
| `\,` | Show all editors. | Normal mode. |
| `⌥h` / `⌥l` | Previous / next editor in group. | Works in any focus state. |
| `\space` | Quick Open. | Normal mode. |
| `\ff` | Find in files. | Normal mode. |
| `\f.` | Reveal active file in Explorer. | Normal mode. |
| `\ca` | Code action. | Normal mode. |
| `K` | Hover. | Normal mode. |
| `\cr` | Rename symbol. | Normal mode. |
| `\cs` | Go to symbol. | Normal mode. |
| `\gd` / `\gr` / `\gi` | Definition / references / implementation. | Normal mode. |
| `\bd` / `\bo` | Close editor / close other editors. | Normal mode. |
| `\hv` | Open SCM view. | Normal mode. |
| `\hD` | File history. | Normal mode. |
| `\hd` | Diff line with previous. | Normal mode. |
| `]h` / `[h` | Next / previous change. | Normal mode. |
| `Ctrl-n` | Add selection to next match. | Normal or visual mode. |
| `\da` / `\dt` | Start debug / stop debug. | Normal mode. |
| `\do` / `\dc` | Step over / continue. | While stopped in debugger. |
| `\db` | Toggle breakpoint. | Normal mode. |
| `\de` | Show debug hover. | While stopped in debugger. |
| Explorer `a/r/c/p/x/d/s/Enter` | New, rename, copy, paste, cut, delete, open side/open. | When Explorer has focus. |

## IdeaVim And IntelliJ

Sources: `vim/.ideavimrc`, `intellij/Kris.xml`

### IdeaVim

| Shortcut | What it does | How to use it |
| --- | --- | --- |
| `gR` | Replace symbol across whole file. | Starts a confirm substitution from definition. |
| `gr` | Replace symbol inside current block. | Starts a confirm substitution in block. |
| Visual `\(`, `\[`, `\q`, `\"` | Wrap selection in parentheses, brackets, single quotes, or double quotes. | Select text first. |
| Visual `\p` | Paste without overwriting yank buffer. | Keeps copied text. |
| Visual `J` / `K` | Move selected lines down / up. | Visual-line selections work best. |
| `Ctrl-h/l` | Move between splitters. | IntelliJ splitter navigation. |
| `H` / `L` | Previous / next tab. | Editor tab navigation. |
| `\ff` / `\fg` / `\ft` / `\f.` | Go to file / symbol / find in path / select in project. | Search and project navigation. |
| `\hd` / `\hD` / `\hv` | Compare file / file history / commits tool window. | VCS workflow. |
| `]h` / `[h` | Next / previous change marker. | VCS hunk navigation. |
| `\wh/wl/wj/wk` | Resize split left/right/down/up. | Split management. |
| `\1`, `\2`, `\3`, `\4`, `\7`, `\8`, `\9` | Project, Commit, Git, Services, Gradle, Database, Terminal. | Tool window access. |

### IntelliJ Keymap Highlights

| Shortcut | What it does |
| --- | --- |
| `Cmd-1/2/3/4/5/6/7/8/9` | Open common tool windows according to `intellij/Kris.xml`. |
| `Cmd-Esc` | Hide active tool window. |
| `Ctrl--` / `Ctrl-=` | Decrease / increase font size. |
| `Alt-0` | Hide all windows. |
| `Ctrl-t` | Open in terminal. |
| `Cmd-r` | Rename terminal session. |
| `Ctrl-Alt-h/j/k/l` | Navigate splitters. |
| `Shift-Ctrl-Cmd-s/d/r` | Window movement/session actions from the custom keymap. |

