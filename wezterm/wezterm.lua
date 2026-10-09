local wezterm = require 'wezterm'
local config  = wezterm.config_builder()

require 'lua.events'

require('lua.appearance')(config)

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
-- 60, not 120: key repeat is every 30ms, so 60 is already double that.
config.max_fps                   = 60
-- Paces the cursor blink, which repainted continuously: 17-21% CPU idle,
-- 2-6% with this and the Constant ease in appearance.lua.
config.animation_fps             = 1
-- IME off: macOS otherwise buffers a held key as marked text and delivers it
-- on release (j crawls, sticks, then jumps). Costs Telex in the terminal.
config.use_ime                   = false
-- Keeps Ctrl-/Alt- away from the IME; restore with use_ime.
-- config.macos_forward_to_ime_modifier_mask = "SHIFT"

return config
