return {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreview", "MarkdownPreviewToggle", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = "cd app && npm install",
    config = function()
        vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", {
            desc = "Toggle Markdown Preview (with Mermaid)",
        })
    end,
}
