return {
    "navarasu/onedark.nvim",
    priority = 1000,
    lazy = false,
    config = function()
        -- One Dark and One Light are the same theme; which one depends on the
        -- appearance in ~/.config/kris-theme. See lua/theme-mode.lua.
        local mode = require("theme-mode")
        local c = mode.colors

        -- Neo-tree chrome the palette cannot reach: the title bar sets only a
        -- background, and the tab chips carry near-black literals from the
        -- plugin. Light only; dark already reads correctly.
        local neotree_chrome = mode.is_light and {
            NeoTreeTitleBar = { fg = c.ink, bg = c.ramp_4 },
            NeoTreeTabActive = { fg = c.ink, bg = c.ramp_0, bold = true },
            NeoTreeTabInactive = { fg = c.muted, bg = c.ramp_2 },
            NeoTreeTabSeparatorActive = { fg = c.ramp_0, bg = c.ramp_0 },
            NeoTreeTabSeparatorInactive = { fg = c.ramp_2, bg = c.ramp_2 },

            -- Markdown in delta's light pastels, as lazygit shows diffs: pink and
            -- green from delta, the other levels in the same family.
            RenderMarkdownH1Bg = { bg = "#ffc0c0" },
            RenderMarkdownH2Bg = { bg = "#d0ffd0" },
            RenderMarkdownH3Bg = { bg = "#fff0b0" },
            RenderMarkdownH4Bg = { bg = "#d0e4ff" },
            RenderMarkdownH5Bg = { bg = "#ead4ff" },
            RenderMarkdownH6Bg = { bg = "#c8f0ec" },
            RenderMarkdownCode = { bg = "#d3c5b4" },
            RenderMarkdownCodeInline = { bg = "#ffe0e0" },
            -- onedark draws search and the selected menu item in the ground
            -- colour (1.1:1 on bg_yellow); ink on WezTerm's selection instead.
            Search = { fg = c.ink, bg = "#d3b375" },
            Visual = { bg = "#d3a184" },
            PmenuSel = { fg = c.ink, bg = "#d3a184", bold = true },
            -- Normal is transparent, so the command line showed the terminal's
            -- own ground. Inside tmux that can be dark, under ink text.
            MsgArea = { fg = c.ink, bg = c.ramp_0 },
        } or {}
        require("onedark").setup({
            style = mode.is_light and "light" or "dark", -- dark, darker, cool, deep, warm, warmer, light
            transparent = true,
            code_style = {
                comments = "italic",
                keywords = "none",
                functions = "none",
                strings = "none",
                variables = "none",
            },
            -- `transparent` clears Normal only; every surface onedark paints
            -- still comes from its own palette. One Light's greys are cool
            -- near-whites and read as grey panels on this warm ground, so the
            -- light neutrals are swapped for WezTerm's ramp.
            colors = mode.is_light and {
                bg0 = c.ramp_0,
                bg1 = c.ramp_1,
                bg2 = c.ramp_2,
                bg3 = c.ramp_3,
                bg_d = c.ramp_4,
                fg = c.ink,
                -- onedark's own grey is 2.5:1 on its near-white ground, no
                -- easier to read on this one. c.muted is 5:1.
                grey = c.muted,
                light_grey = c.muted_ui,
                -- Claude's orange, deep enough to be text rather than a wash.
                bright_orange = "#66291a",
                -- One Light's hues are 2.2-2.9:1 here; WezTerm's inks are 5:1+.
                red = c.ansi[2], green = c.ansi[3], yellow = c.ansi[4], blue = c.ansi[5],
                purple = c.ansi[6], cyan = c.ansi[7], orange = c.brights[4],
                -- Diffs as delta draws them in lazygit (--light defaults).
                diff_add = "#d0ffd0", diff_delete = "#ffe0e0",
                diff_change = "#fff0b0", diff_text = "#ffd88a",
            } or {
                -- Tweak to better match One Dark Islands
                bright_orange = "#d19a66",
            },
            highlights = vim.tbl_extend("force", {
                -- Java annotations in orange/yellow like IntelliJ
                ["@attribute"] = { fg = c.syn_type },
                ["@attribute.java"] = { fg = c.syn_type },

                -- Keywords: `public`, `class`, `implements` in purple
                ["@keyword"] = { fg = c.syn_keyword },
                ["@keyword.java"] = { fg = c.syn_keyword },
                ["@keyword.modifier"] = { fg = c.syn_keyword },
                ["@keyword.modifier.java"] = { fg = c.syn_keyword },
                ["@keyword.type"] = { fg = c.syn_keyword },
                ["@keyword.type.java"] = { fg = c.syn_keyword },
                ["@lsp.type.keyword"] = { fg = c.syn_keyword },
                ["@lsp.type.keyword.java"] = { fg = c.syn_keyword },
                ["@lsp.type.modifier"] = { fg = c.syn_keyword },
                ["@lsp.type.modifier.java"] = { fg = c.syn_keyword },
                ["Keyword"] = { fg = c.syn_keyword },
                ["Statement"] = { fg = c.syn_keyword },
                ["StorageClass"] = { fg = c.syn_keyword },

                -- Class/type names in a different color from keywords
                ["@type"] = { fg = c.syn_type },
                ["@type.java"] = { fg = c.syn_type },
                ["@lsp.type.class"] = { fg = c.syn_type },
                ["@lsp.type.class.java"] = { fg = c.syn_type },
                ["@lsp.type.interface"] = { fg = c.syn_type },
                ["@lsp.type.interface.java"] = { fg = c.syn_type },

                -- Parameters in warm brown (slightly lighter)
                ["@parameter"] = { fg = c.syn_parameter, italic = true },
                ["@lsp.type.parameter"] = { fg = c.syn_parameter, italic = true },
                ["@variable.parameter"] = { fg = c.syn_parameter, italic = true },
                ["@lsp.type.parameter.java"] = { fg = c.syn_parameter, italic = true },
            }, neotree_chrome),
        })

        -- :terminal (lazygit, shells) gets WezTerm's light palette, so a TUI
        -- looks the same inside nvim as outside. After onedark sets its own.
        if mode.is_light then
            vim.api.nvim_create_autocmd("ColorScheme", {
                pattern = "onedark",
                callback = function()
                    for i = 1, 8 do
                        vim.g["terminal_color_" .. (i - 1)] = c.ansi[i]
                        vim.g["terminal_color_" .. (i + 7)] = c.brights[i]
                    end
                end,
            })
        end
    end,
}
