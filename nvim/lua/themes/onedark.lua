return {
    "navarasu/onedark.nvim",
    priority = 1000,
    lazy = false,
    config = function()
        require("onedark").setup({
            style = "dark", -- dark, darker, cool, deep, warm, warmer
            transparent = true,
            code_style = {
                comments = "italic",
                keywords = "none",
                functions = "none",
                strings = "none",
                variables = "none",
            },
            colors = {
                -- Tweak to better match One Dark Islands
                bright_orange = "#d19a66",
            },
            highlights = {
                -- Java annotations in orange/yellow like IntelliJ
                ["@attribute"] = { fg = "#e5c07b" },
                ["@attribute.java"] = { fg = "#e5c07b" },

                -- Keywords: `public`, `class`, `implements` in purple
                ["@keyword"] = { fg = "#c678dd" },
                ["@keyword.java"] = { fg = "#c678dd" },
                ["@keyword.modifier"] = { fg = "#c678dd" },
                ["@keyword.modifier.java"] = { fg = "#c678dd" },
                ["@keyword.type"] = { fg = "#c678dd" },
                ["@keyword.type.java"] = { fg = "#c678dd" },
                ["@lsp.type.keyword"] = { fg = "#c678dd" },
                ["@lsp.type.keyword.java"] = { fg = "#c678dd" },
                ["@lsp.type.modifier"] = { fg = "#c678dd" },
                ["@lsp.type.modifier.java"] = { fg = "#c678dd" },
                ["Keyword"] = { fg = "#c678dd" },
                ["Statement"] = { fg = "#c678dd" },
                ["StorageClass"] = { fg = "#c678dd" },

                -- Class/type names in a different color from keywords
                ["@type"] = { fg = "#e5c07b" },
                ["@type.java"] = { fg = "#e5c07b" },
                ["@lsp.type.class"] = { fg = "#e5c07b" },
                ["@lsp.type.class.java"] = { fg = "#e5c07b" },
                ["@lsp.type.interface"] = { fg = "#e5c07b" },
                ["@lsp.type.interface.java"] = { fg = "#e5c07b" },

                -- Parameters in warm brown (slightly lighter)
                ["@parameter"] = { fg = "#d19e6b", italic = true },
                ["@lsp.type.parameter"] = { fg = "#d19e6b", italic = true },
                ["@variable.parameter"] = { fg = "#d19e6b", italic = true },
                ["@lsp.type.parameter.java"] = { fg = "#d19e6b", italic = true },
            },
        })
    end,
}
