-- <leader>3: Toggle lazygit (floating)
local lg_state = { buf = -1, win = -1 }

-- Wipe the dead terminal buffer, else the next open reuses it and shows
-- "[Process exited 0]" instead of starting lazygit.
local function reset_lazygit()
	if vim.api.nvim_win_is_valid(lg_state.win) then
		pcall(vim.api.nvim_win_hide, lg_state.win)
	end
	if vim.api.nvim_buf_is_valid(lg_state.buf) then
		pcall(vim.api.nvim_buf_delete, lg_state.buf, { force = true })
	end
	lg_state.buf, lg_state.win = -1, -1
end

-- Called over RPC by scripts/lazygit-open.sh when lazygit's `e` runs. The float
-- is hidden rather than closed, so the lazygit session survives and <leader>3
-- brings it back exactly where it was.
function _G.LazygitOpenFile(path, line)
	-- The RPC arrives mid-keystroke inside the terminal job. Deferring keeps the
	-- window juggling out of that context, and lets the shim return immediately
	-- instead of blocking lazygit's UI.
	vim.schedule(function()
		if vim.api.nvim_win_is_valid(lg_state.win) then
			vim.api.nvim_win_hide(lg_state.win)
			lg_state.win = -1
		end

		vim.cmd.edit(vim.fn.fnameescape(path))

		line = tonumber(line) or 0
		if line > 0 then
			pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
		end
	end)

	-- --remote-expr prints whatever this returns; keep lazygit's pane clean.
	return ""
end

-- Shared with the org-wide float in org-git.lua, so the config merge and the
-- shim path cannot drift between the two.
local lazygit_command = require("lazygit-cmd").build

local function toggle_lazygit()
	if vim.api.nvim_win_is_valid(lg_state.win) then
		vim.api.nvim_win_hide(lg_state.win)
		lg_state.win = -1
		return
	end

	local h = math.floor(vim.o.lines * 0.9)
	local w = math.floor(vim.o.columns * 0.9)
	local buf = vim.api.nvim_buf_is_valid(lg_state.buf) and lg_state.buf or vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - w) / 2),
		height = h,
		width = w,
		style = "minimal",
		border = "rounded",
	})
	lg_state.buf, lg_state.win = buf, win

	-- A lazygit frame is exactly as wide as the window, so the global
	-- sidescrolloff of 5 scrolls its left border out of view whenever lazygit
	-- parks the cursor near the right edge, and every panel then looks shifted.
	vim.wo[win].sidescrolloff = 0
	vim.wo[win].scrolloff = 0

	if vim.bo[buf].buftype ~= "terminal" then
		local cmd, shim = lazygit_command()
		-- An argv list, not a shell string: the paths handed to `-ucf` contain
		-- spaces. The shim's own path travels in the environment so the overlay
		-- YAML never has to name it.
		vim.fn.termopen(cmd, {
			env = { LAZYGIT_NVIM_OPEN = shim },
			-- Reads the state, not a captured handle: the float is recreated on
			-- every toggle, so a captured one goes stale.
			on_exit = function()
				vim.schedule(reset_lazygit)
			end,
		})
		vim.bo[buf].buflisted = false

		-- Esc is lazygit's back key; the global map would steal it for normal mode.
		vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = buf, desc = "Send Esc to lazygit" })

		require("floating-helpers").make_modal(buf, "lazygit")

		-- Every way back in must land in terminal mode, or keys go to Vim.
		vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
			buffer = buf,
			callback = function()
				if vim.api.nvim_get_current_buf() == buf and vim.bo[buf].buftype == "terminal" then
					vim.cmd.startinsert()
				end
			end,
		})
	end

	vim.cmd.startinsert()
end

vim.keymap.set({ "n", "t" }, "<leader>3", toggle_lazygit, { desc = "Toggle lazygit" })

local function close_diffview()
    vim.cmd("DiffviewClose")
end

-- q/<esc> close from anywhere in the view, including the file tree panel, which
-- diffview leaves unbound by default.
local function close_keys()
    return {
        { "n", "q", close_diffview, { desc = "Close Diffview" } },
        { "n", "<esc>", close_diffview, { desc = "Close Diffview" } },
    }
end

