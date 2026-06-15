vim.opt.updatetime = 300   -- Faster CursorHold, gitsigns, and swap writes
vim.opt.timeoutlen = 300   -- Faster key sequence completion (leader mappings)

vim.opt.expandtab = true -- Insert spaces instead of tabs
vim.opt.tabstop = 4      -- A <Tab> counts for 4 spaces (display width)
vim.opt.shiftwidth = 4   -- Indent size for >>, <<, autoindent
vim.opt.softtabstop = 4  -- <Tab>/<BS> in insert uses 4 spaces
vim.opt.scrolloff = 5
vim.opt.sidescrolloff = 5
-- vim.g.mapleader = " "  -- Leader key (uncomment if you want <Space> as leader)

vim.opt.number = true         -- Show absolute line numbers
vim.opt.cursorline = true     -- Highlight the current line
vim.opt.relativenumber = true -- Show relative line numbers (great for j/k motions)

vim.opt.hlsearch = true       -- Highlight search matches
vim.opt.incsearch = true      -- Show matches while typing the search

vim.opt.wrap = true           -- Wrap long lines
vim.opt.linebreak = true      -- Wrap at word boundaries (nicer wrapping)

-- Highlights
vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "white" })   -- Line numbers above cursor
vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#ead84e" }) -- Line numbers below cursor

-- Keymaps (general, non-plugin)
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selected lines up" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selected lines down" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr><Esc>", { silent = true, desc = "Clear search highlight" })

-- Terminal mode: single Esc exits to normal mode, Ctrl-] sends Esc to the terminal app
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("t", "<C-]>", function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { desc = "Send Esc to terminal app" })

-- Hide statusline for terminal buffers
vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter", "WinEnter" }, {
  callback = function()
    if vim.bo.buftype == "terminal" then
      vim.wo.statusline = " "
      vim.wo.winbar = ""
    end
  end,
})
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "terminal" then
          vim.wo[win].statusline = " "
          vim.wo[win].winbar = ""
        end
      end
    end, 10)
  end,
})

local function current_path_from_buffer_or_neotree()
    if vim.bo.filetype == "neo-tree" then
        local state = require("neo-tree.sources.manager").get_state("filesystem")
        local node = state.tree:get_node()
        if node and (node.type == "file" or node.type == "directory") then
            return node:get_id()
        end
        return nil
    end

    local file_path = vim.fn.expand("%:p")
    if file_path == "" then
        return nil
    end
    return file_path
end

-- Open current file in browser
vim.keymap.set("n", "<leader>ob", function()
    local file_path = current_path_from_buffer_or_neotree()
    if not file_path then
        print("No file to open")
        return
    end

    if vim.fn.has("mac") == 1 then
        os.execute("open -a 'Google Chrome' " .. vim.fn.shellescape(file_path) .. " &")
    end
end, { desc = "Open current file in browser (supports NeoTree)" })

-- Open current file in Finder
vim.keymap.set("n", "<leader>of", function()
    local file_path = current_path_from_buffer_or_neotree()
    if not file_path then
        print("No file to open")
        return
    end

    if vim.fn.has("mac") == 1 then
        if vim.fn.isdirectory(file_path) == 1 then
            os.execute("open " .. vim.fn.shellescape(file_path) .. " &")
        else
            os.execute("open -R " .. vim.fn.shellescape(file_path) .. " &")
        end
    end
end, { desc = "Open current file in Finder (supports NeoTree)" })

-- Resize mode (window resizing with hjkl)
vim.keymap.set("n", "<leader>wr", function()
    local ns = vim.api.nvim_create_namespace("resize_mode")

    -- Check if already in resize mode, if so turn off
    if vim.g.resize_mode_active then
        vim.on_key(nil, ns)
        vim.g.resize_mode_active = false
        vim.notify("Resize mode: off")
        return
    end

    vim.g.resize_mode_active = true
    vim.notify("Resize mode: h/j/k/l | <leader>wr or Esc to quit")

    vim.on_key(function(key)
        if key == "h" then
            vim.cmd("vertical resize -5")
        elseif key == "l" then
            vim.cmd("vertical resize +5")
        elseif key == "j" then
            vim.cmd("resize -5")
        elseif key == "k" then
            vim.cmd("resize +5")
        elseif key == "\027" then -- Esc
            vim.on_key(nil, ns)
            vim.g.resize_mode_active = false
            vim.notify("Resize mode: off")
        end
    end, ns)
end, { desc = "Toggle resize mode (hjkl to resize)" })

-- VSCode-like keybindings
-- Cmd+Shift+d: Move current buffer to right split (like VSCode moveEditorToNextGroup/IntelliJ Move to Opposite Group)
vim.keymap.set("n", "<leader>sd", function()
    if vim.bo.filetype == "neo-tree" then return end
    local current_buf = vim.api.nvim_get_current_buf()
    -- Find editing windows (exclude neo-tree, floating)
    local edit_wins = {}
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local cfg = vim.api.nvim_win_get_config(w)
      local wbuf = vim.api.nvim_win_get_buf(w)
      if cfg.relative == "" and vim.bo[wbuf].filetype ~= "neo-tree" then
        table.insert(edit_wins, w)
      end
    end
    local current_win = vim.api.nvim_get_current_win()
    if #edit_wins <= 1 then
      -- Only one split: create a new right split
      vim.cmd("vsplit")
      vim.cmd("wincmd h")
      vim.cmd("bprevious")
      vim.cmd("wincmd l")
    else
      -- Multiple splits: move buffer to the rightmost editing window
      local right_win = edit_wins[#edit_wins]
      if current_win == right_win then return end
      vim.api.nvim_win_set_buf(right_win, current_buf)
      vim.cmd("bprevious")
      vim.api.nvim_set_current_win(right_win)
    end
end, { desc = "Move buffer to right split" })
