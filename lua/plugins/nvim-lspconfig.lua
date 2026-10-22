return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "saghen/blink.cmp", -- Link Blink to LSP
    },
    config = function()
      -- Setup Mason (Package Manager)
      require("mason").setup()

      -- mason-lspconfig v2 dropped the `handlers` API: it now auto-enables every
      -- installed server via vim.lsp.enable(), and per-server overrides go
      -- through vim.lsp.config(). these must be registered before setup() below,
      -- so they are merged in before a server is enabled.

      -- advertise Blink's completion capabilities to every server
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Override for Lua
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
          },
        },
      })

      -- Override for Python
      vim.lsp.config("pyright", {
        root_markers = { "pyproject.toml", "setup.py", ".git" },
        settings = {
          python = {
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
            },
          },
        },
      })

      -- Override for C/C++ (clangd)
      vim.lsp.config("clangd", {
        -- Fixes a common multiple offset encoding warning from clangd in Neovim
        cmd = { "clangd", "--offset-encoding=utf-16" },
        filetypes = { "c", "cpp", "hpp", "objc", "objcpp", "cuda", "tpp" },
        root_markers = { '.clangd', 'compile_commands.json', '.git', 'CMakeLists.txt' },
        before_init = function(params, config)
          local root = config.root_dir or vim.fn.getcwd()
          params.initializationOptions = vim.tbl_deep_extend("force",
          params.initializationOptions or {}, {
          fallbackFlags = {
            "-xc++",
            "-I" .. vim.fs.joinpath(root, "include"),
            "-std=c++20",
          },
        })
        end,
      })

      -- Setup Mason-LSPConfig (The Bridge). installed servers are enabled
      -- automatically, so only the wanted set should stay installed.
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "pyright", "clangd" },
      })
    end,
  }
}
