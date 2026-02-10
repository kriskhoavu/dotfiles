return {
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        config = function()
            require("copilot").setup({
                suggestion = {
                    enabled = true,
                    auto_trigger = true,
                    keymap = {
                        accept = "<C-j>",
                        accept_word = "<C-l>",
                        accept_line = "<C-;>",
                        next = "<C-]>",
                        prev = "<M-[>",  -- Changed from <C-[> (which is Esc) to Alt-[
                        dismiss = "<C-e>",
                    },
                },
                panel = {
                    enabled = true,
                },
                filetypes = {
                    yaml = true,
                    markdown = true,
                    help = false,
                    gitcommit = true,
                    gitrebase = false,
                    ["."] = false,
                },
            })
        end,
    },
}
