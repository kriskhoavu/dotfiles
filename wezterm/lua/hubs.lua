local wezterm = require 'wezterm'

-- Full-tab hubs, a list on the left and a live view on the right:
--   Ctrl+Cmd+A  agents   (scripts/ai-sessions.sh)
--   Ctrl+Cmd+O  overmind (scripts/overmind-hub.sh)
-- The key opens a hub, switches to it, or closes it and returns to the tab it
-- was opened from. A hub's list pane is recognised by its title.
local M = {}

M.WEZTERM = wezterm.executable_dir .. "/wezterm"

local titles = {}   -- every hub's list-pane title, for nav()

local function hub_tab(window, title)
  for _, tab in ipairs(window:mux_window():tabs()) do
    for _, p in ipairs(tab:panes()) do
      if p:get_title() == title then return tab end
    end
  end
end

local function tab_by_id(window, id)
  for _, tab in ipairs(window:mux_window():tabs()) do
    if tab:tab_id() == id then return tab end
  end
end

-- The toggle for the hub `script hub` draws; its list pane sets `title`.
local function hub(script, title)
  titles[title] = true
  local return_tab = nil   -- tab_id to go back to when the hub closes

  return wezterm.action_callback(function(window, pane)
    local found = hub_tab(window, title)
    local here = pane:tab()

    if found and found:tab_id() == here:tab_id() then
      -- activate first: closing the active tab makes WezTerm pick a neighbour
      local back = return_tab and tab_by_id(window, return_tab)
      if back then back:activate() end
      for _, p in ipairs(found:panes()) do
        wezterm.run_child_process { M.WEZTERM, "cli", "kill-pane", "--pane-id", tostring(p:pane_id()) }
      end
      return_tab = nil
      return
    end

    if found then
      found:activate()
      return
    end

    return_tab = here:tab_id()
    local tab = window:mux_window():spawn_tab {
      args = { script, "hub" },
      set_environment_variables = { HUB_RETURN_TAB = tostring(return_tab) },
    }
    tab:set_title(title)   -- what format-tab-title checks
  end)
end

M.AGENTS_TITLE   = "ai-sessions"
M.OVERMIND_TITLE = "overmind"
M.agents   = hub(wezterm.config_dir .. "/scripts/ai-sessions.sh", M.AGENTS_TITLE)
M.overmind = hub(wezterm.config_dir .. "/scripts/overmind-hub.sh", M.OVERMIND_TITLE)

-- Ctrl+H / Ctrl+L: hop between list and view inside a hub, plain keys elsewhere.
function M.nav(key)
  return wezterm.action_callback(function(window, pane)
    local tab = pane:tab()
    local list, other
    for _, p in ipairs(tab:panes()) do
      if titles[p:get_title()] then list = p else other = p end
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
