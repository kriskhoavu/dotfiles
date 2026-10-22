local wezterm = require 'wezterm'

local M = {}

M.HOME = wezterm.home_dir

-- Resolve binary paths at startup — WezTerm GUI inherits a minimal PATH
local function find_bin(name)
  for _, dir in ipairs { "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin" } do
    local f = io.open(dir .. "/" .. name, "r")
    if f then f:close(); return dir .. "/" .. name end
  end
  return name
end

M.GIT  = find_bin("git")
M.TMUX = find_bin("tmux")

function M.short_path(path)
  local rel = path:gsub("^" .. M.HOME .. "/?", "")
  if rel == "" then return "~" end
  local parent, leaf = rel:match("([^/]+)/([^/]+)$")
  return parent and (parent .. "/" .. leaf) or ("~/" .. rel)
end

-- Cache git branch per directory with a TTL to avoid spawning on every status update
local branch_cache = {}   -- path → { result, time }
local BRANCH_TTL   = 5    -- seconds; os.time() is whole seconds, so 1 never hit

-- { name, ahead, behind, upstream } for the branch at path, or nil outside a
-- branch. ahead/behind compare with the upstream as of the last fetch.
-- One git process: this runs on WezTerm's UI thread, and a slow spawn (Sophos
-- scans each one) freezes the window for as long as it takes.
function M.git_branch(path)
  local now   = os.time()
  local entry = branch_cache[path]
  if entry and (now - entry.time) < BRANCH_TTL then
    return entry.result
  end

  -- --points-at HEAD keeps the list (and its ahead/behind counting) to the
  -- branches at this commit; "*" marks the checked-out one.
  -- pcall: the spawn raises when path no longer exists, which aborted the
  -- whole status update.
  local called, ok, out = pcall(wezterm.run_child_process, {
    M.GIT, "-C", path, "for-each-ref", "--points-at", "HEAD",
    "--format=%(HEAD)|%(refname:short)|%(upstream)|%(upstream:track,nobracket)", "refs/heads/",
  })
  local result = nil
  for line in ((called and ok and out) or ""):gmatch("[^\n]+") do
    local head, name, upstream, track = line:match("^(.)|([^|]*)|([^|]*)|(.*)$")
    if head == "*" then
      result = {
        name = name,
        -- "gone": the upstream was deleted, so treat the branch as never pushed.
        upstream = upstream ~= "" and track ~= "gone",
        ahead = tonumber(track:match("ahead (%d+)")) or 0,
        behind = tonumber(track:match("behind (%d+)")) or 0,
      }
      break
    end
  end

  branch_cache[path] = { result = result, time = now }
  return result
end

return M
