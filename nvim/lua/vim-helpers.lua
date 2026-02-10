-- all vim helper functions here

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
