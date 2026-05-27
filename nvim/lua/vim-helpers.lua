-- all vim helper functions here

local function find_shortcut_help()
	local config_dir = vim.fn.resolve(vim.fn.stdpath("config"))
	local candidates = {
		vim.fn.fnamemodify(config_dir, ":h") .. "/SHORTCUTS.md",
		vim.fn.getcwd() .. "/SHORTCUTS.md",
		vim.fn.expand("~/Personal/01. happy-learning/Kris/dotfiles/SHORTCUTS.md"),
	}

	for _, path in ipairs(candidates) do
		if vim.fn.filereadable(path) == 1 then
			return path
		end
	end
end

vim.api.nvim_create_user_command("ShortcutHelp", function()
	local path = find_shortcut_help()
	if not path then
		vim.notify("SHORTCUTS.md not found", vim.log.levels.WARN)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.floor(vim.o.columns * 0.78)
	local height = math.floor(vim.o.lines * 0.85)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		border = "rounded",
		style = "minimal",
		title = "  Shortcut Help  ",
		title_pos = "center",
	})

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.readfile(path))
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
	vim.bo[buf].bufhidden = "wipe"
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, silent = true, desc = "Close shortcut help" })
end, { desc = "Open shortcut help center" })

vim.keymap.set("n", "<leader>?", "<cmd>ShortcutHelp<cr>", { desc = "Open shortcut help center" })

-- Copy diagnostic message to clipboard
vim.keymap.set("n", "<leader>ce", function()
	local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
	if #diagnostics > 0 then
		local message = diagnostics[1].message
		vim.fn.setreg("+", message)
		print("Copied diagnostic: " .. message)
	else
		print("No diagnostic at cursor")
	end
end, { noremap = true, silent = true, desc = "Copy diagnostic to clipboard" })


-- Show folder/dir structure
vim.api.nvim_create_user_command("ShowTree", function()
	local buf = vim.api.nvim_create_buf(false, true)
	local editor_width = vim.o.columns
	local editor_height = vim.o.lines
	local width = math.floor(editor_width * 0.6)
	local height = math.floor(editor_height * 0.9)

	local row = math.floor((editor_height - height) / 2)
	local col = math.floor((editor_width - width) / 2)
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		border = "rounded",
		style = "minimal",
	}

	local win = vim.api.nvim_open_win(buf, true, opts)
	local job_id = vim.fn.jobstart("tree -L 4", {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					vim.api.nvim_buf_set_lines(buf, -1, -1, true, { line })
				end
			end
		end,
		on_exit = function()
			-- vim.api.nvim_win_close(win, true)
		end,
	})
	print("Job ID: " .. job_id)
end, {})

vim.keymap.set("n", "<leader>vt", ":ShowTree<CR>", { desc = "Show directory tree in floating window" })

-- Theme switcher
local themes = { "tokyonight", "catppuccin", "darcula-solid" }
local current_theme_idx = 1

vim.api.nvim_create_user_command("ThemeToggle", function()
    current_theme_idx = current_theme_idx % #themes + 1
    vim.cmd.colorscheme(themes[current_theme_idx])
    print("Theme: " .. themes[current_theme_idx])
end, { desc = "Toggle between themes" })

vim.api.nvim_create_user_command("Theme", function(opts)
    local theme = opts.args
    if theme and theme ~= "" then
        vim.cmd.colorscheme(theme)
        print("Theme: " .. theme)
    else
        print("Available: tokyonight, catppuccin, darcula-solid")
    end
end, { nargs = "?", complete = function() return themes end, desc = "Set theme" })

vim.keymap.set("n", "<leader>tt", ":ThemeToggle<CR>", { desc = "Toggle theme" })
