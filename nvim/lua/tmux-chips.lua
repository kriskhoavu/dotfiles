-- A tabline of catppuccin chips for floating windows, matching the tmux window
-- tabs along the bottom of the screen: number block, name block, rounded caps,
-- same colours, same widths.
--
-- Shared by org-git.lua (repo tabs) and vim-helpers.lua (the shortcut help
-- tabs). One implementation because the palette lookup is fiddly -- catppuccin
-- keeps its colours in tmux options, and the window options hold "#{@thm_mauve}"
-- rather than a colour, so the indirection has to be followed before the hex can
-- be parsed. Two copies of that would drift.
--
-- The palette is read from the running tmux rather than pasted in, so changing
-- @catppuccin_flavor moves every bar together. Mocha is the fallback for a plain
-- terminal with no tmux to ask.

local M = {}

local FALLBACK = {
	crust = 0x11111b,
	bg = 0x1e1e2e,
	text = 0xcdd6f4,
	surface_0 = 0x313244,
	surface_1 = 0x45475a,
	overlay_1 = 0x7f849c,
	overlay_2 = 0x9399b2,
	mauve = 0xcba6f7,
	blue = 0x89b4fa,
	yellow = 0xf9e2af,
	teal = 0x94e2d5,
	red = 0xf38ba8,
	green = 0xa6e3a1,
	peach = 0xfab387,
}

-- Nerd Font half-circles, as escapes: written literally they are private-use
-- codepoints that any tool in the pipeline may silently drop.
-- Exported: floating-helpers builds its close chip with the same caps, so every
-- chip in this config has one shape.
M.CAP_LEFT = "\u{e0b6}"
M.CAP_RIGHT = "\u{e0b4}"
local CAP_LEFT, CAP_RIGHT = M.CAP_LEFT, M.CAP_RIGHT

local function read_tmux()
	if not vim.env.TMUX then
		return nil
	end

	local ok, res = pcall(function()
		return vim.system({ "tmux", "show", "-g" }, { text = true }):wait(500)
	end)
	if not ok or not res or res.code ~= 0 then
		return nil
	end

	local raw = {}
	for line in vim.gsplit(res.stdout, "\n", { trimempty = true }) do
		local key, value = line:match('^@([%w_]+)%s+"?([^"]*)"?$')
		if key then
			raw[key] = value
		end
	end

	local function hex(name)
		local value = raw[name]
		if not value then
			return nil
		end
		local ref = value:match("^#{@([%w_]+)}$")
		if ref then
			value = raw[ref]
		end
		local digits = value and value:match("^#(%x%x%x%x%x%x)$")
		return digits and tonumber(digits, 16) or nil
	end

	local palette = {}
	for key, fallback in pairs(FALLBACK) do
		palette[key] = hex("thm_" .. key) or fallback
	end
	palette.number_bg = hex("catppuccin_window_number_color") or palette.overlay_2
	palette.name_bg = hex("catppuccin_window_text_color") or palette.surface_0
	palette.current_number_bg = hex("catppuccin_window_current_number_color") or palette.mauve
	palette.current_name_bg = hex("catppuccin_window_current_text_color") or palette.surface_1
	return palette
end

local cached = nil

-- The palette every caller styles against. Cached: it costs one tmux call, and
-- the colours only change when the flavor does, which also fires ColorScheme.
function M.colors()
	cached = cached or read_tmux() or vim.tbl_extend("force", FALLBACK, {
		number_bg = FALLBACK.overlay_2,
		name_bg = FALLBACK.surface_0,
		current_number_bg = FALLBACK.mauve,
		current_name_bg = FALLBACK.surface_1,
	})
	return cached
end

-- Chips, and the float ground they sit on. The ground is catppuccin's base, not
-- NormalFloat: with the editor's own float background the name blocks were
-- invisible -- onedark's #31353f against catppuccin's #313244 -- and the blocks
-- only read as blocks because tmux puts them on the darker bar.
function M.highlights()
	local c = M.colors()
	local hls = {
		TmuxChipKey = { fg = c.crust, bg = c.number_bg },
		TmuxChipKeyCap = { fg = c.number_bg, bg = c.bg },
		TmuxChip = { fg = c.text, bg = c.name_bg },
		TmuxChipCap = { fg = c.name_bg, bg = c.bg },

		TmuxChipCurrentKey = { fg = c.crust, bg = c.current_number_bg },
		TmuxChipCurrentKeyCap = { fg = c.current_number_bg, bg = c.bg },
		TmuxChipCurrent = { fg = c.text, bg = c.current_name_bg },
		TmuxChipCurrentCap = { fg = c.current_name_bg, bg = c.bg },

		TmuxChipFill = { fg = c.overlay_1, bg = c.bg },
		TmuxChipNormal = { fg = c.text, bg = c.bg },
		TmuxChipBorder = { fg = c.surface_1, bg = c.bg },
		-- The cursor row takes the next surface up: the same step the tabs use
		-- between their inactive and active blocks.
		TmuxChipCursorLine = { bg = c.surface_0 },
	}
	for name, val in pairs(hls) do
		vim.api.nvim_set_hl(0, name, val)
	end
end

M.WINHIGHLIGHT = "NormalFloat:TmuxChipNormal,FloatBorder:TmuxChipBorder,CursorLine:TmuxChipCursorLine"

-- tabs: { { label = "overview", suffix = "%#Group#..." }, ... }, index 1 upward.
-- `current` is 1-based to match. `first_index` is the digit shown on the first
-- chip, for callers whose first tab is keyed 0.
--
-- `on_click` is the name of a global Lua function, called with the clicked
-- chip's own number as its first argument -- statusline click labels pass their
-- minwid through, so the number in the label is both what you see and what the
-- handler receives.
--
-- Geometry copied from tmux's window-status-format: the rounded cap is the
-- number block's left edge, so the digit carries a trailing space only
-- (catppuccin's middle separator), and the name block opens with one space
-- (@catppuccin_window_text is " #W").
function M.tabline(tabs, current, first_index, on_click)
	local parts = {}
	local n = first_index or 1

	for i, tab in ipairs(tabs) do
		local on = i == current
		local number = n + i - 1
		local key = on and "TmuxChipCurrentKey" or "TmuxChipKey"
		local key_cap = on and "TmuxChipCurrentKeyCap" or "TmuxChipKeyCap"
		local body = on and "TmuxChipCurrent" or "TmuxChip"
		local cap = on and "TmuxChipCurrentCap" or "TmuxChipCap"

		-- The whole chip is one click label, caps included, so the rounded ends
		-- are not dead zones.
		if on_click then
			parts[#parts + 1] = "%" .. number .. "@v:lua." .. on_click .. "@"
		end
		parts[#parts + 1] = "%#" .. key_cap .. "#" .. CAP_LEFT
		parts[#parts + 1] = "%#" .. key .. "#" .. number .. " "
		parts[#parts + 1] = "%#" .. body .. "# " .. tab.label .. (tab.suffix or "") .. " "
		parts[#parts + 1] = "%#" .. cap .. "#" .. CAP_RIGHT
		if on_click then
			parts[#parts + 1] = "%X"
		end
		parts[#parts + 1] = "%#TmuxChipFill# "
	end

	parts[#parts + 1] = "%#TmuxChipFill#%="
	return table.concat(parts)
end

M.highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		M.highlights()
	end,
	desc = "Tmux chip highlights",
})

return M
