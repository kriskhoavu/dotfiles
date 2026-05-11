local wezterm = require 'wezterm'

return function(config)
  -- ── Font ──────────────────────────────────────────────────────────────────
  config.font      = wezterm.font("MesloLGS NF", { weight = "Regular" })
  config.font_size = 14.0
  config.use_cap_height_to_scale_fallback_fonts = true
  config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
  config.font_rules = {
    { italic = true, font = wezterm.font("MesloLGS NF", { weight = "Regular", italic = false }) },
  }

  -- ── Colors (iTerm2 "Kris" dark profile) ────────────────────────────────────
  config.colors = {
    foreground    = "#3AD4FF",
    background    = "#151414",
    cursor_bg     = "#BBBBBB",
    cursor_border = "#BBBBBB",
    cursor_fg     = "#FFFBFB",
    selection_bg  = "#FF9D1F",
    selection_fg  = "#000000",
    ansi    = { "#000000", "#BB0000", "#9CFFFC", "#BBBB00", "#DE5000", "#BB00BB", "#00BBBB", "#BBBBBB" },
    brights = { "#9BCB83", "#FF5555", "#55FF55", "#FFFF55", "#5555FF", "#FF55FF", "#60F7F9", "#FFFFFF" },
    tab_bar = {
      background         = "#1A1919",
      active_tab         = { bg_color = "#590000", fg_color = "#FFFFFF", intensity = "Bold" },
      inactive_tab       = { bg_color = "#1A1919", fg_color = "#555555" },
      inactive_tab_hover = { bg_color = "#1E1D1D", fg_color = "#AAAAAA" },
      new_tab            = { bg_color = "#1A1919", fg_color = "#444444" },
      new_tab_hover      = { bg_color = "#1E1D1D", fg_color = "#BBBBBB" },
    },
  }

  -- ── Window ────────────────────────────────────────────────────────────────
  config.window_background_opacity    = 1.0
  config.macos_window_background_blur = 10
  config.text_background_opacity      = 1.0

  -- Transparent body only (tab bar stays opaque)
  config.background = {
    {
      source = { Color = "#151414" },
      opacity = 0.92,
      width = "100%",
      height = "100%",
    },
  }
  config.window_decorations = "RESIZE"
  config.window_padding     = { left = 4, right = 4, top = 4, bottom = 4 }

  -- ── Cursor ────────────────────────────────────────────────────────────────
  config.default_cursor_style = "BlinkingUnderline"
  config.cursor_blink_rate    = 500

  -- ── Tab bar ───────────────────────────────────────────────────────────────
  config.use_fancy_tab_bar            = true
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_bar_at_bottom            = false
  config.tab_max_width                = 9999

  config.window_frame = {
    font                            = wezterm.font("MesloLGS NF", { weight = "Bold" }),
    font_size                       = 14.0,
    active_titlebar_bg              = "#1A1919",
    inactive_titlebar_bg            = "#151414",
    active_titlebar_fg              = "#DDDDDD",
    inactive_titlebar_fg            = "#666666",
    active_titlebar_border_bottom   = "#C9A84C",
    inactive_titlebar_border_bottom = "#151414",
    button_fg                       = "#AAAAAA",
    button_bg                       = "#1A1919",
    button_hover_fg                 = "#FFFFFF",
    button_hover_bg                 = "#252424",
  }
end
