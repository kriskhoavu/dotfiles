local wezterm = require 'wezterm'
local act     = wezterm.action
local h       = require 'lua.helpers'

return function(config)
  -- Option treated as Alt (matching iTerm2 "Treat Option as Alt")
  config.send_composed_key_when_left_alt_is_pressed  = false
  config.send_composed_key_when_right_alt_is_pressed = false

  config.keys = {
    { key = "LeftArrow",  mods = "OPT",       action = act.SendString("\x1bb") },    -- Option+Left  → word back
    { key = "RightArrow", mods = "OPT",       action = act.SendString("\x1bf") },    -- Option+Right → word fwd
    { key = "Enter",      mods = "OPT",       action = act.SendString("\x1b\r") },   -- Option+Enter → Alt+Enter
    { key = "d",          mods = "CTRL|CMD|SHIFT", action = act.SendString("\\sd") }, -- Ctrl+Cmd+Shift+D → nvim <leader>sd
    { key = "t",          mods = "CMD",        action = act.SpawnCommandInNewTab { cwd = h.HOME } },
    { key = "c",          mods = "CTRL",       action = wezterm.action_callback(function(window, pane)
      local sel = window:get_selection_text_for_pane(pane)
      if sel and sel ~= "" then
        window:perform_action(act.CopyTo("Clipboard"), pane)
      else
        window:perform_action(act.SendKey { key = "c", mods = "CTRL" }, pane)
      end
    end) },
  }
end
