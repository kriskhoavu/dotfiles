-- Files over BIGFILE_BYTES (generated JSON, logs, bundles) open plain: no
-- syntax, Treesitter, completion, git signs or markdown rendering. Each of
-- those walks the whole file and made such buffers crawl. LSP still attaches.
-- The other plugins check vim.b.bigfile.

local BIGFILE_BYTES = 1024 * 1024

local group = vim.api.nvim_create_augroup("BigFile", { clear = true })

vim.api.nvim_create_autocmd("BufReadPre", {
	group = group,
	callback = function(args)
		local stat = vim.uv.fs_stat(args.match)
		if stat and stat.size > BIGFILE_BYTES then
			vim.b[args.buf].bigfile = true
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = group,
	callback = function(args)
		local buf = args.buf
		if not vim.b[buf].bigfile then return end
		vim.wo.foldmethod = "manual"
		vim.wo.spell = false
		-- Deferred: the filetype's own syntax load runs after this autocmd.
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(buf) then return end
			pcall(vim.treesitter.stop, buf)
			vim.bo[buf].syntax = ""
		end)
	end,
})

return { BIGFILE_BYTES = BIGFILE_BYTES }