-- <leader>hd / <leader>hD open a gitsigns diff: a read-only `gitsigns://`
-- revision buffer beside the file. Getting back out is the awkward part, so the
-- teardown lives here rather than in the keymap: the revision pane gets its own
-- q/<esc>, and a bare `:q` from either pane is caught as well.

local function is_revision_buf(buf)
    return vim.api.nvim_buf_get_name(buf):match("^gitsigns://") ~= nil
end

-- The revision panes of the current tab. They are matched by name rather than by
-- the 'diff' option: gitsigns clears 'diff' itself on some teardown paths, and a
-- pane left behind by `:q` would then be invisible to this code.
local function revision_windows(tab)
    local revision = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if vim.api.nvim_win_is_valid(win) and is_revision_buf(vim.api.nvim_win_get_buf(win)) then
            table.insert(revision, win)
        end
    end
    return revision
end

-- The buffer each diff was opened from, per tab, so the file can be restored
-- when `:q` has already taken its window away.
local diff_origin = {}

-- The panes showing the file this diff was opened from. Matching the remembered
-- buffer, rather than every window with 'diff' set, keeps an unrelated diff in
-- the same tab (Diffview's blob panes, a hand-rolled :diffsplit) out of the
-- teardown. Only when the diff was started outside these keymaps -- `:Gitsigns
-- diffthis` -- is there nothing to match, and then clearing every diff window is
-- still better than leaving 'diff' set on the file.
local function origin_windows(tab)
    local origin = diff_origin[tab]
    local known = origin ~= nil and vim.api.nvim_buf_is_valid(origin)
    local wins = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if vim.api.nvim_win_is_valid(win) and not is_revision_buf(vim.api.nvim_win_get_buf(win)) then
            local match = known and vim.api.nvim_win_get_buf(win) == origin
                or (not known and vim.wo[win].diff)
            if match then
                table.insert(wins, win)
            end
        end
    end
    return wins
end

local function close_gitsigns_diff_view()
    local tab = vim.api.nvim_get_current_tabpage()
    local revision = revision_windows(tab)
    if #revision == 0 then
        return
    end
    local file = origin_windows(tab)

    -- 'diff' is a window option, so it has to be cleared while the windows still
    -- exist. Only this view's panes are touched, which leaves an unrelated diff
    -- (Diffview, a hand-rolled :diffsplit) alone -- `diffoff!` would not.
    for _, group in ipairs({ revision, file }) do
        for _, win in ipairs(group) do
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_call(win, function()
                    vim.cmd("diffoff")
                end)
            end
        end
    end

    -- `:q` in the file pane leaves the revision blob as the only window. It is an
    -- `acwrite` view of the git index, where `:w` would stage lines, so put the
    -- real file back instead of closing the last window and stranding the user.
    if #file == 0 then
        local keep = table.remove(revision, 1)
        local origin = diff_origin[tab]
        if origin and vim.api.nvim_buf_is_valid(origin) and keep and vim.api.nvim_win_is_valid(keep) then
            vim.api.nvim_win_set_buf(keep, origin)
        elseif keep then
            table.insert(revision, 1, keep)
        end
    end

    for _, win in ipairs(revision) do
        if vim.api.nvim_win_is_valid(win) and #vim.api.nvim_tabpage_list_wins(tab) > 1 then
            vim.api.nvim_win_close(win, true)
        end
    end

    diff_origin[tab] = nil
end

-- Keying the toggle off an open revision pane, rather than off `vim.wo.diff`,
-- matters: gitsigns resets 'diff' when the revision buffer is hidden, and a
-- toggle that trusted it would diff the git index against itself and stack up
-- another pane every press.
local function toggle_gitsigns_diff(base)
    if #revision_windows(0) > 0 then
        close_gitsigns_diff_view()
        return
    end

    diff_origin[vim.api.nvim_get_current_tabpage()] = vim.api.nvim_get_current_buf()
    package.loaded.gitsigns.diffthis(base)
end

local gitsigns_diff_group = vim.api.nvim_create_augroup("GitsignsDiffViewClose", { clear = true })

-- gitsigns builds the revision buffer asynchronously, so its exit keys are bound
-- when the window shows up. Binding them after the `diffthis` call returns would
-- leave a window in which no key gets you out.
vim.api.nvim_create_autocmd("BufWinEnter", {
    group = gitsigns_diff_group,
    pattern = "gitsigns://*",
    callback = function(args)
        for _, key in ipairs({ "q", "<esc>" }) do
            vim.keymap.set("n", key, close_gitsigns_diff_view, {
                buffer = args.buf,
                desc = "Close gitsigns diff view",
            })
        end
    end,
})

-- Safety net for `:q`, `:close` and friends in the file pane, which would
-- otherwise dump the user into the revision blob with the file nowhere in sight.
vim.api.nvim_create_autocmd("WinClosed", {
    group = gitsigns_diff_group,
    callback = function(args)
        local closed = tonumber(args.match)
        if closed == nil then
            return
        end
        local ok, in_diff = pcall(function()
            return vim.wo[closed].diff
        end)
        if not ok or not in_diff then
            return
        end
        -- The window is still listed during WinClosed, so decide once it is gone.
        vim.schedule(function()
            local tab = vim.api.nvim_get_current_tabpage()
            if #revision_windows(tab) > 0 and #origin_windows(tab) == 0 then
                close_gitsigns_diff_view()
            end
        end)
    end,
})

return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns
                local function map(mode, l, r, desc)
                    vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
                end

                -- navigation
                map("n", "]h", gs.next_hunk, "Next hunk")
                map("n", "[h", gs.prev_hunk, "Prev hunk")

                -- Actions (hunk)
                map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
                map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")

                map("v", "<leader>hs", function()
                    gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end, "Stage hunk (visual)")
                map("v", "<leader>hr", function()
                    gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end, "Reset hunk (visual)")

                -- Actions (buffer)
                map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
                map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
                map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")

                -- Blame
                map("n", "<leader>hb", function()
                   gs.blame_line({ full = true })
                end, "Blame line (full)")
                map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle line blame")

                -- Diff / Preview
                map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
                map("n", "<leader>hd", function()
                    toggle_gitsigns_diff()
                end, "Toggle diff this")
                map("n", "<leader>hD", function()
                    toggle_gitsigns_diff("~")
                end, "Toggle diff this ~ (against last commit)")
                -- text object
                map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
            end,
        },
    },
    {
        "sindrets/diffview.nvim",
        config = function(_, opts)
            require("diffview").setup(opts)

            -- Diffview's left pane is a git blob with no path on disk, so LSPs
            -- can't resolve the project and flood it with bogus errors. Diff mode
            -- is for reading: mute diagnostics until the view closes.
            local diagnostics_were_enabled = true
            vim.api.nvim_create_autocmd("User", {
                group = vim.api.nvim_create_augroup("DiffviewQuietDiagnostics", { clear = true }),
                pattern = { "DiffviewViewOpened", "DiffviewViewClosed" },
                callback = function(args)
                    if args.match == "DiffviewViewOpened" then
                        diagnostics_were_enabled = vim.diagnostic.is_enabled()
                        vim.diagnostic.enable(false)
                    elseif diagnostics_were_enabled then
                        vim.diagnostic.enable(true)
                    end
                end,
            })
        end,
        opts = {
            keymaps = {
                view = close_keys(),
                file_panel = close_keys(),
                file_history_panel = close_keys(),
            },
        },
        -- <leader>2: Toggle Git (Diffview)
        keys = {
            {
                "<leader>2",
                function()
                    local lib = require("diffview.lib")
                    if next(lib.views) == nil then
                        vim.cmd("DiffviewOpen")
                    else
                        vim.cmd("DiffviewClose")
                    end
                end,
                desc = "Toggle Diffview",
            },
            {
                "<leader>hf",
                function()
                    vim.cmd("DiffviewFileHistory %")
                end,
                desc = "File history",
            },
            -- Open current file and close DiffView (like VSCode's git.openFile)
            {
                "<leader><Down>",
                function()
                    local lib = require("diffview.lib")
                    local view = lib.get_current_view()
                    if view and view.cur_entry then
                        local path = view.cur_entry.absolute_path
                        vim.cmd("DiffviewClose")
                        vim.cmd("edit " .. vim.fn.fnameescape(path))
                    end
                end,
                desc = "Open current file from Diffview (leader+Down)",
            },
        },
    },
}
