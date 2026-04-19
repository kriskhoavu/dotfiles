return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns
                local function map(mode, l, r, desc)
                    vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
                end

                -- navigation
                map("n", "]h", gs.next_hunk, "Next hunk")
                map("n", "[h", gs.prev_hunk, "Prev hunk")

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
                map("n", "<leader>hd", gs.diffthis, "Diff this")
                map("n", "<leader>hD", function()
                    gs.diffthis("~")
                end, "Diff this ~ (against last commit)")

                -- text object
                map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
            end,
        },
    },
    {
        "sindrets/diffview.nvim",
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
