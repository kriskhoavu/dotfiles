-- Light or dark, and the colours that cannot be asked of the colorscheme.
--
-- The appearance is this config's own state, in ~/.config/kris-theme, not the
-- terminal's and not macOS's. Neovim can be told what the terminal background
-- is (OSC 11, answered while the TUI starts) but that answer is wrong under
-- tmux, which replies from a value it cached when its client attached and never
-- re-asks -- so an editor opened in a long-lived tmux server inherits whatever
-- the desktop looked like that morning. A file has no such lag.
--
-- Anything but "light" is dark, so a machine with no state file looks the way
-- this config has always looked.
--
-- Nothing re-checks after startup: a switch means restarting Neovim, which
-- prefix + T does for every reachable instance. That is the deal this config
-- takes, in exchange for no polling anywhere.
--
-- Most colours follow the colorscheme on their own. What lands here is the
-- handful of places that set a hex directly -- the bufferline, the window
-- grounds in vim-window, the line-number accent -- because those were picked
-- against a dark ground and go invisible on a light one.
--
-- The light values are the same warmed ramp as WezTerm's Claude light palette,
-- so the editor and the terminal body are one warm scale. tmux's bar is
-- deliberately not on it -- it stays dark in both appearances.

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

-- Everything that is not this module still reads &background -- colorschemes
-- first among them -- so the answer has to land there too.
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

	-- No ramp here: One Dark's own neutrals are already right on a dark ground,
	-- so the light table's ramp_*/ink/muted keys have no dark counterpart and
	-- onedark.lua reads them only on the light branch.

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

	-- Claude's neutrals carrying 5% of the accent orange and 8% less
	-- lightness -- the warmed ramp from WezTerm's palette, same six steps.
	-- Light only, see the note in the dark table above. ramp_0 has to be
	-- exactly WezTerm's background: `transparent` leaves Normal showing the
	-- terminal through, and every panel onedark paints has to land on it.
	ramp_0 = "#eedfd1",
	ramp_1 = "#e8dbca",
	ramp_2 = "#e2d6c6",
	ramp_3 = "#ddd2c3",
	ramp_4 = "#d0c5b5",
	ink = "#141413",
	muted = "#565653",
	muted_ui = "#42413c",

	-- One Light hues, the same roles, pulled down far enough to hold up on this
	-- ground: 5:1 and better, where One Light's own values sit at 2-3.
	syn_keyword   = "#8f3c7e",
	syn_type      = "#774d00",
	syn_parameter = "#97401f",
}

M.colors = M.is_light and light or dark

-- The selected buffer keeps a dark-red chip in both appearances -- it matches
-- WezTerm's active tab, which stays dark red under the light theme too -- so
-- everything drawn on top of it stays light either way and is not part of the
-- tables above.
M.selected_bg = M.is_light and "#7a2318" or "#590000"

return M
