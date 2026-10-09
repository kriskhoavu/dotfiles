-- The one way this config opens a floating window. \3, \4, \9 and \? each had
-- their own copy of the centring, the scrolloff and the focus guard, and the
-- copies drifted. Behaviour lives here; the differences are flags.

local M = {}

-- Chrome for the close button. Not "FloatTitle": that is builtin and used for
-- every float's border title. The X sits in a capped chip so it reads as a
-- button rather than a stray glyph.
local function set_highlights()
	local c = require("tmux-chips").colors()
	vim.api.nvim_set_hl(0, "FloatChrome", { fg = c.overlay_1, bg = c.bg })
	vim.api.nvim_set_hl(0, "FloatChromeClose", { fg = c.crust, bg = c.red, bold = true })
	vim.api.nvim_set_hl(0, "FloatChromeCloseCap", { fg = c.red, bg = c.bg })
end

set_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights, desc = "Float chrome highlights" })

-- Ratios of the editor: 90 columns is a different float on a laptop and on 4k.
-- Above 1 means absolute cells.
local function measure(value, total, fallback)
	value = value or fallback
	if value <= 1 then
		return math.floor(total * value)
	end
	return math.min(math.floor(value), total)
end

-- Keep focus inside the float: a float covers the editor, so focus behind one
-- leaves it hanging with no way back. vim-tmux-navigator's Ctrl-hjkl and
-- bufferline's Alt keys are global and have to be answered per buffer.
--
-- Ctrl-hjkl still crosses tmux panes: modal within nvim, not within the
-- terminal. `nav` puts Alt-h / Alt-l to work stepping between tabs instead of
-- killing them; the Alt digits stay dead because tmux eats those first.
function M.make_modal(buf, label, nav)
	for key, dir in pairs({ h = "L", j = "D", k = "U", l = "R" }) do
		vim.keymap.set({ "n", "t" }, "<C-" .. key .. ">", function()
			if vim.env.TMUX then
				vim.system({ "tmux", "select-pane", "-" .. dir })
			end
		end, {
			buffer = buf,
			silent = true,
			desc = "Tmux pane " .. dir .. " (skip nvim windows)",
		})
	end

	local dead = {}
	for i = 1, 9 do
		dead[#dead + 1] = "<A-" .. i .. ">"
	end

	-- Ctrl-Alt-<digit> jumps to a tab. Needs tmux's extended-keys, or the
	-- terminal cannot encode the combination at all.
	if nav and nav.jump then
		for i = 0, 9 do
			vim.keymap.set({ "n", "t" }, "<C-M-" .. i .. ">", function()
				nav.jump(i)
			end, {
				buffer = buf,
				silent = true,
				desc = "Tab " .. i .. " in " .. (label or "this float"),
			})
		end
	end

	if nav and nav.prev and nav.next then
		vim.keymap.set({ "n", "t" }, "<A-h>", nav.prev, {
			buffer = buf,
			silent = true,
			desc = "Previous tab in " .. (label or "this float"),
		})
		vim.keymap.set({ "n", "t" }, "<A-l>", nav.next, {
			buffer = buf,
			silent = true,
			desc = "Next tab in " .. (label or "this float"),
		})
	else
		dead[#dead + 1] = "<A-h>"
		dead[#dead + 1] = "<A-l>"
	end

	for _, key in ipairs(dead) do
		vim.keymap.set({ "n", "t" }, key, "<Nop>", {
			buffer = buf,
			silent = true,
			desc = "Disabled while " .. (label or "this float") .. " is open",
		})
	end
end

-- A winbar click label can only name a global function and pass a number, so
-- each float's closer is parked here under an id.
local closers = {}
local next_id = 0

function _G.FloatsCloseClick(id)
	local closer = closers[id]
	if closer then
		closer()
	end
end

-- The clickable X alone, as a winbar fragment: the tabbed floats append it to
-- what they already draw. `win` may be a window id or a function returning one.
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

	-- The Nerd Font glyph, not a plain X: it fills the cell, which is as bigger
	-- as a fixed grid gets.
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

-- A right-aligned X in the winbar: the one row nvim still owns when a terminal
-- fills the rest, so the only place a click reaches nvim. Costs a row, opt-in.
-- `win` may be a function: a toggled float keeps its buffer but gets a new
-- window each time, so a captured id goes stale.
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

	-- vim-options.lua blanks 'winbar' for terminal buffers. Right in general,
	-- wrong for this button, so repaint after it rather than add an exception.
	vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter", "WinEnter" }, {
		buffer = buf,
		callback = paint,
		desc = "Repaint the float's close button",
	})

	-- Returned because those autocmds fire during nvim_open_win, before the
	-- caller holds the new window id.
	return paint
end

-- Window-local settings, reapplied whenever a float swaps in another buffer.
-- scrolloff is zero everywhere: floats hold full-width TUI frames, and a
-- sidescrolloff of 5 cuts the left border off a lazygit frame.
local function dress_window(win, opts)
	vim.wo[win].sidescrolloff = 0
	vim.wo[win].scrolloff = 0

	-- The chip palette's ground unless asked otherwise, or \9 and \4 sit on
	-- visibly different backgrounds. Pass false to keep the editor's.
	local winhl = opts.winhighlight
	if winhl == nil then
		winhl = require("tmux-chips").WINHIGHLIGHT
	end
	if winhl then
		vim.wo[win].winhighlight = winhl
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
--   nav          { prev, next, jump }: Alt-h / Alt-l step between tabs,
--                Ctrl-Alt-<digit> jumps to one
--   winhighlight window-local highlight overrides; defaults to the chip-palette
--                ground every float shares, false keeps the editor's
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
		M.make_modal(buf, opts.label, opts.nav)
	end

	if opts.close then
		M.close_button(win, buf, opts)
	end

	return buf, win
end

-- Swap a buffer into an existing float. The tabbed floats keep one window and
-- several buffers, so the dressing and the guard follow the buffer in.
function M.attach(win, buf, opts)
	opts = opts or {}
	vim.api.nvim_win_set_buf(win, buf)
	dress_window(win, opts)
	if opts.modal ~= false then
		M.make_modal(buf, opts.label, opts.nav)
	end
end

-- :help in a float, not a split. Not modal: you read it and go back to work.
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
