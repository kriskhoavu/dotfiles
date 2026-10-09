-- \3: lazygit for the current repo in a float.
local lg_state = { buf = -1, win = -1 }

-- Wipe the dead terminal buffer, else the next open reuses it and shows
-- "[Process exited 0]" instead of starting lazygit.
local function reset_lazygit()
	if vim.api.nvim_win_is_valid(lg_state.win) then
		pcall(vim.api.nvim_win_hide, lg_state.win)
	end
	if vim.api.nvim_buf_is_valid(lg_state.buf) then
		pcall(vim.api.nvim_buf_delete, lg_state.buf, { force = true })
	end
	lg_state.buf, lg_state.win = -1, -1
end

-- Called over RPC by scripts/lazygit-open.sh on lazygit's `e`. Hidden, not
-- closed, so the session survives and \3 brings it back where it was.
function _G.LazygitOpenFile(path, line)
	-- The RPC arrives mid-keystroke inside the terminal job: defer, so the shim
	-- returns at once instead of blocking lazygit's UI.
	vim.schedule(function()
		if vim.api.nvim_win_is_valid(lg_state.win) then
			vim.api.nvim_win_hide(lg_state.win)
			lg_state.win = -1
		end

		require("lazygit-cmd").edit(path, line)
	end)

	-- --remote-expr prints whatever this returns; keep lazygit's pane clean.
	return ""
end

-- Shared with the org-wide float in org-git.lua, so the config merge and the
-- shim path cannot drift between the two.
local lazygit_command = require("lazygit-cmd").build

local function toggle_lazygit()
	if vim.api.nvim_win_is_valid(lg_state.win) then
		vim.api.nvim_win_hide(lg_state.win)
		lg_state.win = -1
		return
	end

	local floats = require("floating-helpers")
	local buf, win = floats.open({
		buf = lg_state.buf,
		label = "lazygit",
	})
	lg_state.buf, lg_state.win = buf, win

	-- Registered once on the long-lived buffer, repainted on every open: the
	-- winbar belongs to the window, which is new on each toggle.
	if not lg_state.paint then
		lg_state.paint = floats.close_button(function()
			return lg_state.win
		end, buf, {
			on_close = function()
				if vim.api.nvim_win_is_valid(lg_state.win) then
					vim.api.nvim_win_hide(lg_state.win)
					lg_state.win = -1
				end
			end,
		})
	end
	lg_state.paint()

	if vim.bo[buf].buftype ~= "terminal" then
		local cmd, shim = lazygit_command()
		-- An argv list, not a shell string: the `-ucf` paths contain spaces.
		-- The shim travels in the environment, so the YAML never names it.
		vim.fn.termopen(cmd, {
			env = vim.tbl_extend("error", require("term-env").job_env, { LAZYGIT_NVIM_OPEN = shim }),
			-- Reads the state, not a captured handle: the float is recreated on
			-- every toggle, so a captured one goes stale.
			on_exit = function()
				vim.schedule(reset_lazygit)
			end,
		})
		vim.bo[buf].buflisted = false
		require("lazygit-cmd").attach(buf)
	end

	vim.cmd.startinsert()
end

vim.keymap.set({ "n", "t" }, "<leader>3", toggle_lazygit, { desc = "Toggle lazygit" })
