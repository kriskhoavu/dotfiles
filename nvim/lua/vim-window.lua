-- Window/title behaviors
local api = vim.api
local fn = vim.fn
local gmatch = string.gmatch
local unpack = table.unpack or unpack

vim.opt.title = true
vim.opt.titlestring = "%t - nvim"
vim.opt.fillchars:append({ vert = "|" })

local function current_buffer_title()
    local name = fn.expand("%:t")
    if name == "" then
        name = fn.fnamemodify(fn.getcwd(), ":t")
    end
    return name:gsub("[\r\n\t]", " ")
end

local last_tmux_title = nil

-- Hand-named windows carry @manual_name, set by prefix+C and prefix+, in
-- tmux/.tmux.conf. Renaming those would throw the chosen label away on every
-- buffer switch. An empty name in tmux clears the mark and hands it back.
local function tmux_window_is_manually_named()
    local pane = vim.env.TMUX_PANE
    if not pane then
        return false
    end

    local marker = fn.system({ "tmux", "display-message", "-p", "-t", pane, "#{@manual_name}" })
    if vim.v.shell_error ~= 0 then
        return false
    end

    return vim.trim(marker) == "1"
end

local function sync_terminal_title()
    local title = current_buffer_title()
    vim.opt.titlestring = title

    if vim.env.TMUX and fn.executable("tmux") == 1 and title ~= last_tmux_title then
        if not tmux_window_is_manually_named() then
            -- Target this pane explicitly: without -t tmux renames whatever
            -- window the attached client is looking at, not necessarily ours.
            fn.system({ "tmux", "rename-window", "-t", vim.env.TMUX_PANE or "", title })
        end
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
                local right_edge = col + width
                local overlaps_vertically = row < (crow + cheight) and crow < (row + height)

                if right_edge == ccol and overlaps_vertically then
                    active_border_wins[win] = true
                end
            end
        end
    end

    for _, win in ipairs(wins) do
        if is_trackable_window(win) then
            local border_hl = active_border_wins[win] and "ActiveWindowBorder" or "InactiveWindowBorder"
            apply_window_winhighlight(win, border_hl, win == current)
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
        ctermfg = 220,
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
        fg = c.active_border,
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
