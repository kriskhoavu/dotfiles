local wezterm = require 'wezterm'
local h       = require 'lua.helpers'
local palette = require 'lua.palette'

local pane_cwd   = {}   -- pane_id → path
local tmux_panes = {}   -- pane_id → { is_tmux, path, time }
local TMUX_CHECK_TTL = 5 -- seconds

-- The agents hub tab (lua/ai_sessions.lua) is titled when spawned.
local AGENTS_TITLE = require('lua.ai_sessions').TITLE

local function styled(tab, text)
  local p = palette.current()
  if tab.is_active then
    return { { Attribute = { Intensity = "Bold" } }, { Foreground = { Color = p.active_tab_fg } }, { Text = text } }
  end
  return { { Foreground = { Color = p.inactive_tab_fg } }, { Text = text } }
end

-- Tab title: fixed 10px padding on each side.
wezterm.on("format-tab-title", function(tab)
  local pane = tab.active_pane
  if tab.tab_title == AGENTS_TITLE then
    return styled(tab, string.format("   %d  󰚩 AGENTS   ", tab.tab_index + 1))
  end
  -- Always prefer the pane's live cwd; fall back to cache only if unavailable
  local path
  if pane.current_working_dir then
    path = pane.current_working_dir.file_path or tostring(pane.current_working_dir)
    path = path:gsub("/$", "")
    -- Update cache so other events stay consistent
    pane_cwd[pane.pane_id] = path
  else
    path = pane_cwd[pane.pane_id]
  end
  local PAD     = "   "
  return styled(tab, string.format("%s%d  %s%s", PAD, tab.tab_index + 1, path and h.short_path(path) or pane.title, PAD))
end)

-- Right status: cwd tracking + git branch
wezterm.on("update-right-status", function(window, pane)
  local pid  = pane:pane_id()

  local path

  local cwd = pane:get_current_working_dir()
  if cwd then path = (cwd.file_path or tostring(cwd)):gsub("/$", "") end

  -- tmux detection and its cwd query each cost a process: once per TMUX_CHECK_TTL.
  -- -c targets this pane's own client; untargeted, tmux answers for the last one used.
  local now = os.time()
  local t = tmux_panes[pid]
  if not t or (now - t.time) >= TMUX_CHECK_TTL then
    local proc = pane:get_foreground_process_info()
    t = { is_tmux = proc and proc.name and proc.name:match("^tmux") and true or false, time = now }
    if t.is_tmux then
      local ok, out = wezterm.run_child_process { h.TMUX, "display-message", "-c", pane:get_tty_name() or "", "-p", "#{pane_current_path}" }
      local p = ok and out and out:gsub("%s+$", "")
      if p and p ~= "" and p ~= "/" then t.path = p end
    end
    tmux_panes[pid] = t
  end
  if t.is_tmux and t.path then path = t.path end

  if path then pane_cwd[pid] = path end
  path = path or pane_cwd[pid]
  if not path then window:set_right_status(""); return end

  local status = h.git_branch(path)
  if status ~= "" then
    window:set_right_status(wezterm.format {
      { Foreground = { Color = palette.current().accent } },
      { Text = "  " .. status .. "  " },
    })
  else
    window:set_right_status("")
  end
end)
