local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)


vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- general
vim.opt.termguicolors = true
vim.opt.updatetime = 100
vim.opt.timeoutlen = 300
vim.opt.wrap = true
vim.opt.backup = true
vim.opt.backupdir = vim.fn.expand("~/.cache/nvim/backup")

-- line numbers
vim.opt.statuscolumn = "%C%s%{v:lnum} %{v:relnum}"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.foldcolumn = "1"
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"

-- indentation
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.cmd("filetype plugin indent on")

-- visible whitespace
vim.opt.list = true
vim.opt.listchars:append("space:⋅")
vim.opt.listchars:append("eol:↴")
vim.opt.listchars:append("tab:» ")
vim.opt.listchars:append("trail:·")

-- search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- cursor pair bounce
vim.opt.matchpairs:append("<:>")
vim.opt.showmatch = true
vim.opt.matchtime = 4

-- filetype mapping
vim.filetype.add({
  extension = {
    tpp = "cpp",
  },
})

-- keybinds (all keybindings live in lua/keybinds.lua)
require("keybinds").setup()

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  -- checker = { enabled = true },
  -- Disable LuaRocks support to fix the "hererocks" installation error
  rocks = {
    enabled = false,
  },
})

-- ============================================================================
-- EXTRA SETTINGS
-- ============================================================================

-- Auto-create parent directories on save
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  group = vim.api.nvim_create_augroup("auto_create_dir", { clear = true }),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = (vim.uv or vim.loop).fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- overwrite saving for hyprland configs instead of rename
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  pattern = "*/.config/hypr/**/*.lua",
  callback = function()
    vim.opt.backupcopy = "yes"
  end,
})
