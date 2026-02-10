return {
    "christoomey/vim-tmux-navigator",
    event = "VeryLazy",
    config = function()
        vim.keymap.set('n', '<C-h>', ':TmuxNavigateLeft<CR>')
        vim.keymap.set('n', '<C-j>', ':TmuxNavigateDown<CR>')
        vim.keymap.set('n', '<C-k>', ':TmuxNavigateUp<CR>')
        vim.keymap.set('n', '<C-l>', ':TmuxNavigateRight<CR>')
        -- Terminal mode navigation (escape terminal first, then navigate)
        vim.keymap.set('t', '<C-h>', '<C-\\><C-n>:TmuxNavigateLeft<CR>')
        vim.keymap.set('t', '<C-j>', '<C-\\><C-n>:TmuxNavigateDown<CR>')
        vim.keymap.set('t', '<C-k>', '<C-\\><C-n>:TmuxNavigateUp<CR>')
        vim.keymap.set('t', '<C-l>', '<C-\\><C-n>:TmuxNavigateRight<CR>')
    end
}
