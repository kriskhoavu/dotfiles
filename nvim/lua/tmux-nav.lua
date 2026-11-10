-- Ctrl-h/j/k/l move between nvim splits, and at the last split into the next
-- tmux pane. tmux/.tmux.conf has the other half.
--
-- Replaces the vim-tmux-navigator plugin, which ran tmux through system() and
-- a shell on every move to tmux, and blocked until it returned. This calls
-- tmux directly and does not wait.

local PANE = vim.env.TMUX_PANE
local TMUX_FLAG = { h = "L", j = "D", k = "U", l = "R" }

local function move(dir)
    local before = vim.api.nvim_get_current_win()
    pcall(vim.cmd.wincmd, dir) -- E11 in the command-line window
    if PANE and vim.api.nvim_get_current_win() == before then
        vim.system({ "tmux", "select-pane", "-t", PANE, "-" .. TMUX_FLAG[dir] })
    end
end

-- A terminal window takes input again as soon as it has focus.
local function navigate(dir)
    move(dir)
    vim.schedule(function()
        if vim.bo.buftype == "terminal" then
            vim.cmd("normal! G")
            vim.cmd.startinsert()
        end
    end)
end

for _, dir in ipairs({ "h", "j", "k", "l" }) do
    local key = "<C-" .. dir .. ">"
    vim.keymap.set("n", key, function() navigate(dir) end, { silent = true, desc = "Move to split or tmux pane" })
    -- Insert mode: leave insert mode first, then move.
    vim.keymap.set("i", key, function()
        vim.cmd("stopinsert")
        vim.schedule(function() navigate(dir) end)
    end, { silent = true, desc = "Move to split or tmux pane" })
    -- Terminal mode: back to normal mode first, then move.
    vim.keymap.set("t", key, function()
        vim.api.nvim_feedkeys(vim.keycode("<C-\\><C-n>"), "n", false)
        vim.schedule(function() navigate(dir) end)
    end, { silent = true, desc = "Move to split or tmux pane" })
end

-- tmux hands Ctrl-\ to nvim too: go to the last tmux pane.
vim.keymap.set("n", "<C-\\>", function()
    if PANE then vim.system({ "tmux", "select-pane", "-t", PANE, "-l" }) end
end, { silent = true, desc = "Last tmux pane" })
