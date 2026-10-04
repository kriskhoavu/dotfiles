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

  -- Fully opaque body, plus a dark band along the bottom edge.
  --
  -- The window is rarely an exact multiple of the cell size, and the leftover
  -- is filled with the terminal background: a light notch beside tmux's dark
  -- bar. The centred strip misses the edges, so each corner gets its own layer.
  -- 48 physical pixels is one cell row plus the remainder; 24 covered two
  -- thirds. Stands in for window_content_alignment, absent in this build.
  local bottom_band = function(align)
    return {
      source = { Color = p.status_bar_bg },
      opacity = 1.0,
      width = align == "Center" and 6000 or 48,
      horizontal_align = align,
      height = 48,
      vertical_align = "Bottom",
    }
  end

  config.background = {
    {
      source = { Color = p.background },
      opacity = 1.0,
      width = "100%",
      height = "100%",
    },
    bottom_band("Center"),
    bottom_band("Left"),
    bottom_band("Right"),
  }

  -- RESIZE alone drops the title bar and the traffic lights with it;
  -- INTEGRATED_BUTTONS puts them in the tab bar.
  config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

  -- Native fullscreen for Ctrl-Cmd-F too: the green button always uses it, and
  -- two fullscreen paths left a bare title bar with no tab bar behind it.
  config.native_macos_fullscreen_mode = true
  -- Padding only at the top: anywhere else it shows the terminal background
  -- around content that reaches the edge.
  config.window_padding     = { left = 0, right = 0, top = 4, bottom = 0 }

  -- ── Cursor ────────────────────────────────────────────────────────────────
  config.default_cursor_style = "BlinkingUnderline"
  config.cursor_blink_rate    = 500
  -- Blink on and off rather than fading: the eased default repaints every frame
  -- for as long as the window is open. See animation_fps in wezterm.lua.
  config.cursor_blink_ease_in  = "Constant"
  config.cursor_blink_ease_out = "Constant"

  -- ── Tab bar ───────────────────────────────────────────────────────────────
  config.use_fancy_tab_bar            = true
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_bar_at_bottom            = false
  config.tab_max_width                = 9999

  -- The fancy tab bar has no height setting -- WezTerm derives it from the
  -- font's cell metrics (14 -> 27pt bar, 16 -> 35pt).
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
