-- The one way this config opens a floating window.
--
-- Four floats grew separately -- lazygit (\3), the org git tabs (\4), the
-- terminal (\9) and the shortcut help (\?) -- each with its own copy of the
-- centring arithmetic, its own scrolloff handling, and its own idea of whether
-- focus could leave. The copies drifted: \9 never got the modal guard at all,
-- and \3 and \4 each had to rediscover that a global sidescrolloff shifts a
-- full-width TUI sideways.
--
-- So the behaviour lives here and the differences are flags. A new float is
-- floats.open{...}; anything a float should do by default it does by default.

local M = {}

-- Chrome for the close button. Not "FloatTitle" -- that is a builtin group nvim
-- uses for every float's border title, and redefining it would repaint them all.
--
-- The X sits in a filled chip with the same rounded caps as the tab chips, so it
-- reads as a button rather than as a stray glyph: catppuccin's red, crust text,
-- and the caps carrying the fill colour on the float's own ground.
local function set_highlights()
	local c = require("tmux-chips").colors()
	vim.api.nvim_set_hl(0, "FloatChrome", { fg = c.overlay_1, bg = c.bg })
	vim.api.nvim_set_hl(0, "FloatChromeClose", { fg = c.crust, bg = c.red, bold = true })
	vim.api.nvim_set_hl(0, "FloatChromeCloseCap", { fg = c.red, bg = c.bg })
end

set_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights, desc = "Float chrome highlights" })

-- Ratios of the editor, because a float that is 90 columns wide is a different
-- float on a laptop and on a 4k screen. Values above 1 are taken as absolute
-- cells for the rare case that wants them.
local function measure(value, total, fallback)
	value = value or fallback
	if value <= 1 then
		return math.floor(total * value)
	end
	return math.min(math.floor(value), total)
end

-- Keep focus inside the float.
--
-- Every float here covers the editor, so handing focus to a window behind one
-- leaves it hanging over the screen with no way back. vim-tmux-navigator binds
-- Ctrl-hjkl globally and bufferline's Alt keys cycle buffers; neither knows a
-- float is in front, so both have to be answered per buffer.
--
-- Ctrl-hjkl still crosses tmux panes, which is the part worth keeping: the
-- float is modal within nvim, not within the terminal.
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

-- Close buttons, by float. A winbar click label can only name a global function
-- and hand it a number, so each float's closer is parked here under an id and
-- the label carries that id.
local closers = {}
local next_id = 0

function _G.FloatsCloseClick(id)
	local closer = closers[id]
	if closer then
		closer()
	end
end

-- Just the clickable X, as a winbar fragment. The tabbed floats already own
-- their winbar, so they append this to what they draw rather than having it
-- overwrite the tabs. Registered once per float; the string is reused on every
-- render.
--
-- `win` may be a window id or a function returning one -- see close_button.
function M.close_segment(win, buf, opts)
	opts = opts or {}
	next_id = next_id + 1
	local id = next_id

	closers[id] = function()
		if opts.on_close then
			opts.on_close()
			return
		end
		local w = type(win) == "function" and win() or win
		if w and vim.api.nvim_win_is_valid(w) then
			vim.api.nvim_win_close(w, true)
		end
	end

	if buf then
		vim.api.nvim_create_autocmd("BufWipeout", {
			buffer = buf,
			once = true,
			callback = function()
				closers[id] = nil
			end,
		})
	end

	-- The Nerd Font close glyph rather than the plain multiplication X: it is
	-- drawn heavier and fills the cell, which is as "bigger" as a fixed-width
	-- grid gets.
	local chips = require("tmux-chips")
	return "%"
		.. id
		.. "@v:lua.FloatsCloseClick@"
		.. "%#FloatChromeCloseCap#"
		.. chips.CAP_LEFT
		.. "%#FloatChromeClose# \u{f00d} "
		.. "%#FloatChromeCloseCap#"
		.. chips.CAP_RIGHT
		.. "%X%#FloatChrome# "
end

