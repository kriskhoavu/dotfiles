-- Directories the uppercase searches never walk.
--
-- \fF and \fT drop git's ignore rules, so a workspace that gitignores its own
-- sub-repos stops hiding them. That also lets the junk back in, so this list
-- goes over the top: in fen, 35252 files becomes 1864.
--
-- No slash means any depth. Add here and both searches follow.
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
        -- Dotfiles are already here: the files provider defaults to
        -- hidden = true, unlike grep. What it misses is what .gitignore
        -- hides -- that is \fF.
        { "<leader>ff", function() local opts = with_neotree_directory(); focus_edit_window(); require("fzf-lua").files(opts) end, desc = "Find Files" },
        {
            -- Everything on disk: ignore rules dropped, EXCLUDE put back.
            -- Reaches .env files and gitignored sub-repos.
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
            -- The uppercase twin of \ft, not \fg -- it was \fG, which read
            -- as "git files, but more". Same rules as \fF, for contents.
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
                on_create = function(e)
                    -- Never fall back to the current buffer. fzf-lua calls this
                    -- from two places and fzf_bufnr is nil on one of them, so a
                    -- fallback brands whatever file is open with the picker's
                    -- buffer-local keys -- permanently, long after it closes.
                    local buf = e and e.bufnr
                    if not buf or not vim.api.nvim_buf_is_valid(buf) then
                        return
                    end
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
                    -- Ctrl-l steps into the preview, a real window. Ctrl-h
                    -- steps back, bound on the preview buffer too, or it is
                    -- vim-tmux-navigator's there and focus leaves for good.
                    --
                    -- Esc, answered by fzf itself. fzf-lua binds esc as an
                    -- execute-silent that spawns a fresh nvim to call back
                    -- here; when any link fails the key does nothing at all
                    -- and the picker cannot be closed (seen twice in a
                    -- session, one alive 2h18m). Ctrl-C is print+accept, which
                    -- fzf answers alone -- so send that byte down the channel.
                    local function abort()
                        local chan = vim.bo[buf].channel
                        if chan and chan > 0 then
                            vim.api.nvim_chan_send(chan, string.char(3))
                        end
                    end
                    vim.keymap.set("t", "<Esc>", abort, {
                        buffer = buf,
                        silent = true,
                        desc = "Close the picker",
                    })

                    -- Ctrl-hjkl and Esc belong to the picker while one is open.
                    --
                    -- Installed once, globally, and never taken back: fzf-lua
                    -- rebuilds the buffer and the window behind the preview as
                    -- the selection moves, so a mapping that chases those always
                    -- loses an entry somewhere and the key is vim-tmux-
                    -- navigator's again -- focus leaves for the buffer beneath.
                    --
                    -- Borrowing and restoring them per picker was worse: maparg
                    -- answers with the buffer-local mapping when there is one,
                    -- so what came back was the picker's own Tmux keys, re-bound
                    -- onto whatever file happened to be current at close.
                    --
                    -- With no picker open each key falls through to whatever it
                    -- meant before, captured here at install time.
                    if not _G.__fzf_modal_keys then
                        _G.__fzf_modal_keys = true

                        local function live()
                            local ok, win = pcall(function()
                                return require("fzf-lua.win").__SELF()
                            end)
                            return ok and win or nil
                        end

                        -- Resolved per call, not captured: these outlive every
                        -- individual picker.
                        local function to_fzf(byte)
                            local win = live()
                            local chan = win and win.fzf_bufnr and vim.bo[win.fzf_bufnr].channel
                            if chan and chan > 0 then
                                vim.api.nvim_chan_send(chan, string.char(byte))
                            end
                        end

                        local function focus_list()
                            local win = live()
                            if win and win.fzf_winid and vim.api.nvim_win_is_valid(win.fzf_winid) then
                                vim.api.nvim_set_current_win(win.fzf_winid)
                                vim.cmd.startinsert()
                            end
                        end

                        -- 0x0e and 0x10 are Ctrl-n and Ctrl-p, fzf's own down
                        -- and up, so the list can be stepped from the preview.
                        local inside = {
                            ["<C-h>"] = focus_list,
                            ["<C-j>"] = function() to_fzf(0x0e) end,
                            ["<C-k>"] = function() to_fzf(0x10) end,
                            ["<C-l>"] = function() end,
                            ["<Esc>"] = function()
                                focus_list()
                                to_fzf(0x03)
                            end,
                        }

                        -- The global table, not maparg: maparg would answer with
                        -- the picker's buffer-local mapping.
                        local function previous(lhs)
                            local want = vim.api.nvim_replace_termcodes(lhs, true, true, true)
                            for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
                                if vim.api.nvim_replace_termcodes(m.lhs, true, true, true) == want then
                                    return m
                                end
                            end
                        end

                        for key, fn in pairs(inside) do
                            local prev = previous(key)
                            vim.keymap.set("n", key, function()
                                if live() then
                                    fn()
                                elseif prev and prev.callback then
                                    prev.callback()
                                elseif prev and prev.rhs then
                                    vim.api.nvim_feedkeys(
                                        vim.api.nvim_replace_termcodes(prev.rhs, true, true, true),
                                        prev.noremap == 1 and "n" or "m",
                                        false
                                    )
                                end
                            end, { silent = true, desc = "Stay inside the fzf picker" })
                        end
                    end

                    vim.keymap.set("t", "<C-l>", function()
                        local ok, win = pcall(function()
                            return require("fzf-lua.win").__SELF()
                        end)
                        if ok and win and win.preview_winid and vim.api.nvim_win_is_valid(win.preview_winid) then
                            vim.api.nvim_set_current_win(win.preview_winid)
                        end
                    end, { buffer = buf, silent = true, desc = "Focus the preview" })
                end,
            },
            fzf_colors = { true, bg = "-1", gutter = "-1" },
            keymap = { fzf = { ["ctrl-q"] = "select-all+accept" } },
        })
    end,
}
