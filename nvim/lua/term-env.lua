-- A terminal opened in Neovim is a child of Neovim, not of tmux: Neovim's own
-- terminal emulator sits in between. $TMUX is inherited all the same, so a TUI
-- running there believes it talks straight to tmux and wraps its clipboard
-- writes in tmux's DCS passthrough form. Neovim's emulator has no passthrough
-- support, so the wrapper is dropped and the payload lands on screen as raw
-- base64 -- a Claude Code session corrupts itself the moment it copies.
--
-- Hiding $TMUX from the child alone is enough: it then emits plain OSC 52,
-- which Neovim does understand. Neovim keeps its own $TMUX, so
-- vim-tmux-navigator is untouched, and `tmux` from inside the shell still
-- reaches the server over the default socket.
local M = {}

-- For jobstart/termopen opts, which take an env table rather than inheriting
-- one. An empty value reads as "not in tmux" to every shell and TUI that
-- checks, and jobstart has no way to remove a variable outright.
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
