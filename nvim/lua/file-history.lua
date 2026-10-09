-- Back / forward navigation across files, like IntelliJ's Cmd+[ and Cmd+].
--
-- The jumplist is per-window, records only jumps (a buffer switch leaves no
-- trace) and steps through positions, not files. This is one browser-style
-- history, one entry per file.
--
-- Stepping back re-:edits the recorded path, which is why a file that was
-- closed in the meantime comes back.

local api = vim.api
local fn = vim.fn

local M = {}

local MAX_ENTRIES = 50

-- entries[1] is the oldest visit. `index` points at the entry the cursor is
-- currently sitting on, so back is index - 1 and forward is index + 1.
local entries = {}
local index = 0

-- Set while we are the ones moving the cursor, so the autocmds below don't
-- record our own jump as a fresh visit.
local navigating = false

-- Only real, on-disk file buffers take part. That leaves out terminals,
-- Neo-tree, and scheme-backed buffers such as gitsigns:// diffs, all of which
-- have nothing useful to come back to.
local function trackable(buf)
    if not api.nvim_buf_is_valid(buf) then return false end
    if vim.bo[buf].buftype ~= "" then return false end

    local name = api.nvim_buf_get_name(buf)
    if name == "" then return false end
    if name:match("^%a[%w+.-]*://") then return false end

    return true
end

-- Where the cursor is in the current window, guarded because the window can be
-- in an odd state while buffers are being torn down.
local function cursor()
    local ok, pos = pcall(api.nvim_win_get_cursor, 0)
    if not ok then return 1, 0 end
    return pos[1], pos[2]
end

-- Remember where we left the entry we are standing on, so coming back to it
-- lands on the same line rather than the top of the file.
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
        -- Re-entering the file we are already on is a move within the same
        -- entry, not a new one. Without this every window switch would pile up
        -- duplicates and a single "back" would go nowhere.
        current.lnum, current.col = lnum, col
        return
    end

    -- Visiting a new file after stepping back discards the forward entries,
    -- the way a browser drops its forward history on a new navigation.
    for i = #entries, index + 1, -1 do
        entries[i] = nil
    end

    entries[#entries + 1] = { path = path, lnum = lnum, col = col }

    if #entries > MAX_ENTRIES then
        table.remove(entries, 1)
    end

    index = #entries
end

-- An entry is worth jumping to if the file still exists, or if it is still
-- loaded in a buffer (a new file that has never been written, say).
local function reachable(entry)
    if fn.filereadable(entry.path) == 1 then return true end

    local buf = fn.bufnr(entry.path)
    return buf ~= -1 and api.nvim_buf_is_loaded(buf)
end

-- Neo-tree and floating windows are no place to open a file. Move to a real
-- editing window first, mirroring what the fzf-lua config does.
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

-- step is -1 for back, 1 for forward. Entries whose file has since vanished
-- are skipped over rather than stopping the walk.
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
