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

	if vim.bo[buf].buftype ~= "terminal" then
		vim.fn.termopen("lazygit", {
			-- Reads the state, not a captured handle: the float is recreated on
			-- every toggle, so a captured one goes stale.
			on_exit = function()
				vim.schedule(reset_lazygit)
			end,
		})
		vim.bo[buf].buflisted = false

		-- Esc is lazygit's back key; the global map would steal it for normal mode.
		vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = buf, desc = "Send Esc to lazygit" })

		-- The float is modal: moving to an nvim window behind it strands lazygit
		-- off-screen. Ctrl-hjkl still crosses tmux panes; buffer cycling is dead.
		local tmux_dir = { h = "L", j = "D", k = "U", l = "R" }
		for key, dir in pairs(tmux_dir) do
			vim.keymap.set({ "n", "t" }, "<C-" .. key .. ">", function()
				if vim.env.TMUX then
					vim.fn.system({ "tmux", "select-pane", "-" .. dir })
				end
			end, { buffer = buf, silent = true, desc = "Tmux pane " .. dir .. " (skip nvim windows)" })
		end
		local dead_keys = { "<A-h>", "<A-l>" }
		for i = 1, 9 do
			dead_keys[#dead_keys + 1] = "<A-" .. i .. ">"
		end
		for _, key in ipairs(dead_keys) do
			vim.keymap.set({ "n", "t" }, key, "<Nop>", { buffer = buf, silent = true, desc = "Disabled while lazygit is open" })
		end

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

return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns
                local function close_gitsigns_diff_view()
                    vim.cmd("diffoff!")
                    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                        local buf = vim.api.nvim_win_get_buf(win)
                        local name = vim.api.nvim_buf_get_name(buf)
                        if name:match("^gitsigns://") and vim.api.nvim_win_is_valid(win) then
                            vim.api.nvim_win_close(win, true)
                        end
                    end
                end
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
                    if vim.wo.diff then
                        close_gitsigns_diff_view()
                        return
                    end
                    gs.diffthis()
                end, "Toggle diff this")
                map("n", "<leader>hD", function()
                    if vim.wo.diff then
                        close_gitsigns_diff_view()
                        return
                    end
                    gs.diffthis("~")
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
