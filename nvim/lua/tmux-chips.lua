-- A tabline of chips for floating windows, matching the shape of the tmux
-- window tabs along the bottom of the screen: number block, name block, rounded
-- caps, same widths.
--
-- Shared by org-git.lua (repo tabs) and vim-helpers.lua (the shortcut help
-- tabs). One implementation because two copies would drift.
--
-- The colours follow the editor's appearance, not the running tmux. They used
-- to be read out of tmux so that changing @catppuccin_flavor moved every bar
-- together, and that was right while tmux followed the appearance too. It no
-- longer does -- the status bar is deliberately mocha in both themes -- so
-- reading it produced a float with a mocha background under this palette's ink
-- foreground: #1e1e2e behind #3b2322, dark on dark at 1.4:1. Worse, the same
-- editor looked different inside and outside tmux.
--
-- A float sits on top of the editor, so it takes the editor's side of the
-- split. The chips still echo the tmux tabs in shape; only the colours part
-- company.

local M = {}

-- Mocha, and a parchment light counterpart on the shared warm ramp.
local DARK = {
	crust = 0x11111b,
	bg = 0x1e1e2e,
	text = 0xcdd6f4,
	surface_0 = 0x313244,
	surface_1 = 0x45475a,
	overlay_1 = 0x7f849c,
	overlay_2 = 0x9399b2,
	current_number_bg = 0x590000,  -- the active-window chip, matching WezTerm's tab
	current_number_fg = 0xffffff,  -- and the light digit that sits on it
	red = 0xf38ba8,
}

local LIGHT = {
	crust = 0x241a17,
	bg = 0xc2b28a,
	text = 0x241a17,
	surface_0 = 0xb49d74,
	surface_1 = 0xa38c63,
	overlay_1 = 0x65563d,
	overlay_2 = 0x8b754d,
	current_number_bg = 0x7a2318,  -- the active-window chip, matching WezTerm's tab
	current_number_fg = 0xf2e6cf,  -- and the light digit that sits on it
	red = 0xf35e7e,
}

local PALETTE = require("theme-mode").is_light and LIGHT or DARK

-- Nerd Font half-circles, as escapes: written literally they are private-use
-- codepoints that any tool in the pipeline may silently drop.
-- Exported: floating-helpers builds its close chip with the same caps, so every
-- chip in this config has one shape.
M.CAP_LEFT = "\u{e0b6}"
M.CAP_RIGHT = "\u{e0b4}"
local CAP_LEFT, CAP_RIGHT = M.CAP_LEFT, M.CAP_RIGHT

-- The palette every caller styles against. Built once: the appearance is fixed
-- for the life of the process, so there is nothing to invalidate.
local cached = nil

function M.colors()
	cached = cached or vim.tbl_extend("force", PALETTE, {
		number_bg = PALETTE.overlay_2,
		number_fg = PALETTE.crust,
		name_bg = PALETTE.surface_0,
		current_name_bg = PALETTE.surface_1,
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
		TmuxChipKey = { fg = c.number_fg, bg = c.number_bg },
		TmuxChipKeyCap = { fg = c.number_bg, bg = c.bg },
		TmuxChip = { fg = c.text, bg = c.name_bg },
		TmuxChipCap = { fg = c.name_bg, bg = c.bg },

		-- The active chip can be dark enough that crust is unreadable on it, so
		-- its digit has its own colour rather than sharing the other chips'.
		TmuxChipCurrentKey = { fg = c.current_number_fg, bg = c.current_number_bg },
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
	-- One cell of ground before the first cap, matching the one the close chip
	-- leaves after itself: without it the row is padded on the right only.
	-- %< marks where the row is cut when it does not fit. It has to sit before
	-- the tabs, not after them: truncation eats what follows the marker, so a
	-- marker after the tabs chewed the close button off the right end instead.
	-- Here the oldest tabs go and the button always survives.
	local parts = { "%<%#TmuxChipFill# " }
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
