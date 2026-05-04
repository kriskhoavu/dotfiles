vim.loader.enable() -- Faster Lua module loading (Neovim 0.9.1+)

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
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

require("vim-helpers")
require("vim-options")
require("vim-window")
require("vim-clipboard")
require("floating-helpers")
require("floating-terminal")
require("markdown-runner")
require("lazy").setup({
    { import = "plugins" },
    { import = "themes" },
})

-- Set Theme
vim.cmd.colorscheme("catppuccin-mocha")

-- Auto-reload files changed outside of Neovim
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "BufWinEnter", "BufFilePost" ,"CursorHold", "CursorHoldI" }, {
  pattern = "*",
  command = "checktime",
})
