-- <leader>4: org-wide git float -- one tab per repo under a root directory, plus
-- an overview tab across all of them.
--
-- The problem this solves: lazygit is one repo per process, so no lazygit can
-- ever show repo tabs. A folder of sibling repos (a GitHub org checked out side
-- by side, like ~/.../kompas) therefore needs the tabline drawn by nvim, with one
-- lazygit terminal per repo swapped into a single float. That is all this module
-- is -- tab bookkeeping and a status overview. Every git action inside a tab is
-- lazygit's own; nothing here reimplements staging, committing or pushing.
--
-- Tab 0 is the overview: a plain buffer listing every repo with its branch, dirty
-- count, ahead/behind and last commit subject -- the cross-repo view neither
-- lazygit nor diffview gives.
--
-- Repos are discovered exactly like tmux/scripts/tmux-org-tabs.sh: one level down
-- from the root, <root>/*/.git tested for existence rather than for being a
-- directory, so worktrees and submodules (where .git is a file holding a gitdir
-- pointer) count too. Both tools agreeing on what a repo is matters -- the tmux
-- tabs and these tabs should never disagree.

local lazygit = require("lazygit-cmd")
local chips = require("tmux-chips")
local floats = require("floating-helpers")

local M = {}

local state = {
	win = -1,
	root = nil,
	repos = {}, -- { { name = , path = } } in tab order, tab 1 onward
	bufs = {}, -- repo path -> terminal buffer running its lazygit
	overview = -1,
	current = 0, -- 0 = overview, n = state.repos[n]
	status = {}, -- repo path -> { branch, dirty, ahead, behind, subject }
}

local ns = vim.api.nvim_create_namespace("OrgGit")

-- Highlights ------------------------------------------------------------------

-- The tabline chips, the float ground and the catppuccin palette all come from
-- tmux-chips, which is shared with the shortcut help float. Only the colours of
-- this module's own table are defined here.
local function set_highlights()
	local c = chips.colors()
	local hls = {
		OrgGitChipDirty = { fg = c.yellow, bg = c.name_bg },
		OrgGitChipSync = { fg = c.teal, bg = c.name_bg },

		OrgGitRepo = { fg = c.blue, bold = true },
		OrgGitBranch = { fg = c.overlay_1 },
		OrgGitClean = { fg = c.overlay_1 },
		OrgGitDirty = { fg = c.yellow },
		OrgGitSync = { fg = c.teal },
		OrgGitSubject = { fg = c.overlay_1, italic = true },
		OrgGitHeader = { fg = c.text, bold = true },
		OrgGitHeaderDim = { fg = c.overlay_1 },
		OrgGitColumns = { fg = c.teal },
		OrgGitIndex = { fg = c.mauve },
		OrgGitFooter = { fg = c.overlay_1 },
		OrgGitRule = { fg = c.surface_1 },
	}
	for name, val in pairs(hls) do
		vim.api.nvim_set_hl(0, name, val)
	end
end

set_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights, desc = "Org git highlights" })

-- Discovery ------------------------------------------------------------------

local function discover(root)
	local repos = {}
	for name, kind in vim.fs.dir(root) do
		-- A symlinked repo checkout reports as "link", so both kinds are walked.
		if kind == "directory" or kind == "link" then
			local path = vim.fs.joinpath(root, name)
			if vim.uv.fs_stat(vim.fs.joinpath(path, ".git")) then
				repos[#repos + 1] = { name = name, path = path }
			end
		end
	end
	table.sort(repos, function(a, b)
		return a.name < b.name
	end)
	return repos
end

-- The org root is the parent of the repo you are sitting in: from any file in
-- kompas/agent-plane the root is kompas, and every sibling repo comes along. Fall
-- back to the cwd itself so the module still works when invoked from the folder
-- that holds the repos rather than from inside one.
local function resolve_root()
	local found = vim.fs.find(".git", { path = vim.uv.cwd(), upward = true, limit = 1 })[1]
	if found then
		local root = vim.fs.dirname(vim.fs.dirname(found))
		if #discover(root) > 0 then
			return root
		end
	end
	return vim.uv.cwd()
end

-- Status ---------------------------------------------------------------------

-- porcelain=v2 in one pass per repo: the header lines carry the branch and the
-- ahead/behind pair, and every entry line is one dirty path -- 1 and 2 for
-- tracked changes, u for unmerged, ? for untracked.
local function parse_status(out)
	local info = { branch = "?", dirty = 0, ahead = 0, behind = 0 }
	for line in vim.gsplit(out, "\n", { trimempty = true }) do
		local head = line:match("^# branch%.head (.+)$")
		local ab_a, ab_b = line:match("^# branch%.ab %+(%d+) %-(%d+)$")
		if head then
			info.branch = head
		elseif ab_a then
			info.ahead, info.behind = tonumber(ab_a), tonumber(ab_b)
		elseif line:match("^[12u?] ") then
			info.dirty = info.dirty + 1
		end
	end
	return info
end

-- Called on open, on tab switch and on `r` in the overview. Not polled: a watcher
-- across five repos costs more than it saves, and the counts only matter when the
-- float is actually in front of you.
local function refresh_status(done)
	if #state.repos == 0 then
		if done then
			done()
		end
		return
	end

	local pending = #state.repos * 2

	local function finish()
		pending = pending - 1
		if pending > 0 then
			return
		end
		if done then
			vim.schedule(done)
		end
	end

	for _, repo in ipairs(state.repos) do
		state.status[repo.path] = state.status[repo.path] or {}

		-- --no-optional-locks so a status refresh never fights a build or a
		-- lazygit in the same repo for the index lock.
		vim.system(
			{ "git", "--no-optional-locks", "-C", repo.path, "status", "--porcelain=v2", "--branch" },
			{ text = true },
			function(res)
				if res.code == 0 then
					local info = parse_status(res.stdout)
					local prev = state.status[repo.path] or {}
					info.subject = prev.subject
					state.status[repo.path] = info
				end
				finish()
			end
		)

		vim.system({ "git", "-C", repo.path, "log", "-1", "--pretty=%s" }, { text = true }, function(res)
			local entry = state.status[repo.path] or {}
			entry.subject = res.code == 0 and vim.trim(res.stdout) or ""
			state.status[repo.path] = entry
			finish()
		end)
	end
end

-- Rendering ------------------------------------------------------------------

-- Rendered inside the chip's name block, so the badge highlights carry that
-- block's background -- a badge group with only a foreground falls back to the
-- editor background and shows up as a dark rectangle inside the chip.
local function badge(info)
	if not info then
		return ""
	end
	local out = ""
	local function add(hl, text)
		out = out .. "%#" .. hl .. "#" .. text .. "%#TmuxChip#"
	end
	if (info.dirty or 0) > 0 then
		add("OrgGitChipDirty", " \u{25cf}" .. info.dirty)
	end
	if (info.ahead or 0) > 0 then
		add("OrgGitChipSync", " \u{2191}" .. info.ahead)
	end
	if (info.behind or 0) > 0 then
		add("OrgGitChipSync", " \u{2193}" .. info.behind)
	end
	return out
end

-- The tabline goes in the float's winbar: lazygit owns the terminal grid, so the
-- winbar is the one row of the float nvim still controls. Verified to render even
-- with style="minimal".
local function render_winbar()
	if not vim.api.nvim_win_is_valid(state.win) then
		return
	end

	local tabs = { { label = "overview" } }
	for _, repo in ipairs(state.repos) do
		tabs[#tabs + 1] = { label = repo.name, suffix = badge(state.status[repo.path]) }
	end

	-- first_index 0: the overview is keyed C-g 0, so repo n is chip n, and the
	-- click handler receives that same n.
	vim.wo[state.win].winbar = chips.tabline(tabs, state.current + 1, 0, "OrgGitTabClick")
end

-- string.format's %-Ns pads by bytes, and the badge glyphs are three bytes wide
-- but one cell wide, so a repo with a badge would shove every column after it.
local function pad(text, width)
	local fill = width - vim.fn.strdisplaywidth(text)
	return text .. string.rep(" ", math.max(0, fill))
end

local function render_overview()
	if not vim.api.nvim_buf_is_valid(state.overview) then
		return
	end

	local width = 0
	for _, repo in ipairs(state.repos) do
		width = math.max(width, vim.fn.strdisplaywidth(repo.name))
	end
	width = math.max(width, 4) + 2

	-- The header answers "does anything here need me?" before the eye reaches the
	-- table: totals across the whole org, which is the one number no per-repo
	-- tool can show.
	local total_dirty, total_ahead, repos_dirty = 0, 0, 0
	for _, repo in ipairs(state.repos) do
		local info = state.status[repo.path] or {}
		total_dirty = total_dirty + (info.dirty or 0)
		total_ahead = total_ahead + (info.ahead or 0)
		if (info.dirty or 0) > 0 then
			repos_dirty = repos_dirty + 1
		end
	end

	local header = "  " .. vim.fs.basename(state.root)
	local summary = ("   \u{00b7}   %d repos"):format(#state.repos)
	if total_dirty > 0 then
		summary = summary .. ("   \u{25cf}%d in %d"):format(total_dirty, repos_dirty)
	end
	if total_ahead > 0 then
		summary = summary .. ("   \u{2191}%d to push"):format(total_ahead)
	end
	if total_dirty == 0 and total_ahead == 0 then
		summary = summary .. "   all clean"
	end

	local columns = "  "
		.. pad("", 4)
		.. pad("repo", width)
		.. pad("branch", 14)
		.. pad("status", 9)
		.. pad("sync", 7)
		.. "last commit"
	local rule = "  " .. string.rep("\u{2500}", math.max(20, vim.fn.strdisplaywidth(columns) - 2))

	-- A blank first line: the header was sitting directly under the tabline and
	-- read as a second row of it rather than as the start of the table.
	local lines = { "", header .. summary, "", columns, rule }
	local marks = {}
	row_to_repo, repo_to_row = {}, {}

	local function mark(row, col, len, hl)
		marks[#marks + 1] = { row, col, len, hl }
	end

	mark(1, 0, #header, "OrgGitHeader")
	mark(1, #header, #summary, "OrgGitHeaderDim")
	mark(3, 0, #columns, "OrgGitColumns")
	mark(4, 0, #rule, "OrgGitRule")

	for i, repo in ipairs(state.repos) do
		local info = state.status[repo.path] or {}
		local dirty = (info.dirty or 0) > 0 and ("●" .. info.dirty) or "clean"
		local sync = ""
		if (info.ahead or 0) > 0 then
			sync = sync .. "↑" .. info.ahead
		end
		if (info.behind or 0) > 0 then
			sync = sync .. (sync ~= "" and " " or "") .. "↓" .. info.behind
		end

		-- A repo whose branch has no commits yet has no subject to show; an em
		-- dash says "nothing here" where a blank column just looks unfinished.
		local subject = info.subject
		if not subject or subject == "" then
			subject = "—"
		end

		-- The overview inherits 'wrap', so a long subject spills onto the next
		-- rows and desyncs the cursor-to-repo mapping. Truncated to what is left
		-- of the window instead.
		local used = 2 + 4 + width + 14 + 9 + 7
		local room = math.max(12, vim.api.nvim_win_get_width(state.win) - used - 2)
		if vim.fn.strdisplaywidth(subject) > room then
			subject = vim.fn.strcharpart(subject, 0, room - 1) .. "…"
		end

		local cells = {
			"  ",
			pad(tostring(i), 4),
			pad(repo.name, width),
			pad(info.branch or "?", 14),
			pad(dirty, 9),
			pad(sync, 7),
			subject,
		}
		local line = table.concat(cells)
		lines[#lines + 1] = line
		row_to_repo[#lines] = i -- 1-based buffer row
		repo_to_row[i] = #lines

		-- Byte offsets accumulated from the cells themselves: the badges are
		-- multi-byte, so counted display columns would land in the wrong place.
		local row = #lines - 1
		local at = 0
		local offsets = {}
		for idx, cell in ipairs(cells) do
			offsets[idx] = at
			at = at + #cell
		end

		mark(row, offsets[2], #cells[2], "OrgGitIndex")
		mark(row, offsets[3], #repo.name, "OrgGitRepo")
		mark(row, offsets[4], #(info.branch or "?"), "OrgGitBranch")
		mark(row, offsets[5], #dirty, (info.dirty or 0) > 0 and "OrgGitDirty" or "OrgGitClean")
		if sync ~= "" then
			mark(row, offsets[6], #sync, "OrgGitSync")
		end
		mark(row, offsets[7], #subject, "OrgGitSubject")
	end

	if #state.repos == 0 then
		lines = { "", header .. summary, "", "  no repos one level under this root" }
	end

	lines[#lines + 1] = ""
	local footer = "  \u{23ce} open    r refresh    q close        anywhere: C-g then 0-9"
	lines[#lines + 1] = footer
	mark(#lines - 1, 0, #footer, "OrgGitFooter")

	vim.bo[state.overview].modifiable = true
	vim.api.nvim_buf_set_lines(state.overview, 0, -1, false, lines)
	vim.bo[state.overview].modifiable = false

	vim.api.nvim_buf_clear_namespace(state.overview, ns, 0, -1)
	for _, m in ipairs(marks) do
		pcall(vim.api.nvim_buf_set_extmark, state.overview, ns, m[1], m[2], {
			end_col = m[2] + m[3],
			hl_group = m[4],
		})
	end
end

-- Window ---------------------------------------------------------------------

local function hide()
	if vim.api.nvim_win_is_valid(state.win) then
		pcall(vim.api.nvim_win_hide, state.win)
	end
	state.win = -1
end

-- Called over RPC by scripts/lazygit-open.sh when lazygit's `e` runs, via
-- $LAZYGIT_NVIM_FN. The float is hidden rather than closed, so every repo's
-- lazygit survives and <leader>4 brings the whole set back where it was.
function _G.OrgGitOpenFile(path, line)
	-- The RPC arrives mid-keystroke inside the terminal job; deferring keeps the
	-- window juggling out of that context and lets the shim return at once.
	vim.schedule(function()
		hide()
		vim.cmd.edit(vim.fn.fnameescape(path))
		line = tonumber(line) or 0
		if line > 0 then
			pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
		end
	end)
	return ""
end

-- Ctrl-g is the org prefix. It has to be a prefix rather than plain keys because
-- a repo tab is a live lazygit: the digits are its panel focus, [ ] its panel
-- tabs, Tab its tab cycling, and every other Ctrl key is bound too -- dumping
-- `lazygit -c` leaves only ctrl+g / n / q / v / x free, and Ctrl-arrows belong to
-- macOS Spaces. Consuming Ctrl-g in nvim means the second key never reaches
-- lazygit, so digits work from inside any tab.
local PREFIX = "<C-g>"

local function attach_keys(buf, terminal)
	local function map(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
	end

	for i = 1, 9 do
		map({ "n", "t" }, PREFIX .. i, function()
			M.show(i)
		end, "Org git: repo tab " .. i)
	end
	-- 0 is the overview, keeping the whole scheme to one gesture: C-g then the
	-- number you can see on the tab. Hiding the float stays \\4.
	map({ "n", "t" }, PREFIX .. "0", function()
		M.show(0)
	end, "Org git: overview tab")

	floats.make_modal(buf, "the org git float")

	if not terminal then
		return
	end

	-- Esc is lazygit's back key; a global normal-mode map would steal it.
	map("t", "<Esc>", "<Esc>", "Send Esc to lazygit")
end

local function overview_buf()
	if vim.api.nvim_buf_is_valid(state.overview) then
		return state.overview
	end

	local buf = vim.api.nvim_create_buf(false, true)
	state.overview = buf
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = "orggit"
	vim.bo[buf].buflisted = false

	local function repo_on_line()
		local row = vim.api.nvim_win_get_cursor(state.win)[1]
		return row_to_repo[row]
	end

	vim.keymap.set("n", "<CR>", function()
		local idx = repo_on_line()
		if idx then
			M.show(idx)
		end
	end, { buffer = buf, silent = true, desc = "Org git: open repo tab" })
	vim.keymap.set("n", "r", function()
		refresh_status(function()
			render_overview()
			render_winbar()
		end)
	end, { buffer = buf, silent = true, desc = "Org git: refresh status" })
	vim.keymap.set("n", "q", hide, { buffer = buf, silent = true, desc = "Org git: close" })
	for i = 1, 9 do
		vim.keymap.set("n", tostring(i), function()
			M.show(i)
		end, { buffer = buf, silent = true, desc = "Org git: tab " .. i })
	end
	attach_keys(buf, false)

	return buf
end

-- Spawns a repo's lazygit on first visit, not at open: five idle lazygit
-- processes for an org you only glanced at is a waste, and the tab is created
-- lazily anyway.
local function repo_buf(repo)
	local buf = state.bufs[repo.path]
	if buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
		return buf
	end

	buf = vim.api.nvim_create_buf(false, true)
	state.bufs[repo.path] = buf
	vim.api.nvim_win_set_buf(state.win, buf)

	local cmd, shim = lazygit.build()
	-- An argv list, not a shell string: the paths handed to `-ucf` contain
	-- spaces. The shim's path and the handler name travel in the environment, so
	-- the overlay YAML needs neither.
	vim.fn.jobstart(cmd, {
		term = true,
		cwd = repo.path,
		env = { LAZYGIT_NVIM_OPEN = shim, LAZYGIT_NVIM_FN = "OrgGitOpenFile" },
		on_exit = function()
			-- Wipe the dead terminal, else the next visit reuses it and shows
			-- "[Process exited 0]" instead of starting lazygit.
			vim.schedule(function()
				local dead = state.bufs[repo.path]
				state.bufs[repo.path] = nil
				if vim.api.nvim_buf_is_valid(dead) then
					pcall(vim.api.nvim_buf_delete, dead, { force = true })
				end
				-- Quitting lazygit with `q` should land somewhere useful rather
				-- than on a blank float.
				if vim.api.nvim_win_is_valid(state.win) then
					M.show(0)
				end
			end)
		end,
	})
	vim.bo[buf].buflisted = false
	attach_keys(buf, true)

	-- Every way back into the terminal must land in terminal mode, or keys go to
	-- Vim instead of to lazygit. Registered after vim-options.lua's terminal
	-- autocmd, so the winbar it clears is restored in the same tick.
	vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
		buffer = buf,
		callback = function()
			if vim.api.nvim_get_current_buf() == buf and vim.bo[buf].buftype == "terminal" then
				vim.cmd.startinsert()
				settle_terminal_view()
			end
		end,
	})

	return buf
end

-- A lazygit frame is exactly as wide and tall as the window, so any scrolloff
-- scrolls the view off the frame: sidescrolloff cuts off the left border and
-- every panel looks shifted by those columns. The window is reused across tabs,
-- so an already-scrolled view has to be reset as well as prevented.
--
-- This also puts the tabline back. vim-options.lua clears 'winbar' for every
-- terminal buffer on TermOpen/BufEnter/WinEnter (it hides the statusline in
-- terminals), which would otherwise wipe the tabline the moment the float is
-- re-entered. Re-rendering here rather than fighting that autocmd keeps the
-- terminal-chrome rule in one place.
function settle_terminal_view()
	if not vim.api.nvim_win_is_valid(state.win) then
		return
	end
	vim.wo[state.win].sidescrolloff = 0
	vim.wo[state.win].scrolloff = 0
	vim.fn.winrestview({ leftcol = 0, topline = 1 })
	render_winbar()
end

-- Called by the winbar's click labels. Mouse clicks land here even from inside a
-- lazygit tab: the winbar is nvim's row, not part of the terminal grid, so the
-- click never reaches lazygit's own mouse handling.
function _G.OrgGitTabClick(index)
	M.show(index)
end

function M.show(idx)
	if not vim.api.nvim_win_is_valid(state.win) then
		return
	end
	-- Which repo the cursor should land on when going back to the overview: the
	-- one you just came from, so C-g then Enter is a round trip.
	local previous = state.current
	idx = math.max(0, math.min(idx or 0, #state.repos))
	state.current = idx

	if idx == 0 then
		vim.api.nvim_win_set_buf(state.win, overview_buf())
		render_overview()
		render_winbar()
		vim.cmd.stopinsert()
		-- The cursor is the row selector here, so it must start on a repo rather
		-- than on the header, and cursorline is what makes the selection visible.
		vim.wo[state.win].cursorline = true
		vim.wo[state.win].cursorlineopt = "line"
		local row = repo_to_row[math.max(previous, 1)] or repo_to_row[1]
		if row then
			pcall(vim.api.nvim_win_set_cursor, state.win, { row, 0 })
		end
		return
	end

	local repo = state.repos[idx]
	local buf = repo_buf(repo)
	vim.api.nvim_win_set_buf(state.win, buf)
	vim.wo[state.win].cursorline = false

	render_winbar()
	vim.cmd.startinsert()
	settle_terminal_view()

	-- Counts on the tabline go stale the moment you stage something, so a switch
	-- away from a repo is the natural moment to re-read them.
	refresh_status(function()
		render_winbar()
		if state.current == 0 then
			render_overview()
		end
	end)
end

function M.toggle(root)
	if vim.api.nvim_win_is_valid(state.win) then
		hide()
		return
	end

	local new_root = root and vim.fn.expand(root) or state.root or resolve_root()
	if new_root ~= state.root then
		state.root = new_root
		state.repos = discover(new_root)
		state.status = {}
		state.current = 0
	end

	if #state.repos == 0 then
		vim.notify(
			("org-git: no repos one level under %s"):format(new_root),
			vim.log.levels.WARN
		)
		return
	end

	local h = math.floor(vim.o.lines * 0.9)
	local w = math.floor(vim.o.columns * 0.9)
	state.win = vim.api.nvim_open_win(overview_buf(), true, {
		relative = "editor",
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - w) / 2),
		height = h,
		width = w,
		style = "minimal",
		border = "rounded",
	})

	vim.wo[state.win].winhighlight = chips.WINHIGHLIGHT


	M.show(state.current)
	refresh_status(function()
		render_winbar()
		if state.current == 0 then
			render_overview()
		end
	end)
end

vim.keymap.set({ "n", "t" }, "<leader>4", function()
	M.toggle()
end, { desc = "Toggle org git (repo tabs)" })

-- :OrgGit with no argument uses the resolved root; with one it switches roots, so
-- a second org is a command away rather than a config change.
vim.api.nvim_create_user_command("OrgGit", function(opts)
	M.toggle(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", complete = "dir", desc = "Org-wide git float" })

return M
