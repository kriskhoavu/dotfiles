-- Ctrl+Cmd+Shift+T in WezTerm: move the current file into a dedicated tmux
-- pane. Closing that pane restores the file here; regular tmux splits do not
-- participate in this handoff.
local function is_handoff_window_buffer(buf)
    local buftype = vim.bo[buf].buftype
    return buftype == "" or buftype == "terminal"
end

local function is_editing_window(win)
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
        return false
    end

    local win_buf = vim.api.nvim_win_get_buf(win)
    return vim.bo[win_buf].filetype ~= "neo-tree" and is_handoff_window_buffer(win_buf)
end

local function handoff_restore_window(preferred_win)
    if is_editing_window(preferred_win) then
        return preferred_win
    end

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_editing_window(win) then
            return win
        end
    end
end

local function handoff_replacement_buffer(excluded_buf)
    local alternate_buf = vim.fn.bufnr("#")
    if alternate_buf ~= excluded_buf
        and alternate_buf > 0
        and vim.fn.buflisted(alternate_buf) == 1
        and is_handoff_window_buffer(alternate_buf) then
        return alternate_buf
    end

    for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        if info.bufnr ~= excluded_buf and is_handoff_window_buffer(info.bufnr) then
            return info.bufnr
        end
    end
end

local function handoff_buffer_to_tmux()
    if not vim.env.TMUX or vim.fn.executable("tmux") ~= 1 then
        vim.notify("This shortcut requires Neovim running inside tmux", vim.log.levels.WARN)
        return
    end

    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype == "neo-tree" or vim.bo[buf].buftype ~= "" then
        vim.notify("Focus a file buffer before moving it to tmux", vim.log.levels.WARN)
        return
    end

    local source_win = vim.api.nvim_get_current_win()

    local path = vim.api.nvim_buf_get_name(buf)
    if path == "" then
        vim.notify("Save this buffer before moving it to tmux", vim.log.levels.WARN)
        return
    end
    path = vim.fn.fnamemodify(path, ":p")

    if vim.bo[buf].modified then
        local ok, err = pcall(vim.cmd, "write")
        if not ok then
            vim.notify("Could not save buffer: " .. err, vim.log.levels.ERROR)
            return
        end
    end

    local function restore_buffer()
        if vim.api.nvim_buf_is_valid(buf) and vim.fn.buflisted(buf) == 1 then
            return
        end

        local target_win = handoff_restore_window(source_win)
        if not target_win then
            vim.notify("No editing window available to restore " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.WARN)
            return
        end

        vim.api.nvim_set_current_win(target_win)
        if vim.api.nvim_buf_is_valid(buf) then
            vim.bo[buf].buflisted = true
            vim.api.nvim_win_set_buf(target_win, buf)
            vim.cmd("checktime " .. buf)
        else
            local ok, err = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(path))
            if not ok then
                vim.notify("Could not restore buffer: " .. err, vim.log.levels.ERROR)
                return
            end
        end
        vim.notify("Restored " .. vim.fn.fnamemodify(path, ":t") .. " from tmux")
    end

    local command = "exec nvim " .. vim.fn.shellescape(path)
    vim.system({
        "tmux", "split-window", "-h", "-c", vim.fn.fnamemodify(path, ":h"),
        "-P", "-F", "#{pane_id}", command,
    }, { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                vim.notify("Could not create tmux pane: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
                return
            end

            local pane_id = vim.trim(result.stdout)
            if pane_id == "" then
                vim.notify("tmux did not return the new pane ID", vim.log.levels.ERROR)
                return
            end

            -- Keep the editor window alive by showing another listed file before
            -- hiding this one. This avoids Neo-tree becoming the only window.
            local target_win = handoff_restore_window(source_win)
            if not target_win then
                vim.system({ "tmux", "kill-pane", "-t", pane_id })
                vim.notify("No editing window available for the tmux handoff", vim.log.levels.ERROR)
                return
            end

            local replacement_buf = handoff_replacement_buffer(buf)
            if replacement_buf then
                local switched, switch_err = pcall(vim.api.nvim_win_set_buf, target_win, replacement_buf)
                if not switched then
                    vim.system({ "tmux", "kill-pane", "-t", pane_id })
                    vim.notify("Could not show the replacement buffer: " .. switch_err, vim.log.levels.ERROR)
                    return
                end
                if vim.bo[replacement_buf].buftype == "terminal" then
                    vim.api.nvim_set_current_win(target_win)
                    vim.schedule(function()
                        if vim.api.nvim_win_is_valid(target_win)
                            and vim.api.nvim_win_get_buf(target_win) == replacement_buf then
                            vim.cmd("startinsert")
                        end
                    end)
                end
            else
                vim.api.nvim_win_call(target_win, function()
                    vim.cmd("enew")
                end)
            end

            -- Do not :bdelete: Neo-tree can take over the just-emptied editor
            -- window. Keeping this buffer unlisted removes it from bufferline
            -- while preserving a safe, exact restoration target.
            vim.bo[buf].buflisted = false

            local timer = vim.uv.new_timer()
            local restored = false
            timer:start(500, 500, vim.schedule_wrap(function()
                vim.system({ "tmux", "display-message", "-p", "-t", pane_id, "#{pane_id}" }, { text = true }, function(check)
                    vim.schedule(function()
                        if restored or (check.code == 0 and vim.trim(check.stdout) == pane_id) then
                            return
                        end
                        restored = true
                        timer:stop()
                        timer:close()
                        restore_buffer()
                    end)
                end)
            end))
        end)
    end)
end

vim.keymap.set("n", "<leader>st", handoff_buffer_to_tmux, { desc = "Move buffer to right tmux pane" })

return {}
