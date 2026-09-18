# Shortcut Help Center

Leader key: `\` unless a tool says otherwise.

Use this as the human reference for custom shortcuts in this dotfiles repo. It focuses on shortcuts and aliases that were added here, not every default binding from each tool.

## macOS Window Pairing

Requires Rectangle and Hammerspoon with Accessibility permission. Hammerspoon calls Rectangle directly, so this works even if you customise Rectangle's own shortcuts.

| Shortcut                   | What it does                                                                                                  | How to use it                                                |
|----------------------------|---------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `Ctrl-Option-Shift-Left`   | Moves the focused window to the left half, then opens a searchable picker for a window to place on the right. | Type an app or window title, then press `Enter`.             |
| `Ctrl-Option-Shift-Right`  | Moves the focused window to the right half, then opens a searchable picker for a window to place on the left. | Type an app or window title, then press `Enter`.             |
| `Ctrl-Option-Command-Down` | Opens a searchable list of open apps and windows.                                                             | Type an app or window title, then press `Enter` to focus it. |

## Neovim

Source: `nvim/lua/**`

### Help And Discovery

| Shortcut        | Mode    | What it does                                         | How to use it                                      |
|-----------------|---------|------------------------------------------------------|----------------------------------------------------|
| `\?`            | Normal  | Open this shortcut help center in a floating window. | One tab per section below, so you land in the one you want instead of scrolling the whole file. See [Floating Windows](#floating-windows) for the keys every float shares; `1`-`9` also pick a tab here, and `/` searches inside the current one. |
| `:ShortcutHelp` | Command | Open this shortcut help center.                      | Run as an Ex command. Called again while open, it closes the float.                              |

The tabs are read from this file's `##` headings every time the float opens, so adding a section here adds a tab with no code change, and an edit shows up on the next `\?`.

### Floating Windows

Every float in this config is built by one function (`nvim/lua/floating-helpers.lua`), so they look and behave alike no matter which one you opened. Seven of them exist:

| Float          | Opens with        | Tabs | Pressing it again |
|----------------|-------------------|------|--------------------|
| lazygit        | `\3`              | —    | hides; the lazygit session keeps running |
| org git        | `\4`              | ✔    | hides; every repo's lazygit keeps running |
| terminal       | `\9`              | —    | hides; the shell keeps its history and cwd |
| shortcut help  | `\?`              | ✔    | closes; sections are re-read on the next open |
| tree view      | `:ShowTree`       | —    | closes |
| markdown runner| `\mr`, `\ml`      | —    | closes; warns if the job is still running |

**What they all share**

| Shortcut            | What it does                        | How to use it                                                                                  |
|---------------------|-------------------------------------|------------------------------------------------------------------------------------------------|
| `✕` (click)         | Close or hide the float.            | Top right of every float. Does whatever pressing the float's own key again would do.            |
| `Ctrl-h/j/k/l`      | Move between **tmux panes**.        | Never moves to a Neovim window: a float left behind the editor cannot be reached again.         |
| `Alt-1`-`Alt-9`     | Nothing, deliberately.              | tmux takes these for its own windows before Neovim sees them.                                   |

They are also centred at a ratio of the editor rather than a fixed size, share their colours with the tmux status bar, and turn off `scrolloff` so a full-width TUI is never scrolled out of alignment. `:help` opens as a float too, but is deliberately *not* modal — it is a place you read and leave.

**In a tabbed float** (`\4`, `\?`)

| Shortcut              | What it does                | How to use it                                                                                  |
|-----------------------|-----------------------------|--------------------------------------------------------------------------------------------------|
| `Ctrl-Opt-<digit>`    | Jump straight to that tab.  | The digit on the chip is the digit you press. Works inside a lazygit tab, where plain digits belong to lazygit. |
| `Alt-h` / `Alt-l`     | Previous / next tab.        | Wraps around through the first tab.                                                             |
| Click a tab           | Jump to it.                 | The whole chip is clickable, rounded ends included.                                             |

`Ctrl-Opt-<digit>` needs three things, and all three are in this repo: `wezterm/lua/keys.lua` sends the CSI-u form explicitly (a terminal has no control code for that combination, so nothing would be transmitted at all), `tmux/.tmux.conf` sets `extended-keys on` with the `extkeys` feature so tmux re-encodes it, and Neovim reads it as `<C-M-digit>`.

### Terminal And Floating Tools

| Shortcut | Mode             | What it does                                | How to use it                                                     |
|----------|------------------|---------------------------------------------|-------------------------------------------------------------------|
| `\9`     | Normal, Terminal | Toggle the floating terminal.               | Opens or hides the reusable floating terminal. Clicking the `✕` in its top-right hides it too — same as `\9`, so the shell keeps its history, cwd and whatever is running. |
| `\tt`    | Normal           | Open a real terminal buffer tab.            | Creates a new terminal buffer and enters insert mode.             |
| `Esc`    | Terminal         | Leave terminal insert mode.                 | Use before normal-mode commands like `q`; inside lazygit it goes to lazygit instead. |
| `Ctrl-]` | Terminal         | Send a real Escape key to the terminal app. | Useful inside CLI apps such as Codex, Claude, or other agent UIs. |
| `\3`     | Normal, Terminal | Toggle lazygit in a floating terminal.      | Press again to hide, click the `✕` at its top right, or quit lazygit with `q`; `Esc` stays inside lazygit, and `Ctrl-h/j/k/l` / `Alt-h/l` cannot move focus out of the float. |
| `e`      | Terminal         | Open the selected file in nvim.             | Inside lazygit only: hides the float and edits the file in the nvim hosting it; `\3` or `\4` returns to the same session. `o` still opens in the default app. |
| `\4`     | Normal, Terminal | Toggle the org git float: one tab per repo. | For a folder of sibling repos. Same float as `\3`, but tabbed across every repo in the org. See [Org Git](#org-git-many-repos-at-once). |

### Markdown

| Shortcut | Mode                  | What it does                               | How to use it                                                                 |
|----------|-----------------------|--------------------------------------------|-------------------------------------------------------------------------------|
| `\mr`    | Normal, Markdown      | Run the shell code block under the cursor. | Put cursor inside a fenced `sh`, `bash`, or `shell` block, then press `\mr`.  |
| `mr`     | Normal, Markdown      | Run the shell code block under the cursor. | Shorter reach for `\mr`; buffer-local, so it shadows `m r` (set mark r) only in Markdown. |
| _(both)_ | Normal, Markdown      | Blocks run from the document's repository root. | So relative paths like `deploy/docker/...` resolve the way the block intends, wherever Neovim was started. Outside a repo, the document's own folder is used. The float's title names the directory. |
| `Q` or `✕` | Normal, runner window | Close the runner float.                  | Works directly in terminal mode; the process keeps running in the background, and either way you are told when it is still going. |
| `\ml`    | Normal, Markdown      | List markdown runner background tasks.     | Reopen running or finished task output.                                       |
| `\mp`    | Normal, Markdown      | Toggle Markdown Preview.                   | Opens/stops browser preview.                                                  |
| `\mr`    | Normal, global        | Toggle Render Markdown.                    | In Markdown buffers, the runner mapping is buffer-local and takes priority.   |

### Files, Search, Buffers

| Shortcut    | Mode                     | What it does                                 | How to use it                                  |
|-------------|--------------------------|----------------------------------------------|------------------------------------------------|
| `\1`        | Normal                   | Toggle Neo-tree file explorer.               | Opens or closes the left explorer.             |
| `\f.`       | Normal                   | Reveal current file in Neo-tree.             | Useful when you are deep in buffers.           |
| `\gs`       | Normal                   | Toggle the Git status tree.                  | Same view as `<` / `>` cycling in Neo-tree.    |
| `gf`        | Neo-tree                 | Open Finder at current node's directory.     | Press inside Neo-tree on any file or folder.   |
| `\ff`       | Normal                   | Find files with fzf-lua.                     | Uses the Neo-tree directory when possible.     |
| `\fg`       | Normal                   | Find Git-tracked files.                      | Searches files tracked by Git.                 |
| `\fG`       | Normal                   | Find all files including hidden files.       | Excludes `.git`.                               |
| `\ft`       | Normal                   | Live grep with fzf-lua.                      | Search text in the project.                    |
| `\fb`       | Normal                   | List buffers.                                | Switch between open buffers.                   |
| `\fh`       | Normal                   | Search help tags.                            | Opens Neovim help picker.                      |
| `\fs`       | Normal                   | Search document symbols.                     | Uses LSP symbols when available.               |
| `⌥h` / `⌥l` | Normal, Insert, Terminal | Previous / next buffer.                      | Works in all modes including terminal buffers. |
| `\[` / `\]` | Normal, Insert, Terminal | Step back / forward through the files you visited. | Like IntelliJ's `Cmd+[` / `Cmd+]`. Returns to where the cursor was, and reopens the file even if you closed it. |
| `\x`        | Normal                   | Close current buffer or special diff window. | Keeps terminal buffers handled specially.      |
| `\X`        | Normal                   | Close other buffers.                         | Keeps terminal buffers.                        |

### Editing And Clipboard

| Shortcut                     | Mode           | What it does                                         | How to use it                                                               |
|------------------------------|----------------|------------------------------------------------------|-----------------------------------------------------------------------------|
| `K` / `J`                    | Visual         | Move selected lines up / down.                       | Select lines, press `K` or `J`.                                             |
| `\p`                         | Visual         | Paste over selection without replacing yank.         | Keeps the original copied text available.                                   |
| `d`, `D`, `c`, `C`, `s`, `S` | Normal, Visual | Delete/change/substitute without using clipboard.    | Uses the black-hole register by default.                                    |
| `\p`                         | Normal         | Paste files copied from Finder into Neo-tree.        | Focus Neo-tree on target dir, copy file in Finder (Cmd+C), then press `\p`. |
| `\ce`                        | Normal         | Copy diagnostic message to clipboard.                | Put cursor on a diagnostic first.                                           |
| `\ob`                        | Normal         | Open current buffer in browser (works in Neo-tree).  | Useful for local HTML and generated files.                                  |
| `\of`                        | Normal         | Reveal current buffer in Finder (works in Neo-tree). | Selects files in Finder; opens directories directly.                        |

### Windows And Navigation

| Shortcut       | Mode     | What it does                                | How to use it                                                                                                            |
|----------------|----------|---------------------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| `Ctrl-h/j/k/l` | Normal   | Move between Neovim/tmux panes.             | Works with vim-tmux-navigator.                                                                                           |
| `Ctrl-h/j/k/l` | Terminal | Exit terminal mode, then move pane.         | Useful from terminal buffers. Inside a float they only switch tmux panes, never nvim windows — see [Floating Windows](#floating-windows). |
| `Ctrl-w c`     | Normal   | Close current split window.                 | Use to hide the active pane while keeping others open.                                                                   |
| `\wr`          | Normal   | Toggle resize mode.                         | Then use `h/j/k/l`; press `Esc` or `\wr` to stop.                                                                        |
| `\sd`          | Normal   | Split or move editor to the right.          | Splits inside Neovim. Also triggered by WezTerm `Ctrl+Cmd+Shift+D`.                                                      |
| `\st`          | Normal   | Move the current file to a right tmux pane. | A real tmux pane, not a Neovim split (that is `\sd`). WezTerm `Ctrl+Cmd+Shift+T`; saves and closes the local buffer, then restores it when that pane closes. |
| `\vt`          | Normal   | Show directory tree in a floating window.   | Runs `tree -L 4`.                                                                                                        |
| `:ThemeToggle` | Command  | Cycle the colour scheme.                    | Was `\tt`, but that key now opens a terminal tab (`floating-terminal.lua` loads later and wins), so the theme binding never fires. Run the command, or `:Theme <name>` to pick one. |

### Git In Neovim

**The words first.** A **hunk** is one contiguous block of changed lines; a single file usually has several. A **buffer** is Neovim's word for the whole file you have open. **Staged** means "this is what `git commit` will record" — Git tracks that separately from the text in front of you:
```
              staged                        working copy
             ("index")                   (what you see in nvim)
                 | <------ \hs   \hS ------------ |  stage:   mark it for the next commit
                 | ------- \hu -----------------> |  unstage: unmark it, text untouched
                 | ======= \hr   \hR ===========> |  reset:   OVERWRITE your text with the staged copy
```

Stage and unstage only move that mark, so they can never lose work. **Reset is the one that destroys**, and plain `u` undoes it, because a reset is just an edit to the buffer. The last commit (`HEAD`) only enters the picture for `\hD` and `gr`.

| Shortcut    | Mode             | What it does                                      | How to use it                                                                                    |
|-------------|------------------|---------------------------------------------------|--------------------------------------------------------------------------------------------------|
| `]h` / `[h` | Normal           | Jump to the next / previous changed block.        | Fastest way to walk everything you touched. Needs a file inside a Git repo.                      |
| `\hp`       | Normal           | Peek at what you changed here, without moving.    | Shows the lines you replaced, in a float. `q` closes it.                                         |
| `\hs`       | Normal, Visual   | Stage this hunk: include it in the next commit.   | In Visual mode it stages only the lines you selected. Same idea as `git add -p`.                 |
| `\hS`       | Normal           | Stage the whole file.                             | `\hs` when you want all of it rather than one block.                                             |
| `\hu`       | Normal           | Unstage: take it back out of the next commit.     | Your text is untouched, nothing is lost. For when you staged something too early.                |
| `\hr`       | Normal           | ⚠️ Throw away your edit to this hunk.              | Puts back the **staged** version, so staged work survives. Pressed it by mistake? `u` undoes it. |
| `\hR`       | Normal           | ⚠️ Throw away every unstaged edit in the file.     | Also reverts to the staged version, not to the last commit. `u` undoes it while the file is open.|
| `\hb`       | Normal           | Who last changed this line, and why.              | Author, date and commit message for the cursor line, in a float. `q` closes it.                  |
| `\hB`       | Normal           | The same blame, pinned beside every line.         | A toggle: press again to turn it off. Handy while reading unfamiliar code.                       |
| `\hd`       | Normal           | Side by side: your file vs. the staged version.   | Shows what you have not staged yet. `q`, `Esc` or `\hd` again closes it.                         |
| `\hD`       | Normal           | Side by side: your file vs. one commit further back. | Compares against `HEAD~`, so it shows your uncommitted edits **plus** the last commit's. `q`, `Esc` or `\hD` again closes it. |
| `\hf`       | Normal           | Every past commit that touched this file.         | Walk the file's history and diff any version. `q` or `Esc` closes it.                            |
| `ih`        | Operator, Visual | The current hunk, as a target for other commands. | Combine it: `dih` deletes the hunk, `vih` selects it, `yih` copies it.                            |
| `\2`        | Normal           | Every changed file in the repo, side by side.     | The full review pass before committing. `q` or `Esc` closes it, from the diff or the file list.  |
| `\<Down>`   | Normal           | Stop reviewing this file, start editing it.       | From inside `\2`: closes the diff and opens the real file. VSCode calls this `git.openFile`.     |
| `gd`        | Git status tree  | Diff just the file under the cursor.              | In the `\gs` tree. Same side-by-side view, scoped to one file.                                   |
| `ga` / `gu` | Git status tree  | Stage / unstage the file under the cursor.        | `gt` toggles between the two; `A` stages every changed file at once.                             |
| `gr`        | Git status tree  | ⚠️ Throw away every edit to that file.             | Runs `git checkout HEAD -- <file>`: it reverts to the last commit, drops staged work too, and writes the file on disk, so Neovim's `u` cannot bring it back. |
| `gc` / `gp` | Git status tree  | Commit / push.                                    | `gg` does both at once. `gU` undoes the last commit but keeps its changes, staged.               |

### Org Git: Many Repos At Once

Source: `nvim/lua/org-git.lua`

`\3` shows one repo — the one you are in. `\4` shows **all of them**: a folder of sibling repos (a GitHub org checked out side by side, like `kompas`) becomes tabs in one float, with an overview tab across the whole set. The org root is found on every open: the directory you are in if it holds repos, otherwise the parent of the repo you are in.

Every git action inside a repo tab is lazygit's own — stage with `space`, commit with `c`, amend with `A`, push with `P`, drill into hunks with `Enter`. Nothing is reimplemented here; the module only draws the tabs and the overview, because a single lazygit can only ever show one repo.

| Shortcut          | Mode             | What it does                                 | How to use it                                                                                      |
|-------------------|------------------|----------------------------------------------|------------------------------------------------------------------------------------------------------|
| `\4`              | Normal, Terminal | Open or hide the org float.                  | Hiding keeps every repo's lazygit running, so `\4` returns to the same tab.                            |
| `Ctrl-Opt-<digit>` | Any tab         | Jump to that repo; `0` is the overview.      | Works inside a repo tab too. Returning to the overview puts the cursor on the repo you came from.     |
| `Alt-h` / `Alt-l`  | Any tab         | Previous / next repo.                        | Wraps around through the overview.                                                                    |
| `1`-`9`           | Overview         | Jump to that repo.                           | On the overview the digits need no modifier, since lazygit is not listening there.                    |
| `Enter`           | Overview         | Open the repo under the cursor.              | Its lazygit starts on first visit, not before.                                                       |
| `r`               | Overview         | Re-read every repo's status.                 | Counts also refresh on their own each time you switch tabs.                                          |
| `q`               | Overview         | Close the float.                             | Same as `\4`, as is the `✕`.                                                                          |
| `:OrgGit`         | Command          | Open the float, optionally for another root. | `:OrgGit ~/some/other/org` switches roots, and that choice sticks across `\4`; a bare `:OrgGit` hands the float back to the directory you are in. |

Everything the float shares with the others — the `✕`, the modal `Ctrl-hjkl`, how the tab keys are carried from the keyboard — is in [Floating Windows](#floating-windows).

**Why not plain digits.** A repo tab is a live lazygit, and it binds nearly everything: the digits focus its panels, `[` / `]` switch panel tabs, `Tab` cycles, and every Ctrl key except `g`, `n`, `q`, `v` and `x` is taken. `Ctrl-Left` / `Ctrl-Right` belong to macOS Spaces, and tmux takes `Alt-<digit>`. `Ctrl-Opt-<digit>` is free of all of it.

The overview lists each repo with its branch, how many files are dirty (`●`), how far it is ahead or behind (`↑` / `↓`), and its last commit subject. The tabline carries the same badges, so you can see which repos need attention without leaving the tab you are in.

### LSP And Code

**The words first.** An **LSP** (language server) is a background process that actually parses your project, so it knows where things are defined and what they mean — unlike plain text search. These keys are dead until a server has attached to the file, which is why nothing happens in, say, a scratch buffer. A **diagnostic** is one error, warning or hint the server reported.

Note `gd`, `gr` and `gs` do something different inside the Git status tree (`\gs`) — those bindings are per-window, so there is no real clash.

| Shortcut    | Mode           | What it does                                       | How to use it                                                                                   |
|-------------|----------------|----------------------------------------------------|-------------------------------------------------------------------------------------------------|
| `K`         | Normal         | What is this thing? Docs and type, in a float.     | Cursor on a name. Press `K` twice to jump inside the float and scroll it.                       |
| `gd` / `gD` | Normal         | Jump to where it is defined / declared.            | `Ctrl-o` jumps back. `gD` matters mostly in C-like languages, where the two differ.             |
| `gi`        | Normal         | Jump to what actually implements it.               | For an interface or abstract method, this is the concrete code; `gd` would only reach the interface. |
| `gr`        | Normal         | Everywhere this is used, as a list.                | Check before renaming or deleting something. Pick an entry to jump there.                       |
| `gs`        | Normal         | Which argument am I typing?                        | Shows the function's parameters with the current one highlighted. Useful mid-call.               |
| `\rn`       | Normal         | Rename this everywhere at once.                    | Type the new name, press `Enter`. Renames every reference across the project, not just this file.|
| `\ca`       | Normal, Visual | Offer fixes for the problem under the cursor.      | Import the missing thing, fill in the interface, silence the warning. Pick from the list.        |
| `[d` / `]d` | Normal         | Jump to the previous / next problem in this file.  | Walk the errors instead of hunting for the squiggles.                                            |
| `\e`        | Normal         | Read the full error under the cursor.              | For messages too long to fit inline. `\ce` copies it to the clipboard.                           |
| `\q`        | Normal         | Collect every problem in the file into a list.     | Then `:cnext` / `:cprev` to work through them. Better than `]d` for a long list.                 |
| `\fm`       | Normal         | Reformat the whole file.                           | Uses whatever formatter this filetype is configured with.                                        |
| `\gf`       | Normal, Visual | Reformat via none-ls instead.                      | Use when `\fm` does nothing, i.e. the language server has no formatter of its own.               |
| `\co`       | Normal, Java   | Sort the imports and drop the unused ones.         | Java only.                                                                                       |
| `\crv`      | Normal, Java   | Pull the expression under the cursor into a variable. | Java only. Put the cursor on the expression first.                                            |
| `\crc`      | Normal, Java   | Same, but as a constant.                           | Java only.                                                                                       |
| `\crm`      | Visual, Java   | Pull the selected lines out into a new method.     | Java only. Select the lines first, then press it.                                                |

## Tmux

Source: `tmux/.tmux.conf`

Prefix key: `Ctrl-a`.

| Shortcut            | What it does                    | How to use it                               |
|---------------------|---------------------------------|---------------------------------------------|
| `Ctrl-a Ctrl-a`     | Send prefix to nested tmux.     | Useful inside nested sessions.              |
| `Ctrl-a \`          | Split pane horizontally.        | Opens split in current pane path.           |
| `Ctrl-a -`          | Split pane vertically.          | Opens split in current pane path.           |
| `Ctrl-a r`          | Reload tmux config.             | Sources `~/.tmux.conf`.                     |
| `Ctrl-a h/j/k/l`    | Resize pane left/down/up/right. | Repeatable; moves by 5 cells.               |
| `Ctrl-a m`          | Zoom/unzoom current pane.       | Toggle full-pane zoom.                      |
| `Ctrl-a [` then `v` | Begin copy selection.           | Copy mode uses vi keys.                     |
| `Ctrl-a [` then `y` | Copy selection.                 | Copies from tmux copy mode.                 |
| `Ctrl-a L`          | Clear screen and scrollback.    | In nested tmux, use `Ctrl-a Ctrl-a L`.      |
| `Ctrl-a Left/Right` | Previous / next tmux window.    | Also works with `Ctrl-a Ctrl-Left/Right`.   |
| `⌥1`-`⌥8`           | Jump to tmux window 1-8.        | No prefix. tmux takes these before nvim.    |
| `⌥9`                | Jump to the last tmux window.   | Highest-numbered window, however many.      |
| `Ctrl-a c`          | New tmux window.                | Starts in current pane path.                |
| `Ctrl-Alt-<digit>`  | Passed through to the program.  | `extended-keys` is on, so Neovim can bind combinations a plain terminal cannot encode. |
| `Ctrl-a G`          | A window per repo in a folder.  | Prompts for a root (prefilled with kompas); one window per `<root>/*/.git`, each a shell in that repo. Re-running only adds what is missing. |
| `Ctrl-a e`          | Open an hourly scratch note.    | Splits right and opens `notes_YYMMDDHH.md`. |
| `Ctrl-a o`          | Open today's todo note.         | Splits right and opens `todo_YYMMDD.md`.    |
| `Ctrl-a v`          | Open Neovim in a right split.   | Starts from current pane path.              |
| `Ctrl-a Ctrl-s`     | Save tmux session.              | From tmux-resurrect plugin.                 |
| `Ctrl-a Ctrl-r`     | Restore tmux session.           | From tmux-resurrect plugin.                 |

## Zsh Navigation

Source: `zsh/navigation.zsh`

| Command         | What it does                                       | How to use it                                                            |
|-----------------|----------------------------------------------------|--------------------------------------------------------------------------|
| `op`            | Fuzzy project navigator.                           | Pick a root/group, drill into folders, then `cd` there.                  |
| `op-add [path]` | Save a directory as an `op` root.                  | Defaults to the current directory; persists in `~/.config/zsh/op-roots`. |
| `op-rmv [path]` | Remove a saved `op` root.                          | Pass a path, or omit it to fuzzy-pick a saved root.                      |
| `itmux`         | Fuzzy tmux session picker.                         | Select an existing session or create one if none exists.                 |
| `chrome [path]` | Open a file or directory in Chrome with `file://`. | Defaults to current directory.                                           |

