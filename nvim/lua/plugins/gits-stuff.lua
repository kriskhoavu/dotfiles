-- <leader>3: Toggle lazygit (floating)
local lg_state = { buf = -1, win = -1 }

local function toggle_lazygit()
	if vim.api.nvim_win_is_valid(lg_state.win) then
		vim.api.nvim_win_hide(lg_state.win)
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
			on_exit = function()
				-- lazygit was quit (q): close the window and reset so next open is fresh
				vim.api.nvim_win_hide(win)
				lg_state.buf = -1
			end,
		})
		vim.bo[buf].buflisted = false
	end

	vim.cmd.startinsert()
end

vim.keymap.set({ "n", "t" }, "<leader>3", toggle_lazygit, { desc = "Toggle lazygit" })

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
