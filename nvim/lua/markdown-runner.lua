-- Execute fenced code blocks (```sh / ```bash / ```shell) under the cursor.
-- Keybinding: <leader>mr (markdown run)

local RUNNABLE = { sh = true, bash = true, shell = true }

local function get_code_block_at_cursor()
	local buf = vim.api.nvim_get_current_buf()
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	local start_line, lang

	for i, line in ipairs(lines) do
		if not start_line then
			local fence_lang = line:match("^```(%w+)%s*$")
			if fence_lang and RUNNABLE[fence_lang:lower()] then
				start_line = i
				lang = fence_lang:lower()
			end
		else
			if line:match("^```%s*$") then
				local end_line = i
				if cursor_line >= start_line and cursor_line <= end_line then
					local block = {}
					for j = start_line + 1, end_line - 1 do
						table.insert(block, lines[j])
					end
					return block, lang
				end
				start_line = nil
				lang = nil
			end
		end
	end

	return nil, nil
end

local function run_code_block()
	local block_lines, lang = get_code_block_at_cursor()

	if not block_lines or #block_lines == 0 then
		vim.notify("No executable code block (sh/bash/shell) found at cursor", vim.log.levels.WARN)
		return
	end

	local tmpfile = vim.fn.tempname() .. ".sh"
	local f = io.open(tmpfile, "w")
	if not f then
		vim.notify("Failed to create temp file", vim.log.levels.ERROR)
		return
	end
	f:write(table.concat(block_lines, "\n") .. "\n")
	f:close()

	local height = math.floor(vim.o.lines * 0.4)
	local width = math.floor(vim.o.columns * 0.8)
	local buf = vim.api.nvim_create_buf(false, true)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = "  Run: " .. lang .. " block  ",
		title_pos = "center",
	})

	vim.fn.termopen("bash " .. tmpfile, {
		on_exit = function()
			vim.fn.delete(tmpfile)
		end,
	})

	vim.cmd.startinsert()

	-- Press q in normal mode to close
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, silent = true, desc = "Close runner window" })
end

-- Only bind in markdown files
vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function()
		vim.keymap.set("n", "<leader>mr", run_code_block, {
			buffer = true,
			desc = "Run markdown code block under cursor",
		})
	end,
})