-- A right-aligned clickable X, in the float's winbar -- the one row of a float
-- that nvim still owns when a terminal fills the rest, and the only place a
-- click can land on nvim rather than on the program inside. Costs one row, so
-- it is opt-in.
-- `win` may be a window id or a function returning one. A float that is hidden
-- and reopened -- \9 is a toggle -- gets a new window every time while keeping
-- its buffer, so a captured id goes stale and the button would paint into a
-- window that no longer exists.
function M.close_button(win, buf, opts)
	local function current()
		return type(win) == "function" and win() or win
	end

	-- close_label, not title: title is the border's, and a float may want both.
	local left = opts.close_label and ("%#FloatChrome# " .. opts.close_label .. " ") or ""
	local winbar = left .. "%#FloatChrome#%=" .. M.close_segment(win, buf, opts)

	local function paint()
		local w = current()
		if w and vim.api.nvim_win_is_valid(w) then
			vim.wo[w].winbar = winbar
		end
	end
	paint()

	-- vim-options.lua blanks 'winbar' for every terminal buffer, to keep terminal
	-- chrome out of the way. That rule is right in general and wrong for a button
	-- drawn in the winbar, so repaint after it rather than carving an exception
	-- into it.
	vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter", "WinEnter" }, {
		buffer = buf,
		callback = paint,
		desc = "Repaint the float's close button",
	})

	-- Returned because those autocmds fire *during* nvim_open_win, before the
	-- caller has assigned the new window id, so a reopened float needs one paint
	-- once it knows where it is.
	return paint
end

-- Settings that belong to the window rather than the buffer, reapplied whenever
-- a float swaps in a different buffer.
--
-- scrolloff is zero for every float: they hold full-width TUI frames and fixed
-- tables, and a scrolloff only ever scrolls those out of alignment -- a
-- sidescrolloff of 5 cuts the left border off a lazygit frame and makes every
-- panel look shifted.
local function dress_window(win, opts)
	vim.wo[win].sidescrolloff = 0
	vim.wo[win].scrolloff = 0
	if opts.winhighlight then
		vim.wo[win].winhighlight = opts.winhighlight
	end
	if opts.cursorline ~= nil then
		vim.wo[win].cursorline = opts.cursorline
		vim.wo[win].cursorlineopt = "line"
	end
end

-- Open a centred float. Returns buf, win.
--
--   buf          reuse this buffer, else a scratch one is created
--   width        ratio of the editor (default 0.9), or cells if > 1
--   height       same
--   modal        keep focus inside (default true)
--   label        names the float in the modal mappings' descriptions
--   winhighlight window-local highlight overrides
--   cursorline   highlight the cursor row
--   close        add a clickable X to the float's winbar (costs one row)
--   close_label  text shown at the left of that winbar
--   on_close     what the X does; defaults to closing the window
--   border/title/title_pos/style passed through
function M.open(opts)
	opts = opts or {}

	local height = measure(opts.height, vim.o.lines, 0.9)
	local width = measure(opts.width, vim.o.columns, 0.9)
	local buf = (opts.buf and vim.api.nvim_buf_is_valid(opts.buf)) and opts.buf or vim.api.nvim_create_buf(false, true)

	local config = {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		height = height,
		width = width,
		style = opts.style or "minimal",
		border = opts.border or "rounded",
	}
	if opts.title then
		config.title = opts.title
		config.title_pos = opts.title_pos or "center"
	end

	local win = vim.api.nvim_open_win(buf, opts.enter ~= false, config)
	dress_window(win, opts)

	if opts.modal ~= false then
		M.make_modal(buf, opts.label)
	end

	if opts.close then
		M.close_button(win, buf, opts)
	end

	return buf, win
end

-- Swap a different buffer into an existing float: the tabbed floats keep one
-- window and several buffers, and both the window dressing and the guard have
-- to follow the buffer in.
function M.attach(win, buf, opts)
	opts = opts or {}
	vim.api.nvim_win_set_buf(win, buf)
	dress_window(win, opts)
	if opts.modal ~= false then
		M.make_modal(buf, opts.label)
	end
end

-- :help opens in a float rather than a split. Not modal: help is a place you
-- read something and then go back to work, and its own buffer is a normal one.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "help",
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		vim.cmd("wincmd c")
		M.open({
			buf = buf,
			width = 0.4,
			height = 0.8,
			style = "",
			modal = false,
		})
	end,
})

return M
