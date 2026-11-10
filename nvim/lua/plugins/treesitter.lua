return {
	"nvim-treesitter/nvim-treesitter",
	event = { "BufReadPost", "BufNewFile" },
	build = ":TSUpdate",
	config = function()
		-- Building a parser shells out to the tree-sitter CLI in Mason's bin
		-- directory. Put it on PATH here instead of loading Mason for every file.
		local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
		if not vim.env.PATH:find(mason_bin, 1, true) then
			vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
		end

		local ts = require("nvim-treesitter")
		ts.setup()

		-- main dropped the old option table: setup() understands only
		-- install_dir, so ensure_installed/highlight/indent were ignored and no
		-- parser installed. Request parsers explicitly, highlight per buffer.
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
				if vim.b[args.buf].bigfile or not lang or not vim.tbl_contains(languages, lang) then
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
