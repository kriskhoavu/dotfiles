local api = vim.api
local fn = vim.fn
local floats = require("floating-helpers")
local term_env = require("term-env")
local state = { buf = -1, win = -1 }

local function create_floating_window()
	return floats.open({
		buf = state.buf,
		width = 0.8,
		height = 0.8,
		label = "the floating terminal",
	})
end

local function toggle_term()
	if api.nvim_win_is_valid(state.win) then
		api.nvim_win_hide(state.win)
		return
	end

	state.buf, state.win = create_floating_window()
	if state.paint then
		state.paint()
	end

	if vim.bo[state.buf].buftype ~= "terminal" then
		-- :terminal replaces the window's buffer rather than converting it, so the
		-- scratch buffer the float was opened with is thrown away here -- along
		-- with anything attached to it. Re-read the real buffer and guard that
		-- one, or Ctrl-hjkl walks out of the float.
		term_env.without_tmux(vim.cmd.terminal)
		state.buf = api.nvim_get_current_buf()
		vim.bo[state.buf].buflisted = false -- prevent it from appearing in bufferline
		floats.make_modal(state.buf, "the floating terminal")
		-- Hide rather than close: \9 is a toggle, and the shell inside it keeps
		-- its history, its cwd and whatever is running.
		state.paint = floats.close_button(function()
			return state.win
		end, state.buf, {
			on_close = function()
				if api.nvim_win_is_valid(state.win) then
					api.nvim_win_hide(state.win)
					state.win = -1
				end
			end,
		})
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
	term_env.without_tmux(function()
		vim.cmd("terminal")
	end)
	vim.cmd("startinsert")
end, { desc = "Open terminal as tab" })
