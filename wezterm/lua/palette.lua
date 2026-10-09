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

  -- right-status (git branch), orange in both themes. A step lighter than
  -- Claude's #D97757, which sat back into this bar at 5.6:1.
  accent = "#E59578",
}

-- "Claude light": Claude's light interface, warmed with its own orange.
--
-- Claude's four neutrals (#FAF9F5, #F0EEE6, #EBE9E1, #DDDAD0) carrying 5% of
-- the accent orange and 8% less lightness: #EEDFD1 canvas, #E8DBCA, #E2D6C6,
-- #DDD2C3, #D0C5B5, #C3B8A7. nvim's theme-mode carries the same six steps.
--
-- Text is #141413 at 14.1:1. The ANSI set is re-tuned for this ground -- every
-- normal clears 5:1 and every bright 4:1 -- and slots 7 and 15 are warm greys,
-- because on a light ground "white" text has to be dark to exist.
--
-- Chrome stays dark in both themes, on Claude's dark neutrals, and the active
-- tab keeps its dark red; the orange is for the body and the branch indicator.
M.light = {
  foreground    = "#141413",
  background    = "#EEDFD1",
  cursor_bg     = "#C2552F",
  cursor_border = "#C2552F",
  cursor_fg     = "#FAF9F5",
  selection_bg  = "#D3A184",
  selection_fg  = "#141413",
  ansi    = { "#3D3D3A", "#9C2D19", "#3D5F11", "#774D00", "#1F4E79", "#7A2E6B", "#155E5A", "#54524B" },
  brights = { "#646461", "#AE3E23", "#456E1B", "#885B00", "#2A5F8F", "#8F3C7E", "#1B6F6C", "#66645C" },

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

-- tmux paints its status bar this colour in both appearances (see
-- tmux/.tmux.conf, @kris_bar_bg), and the bottom strip in appearance.lua
-- matches it rather than the body.
M.dark.status_bar_bg = "#151414"
M.light.status_bar_bg = "#151414"

-- Which half is current, from ~/.config/kris-theme: this config's own state,
-- since tmux and nvim cannot follow macOS anyway. Missing means dark. Re-read
-- at most once a second, so handlers outliving a reload see a switch: tab
-- titles call this per tab on every redraw, on the GUI thread, and an open()
-- each time froze the window.
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
