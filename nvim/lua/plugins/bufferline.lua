return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          mode = "buffers",
          numbers = "none",
          close_command = "bdelete! %d",
          right_mouse_command = "bdelete! %d",
          diagnostics = "nvim_lsp",
          diagnostics_indicator = function(count, level)
            local icon = level:match("error") and " " or " "
            return " " .. icon .. count
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
          separator_style = "thin",
          -- Hide unwanted buffers from bufferline
          custom_filter = function(buf_number)
            local buf_name = vim.fn.bufname(buf_number)
            local buf_type = vim.bo[buf_number].buftype
            -- Hide terminal buffers
            -- if buf_type == "terminal" then
            --   return false
            -- end            
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
      vim.keymap.set("n", "<leader>X", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
    end,
  },
}
