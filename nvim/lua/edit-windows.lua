-- Editing windows: not floating, not the Neo-tree sidebar.
local api = vim.api
local M = {}

function M.is_editing(win)
    return api.nvim_win_get_config(win).relative == ""
        and vim.bo[api.nvim_win_get_buf(win)].filetype ~= "neo-tree"
end

-- Editing windows of a tabpage (default: current), in layout order.
function M.list(tab)
    return vim.tbl_filter(M.is_editing, api.nvim_tabpage_list_wins(tab or 0))
end

return M
