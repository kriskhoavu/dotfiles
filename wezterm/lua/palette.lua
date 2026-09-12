-- The light and dark palettes.
--
-- `M.current()` re-reads the theme on every call, so the event handlers that
-- outlive a config reload -- tab titles, right status -- pick up a switch
-- rather than holding the palette they started with.

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

  accent = "#C9A84C",  -- right-status (git branch); sits on the tab bar
}

-- "Novel warm": macOS Terminal.app "Novel", pulled deeper.
--
-- Stock Novel (#DFDBC3) read as washed out here, so the whole parchment family
-- was deepened together -- about 9 degrees browner, 15% darker, slightly more
-- saturated -- rather than darkening the background alone, which would have
-- flattened the steps between the surfaces. nvim's theme-mode carries the same
-- shifted ramp, so the editor and the terminal body are one scale. tmux is not
-- on it: its bar stays dark in both appearances, and only its pane chrome
-- follows the appearance at all.
--
-- The body is parchment with dark-brown text, sitting under the espresso chrome
-- above, so both appearances read as siblings. Novel's own ANSI values are
-- fully saturated and go garish on parchment, so these are the same hues pulled
-- down to ink strength.
--
-- Every entry is tuned against the background above, not picked by eye: the
-- normals clear 5:1 and the brights 4:1. This matters more than it looks --
-- these started out tuned for stock Novel and were never re-checked when the
-- ground was deepened twice, which left bright green at 2.1:1 and every bright
-- below 3:1. Slots 7 and 15 are warm inks rather than the near-whites the names
-- suggest, because on a light ground "white" text has to be dark to exist.
M.light = {
  foreground    = "#241A17",
  background    = "#C2B28A",
  cursor_bg     = "#73635A",
  cursor_border = "#73635A",
  cursor_fg     = "#C2B28A",
  selection_bg  = "#B3935F",
  selection_fg  = "#2B211E",
  ansi    = { "#4A3B36", "#772016", "#32441B", "#543A00", "#1E4165", "#642A51", "#1A4545", "#483D2F" },
  brights = { "#5A4A43", "#883021", "#415323", "#65480E", "#294F77", "#763860", "#245555", "#544632" },

  tab_bar_bg         = "#2E2622",
  active_tab_bg      = "#7A2318",
  active_tab_fg      = "#F2E9D6",
  inactive_tab_bg    = "#2E2622",
  inactive_tab_fg    = "#8A7A6C",
  hover_tab_bg       = "#3A302B",
  hover_tab_fg       = "#D8CDBA",
  new_tab_fg         = "#6B5B50",

  titlebar_bg          = "#2E2622",
  titlebar_bg_inactive = "#241D1A",
  titlebar_fg          = "#E4D9C4",
  titlebar_fg_inactive = "#8A7A6C",
  titlebar_border      = "#C9A84C",
  button_fg            = "#C0B09A",
  button_hover_fg      = "#FFFFFF",
  button_hover_bg      = "#3E332D",

  accent = "#C9A84C",
}

-- tmux paints its status bar this colour in both appearances (see
-- tmux/.tmux.conf, @kris_bar_bg), and the bottom strip in appearance.lua
-- matches it rather than the body.
M.dark.status_bar_bg = "#151414"
M.light.status_bar_bg = "#151414"

-- Which half is current, from ~/.config/kris-theme.
--
-- Not wezterm.gui.get_appearance(): the theme is this config's own state, not
-- macOS's. tmux and Neovim cannot follow the system appearance on their own
-- anyway -- tmux caches the terminal background from when its client attached,
-- and nothing can tell a running editor the desktop changed -- so a switch
-- always meant running the toggle script. Once the script has to exist, having
-- it own the state is simpler than having it mirror macOS into three tools.
--
-- Missing or unreadable means dark, so a fresh machine with no state file looks
-- the way this config has always looked.
--
-- Read on every call rather than cached: the file is a few bytes, this runs at
-- most once per tab per status redraw, and a cache would have to be invalidated
-- on config reload anyway. The toggle script touches wezterm.lua to force that
-- reload.
local STATE = os.getenv("HOME") .. "/.config/kris-theme"

function M.current()
  local file = io.open(STATE, "r")
  if not file then
    return M.dark
  end
  local value = file:read("l")
  file:close()
  return value == "light" and M.light or M.dark
end

return M
