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
	end

	-- Ensure the terminal starts in insert mode
  vim.cmd.startinsert()
end

api.nvim_create_user_command("FloatingTerminal", toggle_term, {})
-- <leader>9: Toggle Terminal (floating)
vim.keymap.set({ "n", "t" }, "<leader>9", toggle_term, { desc = "Toggle floating terminal" })
