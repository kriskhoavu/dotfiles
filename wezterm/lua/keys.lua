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
    { key = "1",          mods = "CTRL",      action = act.SendString("\x1b\\1") }, -- Ctrl+1 → nvim <leader>1
    { key = "2",          mods = "CTRL",      action = act.SendString("\x1b\\2") }, -- Ctrl+2 → nvim <leader>2
    { key = "3",          mods = "CTRL",      action = act.SendString("\x1b\\3") }, -- Ctrl+3 → nvim <leader>3
    { key = "9",          mods = "CTRL",      action = act.SendString("\x1b\\9") }, -- Ctrl+9 → nvim <leader>9
    { key = "t",          mods = "CMD",        action = act.SpawnCommandInNewTab { cwd = h.HOME } },
    { key = "1",          mods = "CMD",       action = act.ActivateTab(0) },            -- Cmd+1 → tab 1
    { key = "2",          mods = "CMD",       action = act.ActivateTab(1) },            -- Cmd+2 → tab 2
    { key = "3",          mods = "CMD",       action = act.ActivateTab(2) },            -- Cmd+3 → tab 3
    { key = "4",          mods = "CMD",       action = act.ActivateTab(3) },            -- Cmd+4 → tab 4
    { key = "5",          mods = "CMD",       action = act.ActivateTab(4) },            -- Cmd+5 → tab 5
    { key = "6",          mods = "CMD",       action = act.ActivateTab(5) },            -- Cmd+6 → tab 6
    { key = "7",          mods = "CMD",       action = act.ActivateTab(6) },            -- Cmd+7 → tab 7
    { key = "8",          mods = "CMD",       action = act.ActivateTab(7) },            -- Cmd+8 → tab 8
    { key = "9",          mods = "CMD",       action = act.ActivateTab(-1) },           -- Cmd+9 → last tab
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
