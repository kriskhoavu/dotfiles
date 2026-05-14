return {
  "rmagatti/auto-session",
  lazy = false,
  opts = {
    suppressed_dirs = { "~/", "~/Downloads", "/tmp" },
    -- Auto save/restore sessions per cwd
    auto_save = true,
    auto_restore = true,
    -- Close special buffers before saving (Neo-tree, etc.)
    pre_save_cmds = {
      function()
        -- Close Neo-tree so it doesn't interfere with restore
        pcall(vim.cmd, "Neotree close")
      end,
    },
    -- Re-edit the active buffer after restore so BufRead fires and LSP attaches
    post_restore_cmds = {
      function()
        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname ~= "" and vim.fn.filereadable(bufname) == 1 then
          vim.cmd("edit")
        end
      end,
    },
    bypass_save_filetypes = { "alpha", "dashboard", "lazy", "mason", "terminal" },
  },
}
