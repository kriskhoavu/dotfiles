return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Neotree",
    keys = {
      { "<leader>1", "<cmd>Neotree toggle left<cr>", silent = true, desc = "Toggle Explorer" },
      { "<leader>f.", "<cmd>Neotree filesystem reveal left<cr>", silent = true, desc = "Select in Project View" },
      -- "<" / ">" cycle sources from here
      { "<leader>gs", "<cmd>Neotree toggle git_status left<cr>", silent = true, desc = "Toggle Git status tree" },
    },
    -- Loaded up front only when it opens at start: no file arguments, or a
    -- directory to hijack. `nvim file` skips its ~60ms.
    init = function()
      local arg = vim.fn.argv(0)
      if vim.fn.argc() == 0 or vim.fn.isdirectory(arg) == 1 then
        require("lazy").load({ plugins = { "neo-tree.nvim" } })
      end
    end,
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

          if not current:is_expanded() then
            -- toggle_directory only renders on its unloaded branch; with skip_redraw a
            -- scanned node collapses without repainting, so handle that here.
            if current.loaded == false then
              fs.toggle_directory(state, current, nil, true, false, function()
                vim.schedule(function()
                  drill(state.tree:get_node(current:get_id()))
                end)
              end)
              return
            end
            current:expand()
            state.explicitly_opened_nodes = state.explicitly_opened_nodes or {}
            state.explicitly_opened_nodes[current:get_id()] = true
          end

          local children = state.tree:get_nodes(current:get_id())
          if not children or #children == 0 then
            renderer.redraw(state)
            return
          end

          -- Continue drilling if single directory child, otherwise stop. Redraw
          -- once here rather than per level so a deep chain costs one repaint.
          local first = children[1]
          if #children == 1 and first.type == "directory" then
            drill(first)
            return
          end
          renderer.redraw(state)
          renderer.focus_node(state, first:get_id())
        end

        drill(node)
      end

      local function copy_node_path(state, mode)
        local node = state.tree:get_node()
        if not node or not node.path then return end

        local path = node.path
        if mode == "relative" then
          path = vim.fn.fnamemodify(path, ":.")
        end

        vim.fn.setreg("+", path)
        vim.fn.setreg('"', path)
        vim.notify("Copied path: " .. path)
      end

      require("neo-tree").setup({
        -- Allow opening files in window with terminal (don't split)
        open_files_do_not_replace_types = { "trouble", "qf" },
        filesystem = {
          use_libuv_file_watcher = true,
          group_empty_dirs = false,
          follow_current_file = { enabled = false },
          filtered_items = {
            -- visible keeps everything on screen; the hide_* flags only mark
            -- entries as filtered, which is what dims them. A leading dot is
            -- a convention, not a demotion -- only gitignored is dimmed.
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = true,
          },
          components = {
            -- Show only basename for root node
            name = function(config, node, state)
              local highlights = require("neo-tree.ui.highlights")
              local common = require("neo-tree.sources.common.components")
              local highlight = config.highlight or highlights.FILE_NAME
              if node.type == "directory" then
                highlight = highlights.DIRECTORY_NAME
              end
              if node:get_depth() == 1 then
                return {
                  text = vim.fn.fnamemodify(node.path, ":t"),
                  highlight = highlight,
                }
              end

              -- Overriding this component drops the dimming the default one
              -- applies, which left only the icon gray.
              if config.use_filtered_colors ~= false then
                local filtered_by = common.filtered_by(config, node, state)
                highlight = filtered_by.highlight or highlight
              end

              return {
                text = node.name,
                highlight = highlight,
              }
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
              ["gf"] = function(state)
                local node = state.tree:get_node()
                local path = node.type == "directory" and node.path or vim.fn.fnamemodify(node.path, ":h")
                vim.fn.jobstart({ "open", path }, { detach = true })
              end,
              ["y"] = function(state)
                copy_node_path(state, "relative")
              end,
              ["Y"] = function(state)
                copy_node_path(state, "absolute")
              end,
            },
          },
        },
        git_status = {
          window = {
            mappings = {
              -- The source has staging and commits but no diff. gd opens
              -- Diffview on the file under the cursor. Lua API, not
              -- :DiffviewOpen: the command exists only once loaded, and a
              -- separate argument keeps paths with spaces intact.
              ["gd"] = function(state)
                local node = state.tree:get_node()
                if not node or not node.path or node.type == "directory" then return end
                require("diffview").open({ "--", node.path })
              end,
            },
          },
        },
      })

      -- Keep NeoTree pinned to the left: lock its width and redirect files opened inside it
      local neotree_win_id = nil
      local neotree_buf_id = nil

      -- Statusline for Neo-tree windows: the tree's root on the left, the
      -- selected entry on the right.
      _G.NeoTreeStatusline = function()
        local ok, state = pcall(function()
          return require("neo-tree.sources.manager").get_state(vim.b.neo_tree_source or "filesystem")
        end)
        local root = ok and state.path or vim.fn.getcwd()
        local node = ok and state.tree and state.tree:get_node()
        local selected = node and node.name or ""
        local function esc(text)
          return (text:gsub("%%", "%%%%"))
        end
        return " " .. esc(vim.fn.fnamemodify(root, ":t")) .. "%=" .. esc(selected) .. " "
      end
      local neotree_statusline = "%{%v:lua.NeoTreeStatusline()%}"

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "neo-tree",
        callback = function()
          vim.wo.statusline = neotree_statusline
        end,
      })
      vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
        callback = function()
          if vim.bo.filetype == "neo-tree" then
            vim.wo.statusline = neotree_statusline
          end
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("NeoTreePin", { clear = true }),
        pattern = "neo-tree",
        callback = function()
          neotree_win_id = vim.api.nvim_get_current_win()
          neotree_buf_id = vim.api.nvim_get_current_buf()
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
            -- No editing window yet: split one off for the file and give the tree its
            -- window back. "wincmd l | edit #" threw E499 with no alternate file.
            vim.cmd("rightbelow vsplit")
            vim.api.nvim_win_set_buf(0, buf)
            if neotree_buf_id and vim.api.nvim_buf_is_valid(neotree_buf_id)
              and vim.api.nvim_win_is_valid(neotree_win_id) then
              vim.api.nvim_win_set_buf(neotree_win_id, neotree_buf_id)
            end
          end
        end,
      })

      -- Auto-open neo-tree when starting without file arguments
      vim.api.nvim_create_autocmd("VimEnter", {
        nested = true,
        callback = vim.schedule_wrap(function()
          if vim.fn.argc() ~= 0 then return end
          vim.cmd("Neotree filesystem reveal left")
          vim.cmd("wincmd l")

          -- A restored terminal comes back unloaded, and an unloaded buffer
          -- reports buftype "", so buftype alone misses it and every start
          -- added another. Match the term:// name, keep one, wipe the husks.
          local live, dead = nil, {}
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf)
              and vim.api.nvim_buf_get_name(buf):match("^term://") then
              if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "terminal" then
                live = live or buf
              else
                dead[#dead + 1] = buf
              end
            end
          end
          for _, buf in ipairs(dead) do
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          end
          if live then return end

          require("term-env").without_tmux(function()
            vim.cmd("terminal")
          end)
        end),
      })
    end,
  },
}