## Git Stuff

Source: `zsh/git-stuff.zsh`, `git/.gitconfig`

### Daily Flow

| Command         | Expands to / does                                   | How to use it                                        |
|-----------------|-----------------------------------------------------|------------------------------------------------------|
| `gs`            | `git status -sb`                                    | Compact status.                                      |
| `ga <file>`     | `git add <file>`                                    | Stage selected files.                                |
| `gaa`           | `git add .`                                         | Stage all changes under current directory.           |
| `gcm "msg"`     | `git commit -m "msg"`                               | Commit with a message.                               |
| `gca`           | `git commit --amend`                                | Amend previous commit.                               |
| `gca-now [msg]` | Amend while updating author/committer date.         | Pass a message or omit to keep the old message.      |
| `gcap`          | Fixup into a picked recent commit, then autosquash. | Stage changes first, run `gcap`, pick commit in fzf. |
| `gP`            | `git push`                                          | Push current branch.                                 |
| `gp`            | `git pull --rebase --autostash`                     | Pull cleanly while preserving local work.            |
| `gf`            | `git fetch --all --prune`                           | Fetch and prune deleted remote refs.                 |
| `git root`      | `git rev-parse --show-toplevel`                     | Print repo root.                                     |
| `cdr`           | `cd` to Git repo root.                              | Use inside any Git worktree.                         |

