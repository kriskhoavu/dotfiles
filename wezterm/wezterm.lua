local wezterm = require 'wezterm'
local act     = wezterm.action
local config  = wezterm.config_builder()

-- Resolve binary paths at startup — WezTerm GUI inherits a minimal PATH
local function find_bin(name)
  for _, dir in ipairs { "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin" } do
    local f = io.open(dir .. "/" .. name, "r")
    if f then f:close(); return dir .. "/" .. name end
  end
  return name
end
local GIT  = find_bin("git")
local TMUX = find_bin("tmux")
local HOME = wezterm.home_dir

-- Caches
-- pane_cwd[pane_id]    = { path, at }   — cwd per pane (throttled tmux queries)
-- git_cache[path]      = { status, at } — git branch status per directory
-- last_active_pane[wid] = pane_id       — detect tab switches for instant refresh
local pane_cwd        = {}
local git_cache       = {}
local last_active_pane = {}  -- [window_id] -> pane_id

local function short_path(path)
  local rel = path:gsub("^" .. HOME .. "/?", "")
  if rel == "" then return "~" end
  local parent, leaf = rel:match("([^/]+)/([^/]+)$")
  return parent and (parent .. "/" .. leaf) or ("~/" .. rel)
end

local function git_status(path, force)
  local now   = os.time()
  local entry = git_cache[path]
  if not force and entry and (now - entry.at) < 60 then return entry.status end

  local status = ""
  local ok, branch = wezterm.run_child_process { GIT, "-C", path, "branch", "--show-current" }
  if ok and branch and branch:match("%S") then
    branch = branch:gsub("%s+$", "")
    status = " " .. branch
    local _, behind = wezterm.run_child_process { GIT, "-C", path, "rev-list", "--count", "HEAD..@{u}" }
    local _, ahead  = wezterm.run_child_process { GIT, "-C", path, "rev-list", "--count", "@{u}..HEAD" }
    local b = tonumber((behind or ""):match("%d+")) or 0
    local a = tonumber((ahead  or ""):match("%d+")) or 0
    if b > 0 then status = status .. "  ⇣" .. b end
    if a > 0 then status = status .. "  ⇡" .. a end
  end

  git_cache[path] = { status = status, at = now }
  return status
end

-- Tab title: index + last-2-dir path, from shared cache so tmux works
wezterm.on("format-tab-title", function(tab)
  local pane  = tab.active_pane
  local entry = pane_cwd[pane.pane_id]
  local path  = entry and entry.path
               or (pane.current_working_dir
                   and (pane.current_working_dir.file_path or tostring(pane.current_working_dir)))
  local label = string.format("  %d  %s  ", tab.tab_index + 1, path and short_path(path) or pane.title)

  if tab.is_active then
    return { { Attribute = { Intensity = "Bold" } }, { Foreground = { Color = "#FFFFFF" } }, { Text = label } }
  end
  return { { Foreground = { Color = "#555555" } }, { Text = label } }
end)

-- Right status: cwd tracking + git branch/sync indicator
-- Also populates pane_cwd for format-tab-title
wezterm.on("update-right-status", function(window, pane)
  local wid  = window:window_id()
  local pid  = pane:pane_id()
  local now  = os.time()

  -- Detect tab switch → force cache bypass for immediate refresh
  local tab_switched = last_active_pane[wid] ~= pid
  last_active_pane[wid] = pid

  local path

  local cwd = pane:get_current_working_dir()
  if cwd then path = (cwd.file_path or tostring(cwd)):gsub("/$", "") end

  local proc = pane:get_foreground_process_info()
  if proc and proc.name and proc.name:match("^tmux") then
    local cached = pane_cwd[pid]
    if tab_switched or not cached or (now - cached.at) >= 60 then
      local ok, out = wezterm.run_child_process { TMUX, "display-message", "-p", "#{pane_current_path}" }
      if ok and out then
        local p = out:gsub("%s+$", "")
        if p ~= "" and p ~= "/" then path = p end
      end
      pane_cwd[pid] = { path = path, at = now }
    else
      path = cached.path
    end
  elseif path then
    pane_cwd[pid] = { path = path, at = now }
  end

  path = path or (pane_cwd[pid] and pane_cwd[pid].path)
  if not path then window:set_right_status(""); return end

  local status = git_status(path, tab_switched)
  if status ~= "" then
    window:set_right_status(wezterm.format {
      { Foreground = { Color = "#C9A84C" } },
      { Text = "  " .. status .. "  " },
    })
  else
    window:set_right_status("")
  end
end)

