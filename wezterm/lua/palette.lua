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

  -- right-status (git branch). Orange in both appearances -- it is the one
  -- indicator that should read the same wherever the eye is coming from, and
  -- the gold it replaced was a second warm accent doing the same job. A step
  -- lighter than Claude's #D97757, which at 5.6:1 on this bar was legible but
  -- sat back into it; this reads at 7.4:1, and 6.4:1 on the light theme's
  -- slightly lighter bar.
  accent = "#E59578",
}

-- "Claude light": Claude's own light interface, warmed further with its orange.
--
-- This replaces a deepened Terminal.app "Novel" parchment (#C2B28A ground,
-- brown inks). That ramp was warm but muddy -- a tan ground turns every syntax
-- hue chalky, and the ink text on it never looked like text on paper. Claude's
-- light appearance solves the same problem the other way: a warm near-white
-- ground, near-black warm ink, and one saturated orange doing all the accent
-- work. Here that ground is then tinted with 5% of the orange and taken 8%
-- darker, which keeps the paper feel of Claude's white while giving the ink
-- something warmer than paper to sit on. Both numbers were walked back from
-- 10%: at 10% orange the ground was a blush rather than paper, and the last
-- couple of points of darkness took it further from Claude's own light than
-- the warmth was worth.
--
-- The grounds are Claude's four neutrals -- #FAF9F5 canvas, #F0EEE6 panel,
-- #EBE9E1 raised, #DDDAD0 border -- with the whole ramp then carrying 5% of
-- the accent orange and 8% less lightness, which is what warms Claude's paper
-- white into this one: #EEDFD1 canvas, #E8DBCA, #E2D6C6, #DDD2C3, #D0C5B5,
-- #C3B8A7. nvim's theme-mode carries the same six steps, so the editor and the
-- terminal body are one scale.
--
-- Text is #141413 at 14.1:1, not a softened grey -- the parchment palette this
-- replaced put #241A17 on its ground at 8:1 and read as brown, which is what
-- "the text looks off" came down to.
--
-- The ANSI set is the same hue wheel pulled to ink strength for this ground:
-- every normal clears 5:1 against the canvas and every bright 4:1 (measured:
-- normals 5.7-8.4, brights 4.6-5.2). They were re-tuned when the ground was
-- first tinted -- against Claude's paper white they had 2-3 points of
-- headroom, and darkening the ground spent most of it: red, green, yellow and
-- six of the eight brights dropped under the floor. Slots 7 and 15 are warm greys rather
-- than the near-whites their names suggest, because on a light ground "white"
-- text has to be dark to exist at all.
--
-- The chrome stays dark, as it does in the dark theme and as tmux's bar does in
-- both -- it frames the work rather than being part of it. It is Claude's own
-- dark neutrals (#262624, #1F1E1D) rather than the old espresso browns, so the
-- two halves of the theme are one family, and the active tab keeps the dark red
-- it has in the dark theme. The orange is for the body and for the one accent
-- on the bar (the branch in the right status), not for the tab itself: a full
-- orange tab made the chrome the loudest thing on screen.
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
