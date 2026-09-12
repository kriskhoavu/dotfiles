return {
    "navarasu/onedark.nvim",
    priority = 1000,
    lazy = false,
    config = function()
        -- One Dark and One Light are the same theme; which one depends on what
        -- the terminal answered for OSC 11. See lua/theme-mode.lua.
        local mode = require("theme-mode")
        local c = mode.colors

        -- Neo-tree chrome the palette cannot reach: the title bar sets only a
        -- background, so it inherits whatever foreground happens to be current,
        -- and the tab chips and their separators carry near-black literals from
        -- the plugin itself. Light only -- dark already reads correctly with
        -- onedark's own values, and these are exactly the groups that would
        -- change it.
        local neotree_chrome = mode.is_light and {
            NeoTreeTitleBar = { fg = c.ink, bg = c.ramp_4 },
            NeoTreeTabActive = { fg = c.ink, bg = c.ramp_0, bold = true },
            NeoTreeTabInactive = { fg = c.muted, bg = c.ramp_2 },
            NeoTreeTabSeparatorActive = { fg = c.ramp_0, bg = c.ramp_0 },
            NeoTreeTabSeparatorInactive = { fg = c.ramp_2, bg = c.ramp_2 },
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
            -- `transparent` only clears Normal. Every surface onedark actually
            -- paints -- the statusline, the tab line, Pmenu, Neo-tree's title
            -- bar and float chrome -- keeps coming from its own palette, and
            -- One Light's greys are near-white (#fafafa, #f0f0f0, #e6e6e6) with
            -- a cool cast. Against the parchment ground those read as white
            -- panels sitting on tan. So the light palette's neutrals are
            -- replaced with the same ramp tmux and WezTerm use, and every group
            -- derived from them follows.
            colors = mode.is_light and {
                bg0 = c.ramp_0,
                bg1 = c.ramp_1,
                bg2 = c.ramp_2,
                bg3 = c.ramp_3,
                bg_d = c.ramp_4,
                fg = c.ink,
                -- Darkened from the ramp: onedark's own grey is a muted 2.5:1
                -- on its near-white ground, and the same step on parchment left
                -- comments too faint to read.
                grey = c.muted,
                light_grey = c.muted_ui,
                bright_orange = "#c18401",
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
    end,
}