### Branches, Logs, Rebase

| Command        | Expands to / does                               | How to use it                  |
|----------------|-------------------------------------------------|--------------------------------|
| `gb` / `gba`   | List local / all branches.                      | Branch inspection.             |
| `gbd <branch>` | Safe delete branch.                             | Uses `git branch -d`.          |
| `gbD <branch>` | Force delete branch.                            | Uses `git branch -D`.          |
| `gc <branch>`  | Checkout branch.                                | Alias for `git checkout`.      |
| `gcb <branch>` | Create and checkout branch.                     | Alias for `git checkout -b`.   |
| `gl` / `gla`   | Pretty graph log current branch / all branches. | Includes changed file names.   |
| `gnew`         | Show remote commits not in local.               | Fetches first.                 |
| `gmine`        | Show local commits not pushed.                  | Fetches first.                 |
| `gconf`        | List conflicted files.                          | During merge/rebase conflicts. |
| `grc` / `gra`  | Rebase continue / abort.                        | Rebase recovery.               |
| `grshow`       | Show current rebase patch.                      | Inspect failed patch.          |
| `gdiff`        | Diff local branch against origin branch.        | Fetches first.                 |

### Tags, Stash, Reset

| Command            | Expands to / does                                       | How to use it                                                        |
|--------------------|---------------------------------------------------------|----------------------------------------------------------------------|
| `glast`            | Latest tag name.                                        | Sorts by tagger date.                                                |
| `gnight`           | Latest `nightly*` tag.                                  | Nightly release helper.                                              |
| `glastc`           | Commit of latest tag.                                   | Dereferences annotated tags.                                         |
| `gst` / `gstp`     | Stash / stash pop.                                      | Save and restore local work.                                         |
| `gstd` / `gstl`    | Drop stash / list stashes.                              | Stash management.                                                    |
| `gro`              | Reset current branch to `origin/current` with `--soft`. | Use `gro --hard` only when you really want to discard local changes. |
| `deploy <tag>`     | Create annotated tag and push it.                       | Tag message includes timestamp.                                      |
| `delete_tag <tag>` | Delete local and remote tag.                            | Removes remote ref then local tag.                                   |
| `redeploy <tag>`   | Delete tag, wait, recreate and push.                    | Release helper.                                                      |

