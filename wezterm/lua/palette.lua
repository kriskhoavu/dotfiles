-- The light and dark palettes.

local M = {}

-- iTerm2 "Kris" dark profile
M.dark = {
  foreground    = "#F6D6B2",
  background    = "#151414",
  cursor_bg     = "#BBBBBB",
  cursor_border = "#BBBBBB",
  cursor_fg     = "#FFFBFB",
  selection_bg  = "#FF9D1F",
  selection_fg  = "#000000",
  ansi    = { "#000000", "#BB0000", "#9CFFFC", "#BBBB00", "#DE5000", "#BB00BB", "#00BBBB", "#BBBBBB" },
  brights = { "#9BCB83", "#FF5555", "#55FF55", "#FFFF55", "#5555FF", "#FF55FF", "#60F7F9", "#FFFFFF" },

  tab_bar_bg         = "#1A1919",
  active_tab_bg      = "#590000",
  active_tab_fg      = "#FFFFFF",
  inactive_tab_bg    = "#1A1919",
  inactive_tab_fg    = "#555555",
  hover_tab_bg       = "#1E1D1D",
  hover_tab_fg       = "#AAAAAA",
  new_tab_fg         = "#444444",

  titlebar_bg          = "#1A1919",
  titlebar_bg_inactive = "#151414",
  titlebar_fg          = "#DDDDDD",
  titlebar_fg_inactive = "#666666",
  titlebar_border      = "#C9A84C",
  button_fg            = "#AAAAAA",
  button_hover_fg      = "#FFFFFF",
  button_hover_bg      = "#252424",

  -- Right-status (git branch), both themes: a step lighter than Claude's
  -- #D97757, which faded into the bar at 5.6:1.
  accent = "#E59578",
}

-- "Claude light": Claude's four neutrals with 5% accent orange and 8% less
-- lightness -> #E4D6C9 canvas, #DED2C2, #D9CDBE, #D4CABB, #C8BDAD, #BBB0A1
-- (nvim's theme-mode uses the same steps). Text 14.1:1; ANSI normals 5:1+,
-- brights 4:1+; slots 7 and 15 are warm greys, since "white" must be dark here.
-- Chrome stays dark in both themes; the active tab keeps its dark red.
M.light = {
  foreground    = "#111110",
  background    = "#E4D6C9",
  cursor_bg     = "#C2552F",
  cursor_border = "#C2552F",
  cursor_fg     = "#FAF9F5",
  selection_bg  = "#D3A184",
  selection_fg  = "#111110",
  ansi    = { "#252524", "#601b0f", "#253B0A", "#492f00", "#13304b", "#4B1C41", "#0D3A37", "#33332E" },
  brights = { "#3d3d3c", "#6B2616", "#2a4411", "#543700", "#1A3B58", "#58254D", "#114442", "#3F3D38" },

  tab_bar_bg         = "#262624",
  active_tab_bg      = "#7A2318",
  active_tab_fg      = "#FAF9F5",
  inactive_tab_bg    = "#262624",
  inactive_tab_fg    = "#8A8880",
  hover_tab_bg       = "#30302E",
  hover_tab_fg       = "#D9D7CF",
  new_tab_fg         = "#6C6B68",

  titlebar_bg          = "#262624",
  titlebar_bg_inactive = "#1F1E1D",
  titlebar_fg          = "#E5E3DB",
  titlebar_fg_inactive = "#8A8880",
  titlebar_border      = "#D97757",
  button_fg            = "#B8B6AE",
  button_hover_fg      = "#FFFFFF",
  button_hover_bg      = "#3A3A37",

  accent = "#E59578",  -- the same orange as the dark theme; see the note there
}

-- tmux's bar colour in both appearances (@kris_bar_bg); appearance.lua's
-- bottom band matches it.
M.dark.status_bar_bg = "#151414"
M.light.status_bar_bg = "#151414"

-- Current half, from ~/.config/kris-theme (missing = dark). Cached for 1s:
-- tab titles call this per tab per redraw on the GUI thread, and an open()
-- each time froze the window; the TTL still lets old handlers see a switch.
local STATE = os.getenv("HOME") .. "/.config/kris-theme"
local TTL   = 1   -- seconds

local cached, cached_at = nil, -1

function M.current()
  local now = os.time()
  if cached and now - cached_at < TTL then return cached end
  local file = io.open(STATE, "r")
  local value = file and file:read("l")
  if file then file:close() end
  cached, cached_at = (value == "light" and M.light or M.dark), now
  return cached
end

return M
