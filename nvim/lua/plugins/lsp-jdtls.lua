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

    -- Cache once per session: OS and arch never change
    local os_config = get_os_config()
    local java_home = os.getenv("JAVA_HOME")
    if not java_home then
      vim.notify("jdtls: JAVA_HOME is not set. Java runtime config will be skipped.", vim.log.levels.WARN)
    end

    local function setup_jdtls()
      -- Exclude build.gradle/pom.xml: they exist in every submodule, causing jdtls
      -- to root at a submodule dir instead of the project root in multi-module builds.
      local root_markers = { "gradlew", "mvnw", "settings.gradle", "settings.gradle.kts", ".git" }
      local root_dir = vim.fs.root(0, root_markers)
      if not root_dir then return end

      -- Hash full path so same-named projects (e.g. two repos named "discovery") get separate workspaces
      local project_name = vim.fn.fnamemodify(root_dir, ":t") .. "-" .. vim.fn.sha256(root_dir):sub(1, 8)
      local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name
      vim.fn.mkdir(workspace_dir, "p")

      local launcher = vim.fn.glob(mason_path .. "/plugins/org.eclipse.equinox.launcher_*.jar")
      if launcher == "" then
        vim.notify("jdtls: launcher jar not found. Run :MasonInstall jdtls", vim.log.levels.ERROR)
        return
      end

      local lombok_jar = mason_path .. "/lombok.jar"
      if vim.fn.filereadable(lombok_jar) == 0 then
        vim.notify("jdtls: lombok.jar not found at " .. lombok_jar .. ". Lombok annotations will not work.", vim.log.levels.WARN)
        lombok_jar = nil
      end

      local cmd = {
        "java",
        "-Xms1g",
        "-Xmx4g",
        "-XX:+UseZGC",
        "-XX:+ZGenerational",
        "-XX:ConcGCThreads=4",
        "-XX:+UseStringDeduplication",
        "-XX:+TieredCompilation",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar", launcher,
        "-configuration", mason_path .. "/" .. os_config,
        "-data", workspace_dir,
      }
      if lombok_jar then
        table.insert(cmd, 2, "-javaagent:" .. lombok_jar)
      end

      local config = {
        cmd = cmd,
        root_dir = root_dir,
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
        init_options = { bundles = {} },
        settings = {
          java = {
            configuration = {
              runtimes = java_home and {
                { name = "JavaSE-21", path = java_home },
              } or nil,
            },
            maxConcurrentBuilds = 4,
            autobuild = { enabled = true },
            inlayHints = { parameterNames = { enabled = "all" } },
            references = { includeDecompiledSources = true },
            completion = {
              filteredTypes = { "com.sun.*", "io.micrometer.shaded.*", "java.awt.*", "jdk.*", "sun.*" },
            },
            import = {
              gradle = {
                enabled = true,
                wrapper = { enabled = true, checksums = {} },
                -- Use offline mode if workspace cache already exists (faster re-open)
                offline = { enabled = vim.fn.isdirectory(workspace_dir .. "/.metadata") == 1 },
                -- Cache Gradle configuration so re-opens skip build script re-evaluation
                arguments = "--configuration-cache --configuration-cache-problems=warn",
              },
              maven = { enabled = true },
              exclusions = {
                "**/node_modules/**",
                "**/.metadata/**",
                "**/archetype-resources/**",
                "**/META-INF/maven/**",
                "**/build/**",
                "**/target/**",
                "**/.gradle/**",
                "**/bin/**",
                "**/.git/**",
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

      -- Strict root_dir match: prevent reuse of a parent-project jdtls client
      -- (e.g. discovery-sap/) when opening a nested project (discovery-sap/discovery/).
      local bufnr = vim.api.nvim_get_current_buf()
      for _, client in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do
        if client.config.root_dir == root_dir then
          vim.lsp.buf_attach_client(bufnr, client.id)
          return
        end
      end
      require("jdtls").start_or_attach(config)
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = setup_jdtls,
    })

    if vim.bo.filetype == "java" then
      setup_jdtls()
    end
  end,
}
