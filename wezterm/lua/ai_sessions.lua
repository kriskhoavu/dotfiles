local wezterm = require 'wezterm'

-- Ctrl+Cmd+A: the agents hub (scripts/ai-sessions.sh), a tab with the agent
-- list on the left and a live view on the right. Open it, switch to it, or
-- close it and return to the tab it was opened from. The hub's list pane is
-- recognised by its title.
local M = {}

M.SCRIPT = wezterm.config_dir .. "/scripts/ai-sessions.sh"
M.TITLE  = "ai-sessions"
M.WEZTERM = wezterm.executable_dir .. "/wezterm"

local return_tab = nil   -- tab_id to go back to when the hub closes

local function hub_tab(window)
  for _, tab in ipairs(window:mux_window():tabs()) do
    for _, p in ipairs(tab:panes()) do
      if p:get_title() == M.TITLE then return tab end
    end
  end
end

local function tab_by_id(window, id)
  for _, tab in ipairs(window:mux_window():tabs()) do
    if tab:tab_id() == id then return tab end
  end
end

M.toggle = wezterm.action_callback(function(window, pane)
  local hub = hub_tab(window)
  local here = pane:tab()

  if hub and hub:tab_id() == here:tab_id() then
    -- activate first: closing the active tab makes WezTerm pick a neighbour
    local back = return_tab and tab_by_id(window, return_tab)
    if back then back:activate() end
    for _, p in ipairs(hub:panes()) do
      wezterm.run_child_process { M.WEZTERM, "cli", "kill-pane", "--pane-id", tostring(p:pane_id()) }
    end
    return_tab = nil
    return
  end

  if hub then
    hub:activate()
    return
  end

  return_tab = here:tab_id()
  window:mux_window():spawn_tab {
    args = { M.SCRIPT, "hub" },
    set_environment_variables = { AI_SESSIONS_RETURN_TAB = tostring(return_tab) },
  }
end)

-- Ctrl+H / Ctrl+L: hop between list and view inside the hub, plain keys elsewhere.
function M.nav(key)
  return wezterm.action_callback(function(window, pane)
    local tab = pane:tab()
    local list, other
    for _, p in ipairs(tab:panes()) do
      if p:get_title() == M.TITLE then list = p else other = p end
    end
    if list and other then
      local target = (key == "l") and other or list
      if target:pane_id() ~= pane:pane_id() then target:activate() end
      return
    end
    window:perform_action(wezterm.action.SendKey { key = key, mods = "CTRL" }, pane)
  end)
end

return M
