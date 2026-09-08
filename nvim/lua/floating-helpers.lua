-- Shared behaviour for the floating windows in this config.

local M = {}

-- Make a float modal: keep focus inside it.
--
-- Every float here covers the editor, so handing focus to a window behind one
-- leaves it hanging over the screen with no way back to it. vim-tmux-navigator
-- binds Ctrl-hjkl globally and bufferline's Alt keys cycle buffers, and neither
-- knows a float is in front -- so both have to be answered per buffer.
--
-- Ctrl-hjkl still crosses tmux panes, which is the part worth keeping: the float
-- is modal within nvim, not within the terminal.
--
-- Applied to every buffer of a float, not just terminal ones. A float's plain
-- buffers (the org git overview, the shortcut help sections) are ordinary
-- windows as far as those plugins are concerned.
function M.make_modal(buf, label)
	for key, dir in pairs({ h = "L", j = "D", k = "U", l = "R" }) do
		vim.keymap.set({ "n", "t" }, "<C-" .. key .. ">", function()
			if vim.env.TMUX then
				vim.fn.system({ "tmux", "select-pane", "-" .. dir })
			end
		end, {
			buffer = buf,
			silent = true,
			desc = "Tmux pane " .. dir .. " (skip nvim windows)",
		})
	end

	local dead = { "<A-h>", "<A-l>" }
	for i = 1, 9 do
		dead[#dead + 1] = "<A-" .. i .. ">"
	end
	for _, key in ipairs(dead) do
		vim.keymap.set({ "n", "t" }, key, "<Nop>", {
			buffer = buf,
			silent = true,
			desc = "Disabled while " .. (label or "this float") .. " is open",
		})
	end
end

-- :help opens in a float rather than a split.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "help",
	callback = function()
		local crbuf = vim.api.nvim_get_current_buf()
		vim.cmd("wincmd c")
		vim.api.nvim_open_win(crbuf, true, {
			relative = "editor",
			width = math.floor(vim.o.columns * 0.4),
			height = math.floor(vim.o.lines * 0.8),
			col = math.floor(vim.o.columns * 0.1),
			row = math.floor(vim.o.lines * 0.1),
			border = "rounded",
		})
	end,
})

return M
