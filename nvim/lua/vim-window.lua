-- Window/title behaviors
local api = vim.api
local fn = vim.fn
local gmatch = string.gmatch
local unpack = table.unpack or unpack

vim.opt.title = true
vim.opt.fillchars:append({ vert = "|" })

local function current_buffer_title()
    local name = fn.expand("%:t")
    if name == "" then
        name = fn.fnamemodify(fn.getcwd(), ":t")
    end
    return name:gsub("[\r\n\t]", " ")
end

local last_tmux_title = nil
local has_tmux = vim.env.TMUX and vim.env.TMUX_PANE and fn.executable("tmux") == 1
local rename_seq = 0

-- Renames this pane's tmux window after the buffer, off the main loop: two
-- blocking tmux calls cost ~30ms per buffer switch. Windows named by hand
-- carry @manual_name (prefix+C / prefix+, in tmux/.tmux.conf) and are left
-- alone. The sequence number drops a rename overtaken by a newer switch.
local function rename_tmux_window(title)
    rename_seq = rename_seq + 1
    local seq, pane = rename_seq, vim.env.TMUX_PANE
    vim.system({ "tmux", "display-message", "-p", "-t", pane, "#{@manual_name}" }, { text = true }, function(r)
        if seq ~= rename_seq or r.code ~= 0 or vim.trim(r.stdout) == "1" then return end
        vim.system({ "tmux", "rename-window", "-t", pane, title })
    end)
end

local function sync_terminal_title()
    local title = current_buffer_title()
    vim.opt.titlestring = title

    if has_tmux and title ~= last_tmux_title then
        rename_tmux_window(title)
        last_tmux_title = title
    end
end

api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter", "BufFilePost" }, {
    group = api.nvim_create_augroup("dynamic_terminal_title", { clear = true }),
    callback = sync_terminal_title,
})

local managed_hl_keys = {
    WinSeparator = true,
    VertSplit = true,
    WinBar = true,
    WinBarNC = true,
    StatusLine = true,
    StatusLineNC = true,
    Normal = true,
    NormalNC = true,
    EndOfBuffer = true,
    SignColumn = true,
    LineNr = true,
    CursorLineNr = true,
    NeoTreeNormal = true,
    NeoTreeNormalNC = true,
    NeoTreeEndOfBuffer = true,
    NeoTreeSignColumn = true,
}

