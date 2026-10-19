-- Directories the uppercase searches (\fF, \fT) never walk. Those drop git's
-- ignore rules so gitignored sub-repos show, which lets the junk back in; this
-- list takes it out again (fen: 35252 files -> 1864). No slash = any depth.
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

-- From NeoTree, focus an editing window first so the pick opens there.
local function focus_edit_window()
    if vim.bo.filetype ~= "neo-tree" then return end

    local w = require("edit-windows").list()[1]
    if w then vim.api.nvim_set_current_win(w) end
end

return {
    "ibhagwan/fzf-lua",
    keys = {
        -- Hidden files are already in (files defaults to hidden = true); what
        -- .gitignore hides is \fF.
        { "<leader>ff", function() local opts = with_neotree_directory(); focus_edit_window(); require("fzf-lua").files(opts) end, desc = "Find Files" },
        {
            -- Ignore rules off, EXCLUDE back on: reaches .env and gitignored sub-repos.
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
            -- \fF's rules applied to contents: the uppercase twin of \ft.
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
                    -- Never fall back to the current buffer: fzf_bufnr is nil on one of two
                    -- call paths, and the fallback would brand the open file with picker keys.
                    local buf = e and e.bufnr
                    if not buf or not vim.api.nvim_buf_is_valid(buf) then
                        return
                    end
                    require("floating-helpers").make_modal(buf, "the fzf picker")
                    -- Ctrl-j/k are fzf's list movement; Ctrl-h has no use here. All go to fzf.
                    for _, key in ipairs({ "<C-h>", "<C-j>", "<C-k>" }) do
                        vim.keymap.set("t", key, key, {
                            buffer = buf,
                            silent = true,
                            desc = "Send " .. key .. " to fzf",
                        })
                    end
                    -- Esc sends Ctrl-C, which fzf answers alone. fzf-lua's own esc spawns a
                    -- fresh nvim to call back here, and when that fails the picker cannot be
                    -- closed (seen twice, one stuck 2h18m).
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

                    -- Global Ctrl-hjkl/Esc while a picker is open, installed once and never
                    -- removed. fzf-lua rebuilds the preview buffer and window as the selection
                    -- moves, so buffer-local maps always miss one and vim-tmux-navigator steals
                    -- focus. Per-picker save/restore failed too: maparg returns the buffer-local
                    -- map. With no picker open, each key does what it did at install time.
                    if not _G.__fzf_modal_keys then
                        _G.__fzf_modal_keys = true

                        -- Opening a pick hides the picker for resume, and __SELF keeps
                        -- returning it: only a picker still on screen counts as open.
                        local function live()
                            local ok, win = pcall(function()
                                return require("fzf-lua.win").__SELF()
                            end)
                            if ok and win and win.fzf_winid and vim.api.nvim_win_is_valid(win.fzf_winid) then
                                return win
                            end
                        end

                        -- Resolved per call: these outlive every picker.
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

                        -- 0x0e/0x10 = Ctrl-n/Ctrl-p, fzf's down/up, to step the list from the preview.
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

                        -- The global table, not maparg, which returns the buffer-local map.
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

-- Ctrl-l steps into the preview; Ctrl-h there (above) steps back.
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
            lsp = {
                -- Open at once and stream results; a timeout blocks until every server answers.
                async_or_timeout = true,
            },
            fzf_colors = { true, bg = "-1", gutter = "-1" },
            keymap = { fzf = { ["ctrl-q"] = "select-all+accept" } },
        })
    end,
}
