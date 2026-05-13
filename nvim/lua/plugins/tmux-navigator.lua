return {
    "christoomey/vim-tmux-navigator",
    event = "VeryLazy",
    config = function()
        vim.keymap.set('n', '<C-h>', '<cmd>TmuxNavigateLeft<CR>', { silent = true })
        vim.keymap.set('n', '<C-j>', '<cmd>TmuxNavigateDown<CR>', { silent = true })
        vim.keymap.set('n', '<C-k>', '<cmd>TmuxNavigateUp<CR>', { silent = true })
        vim.keymap.set('n', '<C-l>', '<cmd>TmuxNavigateRight<CR>', { silent = true })
        -- Terminal mode navigation (escape terminal first, then navigate)
        vim.keymap.set('t', '<C-h>', '<C-\\><C-n><cmd>TmuxNavigateLeft<CR>', { silent = true })
        vim.keymap.set('t', '<C-j>', '<C-\\><C-n><cmd>TmuxNavigateDown<CR>', { silent = true })
        vim.keymap.set('t', '<C-k>', '<C-\\><C-n><cmd>TmuxNavigateUp<CR>', { silent = true })
        vim.keymap.set('t', '<C-l>', '<C-\\><C-n><cmd>TmuxNavigateRight<CR>', { silent = true })
    end
}
