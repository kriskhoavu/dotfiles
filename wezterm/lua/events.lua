local wezterm = require 'wezterm'
local h       = require 'lua.helpers'

-- Caches
local pane_cwd    = {}   -- pane_id → { path }
local tmux_panes  = {}   -- pane_id → { is_tmux, time }
local TMUX_CHECK_TTL = 5 -- seconds

-- Tab title: fixed 10px padding on each side.
wezterm.on("format-tab-title", function(tab)
  local pane  = tab.active_pane
  -- Always prefer the pane's live cwd; fall back to cache only if unavailable
  local path
  if pane.current_working_dir then
    path = pane.current_working_dir.file_path or tostring(pane.current_working_dir)
    path = path:gsub("/$", "")
    -- Update cache so other events stay consistent
    pane_cwd[pane.pane_id] = { path = path }
  else
    local entry = pane_cwd[pane.pane_id]
    path = entry and entry.path
  end
  local PAD     = "   "
  local content = string.format("%s%d  %s%s", PAD, tab.tab_index + 1, path and h.short_path(path) or pane.title, PAD)

  if tab.is_active then
    return { { Attribute = { Intensity = "Bold" } }, { Foreground = { Color = "#FFFFFF" } }, { Text = content } }
  end
  return { { Foreground = { Color = "#555555" } }, { Text = content } }
end)

-- Right status: cwd tracking + git branch
wezterm.on("update-right-status", function(window, pane)
  local pid  = pane:pane_id()

  local path

  local cwd = pane:get_current_working_dir()
  if cwd then path = (cwd.file_path or tostring(cwd)):gsub("/$", "") end

  -- Throttle tmux detection — only re-check every TMUX_CHECK_TTL seconds
  local now   = os.time()
  local tentry = tmux_panes[pid]
  local is_tmux = false
  if not tentry or (now - tentry.time) >= TMUX_CHECK_TTL then
    local proc = pane:get_foreground_process_info()
    is_tmux = proc and proc.name and proc.name:match("^tmux") and true or false
    tmux_panes[pid] = { is_tmux = is_tmux, time = now }
  else
    is_tmux = tentry.is_tmux
  end

  if is_tmux then
    local ok, out = wezterm.run_child_process { h.TMUX, "display-message", "-p", "#{pane_current_path}" }
    if ok and out then
      local p = out:gsub("%s+$", "")
      if p ~= "" and p ~= "/" then path = p end
    end
  end

  if path then pane_cwd[pid] = { path = path } end
  path = path or (pane_cwd[pid] and pane_cwd[pid].path)
  if not path then window:set_right_status(""); return end

  local status = h.git_branch(path)
  if status ~= "" then
    window:set_right_status(wezterm.format {
      { Foreground = { Color = "#C9A84C" } },
      { Text = "  " .. status .. "  " },
    })
  else
    window:set_right_status("")
  end
end)
