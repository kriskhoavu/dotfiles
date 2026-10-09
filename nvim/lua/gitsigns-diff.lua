-- \hd / \hD open a read-only `gitsigns://` revision buffer beside the file.
-- Getting out is the awkward part, so the teardown lives here: the revision
-- pane gets q/<esc>, and a bare `:q` from either pane is caught too.

local function is_revision_buf(buf)
    return vim.api.nvim_buf_get_name(buf):match("^gitsigns://") ~= nil
end

-- Matched by name, not by 'diff': gitsigns clears that on some teardown paths,
-- and a pane left by `:q` would then be invisible here.
local function revision_windows(tab)
    local revision = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if vim.api.nvim_win_is_valid(win) and is_revision_buf(vim.api.nvim_win_get_buf(win)) then
            table.insert(revision, win)
        end
    end
    return revision
end

-- The buffer each diff was opened from, per tab, so the file can be restored
-- when `:q` has already taken its window away.
local diff_origin = {}

-- Matched against the remembered buffer, not every window with 'diff', so an
-- unrelated diff in the same tab stays out of the teardown. With nothing to
-- match (`:Gitsigns diffthis`), clearing them all still beats leaving 'diff'.
local function origin_windows(tab)
    local origin = diff_origin[tab]
    local known = origin ~= nil and vim.api.nvim_buf_is_valid(origin)
    local wins = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if vim.api.nvim_win_is_valid(win) and not is_revision_buf(vim.api.nvim_win_get_buf(win)) then
            local match = known and vim.api.nvim_win_get_buf(win) == origin
                or (not known and vim.wo[win].diff)
            if match then
                table.insert(wins, win)
            end
        end
    end
    return wins
end

local function close_gitsigns_diff_view()
    local tab = vim.api.nvim_get_current_tabpage()
    local revision = revision_windows(tab)
    if #revision == 0 then
        return
    end
    local file = origin_windows(tab)

    -- 'diff' is a window option, so clear it while the windows exist. Only
    -- this view's panes, which `diffoff!` would not respect.
    for _, group in ipairs({ revision, file }) do
        for _, win in ipairs(group) do
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_call(win, function()
                    vim.cmd("diffoff")
                end)
            end
        end
    end

    -- `:q` in the file pane leaves the revision blob alone on screen -- an
    -- `acwrite` view of the index where `:w` stages lines. Put the file back.
    if #file == 0 then
        local keep = table.remove(revision, 1)
        local origin = diff_origin[tab]
        if origin and vim.api.nvim_buf_is_valid(origin) and keep and vim.api.nvim_win_is_valid(keep) then
            vim.api.nvim_win_set_buf(keep, origin)
        elseif keep then
            table.insert(revision, 1, keep)
        end
    end

    for _, win in ipairs(revision) do
        if vim.api.nvim_win_is_valid(win) and #vim.api.nvim_tabpage_list_wins(tab) > 1 then
            vim.api.nvim_win_close(win, true)
        end
    end

    diff_origin[tab] = nil
end

-- Keyed off an open revision pane, not `vim.wo.diff`: gitsigns resets that when
-- the buffer hides, so a toggle trusting it stacks a pane on every press.
local function toggle_gitsigns_diff(base)
    if #revision_windows(0) > 0 then
        close_gitsigns_diff_view()
        return
    end

    diff_origin[vim.api.nvim_get_current_tabpage()] = vim.api.nvim_get_current_buf()
    package.loaded.gitsigns.diffthis(base)
end

local gitsigns_diff_group = vim.api.nvim_create_augroup("GitsignsDiffViewClose", { clear = true })

-- gitsigns builds the revision buffer asynchronously, so bind the exit keys
-- when the window appears -- after `diffthis` returns is too early.
vim.api.nvim_create_autocmd("BufWinEnter", {
    group = gitsigns_diff_group,
    pattern = "gitsigns://*",
    callback = function(args)
        for _, key in ipairs({ "q", "<esc>" }) do
            vim.keymap.set("n", key, close_gitsigns_diff_view, {
                buffer = args.buf,
                desc = "Close gitsigns diff view",
            })
        end
    end,
})

-- Safety net for `:q`, `:close` and friends in the file pane, which would
-- otherwise dump the user into the revision blob with the file nowhere in sight.
vim.api.nvim_create_autocmd("WinClosed", {
    group = gitsigns_diff_group,
    callback = function(args)
        local closed = tonumber(args.match)
        if closed == nil then
            return
        end
        local ok, in_diff = pcall(function()
            return vim.wo[closed].diff
        end)
        if not ok or not in_diff then
            return
        end
        -- The window is still listed during WinClosed, so decide once it is gone.
        vim.schedule(function()
            local tab = vim.api.nvim_get_current_tabpage()
            if #revision_windows(tab) > 0 and #origin_windows(tab) == 0 then
                close_gitsigns_diff_view()
            end
        end)
    end,
})

return { toggle = toggle_gitsigns_diff }