## Development And AI CLI Helpers

Source: `zsh/development.zsh`

### Kubernetes And Docker

| Command                  | What it does                                              | How to use it                            |
|--------------------------|-----------------------------------------------------------|------------------------------------------|
| `k ...`                  | Run `kubectl` and print current namespace in color first. | Use like `k get pods`.                   |
| `kd ...`                 | `kubectl describe ...`                                    | Describe resources.                      |
| `kns [pattern]`          | Fuzzy-pick namespace and set it as current.               | Defaults to `KUBE_NS_PATTERN`.           |
| `kns-add <namespace>`    | Save namespace in local list.                             | Adds to `~/.kube/my-namespaces`.         |
| `kns-remove [namespace]` | Remove namespace from local list.                         | Pass name or pick with fzf.              |
| `kns-ls`                 | List saved namespaces.                                    | Shows the namespace cache.               |
| `kp ...`                 | `kubectl get pods -o wide ...`                            | List pods.                               |
| `kl ...`                 | Pick a pod and stream logs.                               | Uses fzf, tails 200 lines.               |
| `ke [shell]`             | Pick a pod and exec into it.                              | Defaults to `sh`.                        |
| `kdocker`                | Remove all Docker containers.                             | Runs `docker rm -vf $(docker ps -a -q)`. |
| `kport <port>`           | Kill processes listening on a port.                       | Uses `lsof` then `kill -9`.              |
| `kjava`                  | Kill Java processes.                                      | Runs `pkill -9 java`.                    |

