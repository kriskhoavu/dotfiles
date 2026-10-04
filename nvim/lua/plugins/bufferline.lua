return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      -- Dark-red surface, bold white label. Dark in both appearances, like
      -- WezTerm's active tab, so only the unselected surfaces follow the theme.
      local mode = require("theme-mode")
      local c = mode.colors
      local selected_background = mode.selected_bg

      -- :bdelete on a visible buffer closes its window too, which with
      -- Neo-tree and one editing window leaves the tree alone on screen.
      -- Point every window at a replacement first, then delete.
      local function close_buffer_keep_layout(bufnr)
        bufnr = bufnr or vim.api.nvim_get_current_buf()
        if not vim.api.nvim_buf_is_valid(bufnr) then return end

        local function replacement()
          local alt = vim.fn.bufnr("#")
          if alt ~= -1 and alt ~= bufnr and vim.api.nvim_buf_is_valid(alt)
            and vim.bo[alt].buflisted then
            return alt
          end
          for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
            if info.bufnr ~= bufnr then return info.bufnr end
          end
          -- Nothing else listed: an empty buffer keeps the window alive.
          return vim.api.nvim_create_buf(true, false)
        end

        local shown_in = vim.fn.win_findbuf(bufnr)
        if #shown_in > 0 then
          local keep = replacement()
          for _, win in ipairs(shown_in) do
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_set_buf(win, keep)
            end
          end
        end

        -- Terminals are always "modified", so they need the bang.
        if vim.bo[bufnr].buftype == "terminal" then
          pcall(vim.cmd, "bdelete! " .. bufnr)
        else
          pcall(vim.cmd, "bdelete " .. bufnr)
        end
      end

      require("bufferline").setup({
        highlights = {
          fill = { bg = c.fill_bg },
          background = { fg = c.tab_fg, bg = c.tab_bg },
          buffer_visible = { fg = c.visible_fg, bg = c.visible_bg },
          buffer_selected = { fg = "#ffffff", bg = selected_background, bold = true, italic = false },
          indicator_selected = { fg = "#ffffff", bg = selected_background },
          close_button_selected = { fg = "#ffffff", bg = selected_background },
          modified_selected = { fg = "#f5a97f", bg = selected_background },
          diagnostic_selected = { fg = "#ffffff", bg = selected_background },
          hint_selected = { fg = "#94e2d5", bg = selected_background },
          info_selected = { fg = "#89b4fa", bg = selected_background },
          warning_selected = { fg = "#f9e2af", bg = selected_background },
          error_selected = { fg = "#f38ba8", bg = selected_background },
          -- The path prefix on a name two buffers share. Left unset these keep
          -- the colorscheme's grey, a grey block inside the chip.
          duplicate = { fg = c.tab_fg, bg = c.tab_bg, italic = false },
          duplicate_visible = { fg = c.visible_fg, bg = c.visible_bg, italic = false },
          duplicate_selected = { fg = "#ffffff", bg = selected_background, bold = true, italic = false },

          separator = { fg = c.separator, bg = c.tab_bg },
          separator_visible = { fg = c.separator, bg = c.visible_bg },
          separator_selected = { fg = "#ffffff", bg = selected_background },
        },
        options = {
          mode = "buffers",
          numbers = "none",
          close_command = close_buffer_keep_layout,
          right_mouse_command = close_buffer_keep_layout,
          diagnostics = false,
          name_formatter = function(buf)
            -- buf has: name, path, bufnr
            if vim.bo[buf.bufnr].buftype == "terminal" then
              -- Terminal paths look like "term:///path//PID:/bin/zsh"
              -- buf.name is already fnamemodify(path, ":t") which gives "PID:/bin/zsh" or similar
              local path = buf.path or ""
              local shell = path:match("/([^/]+)$") or "terminal"
              -- Assign left-to-right index among listed terminal buffers
              local index = 0
              for _, b in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted and vim.bo[b].buftype == "terminal" then
                  index = index + 1
                  if b == buf.bufnr then
                    return shell .. " - " .. index
                  end
                end
              end
              return shell
            end
          end,
          offsets = {
            {
              filetype = "neo-tree",
              text = "File Explorer",
              highlight = "Directory",
              separator = true,
            },
          },
          show_buffer_close_icons = true,
          show_close_icon = false,
          separator_style = { "┃", "┃" },
          -- Hide unwanted buffers from bufferline
          custom_filter = function(buf_number)
            local buf_name = vim.fn.bufname(buf_number)
            local buf_type = vim.bo[buf_number].buftype
            -- Hide terminal buffers
            -- if buf_type == "terminal" then
            --   return false
            -- end            
            -- Hide gitsigns diff buffers
            if buf_name:match("^gitsigns://") then
              return false
            end
            -- Hide unnamed empty buffers
            if buf_name == "" and buf_type == "" then
              return false
            end
            return true
          end,
        },
      })

      -- Bufferline keymaps
      vim.keymap.set({ "n", "i", "t" }, "<A-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
      vim.keymap.set({ "n", "i", "t" }, "<A-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })

      -- No Alt+digit: tmux is the outer layer and eats Alt+1..9 first.
      -- Alt+h / Alt+l above is the way between buffers.
      vim.keymap.set("n", "<leader>x", function()
        local current = vim.fn.bufnr('%')
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = current })

        -- If in gitsigns diff mode, close the gitsigns window only (keep the file)
        if vim.wo.diff then
          for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local wbuf = vim.api.nvim_win_get_buf(w)
            if vim.fn.bufname(wbuf):match("^gitsigns://") then
              vim.api.nvim_win_close(w, true)
              pcall(vim.cmd, "bdelete! " .. wbuf)
              break
            end
          end
          vim.cmd("diffoff")
          return
        end

        -- Count real editing windows (exclude NeoTree, floating, nofile)
        local editing_wins = {}
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local cfg = vim.api.nvim_win_get_config(w)
          local wbuf = vim.api.nvim_win_get_buf(w)
          if cfg.relative == "" and vim.bo[wbuf].filetype ~= "neo-tree" then
            table.insert(editing_wins, w)
          end
        end

        if #editing_wins > 1 then
          -- Multiple splits open: close this window, delete buffer if no longer visible
          vim.cmd("wincmd c")
          if #vim.fn.win_findbuf(current) == 0 then
            if buftype == "terminal" then
              vim.cmd("bdelete! " .. current)
            else
              pcall(vim.cmd, "bdelete " .. current)
            end
          end
        else
          local bufs = vim.fn.getbufinfo({ buflisted = 1 })
          if #bufs <= 1 then
            vim.cmd("quit")
          else
            vim.cmd("bprevious")
            if buftype == "terminal" then
              vim.cmd("bdelete! " .. current)
            else
              vim.cmd("bdelete " .. current)
            end
          end
        end
      end, { desc = "Close current buffer, switch to previous" })
      vim.keymap.set("n", "<leader>X", function()
        local current = vim.api.nvim_get_current_buf()
        -- A restored session lists buffers without loading them, so the test
        -- is "listed": on "loaded" this did nothing until each was visited.
        for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
          local bufnr = buf.bufnr
          if bufnr ~= current and vim.bo[bufnr].buftype == "" then
            -- An unsaved buffer refuses to close; skip it rather than let the
            -- error abort the rest of the loop.
            pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
          end
        end
      end, { desc = "Close other buffers (keep terminals)" })
    end,
  },
}
