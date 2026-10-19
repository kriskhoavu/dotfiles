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

  -- ── Colors (~/.config/kris-theme; see lua/palette.lua) ─────────────────────
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
  -- A light see-through with blur. The background layers below carry the
  -- window's opacity (window_background_opacity is ignored once they exist);
  -- text_background_opacity covers cells an app paints, as nvim does.
  local OPACITY = 0.92
  config.window_background_opacity    = OPACITY
  config.macos_window_background_blur = 20
  config.text_background_opacity      = OPACITY

  -- Opaque body plus a dark band along the bottom: the window is rarely a whole
  -- number of cells, and the remainder shows a light notch beside tmux's dark
  -- bar. Corners get their own layers (the centred strip misses them). 48px =
  -- one row + remainder (24 covered 2/3). Stands in for window_content_alignment,
  -- absent in this build.
  local bottom_band = function(align)
    return {
      source = { Color = p.status_bar_bg },
      opacity = OPACITY,
      width = align == "Center" and 6000 or 48,
      horizontal_align = align,
      height = 48,
      vertical_align = "Bottom",
    }
  end

  config.background = {
    {
      source = { Color = p.background },
      opacity = OPACITY,
      width = "100%",
      height = "100%",
    },
    bottom_band("Center"),
    bottom_band("Left"),
    bottom_band("Right"),
  }

  -- RESIZE alone drops the traffic lights; INTEGRATED_BUTTONS puts them in the tab bar.
  config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

  -- Native fullscreen for Ctrl-Cmd-F too: mixing it with the green button's left
  -- a bare title bar.
  config.native_macos_fullscreen_mode = true
  -- Top padding only: elsewhere it shows the background around edge content.
  config.window_padding     = { left = 0, right = 0, top = 4, bottom = 0 }

  -- ── Cursor ────────────────────────────────────────────────────────────────
  config.default_cursor_style = "BlinkingUnderline"
  config.cursor_blink_rate    = 500
  -- Constant blink: the eased default repaints every frame. See animation_fps.
  config.cursor_blink_ease_in  = "Constant"
  config.cursor_blink_ease_out = "Constant"

  -- ── Tab bar ───────────────────────────────────────────────────────────────
  config.use_fancy_tab_bar            = true
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_bar_at_bottom            = false
  config.tab_max_width                = 9999

  -- Bar height derives from the font (14 -> 27pt, 16 -> 35pt); no setting.
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
