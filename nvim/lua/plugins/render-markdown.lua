return {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-tree/nvim-web-devicons",
    },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
        file_types = { "markdown" },
        render_modes = { "n", "c", "t" },
        anti_conceal = { enabled = true },
        debounce = 100,

        heading = {
            enabled = true,
            sign = false,
            icons = { "📌 ", "📎 ", "📍 ", "🔹 ", "🔸 ", "🔺 " },
        },

        code = {
            enabled = true,
            sign = false,
            width = "block",
            right_pad = 1,
            border = "thin",
        },

        bullet = {
            enabled = true,
            icons = { "●", "○", "◆", "◇" },
        },

        checkbox = {
            enabled = true,
            position = "inline",
            unchecked = { icon = "☐ " },
            checked = { icon = "✅ " },
        },

        table = {
            enabled = true,
            style = "full",
        },

        callout = {
            note = { raw = "[!NOTE]", rendered = "📝 Note", highlight = "RenderMarkdownInfo" },
            tip = { raw = "[!TIP]", rendered = "💡 Tip", highlight = "RenderMarkdownSuccess" },
            important = { raw = "[!IMPORTANT]", rendered = "❗ Important", highlight = "RenderMarkdownHint" },
            warning = { raw = "[!WARNING]", rendered = "⚠️ Warning", highlight = "RenderMarkdownWarn" },
            caution = { raw = "[!CAUTION]", rendered = "�� Caution", highlight = "RenderMarkdownError" },
        },

        latex = { enabled = false },
    },
    config = function(_, opts)
        require("render-markdown").setup(opts)

        vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown toggle<cr>", {
            desc = "Toggle Render Markdown",
        })
    end,
}
