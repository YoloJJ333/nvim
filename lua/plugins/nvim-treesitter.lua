return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      vim.treesitter.language.register("cpp", "tpp")

      require("nvim-treesitter.configs").setup({
        -- Removed javascript and typescript
        ensure_installed = { "lua", "vim", "vimdoc", "python", "cpp" },
        auto_install = true,
        -- don't auto-install the latex parser: it needs the tree-sitter CLI,
        -- and vimtex handles latex syntax anyway
        ignore_install = { "latex" },
        highlight = {
          enable = true,
          -- vimtex handles latex syntax itself (conceal, math zones)
          disable = { "latex" },
          additional_vim_regex_highlighting = false,
        },
      })
    end,
  }
}
