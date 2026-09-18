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
-- 60, not 120: a held key repeats every 30ms, so 60 is already double what any
-- of this can show.
config.max_fps                   = 60
-- Paces the cursor blink, which was repainting continuously: wezterm-gui sat at
-- 17-21% CPU idle, 2-6% after this and the Constant ease in appearance.lua.
config.animation_fps             = 1
-- IME off: with it on, macOS buffers a held key as marked text and delivers the
-- lot on release -- j from line 1 crawls to 10, sticks, then jumps to the end.
-- Nothing below sees it (nvim eats a 250-key burst cleanly, tmux or not), and
-- selecting a plain layout does not help; tested with ABC current. The cost is
-- Telex and any other composed input inside the terminal.
config.use_ime                   = false
-- Kept Ctrl-/Alt- bindings away from the IME. Flips back with use_ime.
-- config.macos_forward_to_ime_modifier_mask = "SHIFT"

return config
