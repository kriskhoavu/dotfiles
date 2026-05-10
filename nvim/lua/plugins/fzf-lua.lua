local function neotree_directory()
    if vim.bo.filetype ~= "neo-tree" then
        return nil
    end

    local ok_source, source = pcall(vim.api.nvim_buf_get_var, 0, "neo_tree_source")
    if not ok_source or source ~= "filesystem" then
        return nil
    end

    local ok_manager, manager = pcall(require, "neo-tree.sources.manager")
    if not ok_manager then
        return nil
    end

    local winid = nil
    local ok_position, position = pcall(vim.api.nvim_buf_get_var, 0, "neo_tree_position")
    if ok_position and position == "current" then
        winid = vim.api.nvim_get_current_win()
    end

    local state = manager.get_state(source, nil, winid)
    local node = state and state.tree and state.tree:get_node() or nil
    if not node or node.type ~= "directory" then
        return nil
    end

    return node.path
end

local function with_neotree_directory(opts)
    local directory = neotree_directory()
    if not directory then
        return opts or {}
    end

    return vim.tbl_extend("force", opts or {}, { cwd = directory })
end

return {
    "ibhagwan/fzf-lua",
    keys = {
        { "<leader>ff", function() require("fzf-lua").files(with_neotree_directory()) end, desc = "Find Files" },
        { "<leader>ft", function() require("fzf-lua").live_grep(with_neotree_directory()) end, desc = "Live Grep" },
        { "<leader>fg", function() require("fzf-lua").git_files() end, desc = "Find Git Files" },
        {
            "<leader>fG",
            function()
                require("fzf-lua").live_grep(with_neotree_directory({
                    rg_opts = "--hidden --glob '!.git/*' --column --line-number --no-heading --color=always -e",
                }))
            end,
            desc = "Live Grep includes hidden files",
        },
        { "<leader>fb", function() require("fzf-lua").buffers() end, desc = "Buffers" },
        { "<leader>fh", function() require("fzf-lua").help_tags() end, desc = "Help Tags" },
        {
            "<leader>fs",
            function()
                require("fzf-lua").grep(with_neotree_directory({ search = vim.fn.input("Grep For > ") }))
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
