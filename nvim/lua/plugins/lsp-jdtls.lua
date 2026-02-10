-- Java LSP configuration using nvim-jdtls
return {
  "mfussenegger/nvim-jdtls",
  ft = "java",

  config = function()
    local mason_path = vim.fn.stdpath("data") .. "/mason/packages/jdtls"

    local function get_os_config()
      if vim.fn.has("mac") == 1 then
        return vim.fn.system("uname -m"):match("arm64") and "config_mac_arm" or "config_mac"
      elseif vim.fn.has("win32") == 1 then
        return "config_win"
      end
      return vim.fn.system("uname -m"):match("arm") and "config_linux_arm" or "config_linux"
    end

    local function setup_jdtls()
      local root_markers = { "gradlew", "mvnw", "pom.xml", "build.gradle", ".git" }
      local root_dir = vim.fs.root(0, root_markers)
      if not root_dir then
        return
      end

      local project_name = vim.fn.fnamemodify(root_dir, ":t")
      local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name

      local launcher = vim.fn.glob(mason_path .. "/plugins/org.eclipse.equinox.launcher_*.jar")
      if launcher == "" then
        vim.notify("jdtls: launcher jar not found. Run :MasonInstall jdtls", vim.log.levels.ERROR)
        return
      end

      local config = {
        cmd = {
          "java",
          "-javaagent:" .. mason_path .. "/lombok.jar",
          "-Xms512m",
          "-Xmx4g",
          -- GC tối ưu cho low latency          
          "-XX:+UseZGC",
          "-XX:+ZGenerational",
          "-XX:ConcGCThreads=4",
          -- Tối ưu compiler
          "-XX:+TieredCompilation",
          "-XX:TieredStopAtLevel=1", -- Faster startup, JIT later          
          "--add-modules=ALL-SYSTEM",
          "--add-opens", "java.base/java.util=ALL-UNNAMED",
          "--add-opens", "java.base/java.lang=ALL-UNNAMED",
          "-jar", launcher,
          "-configuration", mason_path .. "/" .. get_os_config(),
          "-data", workspace_dir,
        },
        root_dir = root_dir,
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
        init_options = { bundles = {}, },
        settings = {
          java = {
            configuration = {
              runtimes = {
                { name = "JavaSE-21", path = os.getenv("JAVA_HOME") },
              },
            },
            maxConcurrentBuilds = 4,
            autobuild = { enabled = true },            
            inlayHints = { parameterNames = { enabled = "all" } },
            references = { includeDecompiledSources = true },
            import = {
              gradle = {
                enabled = true,
                wrapper = {
                  enabled = true,  -- Use project's gradlew
                  checksums = {},  -- Skip checksum validation
                },
                offline = { enabled = false },
              },
              maven = { enabled = true },
              exclusions = {
                "**/node_modules/**",
                "**/.metadata/**",
                "**/archetype-resources/**",
                "**/META-INF/maven/**",
              },              
            },
          },
        },
        on_attach = function(client, bufnr)
          local jdtls = require("jdtls")
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end
          map("n", "<leader>co", jdtls.organize_imports, "Organize Imports")
          map("n", "<leader>crv", jdtls.extract_variable, "Extract Variable")
          map("n", "<leader>crc", jdtls.extract_constant, "Extract Constant")
          map("v", "<leader>crm", function() jdtls.extract_method(true) end, "Extract Method")
        end,
        handlers = {
          ["language/status"] = function() end,
        },
      }

      require("jdtls").start_or_attach(config)
    end

    -- Create autocmd for Java files
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = setup_jdtls,
    })

    -- Run immediately for current buffer if it's Java
    if vim.bo.filetype == "java" then
      setup_jdtls()
    end
  end,
}
