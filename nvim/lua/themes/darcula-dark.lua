return {
    "xiantang/darcula-dark.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    lazy = true,
    priority = 1000,
    config = function()
        require("darcula").setup({
            opt = {
                integrations = {
                    telescope = true,
                    lualine = true,
                    lsp_semantics_token = true,
                    nvim_cmp = true,
                    dap_nvim = true,
                },
            },
        })
    end
}
-- colorscheme dracula
-- colorscheme darcula-dark
-- colorscheme darcula-solid