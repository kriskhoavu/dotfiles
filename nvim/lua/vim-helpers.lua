local function find_shortcut_help()
	local config_dir = vim.fn.resolve(vim.fn.stdpath("config"))
	local candidates = {
		vim.fn.fnamemodify(config_dir, ":h") .. "/SHORTCUTS.md",
		vim.fn.getcwd() .. "/SHORTCUTS.md",
		vim.fn.expand("~/Personal/01. happy-learning/Kris/dotfiles/SHORTCUTS.md"),
	}

	for _, path in ipairs(candidates) do
		if vim.fn.filereadable(path) == 1 then
			return path
		end
	end
end

-- <leader>?: SHORTCUTS.md in a tabbed float, one tab per "##" section (derived,
-- so a new section is a new tab), with the org git float's chips.
local chips = require("tmux-chips")
local floats = require("floating-helpers")

local SHORT_LABEL = {
	["macOS Window Pairing"] = "macOS",
	["Zsh Navigation"] = "Zsh",
	["Git Stuff"] = "Git",
	["Development And AI CLI Helpers"] = "Dev & AI",
	["IdeaVim And IntelliJ"] = "IdeaVim",
}

-- Text above the first "##" is kept as the first tab's intro, not dropped.
local function parse_sections(path)
	local sections, preamble = {}, {}

	for _, line in ipairs(vim.fn.readfile(path)) do
		local heading = line:match("^## (.+)$")
		if heading then
			sections[#sections + 1] = {
				title = heading,
				label = SHORT_LABEL[heading] or heading:match("^(%S+)"),
				lines = {},
			}
		elseif #sections > 0 then
			table.insert(sections[#sections].lines, line)
		else
			table.insert(preamble, line)
		end
	end

	-- An intro, not part of the first section's body, where it read as belonging
	-- to that heading.
	if sections[1] then
		sections[1].intro = preamble
	end
	return sections
end

local help = { win = -1, bufs = {}, current = 1, sections = nil }

-- Forward declared: the tab click handler and nav use it first.
local help_show

-- Alt-h / Alt-l step sections, as in the org git float.
local help_nav = {
	prev = function()
		help_show((help.current - 2) % #help.sections + 1)
	end,
	next = function()
		help_show(help.current % #help.sections + 1)
	end,
	jump = function(n)
		help_show(n)
	end,
}

-- One buffer per section, so closing wipes them or they pile up.
local function help_close()
	if vim.api.nvim_win_is_valid(help.win) then
		vim.api.nvim_win_close(help.win, true)
	end
	help.win = -1
	local stale = help.bufs
	help.bufs = {}
	vim.schedule(function()
		for _, b in pairs(stale) do
			if vim.api.nvim_buf_is_valid(b) then
				pcall(vim.api.nvim_buf_delete, b, { force = true })
			end
		end
	end)
end

local function help_render()
	if not vim.api.nvim_win_is_valid(help.win) then
		return
	end

	local tabs = {}
	for _, section in ipairs(help.sections) do
		tabs[#tabs + 1] = { label = section.label }
	end
	-- Registered once: re-registering per redraw would leak a closer.
	help.close_x = help.close_x
		or floats.close_segment(function()
			return help.win
		end, nil, { on_close = help_close })

	vim.wo[help.win].winbar = chips.tabline(tabs, help.current, 1, "ShortcutHelpTabClick") .. help.close_x
end

function _G.ShortcutHelpTabClick(index)
	help_show(index)
end

function help_show(idx)
	if not vim.api.nvim_win_is_valid(help.win) or not help.sections[idx] then
		return
	end
	help.current = idx

	local buf = help.bufs[idx]
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		local section = help.sections[idx]
		buf = vim.api.nvim_create_buf(false, true)
		help.bufs[idx] = buf

		-- Heading restored for the markdown renderer; blank row separates it from the tabline.
		local lines = { "" }
		if section.intro then
			vim.list_extend(lines, section.intro)
		end
		vim.list_extend(lines, { "# " .. section.title, "" })
		vim.list_extend(lines, section.lines)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

		vim.bo[buf].filetype = "markdown"
		vim.bo[buf].modifiable = false
		vim.bo[buf].buflisted = false

		local close = help_close

		vim.keymap.set("n", "q", close, { buffer = buf, silent = true, desc = "Close shortcut help" })
		vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true, desc = "Close shortcut help" })
		for i = 1, math.min(#help.sections, 9) do
			vim.keymap.set("n", tostring(i), function()
				help_show(i)
			end, { buffer = buf, silent = true, desc = "Shortcut help: section " .. i })
		end
		-- Tab / S-Tab as an alternative to the digits.
		vim.keymap.set("n", "<Tab>", function()
			help_show(help.current % #help.sections + 1)
		end, { buffer = buf, silent = true, desc = "Shortcut help: next section" })
		vim.keymap.set("n", "<S-Tab>", function()
			help_show((help.current - 2) % #help.sections + 1)
		end, { buffer = buf, silent = true, desc = "Shortcut help: previous section" })
		-- h and l stay cursor motion; Alt-h / Alt-l step sections.
	end

	floats.attach(help.win, buf, { cursorline = true, label = "the shortcut help", nav = help_nav })
	help_render()
end

vim.api.nvim_create_user_command("ShortcutHelp", function()
	local path = find_shortcut_help()
	if not path then
		vim.notify("SHORTCUTS.md not found", vim.log.levels.WARN)
		return
	end

	if vim.api.nvim_win_is_valid(help.win) then
		vim.api.nvim_win_close(help.win, true)
		help.win = -1
		return
	end

	-- Re-read on every open: the file is edited in this repo.
	help.sections = parse_sections(path)
	help.bufs = {}
	if #help.sections == 0 then
		vim.notify("SHORTCUTS.md has no ## sections", vim.log.levels.WARN)
		return
	end

	-- nvim needs a buffer to open a window; help_show swaps in the real one, and
	-- the placeholder is deleted below so it does not leak per open.
	local placeholder = vim.api.nvim_create_buf(false, true)
	local _
	_, help.win = floats.open({
		buf = placeholder,
		width = 0.78,
		height = 0.85,
		label = "the shortcut help",
		cursorline = true,
		nav = help_nav,
	})

	help_show(math.min(help.current, #help.sections))

	if vim.api.nvim_buf_is_valid(placeholder) and vim.api.nvim_get_current_buf() ~= placeholder then
		pcall(vim.api.nvim_buf_delete, placeholder, { force = true })
	end
end, { desc = "Open shortcut help center" })

vim.keymap.set("n", "<leader>?", "<cmd>ShortcutHelp<cr>", { desc = "Open shortcut help center" })

vim.keymap.set("n", "<leader>ce", function()
	local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
	if #diagnostics > 0 then
		local message = diagnostics[1].message
		vim.fn.setreg("+", message)
		print("Copied diagnostic: " .. message)
	else
		print("No diagnostic at cursor")
	end
end, { noremap = true, silent = true, desc = "Copy diagnostic to clipboard" })


-- Directory tree in a float
vim.api.nvim_create_user_command("ShowTree", function()
	local buf, win = floats.open({
		width = 0.6,
		label = "the tree view",
		close = true,
	})

	-- Modal, so it needs a way out besides :q.
	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end, { buffer = buf, silent = true, desc = "Close the tree view" })
	end

	vim.fn.jobstart("tree -L 4", {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					vim.api.nvim_buf_set_lines(buf, -1, -1, true, { line })
				end
			end
		end,
	})
end, {})

vim.keymap.set("n", "<leader>vt", ":ShowTree<CR>", { desc = "Show directory tree in floating window" })

-- Theme switcher
local themes = { "tokyonight", "catppuccin", "darcula-solid" }
local current_theme_idx = 1

vim.api.nvim_create_user_command("ThemeToggle", function()
    current_theme_idx = current_theme_idx % #themes + 1
    vim.cmd.colorscheme(themes[current_theme_idx])
    print("Theme: " .. themes[current_theme_idx])
end, { desc = "Toggle between themes" })

vim.api.nvim_create_user_command("Theme", function(opts)
    local theme = opts.args
    if theme and theme ~= "" then
        vim.cmd.colorscheme(theme)
        print("Theme: " .. theme)
    else
        print("Available: tokyonight, catppuccin, darcula-solid")
    end
end, { nargs = "?", complete = function() return themes end, desc = "Set theme" })

