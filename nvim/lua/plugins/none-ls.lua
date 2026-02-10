return {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    config = function()
        require("conform").setup({
            formatters_by_ft = {
                lua = { "stylua" },
                javascript = { "prettier" },
                typescript = { "prettier" },
                javascriptreact = { "prettier" },
                typescriptreact = { "prettier" },
                json = { "prettier" },
                yaml = { "prettier" },
                html = { "prettier" },
                css = { "prettier" },
                markdown = { "prettier" },
                java = { "google-java-format" },
            },
            -- format_on_save = { timeout_ms = 500, lsp_fallback = true }, -- uncomment to auto-format on save
        })
        vim.keymap.set({ "n", "v" }, "<leader>gf", function()
            require("conform").format({ async = true, lsp_fallback = true })
        end, { desc = "Format file or range" })
    end,
}
