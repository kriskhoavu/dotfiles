return {
    "ibhagwan/fzf-lua",
    opts = {},
    config = function()
        local fzf = require("fzf-lua")
        fzf.setup({
            winopts = {
              width = 0.90,
              height = 0.85,
                preview = { layout = "horizontal", },
            },
            fzf_colors = { true, bg = "-1", gutter = "-1", },
            keymap = { fzf = { ["ctrl-q"] = "select-all+accept" }, },
        })
        vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Find Files" })
        vim.keymap.set("n", "<leader>ft", fzf.live_grep, { desc = "Live Grep" })
        vim.keymap.set("n", "<leader>fg", fzf.git_files, { desc = "Find Git Files" })
        vim.keymap.set("n", "<leader>fG", function()
            require("fzf-lua").live_grep({
                rg_opts = "--hidden --glob '!.git/*' --column --line-number --no-heading --color=always -e",
            })
        end, { desc = "Live Grep includes hidden files" })
        vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Buffers" })
        vim.keymap.set("n", "<leader>fh", fzf.help_tags, { desc = "Help Tags" })
        vim.keymap.set("n", "<leader>fs", function()
            fzf.grep({ search = vim.fn.input("Grep For > ") })
        end, { desc = "FZF grep with input" })
    end,
}