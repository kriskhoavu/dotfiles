vim.loader.enable() -- Faster Lua module loading (Neovim 0.9.1+)

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

require("bigfile")
require("vim-helpers")
require("vim-options")
require("vim-window")
require("vim-clipboard")
require("floating-helpers")
require("floating-terminal")
require("markdown-runner")
require("file-history")
require("restart-clean")
require("org-git")
require("tmux-nav")
require("lazy").setup({
    { import = "plugins" },
    { import = "themes" },
}, {
    rocks = { enabled = false },
    performance = {
        rtp = { disabled_plugins = { "gzip", "tarPlugin", "zipPlugin", "tutor", "netrwPlugin" } },
    },
})

-- Set Theme
vim.cmd.colorscheme("onedark")

-- Auto-reload files changed outside of Neovim (autoread is on by default).
-- checktime raises E11 in the command-line window.
-- FocusGained covers edits made in another tmux pane (focus-events is on).
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  callback = function()
    if vim.fn.getcmdwintype() == "" then vim.cmd.checktime() end
  end,
})

-- Auto-save. Leaving a buffer writes only that buffer, and only if it changed:
-- :wall wrote every modified buffer, and each write starts a jdtls build and a
-- Neo-tree git status on Discovery. Losing focus still writes them all.
-- BufLeave stays so lazygit (\3) and Diffview see the edit just made.
vim.api.nvim_create_autocmd("BufLeave", {
  callback = function(args)
    local bo = vim.bo[args.buf]
    if bo.modified and bo.buftype == "" and bo.modifiable and not bo.readonly
      and vim.api.nvim_buf_get_name(args.buf) ~= "" then
      vim.api.nvim_buf_call(args.buf, function() vim.cmd("silent! update") end)
    end
  end,
})
vim.api.nvim_create_autocmd("FocusLost", { command = "silent! wall" })
