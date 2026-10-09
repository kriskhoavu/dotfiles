require("lazygit-float")
-- Loaded now, not on \hd: its autocmds also tidy up after :Gitsigns diffthis.
local gitsigns_diff = require("gitsigns-diff")

local function close_diffview()
    vim.cmd("DiffviewClose")
end

-- q/<esc> close from anywhere in the view, including the file tree panel, which
-- diffview leaves unbound by default.
local function close_keys()
    return {
        { "n", "q", close_diffview, { desc = "Close Diffview" } },
        { "n", "<esc>", close_diffview, { desc = "Close Diffview" } },
    }
end

return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            -- Who last touched the line under the cursor, at the end of it.
            -- Virtual text, so it never shifts the buffer's own columns.
            current_line_blame = true,
            current_line_blame_opts = {
                virt_text = true,
                virt_text_pos = "eol",
                -- Long enough that it does not flicker while j/k is held.
                delay = 300,
                ignore_whitespace = false,
            },
            current_line_blame_formatter = "  <author>, <author_time:%R> - <summary>",

            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns
                local function map(mode, l, r, desc)
                    vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
                end

                -- navigation
                map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
                map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")

                -- Actions (hunk)
                map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
                map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")

                map("v", "<leader>hs", function()
                    gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end, "Stage hunk (visual)")
                map("v", "<leader>hr", function()
                    gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end, "Reset hunk (visual)")

                -- Actions (buffer)
                map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
                map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
                map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")

                -- Blame
                map("n", "<leader>hb", function()
                   gs.blame_line({ full = true })
                end, "Blame line (full)")
                map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle line blame")

                -- Diff / Preview
                map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
                map("n", "<leader>hd", function()
                    gitsigns_diff.toggle()
                end, "Toggle diff this")
                map("n", "<leader>hD", function()
                    gitsigns_diff.toggle("~")
                end, "Toggle diff this ~ (against last commit)")
                -- text object
                map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
            end,
        },
    },
    {
        "sindrets/diffview.nvim",
        config = function(_, opts)
            require("diffview").setup(opts)

            -- Diffview's left pane is a blob with no path, so LSPs cannot
            -- resolve the project and flood it. Mute until the view closes.
            local diagnostics_were_enabled = true
            vim.api.nvim_create_autocmd("User", {
                group = vim.api.nvim_create_augroup("DiffviewQuietDiagnostics", { clear = true }),
                pattern = { "DiffviewViewOpened", "DiffviewViewClosed" },
                callback = function(args)
                    if args.match == "DiffviewViewOpened" then
                        diagnostics_were_enabled = vim.diagnostic.is_enabled()
                        vim.diagnostic.enable(false)
                    elseif diagnostics_were_enabled then
                        vim.diagnostic.enable(true)
                    end
                end,
            })
        end,
        opts = {
            keymaps = {
                view = close_keys(),
                file_panel = close_keys(),
                file_history_panel = close_keys(),
            },
        },
        -- <leader>2: Toggle Git (Diffview)
        keys = {
            {
                "<leader>2",
                function()
                    local lib = require("diffview.lib")
                    if next(lib.views) == nil then
                        vim.cmd("DiffviewOpen")
                    else
                        vim.cmd("DiffviewClose")
                    end
                end,
                desc = "Toggle Diffview",
            },
            {
                "<leader>hf",
                function()
                    vim.cmd("DiffviewFileHistory %")
                end,
                desc = "File history",
            },
            -- Open current file and close DiffView (like VSCode's git.openFile)
            {
                "<leader><Down>",
                function()
                    local lib = require("diffview.lib")
                    local view = lib.get_current_view()
                    if view and view.cur_entry then
                        local path = view.cur_entry.absolute_path
                        vim.cmd("DiffviewClose")
                        vim.cmd("edit " .. vim.fn.fnameescape(path))
                    end
                end,
                desc = "Open current file from Diffview (leader+Down)",
            },
        },
    },
}
