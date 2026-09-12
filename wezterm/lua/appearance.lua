local wezterm = require 'wezterm'
local palette = require 'lua.palette'

return function(config)
  -- ── Font ──────────────────────────────────────────────────────────────────
  config.font      = wezterm.font("MesloLGS NF", { weight = "Regular" })
  config.font_size = 14.3
  config.use_cap_height_to_scale_fallback_fonts = true
  config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
  config.font_rules = {
    { italic = true, font = wezterm.font("MesloLGS NF", { weight = "Regular", italic = false }) },
  }

  -- ── Colors (follows the macOS light/dark appearance; see lua/palette.lua) ──
  local p = palette.current()

  config.colors = {
    foreground    = p.foreground,
    background    = p.background,
    cursor_bg     = p.cursor_bg,
    cursor_border = p.cursor_border,
    cursor_fg     = p.cursor_fg,
    selection_bg  = p.selection_bg,
    selection_fg  = p.selection_fg,
    ansi          = p.ansi,
    brights       = p.brights,
    tab_bar = {
      background         = p.tab_bar_bg,
      active_tab         = { bg_color = p.active_tab_bg,   fg_color = p.active_tab_fg, intensity = "Bold" },
      inactive_tab       = { bg_color = p.inactive_tab_bg, fg_color = p.inactive_tab_fg },
      inactive_tab_hover = { bg_color = p.hover_tab_bg,    fg_color = p.hover_tab_fg },
      new_tab            = { bg_color = p.tab_bar_bg,      fg_color = p.new_tab_fg },
      new_tab_hover      = { bg_color = p.hover_tab_bg,    fg_color = p.hover_tab_fg },
    },
  }

  -- ── Window ────────────────────────────────────────────────────────────────
  config.window_background_opacity    = 1.0
  config.macos_window_background_blur = 0
  config.text_background_opacity      = 1.0

  -- Fully opaque body (tab bar stays opaque)
  --
  -- The second layer is a dark strip along the bottom edge. A window is rarely
  -- an exact multiple of the cell height, and WezTerm fills the leftover with
  -- the background -- a pale sliver under tmux's dark status bar in light mode.
  -- window_padding is already 0, so that sliver is all that is left, and this
  -- build has no window_content_alignment to move it to the top instead.
  --
  -- The strip is one cell tall, so it covers the remainder plus the rest of the
  -- last row. That row is tmux's status bar, which paints its own opaque
  -- background over it, so nothing changes while tmux is running. In a bare
  -- shell the bottom line would sit on dark instead of parchment.
  --
  -- It does not help the same remainder on the left and right edges: the grid is
  -- centred horizontally and those few points stay parchment. Live with it, or
  -- upgrade to a WezTerm with window_content_alignment.
  config.background = {
    {
      source = { Color = p.background },
      opacity = 1.0,
      width = "100%",
      height = "100%",
    },
    {
      source = { Color = p.status_bar_bg },
      opacity = 1.0,
      width = 6000,
      horizontal_align = "Center",
      height = 24,
      vertical_align = "Bottom",
    },
  }

  -- RESIZE alone drops the macOS title bar, and with it the traffic-light
  -- buttons: nothing is left to maximize the window. INTEGRATED_BUTTONS
  -- puts them in the tab bar instead, keeping the title bar hidden.
  config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

  -- Use macOS's own fullscreen for Ctrl-Cmd-F too, rather than WezTerm's
  -- "simple" one. The green button always enters the native mode whatever this
  -- is set to, and with INTEGRATED_BUTTONS that transition was sometimes leaving
  -- a bare system title bar with no tab bar behind it. Having one fullscreen
  -- path instead of two keeps the buttons and the tab bar in step.
  config.native_macos_fullscreen_mode = true
  -- Padding only at the top. Anywhere else it shows the terminal background
  -- around content that reaches the edge -- most visibly as a pale strip under
  -- tmux's status bar in light mode, but the same applies to the sides.
  config.window_padding     = { left = 0, right = 0, top = 4, bottom = 0 }

  -- ── Cursor ────────────────────────────────────────────────────────────────
  config.default_cursor_style = "BlinkingUnderline"
  config.cursor_blink_rate    = 500

  -- ── Tab bar ───────────────────────────────────────────────────────────────
  config.use_fancy_tab_bar            = true
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_bar_at_bottom            = false
  config.tab_max_width                = 9999

  -- The fancy tab bar has no height setting: WezTerm derives it from this
  -- font's cell metrics, so bar height and label size move together (measured:
  -- font_size 14 -> 27pt bar, 16 -> 35pt; a `scale` attribute on the font is
  -- ignored). 14.0 keeps the labels at terminal size and the bar compact.
  config.window_frame = {
    font                            = wezterm.font("MesloLGS NF", { weight = "Bold" }),
    font_size                       = 14.0,
    active_titlebar_bg              = p.titlebar_bg,
    inactive_titlebar_bg            = p.titlebar_bg_inactive,
    active_titlebar_fg              = p.titlebar_fg,
    inactive_titlebar_fg            = p.titlebar_fg_inactive,
    active_titlebar_border_bottom   = p.titlebar_border,
    inactive_titlebar_border_bottom = p.titlebar_bg_inactive,
    button_fg                       = p.button_fg,
    button_bg                       = p.titlebar_bg,
    button_hover_fg                 = p.button_hover_fg,
    button_hover_bg                 = p.button_hover_bg,
  }
end
