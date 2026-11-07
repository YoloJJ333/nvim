-- ============================================================================
-- Keybindings
-- ============================================================================
-- Central home for every keybinding in this config. Every binding is written
-- as a lazy.nvim-style key spec, so they all look the same:
--
--   { lhs, rhs, mode = "n", desc = "...", <any other vim.keymap.set opt> }
--
-- (`mode` defaults to "n".) Where they get applied:
--
--   * M.setup()                  general + LSP maps, applied once from init.lua
--   * M.gitsigns_attach(bufnr)   buffer-local, passed as gitsigns' on_attach
--   * M.vimtex_fragment_toggle() buffer-local, wired up from
--                                lua/plugins/vimtex.lua
--   * M.plugins.<name>           lazy.nvim `keys` specs, referenced from the
--                                matching file in lua/plugins/ (so those plugins
--                                stay lazy-loaded on their keys)

local M = {}

-- Apply a list of key specs. `defaults` is merged into every spec's opts
-- (e.g. { buffer = bufnr }).
local function apply(specs, defaults)
  for _, spec in ipairs(specs) do
    local opts = vim.deepcopy(defaults or {})
    local mode = "n"
    for k, v in pairs(spec) do
      if k == "mode" then
        mode = v
      elseif type(k) ~= "number" then
        opts[k] = v
      end
    end
    vim.keymap.set(mode, spec[1], spec[2], opts)
  end
end

-- --- General ----------------------------------------------------------------
local general = {
  -- yank to the system clipboard
  { "y", '"+y', mode = { "n", "x" }, silent = true, desc = "Yank to system clipboard" },
  { "Y", '"+Y', silent = true, desc = "Yank line to system clipboard" },

  -- terminal
  { "<F4>", ":sp term://", desc = "Open terminal split" },
  { "<C-q>", "<C-\\><C-n>", mode = "t", desc = "Leave terminal mode" },

  -- move between splits
  { "<C-h>", "<C-w>h", desc = "Window left" },
  { "<C-j>", "<C-w>j", desc = "Window down" },
  { "<C-k>", "<C-w>k", desc = "Window up" },
  { "<C-l>", "<C-w>l", desc = "Window right" },
  -- resize splits
  { "<C-A-h>", "<C-w><", desc = "Narrower window" },
  { "<C-A-j>", "<C-w>-", desc = "Shorter window" },
  { "<C-A-k>", "<C-w>+", desc = "Taller window" },
  { "<C-A-l>", "<C-w>>", desc = "Wider window" },

  -- oil
  { "-", "<CMD>Oil<CR>", desc = "Open parent directory" },
}

-- --- LSP (buffer-local, on LspAttach) ---------------------------------------
local lsp = {
  -- navigation
  { "gd", vim.lsp.buf.definition, desc = "Go to definition" },
  { "gD", vim.lsp.buf.declaration, desc = "Go to declaration" },
  { "gr", vim.lsp.buf.references, desc = "List references" },
  { "gi", vim.lsp.buf.implementation, desc = "Go to implementation" },
  { "go", vim.lsp.buf.type_definition, desc = "Go to type definition" },

  -- actions
  { "K", vim.lsp.buf.hover, desc = "Hover docs" },
  { "gs", vim.lsp.buf.signature_help, desc = "Signature help" },
  { "<leader>rn", vim.lsp.buf.rename, desc = "Rename symbol" },
  { "<leader>ca", vim.lsp.buf.code_action, desc = "Code action" },
  { "<leader>f", function() vim.lsp.buf.format({ async = true }) end, desc = "Format file" },

  -- diagnostics
  { "ge", vim.diagnostic.open_float, desc = "Show diagnostic in float" },
  { "<leader>e", vim.diagnostic.setloclist, desc = "Diagnostics to loclist" },
}

-- --- Gitsigns (buffer-local, via on_attach) ---------------------------------
-- gs("fn", args...) -> a function that calls require("gitsigns").fn(args...)
local function gs(name, ...)
  local args = { ... }
  return function() require("gitsigns")[name](unpack(args)) end
end

-- In diff mode keep Vim's own ]c / [c; otherwise jump between hunks.
local function hunk_nav(key, direction)
  return function()
    if vim.wo.diff then
      vim.cmd.normal({ key, bang = true })
    else
      require("gitsigns").nav_hunk(direction)
    end
  end
end

local function visual_range() return { vim.fn.line("."), vim.fn.line("v") } end

local gitsigns = {
  -- navigation
  { "]c", hunk_nav("]c", "next"), desc = "Next hunk" },
  { "[c", hunk_nav("[c", "prev"), desc = "Previous hunk" },

  -- actions
  { "<leader>hs", gs("stage_hunk"), desc = "Stage hunk" },
  { "<leader>hr", gs("reset_hunk"), desc = "Reset hunk" },
  { "<leader>hs", function() require("gitsigns").stage_hunk(visual_range()) end, mode = "v", desc = "Stage selected lines" },
  { "<leader>hr", function() require("gitsigns").reset_hunk(visual_range()) end, mode = "v", desc = "Reset selected lines" },
  { "<leader>hS", gs("stage_buffer"), desc = "Stage buffer" },
  { "<leader>hR", gs("reset_buffer"), desc = "Reset buffer" },
  { "<leader>hp", gs("preview_hunk"), desc = "Preview hunk" },
  { "<leader>hi", gs("preview_hunk_inline"), desc = "Preview hunk inline" },
  { "<leader>hb", gs("blame_line", { full = true }), desc = "Blame line" },
  { "<leader>hd", gs("diffthis"), desc = "Diff against index" },
  { "<leader>hD", gs("diffthis", "~"), desc = "Diff against last commit" },
  { "<leader>hQ", gs("setqflist", "all"), desc = "All repo hunks to quickfix" },
  { "<leader>hq", gs("setqflist"), desc = "Buffer hunks to quickfix" },

  -- toggles
  { "<leader>tb", gs("toggle_current_line_blame"), desc = "Toggle line blame" },
  { "<leader>tw", gs("toggle_word_diff"), desc = "Toggle word diff" },

  -- text object
  { "ih", gs("select_hunk"), mode = { "o", "x" }, desc = "Select hunk" },
}

-- ============================================================================
-- Entry points
-- ============================================================================

-- General and LSP maps. Called once from init.lua (after mapleader is set).
function M.setup()
  -- :W behaves like :w
  vim.cmd([[cabbrev W w]])

  apply(general)

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspConfig", {}),
    callback = function(args)
      apply(lsp, { buffer = args.buf, silent = true })
    end,
  })
end

-- Gitsigns on_attach. Use it as `on_attach = require("keybinds").gitsigns_attach`.
function M.gitsigns_attach(bufnr)
  apply(gitsigns, { buffer = bufnr })
end

-- vimtex fragment-preview toggle. Buffer-local, so it is set from the FileType
-- autocmd in lua/plugins/vimtex.lua; `action` carries the toggle behavior.
function M.vimtex_fragment_toggle(buf, action)
  apply({
    { "<localleader>lm", action, silent = true, desc = "Toggle fragment preview text/xournal++ mode" },
  }, { buffer = buf })
end

-- Plugin lazy-load `keys` specs, referenced from lua/plugins/<name>.lua.
-- Same spec format as above; lazy.nvim applies these itself.
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

return M
