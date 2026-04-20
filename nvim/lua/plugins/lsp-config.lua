return {
	{
		"williamboman/mason.nvim",
		-- Loads on demand (:Mason) or as a dep of mason-lspconfig
		cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUpdate", "MasonLog" },
		config = function()
			require("mason").setup({
				ui = {
					border = "rounded",
					icons = {
						package_pending = "➜",
						package_installed = "✓",
						package_uninstalled = "✗",
					},
				},
				max_concurrent_installers = 4,
			})
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		lazy = true, -- loads only as a dep of nvim-lspconfig
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				auto_install = true,
				ensure_installed = { "lua_ls", "ts_ls", "eslint", "yamlls", "bashls", "helm_ls", "jdtls" },
				-- Note: jdtls is handled by nvim-jdtls plugin in lsp-jdtls.lua
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		-- BufReadPre fires before FileType detection, so vim.lsp.enable() autocmds
		-- are in place before LSP needs to attach for the first opened file
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"williamboman/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp", -- must be loaded before lsp capabilities are built
		},
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			local simple_servers = { "ts_ls", "eslint", "yamlls", "bashls", "helm_ls" }

			for _, server in ipairs(simple_servers) do
				vim.lsp.config(server, {
					capabilities = capabilities,
				})
			end

			-- Lua LSP's special config
			vim.lsp.config("lua_ls", {
				cmd = { "lua-language-server" },
				capabilities = capabilities,
				settings = {
					Lua = {
						diagnostics = { globals = { "vim" } },
						workspace = {
							checkThirdParty = false,
							library = { vim.env.VIMRUNTIME },
						},
						telemetry = { enable = false },
					},
				},
			})

			-- Enable LSP servers
			vim.lsp.enable({ "lua_ls", "ts_ls", "eslint", "yamlls", "bashls", "helm_ls" }, true)

			-- LSP Keymaps
			vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
			vim.keymap.set("n", "gi", vim.lsp.buf.implementation, {})
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
			vim.keymap.set("n", "gD", vim.lsp.buf.declaration, {})
			vim.keymap.set("n", "gr", vim.lsp.buf.references, {})
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, {})
			vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, {})
			vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, {})
	
			-- Diagnostic Keymaps
			vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, {})
			vim.keymap.set("n", "]d", vim.diagnostic.goto_next, {})
			vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, {})
			vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, {})

			vim.keymap.set("n", "<leader>fm", function()
				local filetype = vim.bo.filetype
				local symbols_map = {
					python = "Function",
					javascript = "Function",
					typescript = "Function",
					java = "Class",
					lua = "Function",
					go = { "Method", "Struct", "Interface" },
				}
				local symbols = symbols_map[filetype] or "Function"
				require("fzf-lua").lsp_document_symbols({ symbols = symbols })
			end, {})

			-- Diagnostic UI config
			vim.diagnostic.config({
				virtual_text = { prefix = "●" },
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = {
					border = "rounded",
					source = true,
				},
			})
		end,
	},
}
