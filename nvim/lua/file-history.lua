-- Browser-style back / forward across files, like IntelliJ's Cmd+[ / Cmd+].
-- The jumplist is per-window, ignores buffer switches and steps positions, not
-- files. Back re-:edits the path, so closed files come back.

local api = vim.api
local fn = vim.fn

local M = {}

local MAX_ENTRIES = 50

-- entries[1] is the oldest; `index` is the current entry.
local entries = {}
local index = 0

-- Set while we move the cursor, so our own jump is not recorded.
local navigating = false

-- Only on-disk file buffers: no terminals, Neo-tree or scheme:// buffers.
local function trackable(buf)
    if not api.nvim_buf_is_valid(buf) then return false end
    if vim.bo[buf].buftype ~= "" then return false end

    local name = api.nvim_buf_get_name(buf)
    if name == "" then return false end
    if name:match("^%a[%w+.-]*://") then return false end

    return true
end

-- Guarded: the window can be odd while buffers are torn down.
local function cursor()
    local ok, pos = pcall(api.nvim_win_get_cursor, 0)
    if not ok then return 1, 0 end
    return pos[1], pos[2]
end

-- Remember the line, so coming back lands there, not at the top.
local function save_position()
    local entry = entries[index]
    if not entry then return end
    if entry.path ~= api.nvim_buf_get_name(0) then return end

    entry.lnum, entry.col = cursor()
end

local function record(buf)
    local path = api.nvim_buf_get_name(buf)
    local lnum, col = cursor()

    local current = entries[index]
    if current and current.path == path then
        -- Same file = a move within the entry, else window switches pile up duplicates.
        current.lnum, current.col = lnum, col
        return
    end

    -- A new visit after stepping back drops forward history, as in a browser.
    for i = #entries, index + 1, -1 do
        entries[i] = nil
    end

    entries[#entries + 1] = { path = path, lnum = lnum, col = col }

    if #entries > MAX_ENTRIES then
        table.remove(entries, 1)
    end

    index = #entries
end

-- Jumpable if the file exists or is still loaded (e.g. never written).
local function reachable(entry)
    if fn.filereadable(entry.path) == 1 then return true end

    local buf = fn.bufnr(entry.path)
    return buf ~= -1 and api.nvim_buf_is_loaded(buf)
end

-- Move out of Neo-tree / floats to an editing window first, as fzf-lua does.
local function focus_edit_window()
    local buf = api.nvim_get_current_buf()
    if vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "neo-tree" then
        return
    end

    for _, win in ipairs(require("edit-windows").list()) do
        if vim.bo[api.nvim_win_get_buf(win)].buftype == "" then
            api.nvim_set_current_win(win)
            return
        end
    end
end

local function jump(entry)
    focus_edit_window()

    vim.cmd("edit " .. fn.fnameescape(entry.path))

    local last = api.nvim_buf_line_count(0)
    pcall(api.nvim_win_set_cursor, 0, { math.min(entry.lnum, last), entry.col })
end

-- step: -1 back, 1 forward. Vanished files are skipped.
local function navigate(step, what)
    save_position()

    local target = index + step
    while entries[target] and not reachable(entries[target]) do
        target = target + step
    end

    local entry = entries[target]
    if not entry then
        vim.notify("No " .. what .. " file in history", vim.log.levels.INFO)
        return
    end

    navigating = true
    local ok, err = pcall(jump, entry)
    navigating = false

    if not ok then
        vim.notify("Could not open " .. entry.path .. ": " .. tostring(err), vim.log.levels.WARN)
        return
    end

    index = target
end

function M.back()
    navigate(-1, "previous")
end

function M.forward()
    navigate(1, "next")
end

local group = api.nvim_create_augroup("FileHistory", { clear = true })

api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
        if navigating then return end
        if not trackable(args.buf) then return end
        if args.buf ~= api.nvim_get_current_buf() then return end

        record(args.buf)
    end,
})

api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(args)
        if navigating then return end
        if not trackable(args.buf) then return end

        save_position()
    end,
})

vim.keymap.set("n", "<leader>[", M.back, { desc = "Back to previous file" })
vim.keymap.set("n", "<leader>]", M.forward, { desc = "Forward to next file" })

return M
