-- Clipboard utilities
-- Sourced from init.lua

-- Clipboard: use system clipboard (+) by default (macOS/modern)
vim.opt.clipboard = "unnamedplus"

-- Paste over selection without overwriting yank register
vim.keymap.set("x", "<leader>p", '"_dP', { desc = "Paste over selection (keep yank)" })

-- Delete/change into black hole register (don't overwrite clipboard)
vim.keymap.set({ "n", "v" }, "d", '"_d', { desc = "Delete (no clipboard)" })
vim.keymap.set({ "n", "v" }, "D", '"_D', { desc = "Delete to EOL (no clipboard)" })
vim.keymap.set({ "n", "v" }, "c", '"_c', { desc = "Change (no clipboard)" })
vim.keymap.set({ "n", "v" }, "C", '"_C', { desc = "Change to EOL (no clipboard)" })
vim.keymap.set({ "n", "v" }, "s", '"_s', { desc = "Substitute (no clipboard)" })
vim.keymap.set({ "n", "v" }, "S", '"_S', { desc = "Substitute line (no clipboard)" })

-- Copy current file path (absolute) to clipboard
vim.keymap.set("n", "<leader>cp", function()
  local filepath = vim.fn.expand("%:p")
  vim.fn.setreg("+", filepath)
  vim.fn.system("echo '" .. filepath .. "' | pbcopy")
  print("Copied: " .. filepath)
end, { desc = "Copy absolute path to clipboard" })

-- Paste file from clipboard (macOS Finder Cmd+C) into neo-tree's focused directory
vim.api.nvim_create_user_command("PasteFile", function()
  -- pbpaste only reads plain text; Finder copies files as «class furl», so use osascript
  local path = vim.fn.system(
    "osascript -e 'POSIX path of (the clipboard as \xc2\xabclass furl\xc2\xbb)'"
  ):gsub("%s+$", "")

  if path == "" or path:match("^execution error") then
    vim.notify("No file in clipboard. Copy a file in Finder (Cmd+C) first.", vim.log.levels.WARN)
    return
  end

  -- Resolve target directory from neo-tree focused node, fallback to cwd
  local dest_dir = vim.fn.getcwd()
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if ok then
    local state = manager.get_state("filesystem")
    if state and state.tree then
      local node = state.tree:get_node()
      if node then
        dest_dir = node.type == "directory" and node.path or vim.fn.fnamemodify(node.path, ":h")
      end
    end
  end

  vim.fn.system("cp -r '" .. path .. "' '" .. dest_dir .. "/'")
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to paste: " .. path, vim.log.levels.ERROR)
    return
  end

  local filename = vim.fn.fnamemodify(path, ":t")
  vim.notify("Pasted: " .. filename .. " → " .. dest_dir)
  require("neo-tree.sources.manager").refresh("filesystem")
end, {})
vim.keymap.set("n", "<leader>p", ":PasteFile<CR>")
