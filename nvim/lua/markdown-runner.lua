-- Execute fenced code blocks (```sh / ```bash / ```shell) under the cursor.
-- Keybindings: <leader>mr (run), <leader>ml (list background tasks)

local floats = require("floating-helpers")
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
	local win
	-- Declared before the float so the close button can call it: the X and Q are
	-- the same action, and a runner window must warn about a live process rather
	-- than vanish silently.
	local close_runner
	close_runner = function()
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
	end

	local _
	_, win = floats.open({
		buf = buf,
		width = 0.8,
		height = 0.4,
		title = "  " .. label .. "  ",
		label = "the markdown runner",
		close = true,
		on_close = function()
			close_runner()
		end,
	})
	vim.cmd.startinsert()
	vim.keymap.set({ "n", "t" }, "Q", close_runner, { buffer = buf, silent = true, desc = "Close runner window" })
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

-- Where to run a block from. Relative paths in a code block are almost always
-- written against the repository root ("deploy/docker/...", "src/main.rs"), not
-- against wherever Neovim happened to be started, and not against the document
-- itself -- a file under deploy/docker/local/ still refers to deploy/docker/...
-- from the top. So resolve the enclosing repository and fall back to the
-- document's own directory when there isn't one.
local function block_cwd(buf)
	local file = vim.api.nvim_buf_get_name(buf)
	if file == "" then
		return vim.fn.getcwd()
	end

	local dir = vim.fn.fnamemodify(file, ":p:h")

	local root = vim.fs.root(file, { ".git" })
	if root then
		return root
	end

	return dir
end

local function run_code_block()
	local source_buf = vim.api.nvim_get_current_buf()
	local cwd = block_cwd(source_buf)
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

	-- close_runner is defined below, once the job exists; the button reaches it
	-- through this local so the X and Q stay one behaviour.
	local close_runner
	local buf, win = floats.open({
		width = 0.8,
		height = 0.4,
		title = "  Run: " .. lang .. " block  in " .. vim.fn.fnamemodify(cwd, ":t") .. "  ",
		label = "the markdown runner",
		close = true,
		on_close = function()
			if close_runner then
				close_runner()
			end
		end,
	})

	local job_id = vim.fn.termopen("bash " .. tmpfile, {
		cwd = cwd,
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

	-- Q closes the window in either normal or terminal mode; the process keeps running.
	close_runner = function()
		if vim.api.nvim_win_is_valid(win) then
			local still_running = job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1
			if still_running then
				vim.notify("Process running in background…", vim.log.levels.INFO)
			end
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.keymap.set({ "n", "t" }, "Q", close_runner, { buffer = buf, silent = true, desc = "Close runner window" })
end

-- Only bind in markdown files
vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function()
		vim.keymap.set("n", "<leader>mr", run_code_block, {
			buffer = true,
			desc = "Run markdown code block under cursor",
		})
		-- Bare "mr" as well, for a shorter reach. Buffer-local, so it only
		-- shadows the "set mark r" command inside markdown files.
		vim.keymap.set("n", "mr", run_code_block, {
			buffer = true,
			desc = "Run markdown code block under cursor",
		})
		vim.keymap.set("n", "<leader>ml", list_bg_tasks, {
			buffer = true,
			desc = "List background markdown runner tasks",
		})
	end,
})
