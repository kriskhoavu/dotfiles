-- Chips for floating windows, shaped like the tmux window tabs: number block,
-- name block, rounded caps, same widths. Shared by org-git.lua and
-- vim-helpers.lua, so the two cannot drift.
--
-- Colours follow the editor, not the running tmux. They used to be read from
-- tmux, which stopped working once the bar went dark in both themes: that gave
-- dark-on-dark at 1.4:1, and the same editor looked different inside tmux.
-- A float sits on the editor, so it takes the editor's side.

local M = {}

-- Mocha, and a light counterpart on the warmed ramp (see theme-mode).
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
	-- Accents for whatever is drawn on a chip or on the float, tuned against
	-- both grounds: 5:1 or better on the name block, more on the float.
	gold = 0xd8a657,
	green = 0x7bbf6a,
	teal = 0x6fc3bd,
	blue = 0x89b4fa,
	mauve = 0xcba6f7,
}

local LIGHT = {
	crust = 0x141413,
	bg = 0xe2d6c6,
	text = 0x141413,
	surface_0 = 0xddd2c3,
	surface_1 = 0xd0c5b5,
	overlay_1 = 0x42413c,
	overlay_2 = 0xc3b8a7,
	current_number_bg = 0x7a2318,  -- the active-window chip, matching WezTerm's tab
	current_number_fg = 0xfaf9f5,  -- and the light digit that sits on it
	red = 0xd97757,
	gold = 0x7a5000,
	green = 0x3d5f11,
	teal = 0x155e5a,
	blue = 0x1f4e79,
	mauve = 0x7a2e6b,
}

local PALETTE = require("theme-mode").is_light and LIGHT or DARK

-- Nerd Font half-circles as escapes: written literally they are private-use
-- codepoints any tool may drop. Exported so the close chip shares the shape.
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

-- Chips and their ground. This palette's own base, not NormalFloat: against
-- the editor's float background the name blocks were invisible (#31353f vs
-- #313244) -- they only read as blocks on a darker ground.
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

-- tabs: { { label = "overview", suffix = "%#Group#..." }, ... }, 1-based, as is
-- `current`. `first_index` is the digit on the first chip, for 0-keyed callers.
--
-- `on_click` names a global Lua function, called with the clicked chip's
-- number: click labels pass their minwid through.
--
-- Geometry copied from tmux's window-status-format: the cap is the number
-- block's left edge, so the digit carries only a trailing space.
function M.tabline(tabs, current, first_index, on_click)
	-- One cell of ground before the first cap, matching the close chip's, or
	-- the row is padded on the right only.
	-- %< marks where the row is cut. Before the tabs, not after: truncation
	-- eats what follows the marker, so after them it ate the close button.
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
