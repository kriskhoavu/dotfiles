-- Directories the uppercase searches never walk.
--
-- \fF and \fT drop git's ignore rules, which is the point of them -- a
-- workspace root that lists its own sub-repos in .gitignore (fen does, so
-- that nothing commits a gitlink) otherwise hides every file in every plane
-- from an ordinary search. Dropping the rules also lets in the junk they were
-- keeping out, so this list goes back over the top: measured in fen, 35252
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
                -- Keep focus in the picker, like every other float here.
                --
                -- fzf-lua builds its own window rather than going through
                -- floating-helpers, so it never got the modal guard: Ctrl-hjkl
                -- is bound globally by vim-tmux-navigator in terminal mode too,
                -- and the picker is a terminal, so those keys threw focus to a
                -- window behind the popup and left it hanging there.
                --
                -- The four are then handed back to fzf in terminal mode, where
                -- Ctrl-j and Ctrl-k are its own list movement. make_modal sends
                -- them to tmux, which is right for a float you read and wrong
                -- for one you are typing into.
                on_create = function(e)
                    local buf = e and e.bufnr or vim.api.nvim_get_current_buf()
                    require("floating-helpers").make_modal(buf, "the fzf picker")
                    -- Ctrl-j and Ctrl-k are fzf's own list movement, and Ctrl-h
                    -- has nothing to do here, so all three go to fzf.
                    for _, key in ipairs({ "<C-h>", "<C-j>", "<C-k>" }) do
                        vim.keymap.set("t", key, key, {
                            buffer = buf,
                            silent = true,
                            desc = "Send " .. key .. " to fzf",
                        })
                    end
                    -- Ctrl-l steps into the preview, which is a real window and
                    -- can be read and scrolled like one. Ctrl-h steps back, and
                    -- is bound on the preview buffer at the same time: over
                    -- there it would otherwise be vim-tmux-navigator's and
                    -- would throw focus out of the picker for good.
                    vim.keymap.set("t", "<C-l>", function()
                        local win = require("fzf-lua.win").__SELF()
                        if not win or not win.preview_winid or not vim.api.nvim_win_is_valid(win.preview_winid) then
                            return
                        end
                        local fzf_winid = win.fzf_winid
                        local preview_buf = vim.api.nvim_win_get_buf(win.preview_winid)
                        vim.keymap.set("n", "<C-h>", function()
                            if vim.api.nvim_win_is_valid(fzf_winid) then
                                vim.api.nvim_set_current_win(fzf_winid)
                                vim.cmd.startinsert()
                            end
                        end, { buffer = preview_buf, silent = true, desc = "Back to the fzf list" })
                        -- Esc closes the picker from here too. It is fzf's own
                        -- abort, handed to it down the terminal channel, rather
                        -- than a window being closed behind its back -- the
                        -- preview belongs to a running fzf, and killing the
                        -- window without telling it leaves the process behind.
                        vim.keymap.set("n", "<Esc>", function()
                            if not vim.api.nvim_win_is_valid(fzf_winid) then
                                return
                            end
                            vim.api.nvim_set_current_win(fzf_winid)
                            local chan = vim.bo[vim.api.nvim_win_get_buf(fzf_winid)].channel
                            if chan and chan > 0 then
                                vim.api.nvim_chan_send(chan, "\27")
                            end
                        end, { buffer = preview_buf, silent = true, desc = "Close the picker" })
                        vim.api.nvim_set_current_win(win.preview_winid)
                    end, { buffer = buf, silent = true, desc = "Focus the preview" })
                end,
            },
            fzf_colors = { true, bg = "-1", gutter = "-1" },
            keymap = { fzf = { ["ctrl-q"] = "select-all+accept" } },
        })
    end,
}
