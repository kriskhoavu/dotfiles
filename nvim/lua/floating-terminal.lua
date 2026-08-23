local api = vim.api
local fn = vim.fn
local state = { buf = -1, win = -1 }

local function create_floating_window()
	local height = math.floor(vim.o.lines * 0.8)
	local width = math.floor(vim.o.columns * 0.8)
	local buf = api.nvim_buf_is_valid(state.buf) and state.buf or api.nvim_create_buf(false, true)

	local win = api.nvim_open_win(buf, true, {
    row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		height = height,
		width = width,
		style = "minimal",
		border = "rounded",
		relative = "editor",
	})
	return buf, win
end

local function toggle_term()
	if api.nvim_win_is_valid(state.win) then
		api.nvim_win_hide(state.win)
		return
	end

	state.buf, state.win = create_floating_window()

	if vim.bo[state.buf].buftype ~= "terminal" then
		vim.cmd.terminal()
		vim.bo[state.buf].buflisted = false -- prevent it from appearing in bufferline
	end

	-- Ensure the terminal starts in insert mode
  vim.cmd.startinsert()
end

api.nvim_create_user_command("FloatingTerminal", toggle_term, {})
-- <leader>9: Toggle Terminal (floating)
vim.keymap.set({ "n", "t" }, "<leader>9", toggle_term, { desc = "Toggle floating terminal" })

-- A window a terminal may take over: not floating, not the Neo-tree sidebar.
local function is_editing_window(win)
	if api.nvim_win_get_config(win).relative ~= "" then
		return false
	end
	return vim.bo[api.nvim_win_get_buf(win)].filetype ~= "neo-tree"
end

-- <leader>tt: Open a real terminal as a bufferline tab
vim.keymap.set("n", "<leader>tt", function()
	-- "enew" replaces the buffer in the current window, so running it while the
	-- cursor sits in Neo-tree hands the sidebar to the terminal and leaves the
	-- tree to be rescued by the NeoTreeRedirect autocmd. Pick a real editing
	-- window up front, splitting one off the sidebar if none exists.
	local target = nil
	if is_editing_window(api.nvim_get_current_win()) then
		target = api.nvim_get_current_win()
	else
		for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
			if is_editing_window(win) then
				target = win
				break
			end
		end
	end

	if target then
		api.nvim_set_current_win(target)
	else
		vim.cmd("rightbelow vsplit")
	end

	vim.cmd("enew")
	vim.cmd("terminal")
	vim.cmd("startinsert")
end, { desc = "Open terminal as tab" })
