-- blink.cmp: one plugin in place of nvim-cmp, LuaSnip, cmp_luasnip,
-- cmp-nvim-lsp, cmp-buffer and cmp-path. Fuzzy matching runs in a prebuilt
-- Rust binary (version = "1.*" downloads it); without it blink falls back to
-- Lua and warns. Snippets use vim.snippet with friendly-snippets.
return {
	"saghen/blink.cmp",
	version = "1.*",
	event = "InsertEnter",
	dependencies = { "rafamadriz/friendly-snippets" },
	opts = {
		-- Off in prompts and in files lua/bigfile.lua marks.
		enabled = function()
			return vim.bo.buftype ~= "prompt" and not vim.b.bigfile
		end,
		keymap = {
			preset = "none",
			["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-e>"] = { "hide", "fallback" },
			["<CR>"] = { "accept", "fallback" },
			-- With no menu open these fall back to vim-tmux-navigator.
			["<C-j>"] = { "select_next", "fallback" },
			["<C-k>"] = { "select_prev", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
			["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
		},
		completion = {
			menu = { border = "rounded" },
			documentation = { auto_show = true, window = { border = "rounded" } },
		},
		sources = {
			default = { "lsp", "snippets", "buffer", "path" },
		},
		-- nvim-cmp had no command-line completion; keep it that way.
		cmdline = { enabled = false },
	},
}
