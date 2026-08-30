-- Helm templates are Go templates, not YAML: yamlls reports every {{ ... }} as
-- "Missing , or : between flow map items". This plugin detects charts as the
-- "helm" filetype -- which yamlls ignores and helm_ls claims -- and ships the
-- Go template syntax that plain YAML highlighting cannot provide.
return {
	"towolf/vim-helm",
	lazy = false, -- its ftdetect has to run before the first chart file opens
	init = function()
		-- vim-helm switches the filetype from inside a "FileType yaml" autocmd,
		-- so the yaml syntax load finishes last and leaves b:current_syntax as
		-- "yaml": syntax/helm.vim is sourced but its Go template groups never
		-- apply, and everything inside {{ }} renders as a plain scalar. Ask for
		-- the helm syntax again once the filetype has settled.
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
