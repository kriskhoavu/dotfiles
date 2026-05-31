return {
    "christoomey/vim-tmux-navigator",
    event = "VeryLazy",
    config = function()
        local function navigate(command)
            vim.cmd(command)
            vim.schedule(function()
                if vim.bo.buftype == "terminal" then
                    vim.cmd("normal! G")
                    vim.cmd.startinsert()
                end
            end)
        end

        local function terminal_navigate(command)
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
            vim.schedule(function()
                navigate(command)
            end)
        end

        vim.keymap.set('n', '<C-h>', function() navigate("TmuxNavigateLeft") end, { silent = true })
        vim.keymap.set('n', '<C-j>', function() navigate("TmuxNavigateDown") end, { silent = true })
        vim.keymap.set('n', '<C-k>', function() navigate("TmuxNavigateUp") end, { silent = true })
        vim.keymap.set('n', '<C-l>', function() navigate("TmuxNavigateRight") end, { silent = true })

        -- Terminal mode navigation: escape first, move, then resume terminal input on terminal windows.
        vim.keymap.set('t', '<C-h>', function() terminal_navigate("TmuxNavigateLeft") end, { silent = true })
        vim.keymap.set('t', '<C-j>', function() terminal_navigate("TmuxNavigateDown") end, { silent = true })
        vim.keymap.set('t', '<C-k>', function() terminal_navigate("TmuxNavigateUp") end, { silent = true })
        vim.keymap.set('t', '<C-l>', function() terminal_navigate("TmuxNavigateRight") end, { silent = true })
    end
}
