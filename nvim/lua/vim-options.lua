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

-- Terminal mode: Escape exits to normal mode
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Open current file in browser
vim.keymap.set("n", "<leader>ob", function()
    local file_path = vim.fn.expand("%:p")
    if file_path ~= "" then
        if vim.fn.has("mac") == 1 then
            os.execute("open -a 'Google Chrome' " .. file_path .. " &")
        end
    else
        print("No file to open")
    end
end, { desc = "Open current file in browser" })

-- Notification filter (silence noisy LSP warnings)
local notify_original = vim.notify
vim.notify = function(msg, ...)
    if
        msg
        and (
            msg:match("position_encoding param is required")
            or msg:match("Defaulting to position encoding of the first client")
            or msg:match("multiple different client offset_encodings")
        )
    then
        return
    end
    return notify_original(msg, ...)
end

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
    vim.cmd("vsplit")  -- create vertical split (cursor in new right pane)
    vim.cmd("wincmd h") -- go back to left pane
    vim.cmd("bprevious") -- switch left pane to previous buffer
    vim.cmd("wincmd l") -- return to right pane with original buffer
end, { desc = "Move buffer to right split" })