### AI CLI

| Command             | What it does                                      | How to use it                        |
|---------------------|---------------------------------------------------|--------------------------------------|
| `copilot-god`       | Copilot CLI with all tools/paths allowed.         | Use for trusted workspaces.          |
| `copilot-god-r`     | Resume Copilot CLI with all tools/paths allowed.  | Continue previous session.           |
| `qcopilot "prompt"` | One-shot Copilot prompt.                          | Silent print mode.                   |
| `icopilot ...`      | Interactive Copilot helper.                       | Pass args to enter interactive mode. |
| `claude-god`        | Claude CLI skipping permissions.                  | Use for trusted workspaces.          |
| `claude-god-r`      | Resume Claude CLI skipping permissions.           | Continue previous session.           |
| `qclaude "prompt"`  | One-shot Claude prompt.                           | Uses `--print -p`.                   |
| `iclaude ...`       | Interactive Claude helper.                        | Pass args to enter interactive mode. |
| `codex-god`         | Codex CLI bypassing approvals and sandbox.        | Use for trusted workspaces.          |
| `codex-god-r`       | Resume Codex CLI bypassing approvals and sandbox. | Continue previous session.           |
| `serena-ps`         | Show Serena MCP and JDTLS processes.              | Debug orphaned language servers.     |
| `serena-kill`       | Kill orphaned Serena JDTLS processes.             | Cleanup helper.                      |

