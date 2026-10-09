-- Light or dark, plus the colours the colorscheme cannot be asked for.
--
-- State lives in ~/.config/kris-theme (anything but "light" is dark). Not OSC 11:
-- tmux answers from a value cached when its client attached. Read once at
-- startup; prefix + T restarts nvim to switch, so nothing polls.
--
-- Only hard-coded hexes live here (bufferline, window grounds, line-number
-- accent). Light values use WezTerm's warmed ramp; tmux's bar stays dark.

local M = {}

local STATE = os.getenv("HOME") .. "/.config/kris-theme"

local function read_state()
	local file = io.open(STATE, "r")
	if not file then
		return "dark"
	end
	local value = file:read("l")
	file:close()
	return value == "light" and "light" or "dark"
end

local appearance = read_state()

M.is_light = appearance == "light"

-- Colorschemes and the rest still read &background.
vim.o.background = appearance

local dark = {
	-- bufferline
	fill_bg      = "#0f1117",
	tab_bg       = "#1a1f2b",
	tab_fg       = "#7f8ea3",
	visible_bg   = "#1f2633",
	visible_fg   = "#aab7cf",
	separator    = "#344055",

	-- vim-window: the focused window is lifted, the rest recede
	active_bg        = "#1e1e2e",
	inactive_bg      = "#080a0f",
	active_border    = "#ffcc00",
	inactive_border  = "#3a3f4b",
	active_linenr    = "#8fa1bd",
	inactive_linenr  = "#4b5160",

	linenr_below = "#ead84e",

	-- No ramp: One Dark's neutrals already work; ramp_*/ink/muted are light-only.

	-- onedark syntax overrides (One Dark hues)
	syn_keyword   = "#c678dd",
	syn_type      = "#e5c07b",
	syn_parameter = "#d19e6b",
}

local light = {
	fill_bg      = "#E2D6C6",
	tab_bg       = "#E8DBCA",
	tab_fg       = "#565653",
	visible_bg   = "#DDD2C3",
	visible_fg   = "#3D3D3A",
	separator    = "#C3B8A7",

	active_bg        = "#EEDFD1",
	inactive_bg      = "#E2D6C6",
	active_border    = "#D97757",
	inactive_border  = "#C3B8A7",
	active_linenr    = "#42413C",
	inactive_linenr  = "#75736C",

	linenr_below = "#A6432A",

	-- Claude's neutrals, 5% accent orange, 8% darker: WezTerm's six-step ramp.
	-- ramp_0 must equal WezTerm's background: Normal is transparent.
	ramp_0 = "#eedfd1",
	ramp_1 = "#e8dbca",
	ramp_2 = "#e2d6c6",
	ramp_3 = "#ddd2c3",
	ramp_4 = "#d0c5b5",
	ink = "#141413",
	muted = "#565653",
	muted_ui = "#42413c",

	-- One Light hues darkened to 5:1+ on this ground (One Light's sit at 2-3).
	syn_keyword   = "#8f3c7e",
	syn_type      = "#774d00",
	syn_parameter = "#97401f",
}

M.colors = M.is_light and light or dark

-- Selected buffer keeps a dark-red chip in both modes, matching WezTerm's tab.
M.selected_bg = M.is_light and "#7a2318" or "#590000"

return M
