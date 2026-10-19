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
	close_fg     = "#7f8ea3",

	-- vim-window: the focused window is lifted and boxed in muted gold, the rest recede
	active_bg        = "#1e1e2e",
	inactive_bg      = "#080a0f",
	active_border    = "#6a5324",
	active_border_fg = "#f0e6d0",
	inactive_border  = "#3a3f4b",
	active_cursorlinenr = "#ffcc00",
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
	-- Chips lighter than a darker strip, ink text: one step apart they blurred.
	fill_bg      = "#A99E8F",
	tab_bg       = "#CFC5B7",
	tab_fg       = "#111110",
	visible_bg   = "#E4D6C9",
	visible_fg   = "#111110",
	separator    = "#8C8173",
	close_fg     = "#4f483f",

	active_bg        = "#E4D6C9",
	inactive_bg      = "#D9CDBE",
	active_border    = "#8a5a00",
	active_border_fg = "#ffffff",
	inactive_border  = "#BBB0A1",
	active_cursorlinenr = "#D97757",
	active_linenr    = "#292825",
	inactive_linenr  = "#474742",

	linenr_below = "#66291A",

	-- Claude's neutrals, 5% accent orange, 8% darker: WezTerm's six-step ramp.
	-- ramp_0 must equal WezTerm's background: Normal is transparent.
	ramp_0 = "#e4d6c9",
	ramp_1 = "#ded2c2",
	ramp_2 = "#d9cdbe",
	ramp_3 = "#d4cabb",
	ramp_4 = "#c8bdad",
	ink = "#111110",
	muted = "#353533",
	muted_ui = "#292825",

	-- One Light hues darkened to 5:1+ on this ground (One Light's sit at 2-3).
	syn_keyword   = "#58254d",
	syn_type      = "#492f00",
	syn_parameter = "#5d2713",

	-- WezTerm's light ANSI palette (wezterm/lua/palette.lua), 4.6:1+ here. One
	-- Light's hues sit at 2.2-2.9:1 and reached every :terminal, lazygit and
	-- Neo-tree through onedark.
	ansi    = { "#252524", "#601b0f", "#253b0a", "#492f00", "#13304b", "#4b1c41", "#0d3a37", "#33332e" },
	brights = { "#3d3d3c", "#6b2616", "#2a4411", "#543700", "#1a3b58", "#58254d", "#114442", "#3f3d38" },
}

M.colors = M.is_light and light or dark

-- Selected buffer keeps a dark-red chip in both modes, matching WezTerm's tab.
M.selected_bg = M.is_light and "#7a2318" or "#590000"

return M
