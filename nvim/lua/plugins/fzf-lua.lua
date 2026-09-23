-- Directories the uppercase searches never walk.
--
-- \fF and \fT drop git's ignore rules, which is the point of them -- a
-- workspace root that lists its own sub-repos in .gitignore (kompas does, so
-- that nothing commits a gitlink) otherwise hides every file in every plane
-- from an ordinary search. Dropping the rules also lets in the junk they were
-- keeping out, so this list goes back over the top: measured in kompas, 35252
-- files becomes 1864.
--
-- A name with no slash matches at any depth, so "node_modules" catches all
-- sixteen of them. Add to this list and both searches follow.
local EXCLUDE = {
	".git",
	"node_modules",
	".venv",
	"venv",
	"__pycache__",
	"dist",
	"build",
	"target",
	".gradle",
	"vendor",
	".next",
	".turbo",
	"coverage",
	".terraform",
	".mypy_cache",
	".pytest_cache",
}

local function rg_excludes()
	local out = {}
	for _, dir in ipairs(EXCLUDE) do
		out[#out + 1] = ("-g '!%s'"):format(dir)
	end
	return table.concat(out, " ")
end

local function fd_excludes()
	local out = {}
	for _, dir in ipairs(EXCLUDE) do
		out[#out + 1] = ("--exclude %s"):format(dir)
	end
	return table.concat(out, " ")
end

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

-- When launching fzf from NeoTree, switch to an editing window first
-- so the selected file opens in the right place
local function focus_edit_window()
    if vim.bo.filetype ~= "neo-tree" then return end

    local cur_win = vim.api.nvim_get_current_win()
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if w ~= cur_win then
            local cfg = vim.api.nvim_win_get_config(w)
            local buf = vim.api.nvim_win_get_buf(w)
            if cfg.relative == "" and vim.bo[buf].filetype ~= "neo-tree" then
                vim.api.nvim_set_current_win(w)
                return
            end
        end
    end
end

return {
    "ibhagwan/fzf-lua",
    keys = {
        -- Dotfiles are in this listing already -- fzf-lua's files provider
        -- defaults to hidden = true, unlike its grep, which is why <leader>fT
        -- has to ask for them. What it leaves out is what .gitignore does:
        -- <leader>fF below.
        { "<leader>ff", function() local opts = with_neotree_directory(); focus_edit_window(); require("fzf-lua").files(opts) end, desc = "Find Files" },
        {
            -- Everything on disk, ignore rules dropped and EXCLUDE put back.
            -- Reaches what .gitignore hides: secrets and .env files, and the
            -- sub-repos of a workspace that ignores them.
            "<leader>fF",
            function()
                local opts = with_neotree_directory({
                    fd_opts = "--color=never --type f --type l --hidden --no-ignore " .. fd_excludes(),
                    rg_opts = "--color=never --files --hidden --no-ignore " .. rg_excludes(),
                })
                focus_edit_window()
                require("fzf-lua").files(opts)
            end,
            desc = "Find Files everywhere (ignore rules off)",
        },
        { "<leader>ft", function() local opts = with_neotree_directory(); focus_edit_window(); require("fzf-lua").live_grep(opts) end, desc = "Live Grep" },
        { "<leader>fg", function() local opts = with_neotree_directory(); focus_edit_window(); require("fzf-lua").git_files(opts) end, desc = "Find Git Files" },
        {
            -- The uppercase twin of <leader>ft, not of <leader>fg: it was
            -- <leader>fG and read as "git files, but more", which is the one
            -- thing it is not. Same rules as <leader>fF, for contents.
            "<leader>fT",
            function()
                local opts = with_neotree_directory({
                    rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --no-ignore "
                        .. rg_excludes()
                        .. " -e",
                })
                focus_edit_window()
                require("fzf-lua").live_grep(opts)
            end,
            desc = "Live Grep everywhere (ignore rules off)",
        },
        { "<leader>fb", function() focus_edit_window(); require("fzf-lua").buffers() end, desc = "Buffers" },
        { "<leader>fh", function() focus_edit_window(); require("fzf-lua").help_tags() end, desc = "Help Tags" },
        {
            "<leader>fs",
            function()
                local opts = with_neotree_directory({ search = vim.fn.input("Grep For > ") })
                focus_edit_window()
                require("fzf-lua").grep(opts)
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
