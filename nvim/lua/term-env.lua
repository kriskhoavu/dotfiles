-- A terminal in Neovim is a child of Neovim, not of tmux, but inherits $TMUX
-- anyway. A TUI then wraps its clipboard writes in tmux's DCS passthrough form,
-- which Neovim's emulator cannot decode: the wrapper is dropped and the payload
-- lands on screen as raw base64. Hiding $TMUX gets plain OSC 52 instead.
--
-- Neovim keeps its own $TMUX, so vim-tmux-navigator is untouched, and `tmux`
-- still reaches the server over the default socket.
local M = {}

-- For jobstart/termopen, which take an env table. Empty reads as "not in tmux"
-- everywhere; jobstart cannot remove a variable outright.
M.job_env = { TMUX = "", TMUX_PANE = "" }

function M.without_tmux(fn)
	local tmux, pane = vim.env.TMUX, vim.env.TMUX_PANE
	vim.env.TMUX, vim.env.TMUX_PANE = nil, nil

	local ok, result = pcall(fn)

	vim.env.TMUX, vim.env.TMUX_PANE = tmux, pane
	if not ok then
		error(result, 0)
	end
	return result
end

return M
