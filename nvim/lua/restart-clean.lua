-- Make ":restart" mean "start over", not "restore what I had".
--
-- Neovim 0.12's :restart saves the live state with mksession! and sources it in
-- the new instance (see runtime/lua/vim/_core/server.lua). It offers no
-- pre-save hook, so auto-session's pre_save_cmds -- which close Neo-tree for
-- exactly this reason -- never run. The session then brings Neo-tree's window
-- back as an ordinary buffer carrying Neo-tree's own name, and Neo-tree fails
-- with "E95: Buffer with this name already exists" when it tries to create the
-- real one. The stale buffer also shows up as a bogus tab in the bufferline and
-- is what holds the focus on arrival.
--
-- Cleaning up afterwards cannot work: the session creates that buffer unnamed
-- and names it later, and Neo-tree reaches it while the session script is still
-- running, before any autocmd of ours could rename or remove it. So the tidying
-- happens on the way out instead, leaving :restart nothing to restore, and the
-- workspace is rebuilt on the way back in.

local api = vim.api

local M = {}

local group = api.nvim_create_augroup("RestartClean", { clear = true })

local function wipe_all_buffers()
    for _, buf in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_valid(buf) then
            pcall(api.nvim_buf_delete, buf, { force = true })
        end
    end
end

-- Wiping every buffer leaves Neovim to create an empty one; turning that into
-- the terminal means the terminal is what has focus, as on a normal start.
local function open_workspace()
    vim.cmd("silent! only")
    vim.cmd("terminal")
    vim.cmd("stopinsert")

    -- "show" opens the tree without taking the focus off the terminal.
    pcall(vim.cmd, "Neotree show")
end

-- Runs in the instance being replaced, before :restart writes its session.
function M.restart()
    pcall(vim.cmd, "Neotree close")
    wipe_all_buffers()

    vim.cmd("restart")
end

-- ":restart" is a built-in lowercase command, and user commands must start with
-- a capital, so it cannot be shadowed the usual way. A command-line abbreviation
-- is the way in; it is deliberately anchored so that only a bare ":restart"
-- is diverted, leaving ":restart!" and any argument form alone.
vim.cmd([[
  cnoreabbrev <expr> restart
    \ (getcmdtype() ==# ':' && getcmdline() ==# 'restart')
    \ ? 'lua require("restart-clean").restart()'
    \ : 'restart'
]])

-- The arriving half. auto-session still restores this directory's saved session
-- on VimEnter, so clear that too before laying out the workspace.
if vim.v.startreason == "restart" then
    -- :restart re-execs with the original argv, so any file named on the
    -- command line is opened again while the outgoing process still holds its
    -- swapfile -- a guaranteed false alarm. Silence swapfile warnings for the
    -- handover only, and hand shortmess back once we are on our feet.
    local shortmess = vim.o.shortmess
    vim.opt.shortmess:append("A")

    api.nvim_create_autocmd("VimEnter", {
        group = group,
        once = true,
        callback = function()
            vim.schedule(function()
                wipe_all_buffers()
                open_workspace()
                vim.o.shortmess = shortmess
            end)
        end,
    })
end

return M
