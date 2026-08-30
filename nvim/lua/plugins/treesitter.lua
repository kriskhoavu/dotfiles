return {
	"nvim-treesitter/nvim-treesitter",
	event = { "BufReadPost", "BufNewFile" },
	build = ":TSUpdate",
	-- Building a parser shells out to the tree-sitter CLI, which lives in
	-- Mason's bin directory; Mason only puts it on PATH once it has loaded.
	dependencies = { "williamboman/mason.nvim" },
	config = function()
		local ts = require("nvim-treesitter")
		ts.setup()

		-- This plugin's main branch dropped the old option table: setup() only
		-- understands install_dir, so the ensure_installed/highlight/indent
		-- options here were silently ignored and no parser was ever installed.
		-- Parsers are requested explicitly, and highlighting is started per
		-- buffer instead of being switched on globally.
		local languages = {
			"bash",
			"groovy",
			"html",
			"java",
			"javascript",
			"kotlin",
			"lua",
			"markdown",
			"markdown_inline",
			"query",
			"vim",
			"vimdoc",
			"yaml",
		}

		local installed = ts.get_installed()
		local missing = vim.tbl_filter(function(lang)
			return not vim.tbl_contains(installed, lang)
		end, languages)
		if #missing > 0 then
			ts.install(missing)
		end

		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
				if not lang or not vim.tbl_contains(languages, lang) then
					return
				end
				-- A parser still compiling in the background is not an error here.
				if pcall(vim.treesitter.start, args.buf, lang) then
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end,
		})
	end,
}
