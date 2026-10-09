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

-- Called over RPC by scripts/lazygit-open.sh on lazygit's `e`. Hidden, not
-- closed, so the session survives and \3 brings it back where it was.
function _G.LazygitOpenFile(path, line)
	-- The RPC arrives mid-keystroke inside the terminal job: defer, so the shim
	-- returns at once instead of blocking lazygit's UI.
	vim.schedule(function()
		if vim.api.nvim_win_is_valid(lg_state.win) then
			vim.api.nvim_win_hide(lg_state.win)
			lg_state.win = -1
		end

		require("lazygit-cmd").edit(path, line)
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

	local floats = require("floating-helpers")
	local buf, win = floats.open({
		buf = lg_state.buf,
		label = "lazygit",
	})
	lg_state.buf, lg_state.win = buf, win

	-- Registered once on the long-lived buffer, repainted on every open: the
	-- winbar belongs to the window, which is new on each toggle.
	if not lg_state.paint then
		lg_state.paint = floats.close_button(function()
			return lg_state.win
		end, buf, {
			on_close = function()
				if vim.api.nvim_win_is_valid(lg_state.win) then
					vim.api.nvim_win_hide(lg_state.win)
					lg_state.win = -1
				end
			end,
		})
	end
	lg_state.paint()

	if vim.bo[buf].buftype ~= "terminal" then
		local cmd, shim = lazygit_command()
		-- An argv list, not a shell string: the `-ucf` paths contain spaces.
		-- The shim travels in the environment, so the YAML never names it.
		vim.fn.termopen(cmd, {
			env = vim.tbl_extend("error", require("term-env").job_env, { LAZYGIT_NVIM_OPEN = shim }),
			-- Reads the state, not a captured handle: the float is recreated on
			-- every toggle, so a captured one goes stale.
			on_exit = function()
				vim.schedule(reset_lazygit)
			end,
		})
		vim.bo[buf].buflisted = false
		require("lazygit-cmd").attach(buf)
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

-- \hd / \hD open a read-only `gitsigns://` revision buffer beside the file.
-- Getting out is the awkward part, so the teardown lives here: the revision
-- pane gets q/<esc>, and a bare `:q` from either pane is caught too.

local function is_revision_buf(buf)
    return vim.api.nvim_buf_get_name(buf):match("^gitsigns://") ~= nil
end

-- Matched by name, not by 'diff': gitsigns clears that on some teardown paths,
-- and a pane left by `:q` would then be invisible here.
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

-- Matched against the remembered buffer, not every window with 'diff', so an
-- unrelated diff in the same tab stays out of the teardown. With nothing to
-- match (`:Gitsigns diffthis`), clearing them all still beats leaving 'diff'.
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

    -- 'diff' is a window option, so clear it while the windows exist. Only
    -- this view's panes, which `diffoff!` would not respect.
    for _, group in ipairs({ revision, file }) do
        for _, win in ipairs(group) do
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_call(win, function()
                    vim.cmd("diffoff")
                end)
            end
        end
    end

    -- `:q` in the file pane leaves the revision blob alone on screen -- an
    -- `acwrite` view of the index where `:w` stages lines. Put the file back.
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

-- Keyed off an open revision pane, not `vim.wo.diff`: gitsigns resets that when
-- the buffer hides, so a toggle trusting it stacks a pane on every press.
local function toggle_gitsigns_diff(base)
    if #revision_windows(0) > 0 then
        close_gitsigns_diff_view()
        return
    end

    diff_origin[vim.api.nvim_get_current_tabpage()] = vim.api.nvim_get_current_buf()
    package.loaded.gitsigns.diffthis(base)
end

local gitsigns_diff_group = vim.api.nvim_create_augroup("GitsignsDiffViewClose", { clear = true })

-- gitsigns builds the revision buffer asynchronously, so bind the exit keys
-- when the window appears -- after `diffthis` returns is too early.
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
            -- Who last touched the line under the cursor, at the end of it.
            -- Virtual text, so it never shifts the buffer's own columns.
            current_line_blame = true,
            current_line_blame_opts = {
                virt_text = true,
                virt_text_pos = "eol",
                -- Long enough that it does not flicker while j/k is held.
                delay = 300,
                ignore_whitespace = false,
            },
            current_line_blame_formatter = "  <author>, <author_time:%R> - <summary>",

            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns
                local function map(mode, l, r, desc)
                    vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
                end

                -- navigation
                map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
                map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")

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

            -- Diffview's left pane is a blob with no path, so LSPs cannot
            -- resolve the project and flood it. Mute until the view closes.
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