### Shell

| Command        | What it does          | How to use it           |        |
|----------------|-----------------------|-------------------------|--------|
| `x`            | Exit shell.           | Alias for `exit`.       |        |
| `hc`           | Clear shell history.  | Alias for `history -c`. |        |
| `hg <pattern>` | Search shell history. | Alias for `history      | grep`. |
| `Up` / `Down`  | Search history for what you already typed. | Matches anywhere in the command, not just the start. Source: `zsh/.zshrc`. | |

## WezTerm

Source: `wezterm/lua/keys.lua`

| Shortcut               | What it does                                     | How to use it                                                    |
|------------------------|--------------------------------------------------|------------------------------------------------------------------|
| `Option-Left`          | Send Alt-b.                                      | Move one word back in shells/editors that support readline.      |
| `Option-Right`         | Send Alt-f.                                      | Move one word forward.                                           |
| `Option-Enter`         | Send Alt-Enter.                                  | Useful for CLIs that bind Alt-Enter.                             |
| `Ctrl-Cmd-Shift-D`     | Send `\sd` to the terminal.                      | Triggers Neovim split/move-right mapping when focused in Neovim. |
| `Ctrl-Cmd-Shift-T`     | Send `\st` to the terminal.                      | Hands the focused Neovim buffer off to a right tmux pane.        |
| `Cmd-T`                | Open a new WezTerm tab at home.                  | Starts in `$HOME`.                                               |
| `Cmd-Shift-Enter`      | Split right.                                     | Creates a side-by-side WezTerm pane in the current directory.    |
| `Cmd-Option-Enter`     | Split down.                                      | Creates a stacked WezTerm pane in the current directory.         |
| `Ctrl-Cmd-Arrow`       | Focus pane in that direction.                    | Switches between WezTerm panes.                                  |
| `Ctrl-Cmd-Shift-Arrow` | Resize active pane.                              | Moves the adjacent divider by 5 cells.                           |
| `Ctrl-Cmd-R`           | Rotate panes clockwise.                          | Cycles the panes through their existing layout positions.        |
| `Ctrl-Cmd-F`           | Toggle fullscreen.                               | Same shortcut macOS uses; the green button in the tab bar zooms. |
| `Ctrl-C`               | Copy if text is selected; otherwise send Ctrl-C. | Smart terminal copy/interrupt behavior.                          |

