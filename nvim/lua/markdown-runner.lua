-- Execute fenced code blocks (```sh / ```bash / ```shell) under the cursor.
-- Keybindings: <leader>mr (run), <leader>ml (list background tasks)

local RUNNABLE = { sh = true, bash = true, shell = true }

-- Tracks background tasks: { buf, job_id, label }
local bg_tasks = {}

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

local function open_buf_in_float(buf, label)
	local height = math.floor(vim.o.lines * 0.4)
	local width = math.floor(vim.o.columns * 0.8)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = "  " .. label .. "  ",
		title_pos = "center",
	})
	vim.cmd.startinsert()
	vim.keymap.set("n", "Q", function()
		if vim.api.nvim_win_is_valid(win) then
			local task
			for _, t in ipairs(bg_tasks) do
				if t.buf == buf then
					task = t
					break
				end
			end
			local still_running = task and vim.fn.jobwait({ task.job_id }, 0)[1] == -1
			if still_running then
				vim.notify("Process running in background…", vim.log.levels.INFO)
			end
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, silent = true, desc = "Close runner window" })
end

local function list_bg_tasks()
	-- Prune finished tasks whose buffers are gone
	bg_tasks = vim.tbl_filter(function(t)
		return vim.api.nvim_buf_is_valid(t.buf)
	end, bg_tasks)

	if #bg_tasks == 0 then
		vim.notify("No background tasks running", vim.log.levels.INFO)
		return
	end

	local items = {}
	for _, t in ipairs(bg_tasks) do
		local running = vim.fn.jobwait({ t.job_id }, 0)[1] == -1
		table.insert(items, { task = t, running = running })
	end

	local labels = vim.tbl_map(function(item)
		local status = item.running and "⏳ running" or "✅ done"
		return string.format("[%s] %s", status, item.task.label)
	end, items)

	vim.ui.select(labels, { prompt = "Background tasks" }, function(_, idx)
		if not idx then return end
		local chosen = items[idx]
		if vim.api.nvim_buf_is_valid(chosen.task.buf) then
			open_buf_in_float(chosen.task.buf, chosen.task.label)
		else
			vim.notify("Task buffer is no longer available", vim.log.levels.WARN)
		end
	end)
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

	local job_id = vim.fn.termopen("bash " .. tmpfile, {
		on_exit = function(_, exit_code)
			vim.fn.delete(tmpfile)
			vim.schedule(function()
				-- Remove from background task list
				bg_tasks = vim.tbl_filter(function(t) return t.buf ~= buf end, bg_tasks)

				if vim.api.nvim_buf_is_valid(buf) then
					local wins = vim.fn.win_findbuf(buf)
					if #wins == 0 then
						-- Buffer is hidden (user pressed q); clean up and notify
						vim.api.nvim_buf_delete(buf, { force = true })
						local msg = "Markdown runner finished"
						local level = exit_code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
						if exit_code ~= 0 then
							msg = msg .. " (exit code: " .. exit_code .. ")"
						end
						vim.notify(msg, level)
					end
				end
			end)
		end,
	})

	-- Register as a background task so \ml can find it
	local label = "Run: " .. lang .. " block"
	table.insert(bg_tasks, { buf = buf, job_id = job_id, label = label })

	-- Hide instead of delete when the window closes so the job keeps running
	vim.bo[buf].bufhidden = "hide"

	vim.cmd.startinsert()

	-- Press Q in normal mode to close the window (process keeps running if still active)
	vim.keymap.set("n", "Q", function()
		if vim.api.nvim_win_is_valid(win) then
			local still_running = job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1
			if still_running then
				vim.notify("Process running in background…", vim.log.levels.INFO)
			end
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
		vim.keymap.set("n", "<leader>ml", list_bg_tasks, {
			buffer = true,
			desc = "List background markdown runner tasks",
		})
	end,
})
