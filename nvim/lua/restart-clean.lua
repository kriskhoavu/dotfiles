-- Make ":restart" mean "start over", not "restore what I had".
--
-- 0.12's :restart saves with mksession! and offers no pre-save hook, so
-- auto-session's pre_save_cmds never close Neo-tree. The session then restores
-- Neo-tree's window as an ordinary buffer under Neo-tree's own name, and
-- Neo-tree dies on "E95: Buffer with this name already exists".
--
-- Cleaning up afterwards cannot work: that buffer is created unnamed and named
-- later, while the session script still runs. So tidy on the way out, leaving
-- :restart nothing to restore, and rebuild on the way back in.

local term_env = require("term-env")

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
    term_env.without_tmux(function()
        vim.cmd("terminal")
    end)
    vim.cmd("stopinsert")

    -- "show" opens the tree without taking the focus off the terminal.
    pcall(vim.cmd, "Neotree show")
end

-- Runs in the instance being replaced, before :restart writes its session.
function M.restart()
    if package.loaded["neo-tree"] then pcall(vim.cmd, "Neotree close") end
    wipe_all_buffers()

    vim.cmd("restart")
end

-- User commands must start with a capital, so a lowercase builtin cannot be
-- shadowed. A cmdline abbreviation is the way in, anchored so only a bare
-- ":restart" is diverted.
vim.cmd([[
  cnoreabbrev <expr> restart
    \ (getcmdtype() ==# ':' && getcmdline() ==# 'restart')
    \ ? 'lua require("restart-clean").restart()'
    \ : 'restart'
]])

-- The arriving half. auto-session still restores this directory's saved session
-- on VimEnter, so clear that too before laying out the workspace.
if vim.v.startreason == "restart" then
    -- :restart re-execs with the original argv, so a file named there reopens
    -- while the outgoing process still holds its swapfile: a guaranteed false
    -- alarm. Silence it for the handover only.
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