local function split_keep_unmanaged_winhighlight(existing)
    local parts = {}
    for chunk in gmatch(existing, "[^,]+") do
        local key, value = chunk:match("^%s*([^:]+):([^:]+)%s*$")
        if key and value and not managed_hl_keys[key] then
            parts[#parts + 1] = key .. ":" .. value
        end
    end
    return parts
end

-- The winbar is the window's top border: an empty bar padded with "─".
local TOP_BORDER = "%="

local function set_top_border(win)
    local winbar = vim.wo[win].winbar
    -- Leave a winbar some other feature drew.
    if winbar ~= "" and winbar ~= TOP_BORDER then
        return
    end
    if winbar ~= TOP_BORDER then
        vim.wo[win].winbar = TOP_BORDER
    end
    local fillchars = api.nvim_get_option_value("fillchars", { scope = "global" }) .. ",wbr:─"
    if api.nvim_get_option_value("fillchars", { win = win }) ~= fillchars then
        api.nvim_set_option_value("fillchars", fillchars, { scope = "local", win = win })
    end
end

local function is_trackable_window(win)
    if not api.nvim_win_is_valid(win) then
        return false
    end

    if api.nvim_win_get_config(win).relative ~= "" then
        return false
    end

    return true
end

local function apply_window_winhighlight(win, border_hl, is_active)
    local parts = split_keep_unmanaged_winhighlight(vim.wo[win].winhighlight)
    local is_neotree = vim.bo[api.nvim_win_get_buf(win)].filetype == "neo-tree"
    parts[#parts + 1] = "WinSeparator:" .. border_hl
    parts[#parts + 1] = "VertSplit:" .. border_hl

    -- Top (winbar) and bottom (statusline) edges.
    local edge_hl = is_active and "ActiveWindowBorder" or "InactiveWindowBorder"
    parts[#parts + 1] = "WinBar:" .. edge_hl
    parts[#parts + 1] = "WinBarNC:" .. edge_hl
    if is_active then
        parts[#parts + 1] = "StatusLine:ActiveWindowStatusLine"
        parts[#parts + 1] = "StatusLineNC:ActiveWindowStatusLine"
    end

    if is_active then
        parts[#parts + 1] = "Normal:ActiveWindowNormal"
        parts[#parts + 1] = "NormalNC:ActiveWindowNormal"
        parts[#parts + 1] = "EndOfBuffer:ActiveWindowNormal"
        parts[#parts + 1] = "SignColumn:ActiveWindowNormal"
        parts[#parts + 1] = "LineNr:ActiveWindowLineNr"
        parts[#parts + 1] = "CursorLineNr:ActiveWindowCursorLineNr"
    else
        parts[#parts + 1] = "Normal:InactiveWindowNormal"
        parts[#parts + 1] = "NormalNC:InactiveWindowNormal"
        parts[#parts + 1] = "EndOfBuffer:InactiveWindowNormal"
        parts[#parts + 1] = "SignColumn:InactiveWindowNormal"
        parts[#parts + 1] = "LineNr:InactiveWindowLineNr"
        parts[#parts + 1] = "CursorLineNr:InactiveWindowLineNr"
    end

    if is_neotree then
        local prefix = is_active and "Active" or "Inactive"
        parts[#parts + 1] = "NeoTreeNormal:" .. prefix .. "NeoTreeNormal"
        parts[#parts + 1] = "NeoTreeNormalNC:" .. prefix .. "NeoTreeNormal"
        parts[#parts + 1] = "NeoTreeEndOfBuffer:" .. prefix .. "NeoTreeEndOfBuffer"
        parts[#parts + 1] = "NeoTreeSignColumn:" .. prefix .. "NeoTreeSignColumn"
    end

    local winhighlight = table.concat(parts, ",")
    if vim.wo[win].winhighlight ~= winhighlight then
        vim.wo[win].winhighlight = winhighlight
    end
end

local function clear_managed_winhighlight(win)
    local winhighlight = table.concat(split_keep_unmanaged_winhighlight(vim.wo[win].winhighlight), ",")
    if vim.wo[win].winhighlight ~= winhighlight then
        vim.wo[win].winhighlight = winhighlight
    end
end

local function refresh_window_borders()
    local wins = api.nvim_tabpage_list_wins(0)
    local current = api.nvim_get_current_win()
    local active_border_wins = { [current] = true }

    if api.nvim_win_is_valid(current) and is_trackable_window(current) then
        local crow, ccol = unpack(api.nvim_win_get_position(current))
        local cheight = api.nvim_win_get_height(current)

        for _, win in ipairs(wins) do
            if win ~= current and is_trackable_window(win) then
                local row, col = unpack(api.nvim_win_get_position(win))
                local width = api.nvim_win_get_width(win)
                local height = api.nvim_win_get_height(win)
                -- The separator column sits between the two windows.
                local separator_col = col + width
                local overlaps_vertically = row < (crow + cheight) and crow < (row + height)

                if separator_col + 1 == ccol and overlaps_vertically then
                    active_border_wins[win] = true
                end
            end
        end
    end

    for _, win in ipairs(wins) do
        if is_trackable_window(win) then
            local border_hl = active_border_wins[win] and "ActiveWindowBorder" or "InactiveWindowBorder"
            apply_window_winhighlight(win, border_hl, win == current)
            set_top_border(win)
        else
            clear_managed_winhighlight(win)
        end
    end
end

local function set_window_border_highlights()
    -- A muted surface for the focused window, one step off the editor ground.
    -- Per appearance: see lua/theme-mode.lua.
    local c = require("theme-mode").colors
    local active_background = c.active_bg
    local inactive_background = c.inactive_bg

    local function copy_highlight_with_background(source, target, background)
        local highlight = api.nvim_get_hl(0, { name = source, link = false })
        highlight.bg = background
        api.nvim_set_hl(0, target, highlight)
    end

    api.nvim_set_hl(0, "ActiveWindowBorder", {
        fg = c.active_border,
        ctermfg = 179,
        bold = true,
    })
    api.nvim_set_hl(0, "ActiveWindowStatusLine", {
        fg = c.active_border_fg,
        bg = c.active_border,
        ctermfg = 235,
        ctermbg = 179,
        bold = true,
    })
    api.nvim_set_hl(0, "InactiveWindowBorder", {
        fg = c.inactive_border,
        ctermfg = 239,
    })
    api.nvim_set_hl(0, "ActiveWindowNormal", {
        bg = active_background,
    })
    api.nvim_set_hl(0, "ActiveWindowLineNr", {
        fg = c.active_linenr,
        bg = active_background,
    })
    api.nvim_set_hl(0, "ActiveWindowCursorLineNr", {
        fg = c.active_cursorlinenr,
        bg = active_background,
        bold = true,
    })
    api.nvim_set_hl(0, "InactiveWindowNormal", {
        bg = inactive_background,
    })
    api.nvim_set_hl(0, "InactiveWindowLineNr", {
        fg = c.inactive_linenr,
        bg = inactive_background,
    })
    copy_highlight_with_background("NeoTreeNormal", "ActiveNeoTreeNormal", active_background)
    copy_highlight_with_background("NeoTreeNormal", "InactiveNeoTreeNormal", inactive_background)
    copy_highlight_with_background("NeoTreeEndOfBuffer", "ActiveNeoTreeEndOfBuffer", active_background)
    copy_highlight_with_background("NeoTreeEndOfBuffer", "InactiveNeoTreeEndOfBuffer", inactive_background)
    copy_highlight_with_background("NeoTreeSignColumn", "ActiveNeoTreeSignColumn", active_background)
    copy_highlight_with_background("NeoTreeSignColumn", "InactiveNeoTreeSignColumn", inactive_background)
end

local border_group = api.nvim_create_augroup("active_window_border", { clear = true })

api.nvim_create_autocmd({ "ColorScheme" }, {
    group = border_group,
    callback = function()
        set_window_border_highlights()
        refresh_window_borders()
    end,
})

api.nvim_create_autocmd({ "VimEnter", "BufWinEnter", "WinEnter", "WinLeave", "TabEnter" }, {
    group = border_group,
    callback = refresh_window_borders,
})

-- Neo-tree rewrites its window's 'winhighlight' on BufEnter; reapply after it.
api.nvim_create_autocmd("BufEnter", {
    group = border_group,
    callback = function()
        vim.schedule(refresh_window_borders)
    end,
})

api.nvim_create_autocmd("FileType", {
    group = border_group,
    pattern = "neo-tree",
    callback = function()
        vim.schedule(function()
            set_window_border_highlights()
            refresh_window_borders()
        end)
    end,
})

set_window_border_highlights()
refresh_window_borders()
