-- Make ":restart" start clean instead of restoring the session.
--
-- 0.12's :restart uses mksession! with no pre-save hook, so auto-session never
-- closes Neo-tree, and the restored Neo-tree buffer dies on "E95: Buffer with
-- this name already exists". It is named mid-script, so post-cleanup cannot
-- catch it: tidy on the way out, rebuild on the way in.

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

-- Turn the empty buffer left after the wipe into a focused terminal, as on a
-- normal start.
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

-- A lowercase builtin cannot be shadowed by a user command, so use an
-- abbreviation that only fires on a bare ":restart".
vim.cmd([[
  cnoreabbrev <expr> restart
    \ (getcmdtype() ==# ':' && getcmdline() ==# 'restart')
    \ ? 'lua require("restart-clean").restart()'
    \ : 'restart'
]])

-- Incoming side: auto-session still restores on VimEnter, so clear that too.
if vim.v.startreason == "restart" then
    -- :restart re-execs the original argv, so a named file reopens while the old
    -- process holds its swapfile. Silence that false alarm for the handover.
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
