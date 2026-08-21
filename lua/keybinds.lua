-- ============================================================================
-- Keybindings
-- ============================================================================
-- Central home for every keybinding in this config:
--
--   * M.setup()                  editor + LSP maps, applied once from init.lua
--   * M.plugins.<name>           lazy.nvim `keys` specs, referenced from the
--                                matching file in lua/plugins/ (so those plugins
--                                stay lazy-loaded on their keys)
--   * M.vimtex_fragment_toggle() buffer-local map, wired up from
--                                lua/plugins/vimtex.lua

local M = {}

-- Editor and LSP maps. Called once from init.lua (after mapleader is set).
function M.setup()
  local map = vim.keymap.set
  local noremap_silent = { noremap = true, silent = true }

  -- --- General ------------------------------------------------------------
  -- yank to the system clipboard
  map({ "n", "x" }, "y", '"+y', noremap_silent)
  map("n", "Y", '"+Y', noremap_silent)

  -- :W behaves like :w
  vim.cmd([[cabbrev W w]])

  -- --- Terminal -----------------------------------------------------------
  map("n", "<F4>", ":sp term://")
  map("t", "<C-q>", "<C-\\><C-n>")

  -- --- Windows ------------------------------------------------------------
  -- move between splits
  map("n", "<C-h>", "<C-w>h")
  map("n", "<C-j>", "<C-w>j")
  map("n", "<C-k>", "<C-w>k")
  map("n", "<C-l>", "<C-w>l")
  -- resize splits
  map("n", "<C-A-h>", "<C-w><")
  map("n", "<C-A-j>", "<C-w>-")
  map("n", "<C-A-k>", "<C-w>+")
  map("n", "<C-A-l>", "<C-w>>")

  -- --- Oil ----------------------------------------------------------------
  map("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

  -- --- LSP (on attach) ----------------------------------------------------
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspConfig", {}),
    callback = function(args)
      local opts = { buffer = args.buf, silent = true }

      -- navigation
      map("n", "gd", vim.lsp.buf.definition, opts)
      map("n", "gD", vim.lsp.buf.declaration, opts)
      map("n", "gr", vim.lsp.buf.references, opts)
      map("n", "gi", vim.lsp.buf.implementation, opts)
      map("n", "go", vim.lsp.buf.type_definition, opts) -- type of the variable under the cursor

      -- actions
      map("n", "K", vim.lsp.buf.hover, opts)
      map("n", "gs", vim.lsp.buf.signature_help, opts) -- params for the function being typed
      map("n", "<leader>rn", vim.lsp.buf.rename, opts)
      map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
      map("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, opts) -- format the file

      -- diagnostics
      map("n", "ge", vim.diagnostic.open_float, opts) -- full error message in a float
      map("n", "<leader>e", vim.diagnostic.setloclist, opts) -- all errors in a loclist
    end,
  })
end

-- Plugin lazy-load `keys` specs, referenced from lua/plugins/<name>.lua.
M.plugins = {
  telescope = {
    { "<leader>sf", function() require("telescope.builtin").find_files() end, desc = "Search Files" },
    { "<leader>sg", function() require("telescope.builtin").live_grep() end,  desc = "Search Grep" },
    { "<leader>sb", function() require("telescope.builtin").buffers() end,    desc = "Search Buffers" },
    { "<leader>sh", function() require("telescope.builtin").help_tags() end,  desc = "Search Help" },
  },

  multiple_cursors = {
    { "<C-Up>",        "<Cmd>MultipleCursorsAddUp<CR>",            mode = { "n", "i", "x" }, desc = "Add cursor and move up" },
    { "<C-Down>",      "<Cmd>MultipleCursorsAddDown<CR>",          mode = { "n", "i", "x" }, desc = "Add cursor and move down" },
    { "<C-LeftMouse>", "<Cmd>MultipleCursorsMouseAddDelete<CR>",   mode = { "n", "i" },      desc = "Add or remove cursor" },
    { "<Leader>m",     "<Cmd>MultipleCursorsAddVisualArea<CR>",    mode = { "x" },           desc = "Add cursors to the lines of the visual area" },
    { "<Leader>a",     "<Cmd>MultipleCursorsAddMatches<CR>",       mode = { "n", "x" },      desc = "Add cursors to cword" },
    { "<Leader>A",     "<Cmd>MultipleCursorsAddMatchesV<CR>",      mode = { "n", "x" },      desc = "Add cursors to cword in previous area" },
    { "<Leader>d",     "<Cmd>MultipleCursorsAddJumpNextMatch<CR>", mode = { "n", "x" },      desc = "Add cursor and jump to next cword" },
    { "<Leader>D",     "<Cmd>MultipleCursorsJumpNextMatch<CR>",    mode = { "n", "x" },      desc = "Jump to next cword" },
    { "<Leader>l",     "<Cmd>MultipleCursorsLock<CR>",             mode = { "n", "x" },      desc = "Lock virtual cursors" },
  },
}

-- vimtex fragment-preview toggle. Buffer-local, so it is set from the FileType
-- autocmd in lua/plugins/vimtex.lua; `action` carries the toggle behavior.
function M.vimtex_fragment_toggle(buf, action)
  vim.keymap.set("n", "<localleader>lm", action,
    { buffer = buf, silent = true, desc = "toggle fragment preview text/xournal++ mode" })
end

return M
