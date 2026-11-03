return {
    "navarasu/onedark.nvim",
    priority = 1000,
    lazy = false,
    config = function()
        -- One Dark and One Light are the same theme; which one depends on the
        -- appearance in ~/.config/kris-theme. See lua/theme-mode.lua.
        local mode = require("theme-mode")
        local c = mode.colors

        -- Light mode draws keywords, types and parameters bold: on the pale
        -- ground their hues read thinner than in dark mode.
        local bold = mode.is_light and "bold" or "none"

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
            RenderMarkdownCode = { bg = "#cec0b0" },
            RenderMarkdownCodeInline = { bg = "#ffe0e0" },
            -- onedark draws search and the selected menu item in the ground
            -- colour (1.1:1 on bg_yellow); ink on WezTerm's selection instead.
            Search = { fg = c.ink, bg = "#d3b375" },
            Visual = { bg = "#d3a184" },
            PmenuSel = { fg = c.ink, bg = "#d3a184", bold = true },
            -- fzf-lua on the floats' ground and black border, like \9 and \3
            -- (lua/tmux-chips.lua); it linked to Normal, the editor's darker one.
            FzfLuaNormal = { fg = c.ink, bg = "#eee7df" },
            FzfLuaBorder = { fg = "#111110", bg = "#eee7df" },
            FzfLuaCursorLine = { fg = c.ink, bg = "#d3a184" },
            -- Normal is transparent, so the command line showed the terminal's
            -- own ground. Inside tmux that can be dark, under ink text.
            MsgArea = { fg = c.ink, bg = c.ramp_0 },
        } or {}
        require("onedark").setup({
            style = mode.is_light and "light" or "dark", -- dark, darker, cool, deep, warm, warmer, light
            -- Light paints its own ground (bg0 = ramp_0, WezTerm's canvas): see-through
            -- light washed out. Dark stays transparent over WezTerm.
            transparent = not mode.is_light,
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
                -- Code hues, apart from the terminal's near-black inks: those made
                -- keywords, types and strings one colour. Saturated, 5-5.5:1.
                red = "#962318", green = "#285c08", yellow = "#6c4600", blue = "#184c9c",
                purple = "#702a92", cyan = "#065a5a", orange = "#883a00",
                -- Diffs as delta draws them in lazygit (--light defaults).
                diff_add = "#d0ffd0", diff_delete = "#ffe0e0",
                diff_change = "#fff0b0", diff_text = "#ffd88a",
            } or {
                -- Tweak to better match One Dark Islands
                bright_orange = "#d19a66",
            },
            highlights = vim.tbl_extend("force", {
                -- Java annotations in orange/yellow like IntelliJ
                ["@attribute"] = { fg = c.syn_type, fmt = bold },
                ["@attribute.java"] = { fg = c.syn_type, fmt = bold },

                -- Keywords: `public`, `class`, `implements` in purple
                ["@keyword"] = { fg = c.syn_keyword, fmt = bold },
                ["@keyword.java"] = { fg = c.syn_keyword, fmt = bold },
                ["@keyword.modifier"] = { fg = c.syn_keyword, fmt = bold },
                ["@keyword.modifier.java"] = { fg = c.syn_keyword, fmt = bold },
                ["@keyword.type"] = { fg = c.syn_keyword, fmt = bold },
                ["@keyword.type.java"] = { fg = c.syn_keyword, fmt = bold },
                ["@lsp.type.keyword"] = { fg = c.syn_keyword, fmt = bold },
                ["@lsp.type.keyword.java"] = { fg = c.syn_keyword, fmt = bold },
                ["@lsp.type.modifier"] = { fg = c.syn_keyword, fmt = bold },
                ["@lsp.type.modifier.java"] = { fg = c.syn_keyword, fmt = bold },
                ["Keyword"] = { fg = c.syn_keyword, fmt = bold },
                ["Statement"] = { fg = c.syn_keyword, fmt = bold },
                ["StorageClass"] = { fg = c.syn_keyword, fmt = bold },

                -- Class/type names in a different color from keywords
                ["@type"] = { fg = c.syn_type, fmt = bold },
                ["@type.java"] = { fg = c.syn_type, fmt = bold },
                ["@lsp.type.class"] = { fg = c.syn_type, fmt = bold },
                ["@lsp.type.class.java"] = { fg = c.syn_type, fmt = bold },
                ["@lsp.type.interface"] = { fg = c.syn_type, fmt = bold },
                ["@lsp.type.interface.java"] = { fg = c.syn_type, fmt = bold },

                -- Parameters in warm brown (slightly lighter)
                ["@parameter"] = { fg = c.syn_parameter, fmt = mode.is_light and "bold,italic" or "italic" },
                ["@lsp.type.parameter"] = { fg = c.syn_parameter, fmt = mode.is_light and "bold,italic" or "italic" },
                ["@variable.parameter"] = { fg = c.syn_parameter, fmt = mode.is_light and "bold,italic" or "italic" },
                ["@lsp.type.parameter.java"] = { fg = c.syn_parameter, fmt = mode.is_light and "bold,italic" or "italic" },
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
