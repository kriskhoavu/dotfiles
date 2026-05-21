return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        highlights = {
          fill = { bg = "#0f1117" },
          background = { fg = "#7f8ea3", bg = "#1a1f2b" },
          buffer_visible = { fg = "#aab7cf", bg = "#1f2633" },
          buffer_selected = { fg = "#e8eefc", bg = "#2b3b57", bold = true, italic = false },
          indicator_selected = { fg = "#8b0000", bg = "#2b3b57" },
          close_button_selected = { fg = "#dbe6ff", bg = "#2b3b57" },
          modified_selected = { fg = "#f5a97f", bg = "#2b3b57" },
          diagnostic_selected = { fg = "#e8eefc", bg = "#2b3b57" },
          hint_selected = { fg = "#8bd5ca", bg = "#2b3b57" },
          info_selected = { fg = "#7dc4e4", bg = "#2b3b57" },
          warning_selected = { fg = "#f5a97f", bg = "#2b3b57" },
          error_selected = { fg = "#ed8796", bg = "#2b3b57" },
          separator = { fg = "#344055", bg = "#1a1f2b" },
          separator_visible = { fg = "#344055", bg = "#1f2633" },
          separator_selected = { fg = "#f5a97f", bg = "#2b3b57" },
        },
        options = {
          mode = "buffers",
          numbers = "none",
          close_command = "bdelete! %d",
          right_mouse_command = "bdelete! %d",
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
      vim.keymap.set("n", "H", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
      vim.keymap.set("n", "L", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
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
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if buf ~= current and vim.api.nvim_buf_is_loaded(buf) then
            local bt = vim.bo[buf].buftype
            if bt == "" then
              vim.api.nvim_buf_delete(buf, { force = false })
            end
          end
        end
      end, { desc = "Close other buffers (keep terminals)" })
    end,
  },
}
