-- Helm templates are Go templates, not YAML, and yamlls reports every {{ }} as
-- "Missing , or : between flow map items". This plugin claims them as the
-- "helm" filetype and ships the Go template syntax.
return {
	"towolf/vim-helm",
	lazy = false, -- its ftdetect has to run before the first chart file opens
	init = function()
		-- vim-helm switches filetype from inside a "FileType yaml" autocmd, so
		-- the yaml syntax loads last and b:current_syntax stays "yaml" -- the
		-- Go template groups never apply. Ask again once it has settled.
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "helm",
			callback = function(args)
				-- Deferred: this fires while the original FileType yaml chain is
				-- still running, and its pending syntax load would overwrite us.
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(args.buf)
						and vim.bo[args.buf].filetype == "helm"
						and vim.b[args.buf].current_syntax ~= "helm" then
						vim.bo[args.buf].syntax = "helm"
					end
				end)
			end,
		})
	end,
}
