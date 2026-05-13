return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    lazy = false,
    config = function()
      local fs_commands = require("neo-tree.sources.filesystem.commands")
      local fs = require("neo-tree.sources.filesystem")
      local renderer = require("neo-tree.ui.renderer")

      -- Drill-down: auto-expand through single-child directories
      local function drill_down(state)
        local node = state.tree:get_node()
        if not node then return end

        -- Open file normally
        if node.type ~= "directory" then
          fs_commands.open(state)
          return
        end

        local function drill(current)
          if not current then return end

          -- Expand first, then retry via callback
          if not current:is_expanded() then
            fs.toggle_directory(state, current, nil, true, false, function()
              vim.schedule(function()
                drill(state.tree:get_node(current:get_id()))
              end)
            end)
            return
          end

          local children = state.tree:get_nodes(current:get_id())
          if not children or #children == 0 then return end

          -- Continue drilling if single directory child, otherwise stop
          local first = children[1]
          renderer.focus_node(state, first:get_id())
          if #children == 1 and first.type == "directory" then
            drill(first)
          end
        end

        drill(node)
      end

      require("neo-tree").setup({
        -- Allow opening files in window with terminal (don't split)
        open_files_do_not_replace_types = { "trouble", "qf" },
        filesystem = {
          use_libuv_file_watcher = true,
          group_empty_dirs = false,
          follow_current_file = { enabled = true },
          filtered_items = {
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = true,
          },
          components = {
            -- Show only basename for root node
            name = function(config, node, state)
              local highlights = require("neo-tree.ui.highlights")
              local highlight = config.highlight or highlights.FILE_NAME
              if node.type == "directory" then
                highlight = highlights.DIRECTORY_NAME
              end
              if node:get_depth() == 1 then
                return {
                  text = vim.fn.fnamemodify(node.path, ":t"),
                  highlight = highlight,
                }
              else
                return {
                  text = node.name,
                  highlight = highlight,
                }
              end
            end,
          },
          find_by_full_path_words = false,
          find_command = "find",
          find_args = {
            fd = {
              "--exclude", ".git",
              "--exclude", "node_modules",
            },
          },
          async_directory_scan = "auto",
          window = {
            mappings = {
              ["<cr>"] = drill_down,
              ["l"] = drill_down,
              ["h"] = "close_node",
              ["/"] = "fuzzy_finder",
            },
          },
        },
      })

      -- VSCode/IntelliJ-like keybindings
      -- <leader>1: Toggle Explorer (Neo-tree)
      vim.keymap.set("n", "<leader>1", "<cmd>Neotree toggle left<cr>", { silent = true, desc = "Toggle Explorer" })
      vim.keymap.set("n", "<leader>f.", "<cmd>Neotree filesystem reveal left<cr>", { silent = true, desc = "Select in Project View" })

      -- Keep NeoTree pinned to the left: lock its width and redirect files opened inside it
      local neotree_win_id = nil

      -- Hide statusline for Neo-tree windows
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "neo-tree",
        callback = function()
          vim.wo.statusline = " "
        end,
      })
      vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
        callback = function()
          if vim.bo.filetype == "neo-tree" then
            vim.wo.statusline = " "
          end
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("NeoTreePin", { clear = true }),
        pattern = "neo-tree",
        callback = function()
          neotree_win_id = vim.api.nvim_get_current_win()
          vim.opt_local.winfixwidth = true
        end,
      })

      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = vim.api.nvim_create_augroup("NeoTreeRedirect", { clear = true }),
        callback = function(args)
          local buf = args.buf
          if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype == "neo-tree" then return end
          local win = vim.api.nvim_get_current_win()
          if not neotree_win_id or win ~= neotree_win_id then return end

          -- A regular file landed in the NeoTree window — find a proper editing window
          local target = nil
          for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if w ~= neotree_win_id then
              local wbuf = vim.api.nvim_win_get_buf(w)
              local cfg  = vim.api.nvim_win_get_config(w)
              if vim.bo[wbuf].filetype ~= "neo-tree" and cfg.relative == "" then
                target = w
                break
              end
            end
          end

          if target then
            vim.api.nvim_win_set_buf(target, buf)
            vim.api.nvim_set_current_win(target)
          else
            -- No editing window exists yet — open one to the right
            vim.cmd("wincmd l | edit #")
          end
        end,
      })

      -- Auto-open neo-tree when starting without file arguments
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          if vim.fn.argc() ~= 0 then return end
          vim.cmd("Neotree filesystem reveal left")
          vim.cmd("wincmd l")   -- Move to right window
          vim.cmd("terminal")   -- Open terminal
        end,
      })
    end,
  },
}
