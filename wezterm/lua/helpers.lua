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
local BRANCH_TTL   = 1    -- seconds

function M.git_branch(path)
  local now   = os.time()
  local entry = branch_cache[path]
  if entry and (now - entry.time) < BRANCH_TTL then
    return entry.result
  end

  local ok, branch = wezterm.run_child_process { M.GIT, "-C", path, "branch", "--show-current" }
  local result = ""
  if ok and branch and branch:match("%S") then
    result = " " .. branch:gsub("%s+$", "")
  end

  branch_cache[path] = { result = result, time = now }
  return result
end

return M