## VSCode

Source: `vscode/keybindings.json`

Leader key in VSCode Vim bindings: `\`.

| Shortcut                       | What it does                                           | How to use it                                            |
|--------------------------------|--------------------------------------------------------|----------------------------------------------------------|
| `Cmd-1`                        | Toggle/focus Explorer.                                 | Opens Explorer, or hides sidebar if Explorer is focused. |
| `Cmd-2`                        | Toggle/focus Source Control.                           | Opens SCM, or hides sidebar if SCM is focused.           |
| `Cmd-3`                        | Open Git Graph.                                        | Requires Git Graph extension.                            |
| `Cmd-4`                        | Open Debug view.                                       | Replaces default Shift-Cmd-D debug shortcut.             |
| `Cmd-7`                        | Open Gradle view.                                      | Requires Gradle extension.                               |
| `Cmd-9`                        | Toggle integrated terminal.                            | Terminal must be active.                                 |
| `Ctrl-t`                       | Open in integrated terminal.                           | Uses `openInIntegratedTerminal`.                         |
| `Ctrl-h/j/k/l`                 | Navigate editor groups/views.                          | Vim-style focus movement.                                |
| `\e`                           | Toggle Explorer and focus it / return to editor.       | Normal mode.                                             |
| `\,`                           | Show all editors.                                      | Normal mode.                                             |
| `⌥h` / `⌥l`                    | Previous / next editor in group.                       | Works in any focus state.                                |
| `\space`                       | Quick Open.                                            | Normal mode.                                             |
| `\ff`                          | Find in files.                                         | Normal mode.                                             |
| `\f.`                          | Reveal active file in Explorer.                        | Normal mode.                                             |
| `\ca`                          | Code action.                                           | Normal mode.                                             |
| `K`                            | Hover.                                                 | Normal mode.                                             |
| `\cr`                          | Rename symbol.                                         | Normal mode.                                             |
| `\cs`                          | Go to symbol.                                          | Normal mode.                                             |
| `\gd` / `\gr` / `\gi`          | Definition / references / implementation.              | Normal mode.                                             |
| `\bd` / `\bo`                  | Close editor / close other editors.                    | Normal mode.                                             |
| `\hv`                          | Open SCM view.                                         | Normal mode.                                             |
| `\hD`                          | File history.                                          | Normal mode.                                             |
| `\hd`                          | Diff line with previous.                               | Normal mode.                                             |
| `]h` / `[h`                    | Next / previous change.                                | Normal mode.                                             |
| `Ctrl-n`                       | Add selection to next match.                           | Normal or visual mode.                                   |
| `\da` / `\dt`                  | Start debug / stop debug.                              | Normal mode.                                             |
| `\do` / `\dc`                  | Step over / continue.                                  | While stopped in debugger.                               |
| `\db`                          | Toggle breakpoint.                                     | Normal mode.                                             |
| `\de`                          | Show debug hover.                                      | While stopped in debugger.                               |
| Explorer `a/r/c/p/x/d/s/Enter` | New, rename, copy, paste, cut, delete, open side/open. | When Explorer has focus.                                 |

## IdeaVim And IntelliJ

Sources: `vim/.ideavimrc`, `intellij/Kris.xml`

### IdeaVim

| Shortcut                                 | What it does                                                              | How to use it                                  |
|------------------------------------------|---------------------------------------------------------------------------|------------------------------------------------|
| `gR`                                     | Replace symbol across whole file.                                         | Starts a confirm substitution from definition. |
| `gr`                                     | Replace symbol inside current block.                                      | Starts a confirm substitution in block.        |
| Visual `\(`, `\[`, `\q`, `\"`            | Wrap selection in parentheses, brackets, single quotes, or double quotes. | Select text first.                             |
| Visual `\p`                              | Paste without overwriting yank buffer.                                    | Keeps copied text.                             |
| Visual `J` / `K`                         | Move selected lines down / up.                                            | Visual-line selections work best.              |
| `Ctrl-h/l`                               | Move between splitters.                                                   | IntelliJ splitter navigation.                  |
| `H` / `L`                                | Previous / next tab.                                                      | Editor tab navigation.                         |
| `\ff` / `\fg` / `\ft` / `\f.`            | Go to file / symbol / find in path / select in project.                   | Search and project navigation.                 |
| `\hd` / `\hD` / `\hv`                    | Compare file / file history / commits tool window.                        | VCS workflow.                                  |
| `]h` / `[h`                              | Next / previous change marker.                                            | VCS hunk navigation.                           |
| `\wh/wl/wj/wk`                           | Resize split left/right/down/up.                                          | Split management.                              |
| `\1`, `\2`, `\3`, `\4`, `\7`, `\8`, `\9` | Project, Commit, Git, Services, Gradle, Database, Terminal.               | Tool window access.                            |

### IntelliJ Keymap Highlights

| Shortcut                | What it does                                               |
|-------------------------|------------------------------------------------------------|
| `Cmd-1/2/3/4/5/6/7/8/9` | Open common tool windows according to `intellij/Kris.xml`. |
| `Cmd-Esc`               | Hide active tool window.                                   |
| `Ctrl--` / `Ctrl-=`     | Decrease / increase font size.                             |
| `Alt-0`                 | Hide all windows.                                          |
| `Ctrl-t`                | Open in terminal.                                          |
| `Cmd-r`                 | Rename terminal session.                                   |
| `Ctrl-Alt-h/j/k/l`      | Navigate splitters.                                        |
| `Shift-Ctrl-Cmd-s/d/r`  | Window movement/session actions from the custom keymap.    |
