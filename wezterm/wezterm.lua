local wezterm = require 'wezterm'
local config  = wezterm.config_builder()

-- Load event handlers (tab titles, right status)
require 'lua.events'

-- Apply appearance (font, colors, window, tab bar)
require('lua.appearance')(config)

-- Apply key bindings
require('lua.keys')(config)

-- ── Misc ──────────────────────────────────────────────────────────────────────
config.scrollback_lines          = 10000
config.term                      = "xterm-256color"
config.initial_cols              = 80
config.initial_rows              = 25
config.audible_bell              = "Disabled"
config.visual_bell               = { fade_in_duration_ms = 0, fade_out_duration_ms = 0 }
config.window_close_confirmation = "NeverPrompt"
config.front_end                 = "WebGpu"
config.max_fps                   = 120
config.use_ime                   = true
config.macos_forward_to_ime_modifier_mask = "SHIFT"

return config