-- ── Font ──────────────────────────────────────────────────────────────────────
config.font      = wezterm.font("MesloLGS NF", { weight = "Regular" })
config.font_size = 14.0
config.use_cap_height_to_scale_fallback_fonts = true
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }  -- no ligatures
config.font_rules = {
  { italic = true, font = wezterm.font("MesloLGS NF", { weight = "Regular", italic = false }) },
}

-- ── Colors (iTerm2 "Kris" dark profile) ──────────────────────────────────────
config.colors = {
  foreground    = "#3AD4FF",
  background    = "#151414",
  cursor_bg     = "#BBBBBB",
  cursor_border = "#BBBBBB",
  cursor_fg     = "#FFFBFB",
  selection_bg  = "#FF9D1F",
  selection_fg  = "#000000",
  ansi    = { "#000000", "#BB0000", "#9CFFFC", "#BBBB00", "#DE5000", "#BB00BB", "#00BBBB", "#BBBBBB" },
  brights = { "#9BCB83", "#FF5555", "#55FF55", "#FFFF55", "#5555FF", "#FF55FF", "#60F7F9", "#FFFFFF" },
  tab_bar = {
    background         = "#1A1919",
    active_tab         = { bg_color = "#590000", fg_color = "#FFFFFF", intensity = "Bold" },
    inactive_tab       = { bg_color = "#1A1919", fg_color = "#555555" },
    inactive_tab_hover = { bg_color = "#1E1D1D", fg_color = "#AAAAAA" },
    new_tab            = { bg_color = "#1A1919", fg_color = "#444444" },
    new_tab_hover      = { bg_color = "#1E1D1D", fg_color = "#BBBBBB" },
  },
}

-- ── Window ────────────────────────────────────────────────────────────────────
config.window_background_opacity    = 0.92
config.macos_window_background_blur = 10
config.text_background_opacity      = 1.0
config.window_decorations           = "RESIZE"
config.window_padding               = { left = 4, right = 4, top = 4, bottom = 4 }

-- ── Cursor (iTerm2: Underline, Blinking) ─────────────────────────────────────
config.default_cursor_style = "BlinkingUnderline"
config.cursor_blink_rate    = 500

-- ── Tab bar ───────────────────────────────────────────────────────────────────
config.use_fancy_tab_bar            = true
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom            = false
config.tab_max_width                = 44

config.window_frame = {
  font                            = wezterm.font("MesloLGS NF", { weight = "Bold" }),
  font_size                       = 13.0,
  active_titlebar_bg              = "#1A1919",
  inactive_titlebar_bg            = "#151414",
  active_titlebar_fg              = "#DDDDDD",
  inactive_titlebar_fg            = "#666666",
  active_titlebar_border_bottom   = "#C9A84C",
  inactive_titlebar_border_bottom = "#151414",
  button_fg                       = "#AAAAAA",
  button_bg                       = "#1A1919",
  button_hover_fg                 = "#FFFFFF",
  button_hover_bg                 = "#252424",
}

-- ── Misc ──────────────────────────────────────────────────────────────────────
config.scrollback_lines          = 10000
config.term                      = "xterm-256color"
config.initial_cols              = 80
config.initial_rows              = 25
config.audible_bell              = "Disabled"
config.visual_bell               = { fade_in_duration_ms = 75, fade_out_duration_ms = 75 }
config.window_close_confirmation = "NeverPrompt"

-- ── Key bindings ──────────────────────────────────────────────────────────────
-- Option treated as Alt (matching iTerm2 "Treat Option as Alt")
config.send_composed_key_when_left_alt_is_pressed  = false
config.send_composed_key_when_right_alt_is_pressed = false

config.keys = {
  { key = "LeftArrow",  mods = "OPT",       action = act.SendString("\x1bb") },   -- Option+Left  → word back
  { key = "RightArrow", mods = "OPT",       action = act.SendString("\x1bf") },   -- Option+Right → word fwd
  { key = "d",          mods = "CMD|SHIFT",  action = act.SendString("\\sd") },   -- Cmd+Shift+D  → nvim <leader>sd
  { key = "t",          mods = "CMD",        action = act.SpawnCommandInNewTab { cwd = HOME } }, -- Cmd+T → home
}

return config
