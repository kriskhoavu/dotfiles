return {
    "ibhagwan/fzf-lua",
    keys = {
        { "<leader>ff", function() require("fzf-lua").files() end, desc = "Find Files" },
        { "<leader>ft", function() require("fzf-lua").live_grep() end, desc = "Live Grep" },
        { "<leader>fg", function() require("fzf-lua").git_files() end, desc = "Find Git Files" },
        {
            "<leader>fG",
            function()
                require("fzf-lua").live_grep({
                    rg_opts = "--hidden --glob '!.git/*' --column --line-number --no-heading --color=always -e",
                })
            end,
            desc = "Live Grep includes hidden files",
        },
        { "<leader>fb", function() require("fzf-lua").buffers() end, desc = "Buffers" },
        { "<leader>fh", function() require("fzf-lua").help_tags() end, desc = "Help Tags" },
        {
            "<leader>fs",
            function()
                require("fzf-lua").grep({ search = vim.fn.input("Grep For > ") })
            end,
            desc = "FZF grep with input",
        },
    },
    config = function()
        require("fzf-lua").setup({
            winopts = {
                width = 0.90,
                height = 0.85,
                preview = { layout = "horizontal" },
            },
            fzf_colors = { true, bg = "-1", gutter = "-1" },
            keymap = { fzf = { ["ctrl-q"] = "select-all+accept" } },
        })
    end,
}
