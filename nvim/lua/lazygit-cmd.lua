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
	table.insert(configs, vim.fs.joinpath(config_dir, "lazygit-nvim.yml"))

	return { "lazygit", "--use-config-file", table.concat(configs, ",") },
		vim.fs.joinpath(config_dir, "scripts", "lazygit-open.sh")
end

return M
