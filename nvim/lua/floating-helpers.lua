-- The one way this config opens a floating window; per-float differences are flags.

local M = {}

-- Close-button chrome. Not "FloatTitle", which is builtin for border titles.
local function set_highlights()
	local c = require("tmux-chips").colors()
	vim.api.nvim_set_hl(0, "FloatChrome", { fg = c.overlay_1, bg = c.bg })
	vim.api.nvim_set_hl(0, "FloatChromeClose", { fg = c.crust, bg = c.red, bold = true })
	vim.api.nvim_set_hl(0, "FloatChromeCloseCap", { fg = c.red, bg = c.bg })
end

set_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights, desc = "Float chrome highlights" })

-- Size as a ratio of the editor, or absolute cells when above 1.
local function measure(value, total, fallback)
	value = value or fallback
	if value <= 1 then
		return math.floor(total * value)
	end
	return math.min(math.floor(value), total)
end

-- Keep focus inside the float, or it is lost behind it. vim-tmux-navigator's
-- Ctrl-hjkl and bufferline's Alt keys are global, so they are overridden per
-- buffer. Ctrl-hjkl still crosses tmux panes. `nav` repurposes Alt-h / Alt-l
-- for tab steps; Alt digits stay dead (tmux eats them first).
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

	-- Ctrl-Alt-<digit> jumps to a tab; needs tmux extended-keys to be encodable.
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

-- Winbar click labels can only call a global with a number, so closers are
-- parked here by id.
local closers = {}
local next_id = 0

function _G.FloatsCloseClick(id)
	local closer = closers[id]
	if closer then
		closer()
	end
end

-- The clickable X as a winbar fragment for floats that draw their own winbar.
-- `win` may be a window id or a function returning one.
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

	-- Nerd Font glyph, not X: it fills the cell.
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

-- Right-aligned X in the winbar, the only row a click reaches nvim when a
-- terminal fills the rest. Opt-in: costs a row. `win` may be a function, since
-- a toggled float gets a new window each time.
function M.close_button(win, buf, opts)
	local function current()
		return type(win) == "function" and win() or win
	end

	-- close_label, not title: title is the border's.
	local left = opts.close_label and ("%#FloatChrome# " .. opts.close_label .. " ") or ""
	local winbar = left .. "%#FloatChrome#%=" .. M.close_segment(win, buf, opts)

	local function paint()
		local w = current()
		if w and vim.api.nvim_win_is_valid(w) then
			vim.wo[w].winbar = winbar
		end
	end
	paint()

	-- vim-options.lua blanks 'winbar' for terminals; repaint after it.
	vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter", "WinEnter" }, {
		buffer = buf,
		callback = paint,
		desc = "Repaint the float's close button",
	})

	-- Returned because these autocmds fire inside nvim_open_win, before the caller
	-- has the window id.
	return paint
end

-- Reapplied whenever a float swaps buffers. scrolloff 0: floats hold full-width
-- TUI frames, and sidescrolloff 5 cuts lazygit's left border.
local function dress_window(win, opts)
	vim.wo[win].sidescrolloff = 0
	vim.wo[win].scrolloff = 0

	-- Chip-palette ground by default so all floats match; false keeps the editor's.
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

-- Swap a buffer into an existing float (tabbed floats: one window, many buffers).
function M.attach(win, buf, opts)
	opts = opts or {}
	vim.api.nvim_win_set_buf(win, buf)
	dress_window(win, opts)
	if opts.modal ~= false then
		M.make_modal(buf, opts.label, opts.nav)
	end
end

-- :help in a non-modal float, not a split.
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
