-- Window/title behaviors
vim.opt.title = true -- Let terminal display title updates from Neovim
vim.opt.titlestring = "%t - nvim"

local function current_buffer_title()
    local name = vim.fn.expand("%:t")
    if name == "" then
        local cwd_tail = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
        name = cwd_tail ~= "" and cwd_tail
    end
    return (name:gsub("[\r\n\t]", " "))
end

local function sync_terminal_title()
    local title = current_buffer_title()
    vim.opt.titlestring = title

    -- Inside tmux, rename tmux window so iTerm2 title can follow it.
    if vim.env.TMUX and vim.fn.executable("tmux") == 1 then
        vim.fn.system({"tmux", "rename-window", title})
    end
end

local title_group = vim.api.nvim_create_augroup("dynamic_terminal_title", {
    clear = true
})

vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter", "WinEnter", "BufFilePost"}, {
    group = title_group,
    callback = sync_terminal_title
})
