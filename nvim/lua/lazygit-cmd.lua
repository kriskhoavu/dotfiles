-- The lazygit argv shared by every float in this config: the single-repo one in
-- plugins/gits-stuff.lua and the org-wide tabbed one in org-git.lua.
--
-- It lives in its own module because both callers must agree on the config merge
-- and on where the editor shim is. Two copies would drift the moment one of them
-- gained an option.
local M = {}

-- Returns the argv and the path of the shim lazygit's `e` should run.
--
-- The overlay lives beside this config, and stdpath resolves it wherever the
-- dotfiles are checked out -- the repo path itself contains spaces.
function M.build()
	local config_dir = vim.fn.stdpath("config")
	local configs = {}

	-- The personal config is not managed by these dotfiles, so use it only if it
	-- is actually there. `-ucf` merges left to right, overlay last.
	local user_config = vim.fs.joinpath(vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config"), "lazygit", "config.yml")
	if vim.uv.fs_stat(user_config) then
		table.insert(configs, user_config)
	end
	-- The half matching the current appearance, same split and state file as
	-- the wrapper in zsh/git-stuff.zsh. Without it the floats always get dark:
	-- only ~/.config/lazygit/config.yml is read by default.
	local theme = require("theme-mode").is_light and "theme-light.yml" or "theme-dark.yml"
	local theme_config = vim.fs.joinpath(vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config"), "lazygit", theme)
	if vim.uv.fs_stat(theme_config) then
		table.insert(configs, theme_config)
	end

	table.insert(configs, vim.fs.joinpath(config_dir, "lazygit-nvim.yml"))

	return { "lazygit", "--use-config-file", table.concat(configs, ",") },
		vim.fs.joinpath(config_dir, "scripts", "lazygit-open.sh")
end

-- Opens lazygit's `e` target: the RPC handlers' shared tail.
function M.edit(path, line)
	vim.cmd.edit(vim.fn.fnameescape(path))
	line = tonumber(line) or 0
	if line > 0 then
		pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
	end
end

-- Keys every lazygit terminal needs: Esc reaches lazygit (its back key, which
-- the global map would steal), and every way back in lands in terminal mode,
-- or keys go to Vim. on_enter runs after that.
function M.attach(buf, on_enter)
	vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = buf, silent = true, desc = "Send Esc to lazygit" })
	vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
		buffer = buf,
		callback = function()
			if vim.api.nvim_get_current_buf() == buf and vim.bo[buf].buftype == "terminal" then
				vim.cmd.startinsert()
				if on_enter then on_enter() end
			end
		end,
	})
end

return M
