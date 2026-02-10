return {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    config = function()
        require("catppuccin").setup({
            flavour = "mocha", -- latte, frappe, macchiato, mocha
            transparent_background = true,
            custom_highlights = function(colors)
                return {
                    ["@parameter"] = { fg = colors.sky, italic = true },
                    ["@lsp.type.parameter"] = { fg = colors.sky, italic = true },
                }
            end,
            integrations = {
                native_lsp = {
                    enabled = true
                },
                fzf = true,
                cmp = true,
                mason = true,
                neotree = true,
                gitsigns = true,
                diffview = true,
                which_key = true,
                treesitter = true,
                bufferline = true,
                telescope = { enabled = true }
            }
        })
    end
}
-- colorscheme catppuccin
-- colorscheme catppuccin-mocha
-- colorscheme catppuccin-latte
-- colorscheme catppuccin-frappe
-- colorscheme catppuccin-macchiato
