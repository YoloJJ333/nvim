-- latex compile + live pdf preview (like markdown-preview for .tex)
--
-- files without \documentclass (fragments) are compiled through an
-- auto-generated wrapper in ~/.cache/nvim/tex-preview/ so any latex renders
-- (and build clutter stays out of the project; tex refuses to write aux
-- files for dot-hidden names, so the wrapper can't live hidden next to the
-- fragment).
--
-- <localleader>lm toggles the wrapper between:
--   text mode (default) -- plain article view; $...$ is inline math
--   xournal++ mode      -- renders the fragment through Xournal++'s own default
--                          template (standalone + \( \displaystyle ... \)), so
--                          the preview matches exactly what Xournal++ will show
--                          when you paste the fragment in: math by default,
--                          $...$ toggles to text, \\ breaks lines. blank lines
--                          split the source into separate pastes, each rendered
--                          in its own \( \displaystyle ... \). the source text
--                          is kept verbatim, so it keeps its single $.
--
-- with continuous compilation (\ll) running, latexmk -pvc recompiles and zathura
-- reloads on its own -- no manual \lv. text mode \inputs the source, so it
-- updates when you save. xournal++ mode bakes the split buffer text into the
-- wrapper and rebuilds it live on each edit (debounced), so it updates as you
-- type, no save needed.
--
-- the \ll (continuous compilation) state is remembered across sessions: toggle
-- it on and every tex file you open afterwards auto-starts it; toggle it off
-- and they stop auto-starting. state lives in ~/.cache/nvim/tex-preview/.

local function wrapper_path(src)
  return vim.fn.stdpath("cache") .. "/tex-preview/"
    .. vim.fn.fnamemodify(src, ":t:r") .. "-" .. vim.fn.sha256(src):sub(1, 8) .. ".tex"
end

-- current source lines: prefer the live buffer (so a toggle/save reflects
-- unsaved edits), fall back to disk (e.g. at BufReadPre, before load).
local function read_src_lines(src)
  local buf = vim.fn.bufnr(src)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end
  local ok, lines = pcall(vim.fn.readfile, src)
  return ok and lines or {}
end

-- split the source into blank-line-separated chunks -- each chunk is one
-- independent Xournal++ paste, previewed in its own \( \displaystyle ... \).
local function split_chunks(lines)
  local chunks, cur = {}, {}
  for _, l in ipairs(lines) do
    if l:match("^%s*$") then
      if #cur > 0 then chunks[#chunks + 1] = cur; cur = {} end
    else
      cur[#cur + 1] = l
    end
  end
  if #cur > 0 then chunks[#chunks + 1] = cur end
  return chunks
end

local function write_wrapper(src, xournal)
  local srcdir = vim.fn.fnamemodify(src, ":h")
  -- resolve relative \input inside the fragment against the source dir
  local input_path = "\\makeatletter\\def\\input@path{{" .. srcdir .. "/}}\\makeatother"
  local input = "\\input{" .. vim.fn.fnamemodify(src, ":t:r") .. "}"
  local lines
  if xournal then
    -- Xournal++'s default template, verbatim enough that the preview matches
    -- what Xournal++ renders. \( \displaystyle ... \) is what makes math the
    -- default and lets $...$ toggle to text and \\ break lines. because a blank
    -- line is an illegal \par inside math, the source is baked in split on
    -- blank lines -- each chunk gets its own \( \displaystyle ... \), stacked
    -- with a gap, exactly as pasting each segment into Xournal++ would look.
    lines = {
      "% auto-generated preview wrapper (lua/plugins/vimtex.lua) -- safe to delete",
      "% tex-preview-mode: xournal",
      "\\documentclass[varwidth=0.999\\maxdimen, crop, border=5pt]{standalone}",
      "\\usepackage{amsmath}",
      "\\usepackage{amssymb}",
      "\\usepackage{graphicx}",
      input_path,
      "\\graphicspath{{" .. srcdir .. "/}}",
      "\\begin{document}",
      "\\setlength{\\textwidth}{345.0pt}\\setlength{\\linewidth}{\\textwidth}\\setlength{\\columnwidth}{\\textwidth}",
    }
    local chunks = split_chunks(read_src_lines(src))
    if #chunks == 0 then chunks = { { "" } } end
    for i, chunk in ipairs(chunks) do
      if i > 1 then
        lines[#lines + 1] = "\\par\\bigskip" -- visual gap between pastes
      end
      lines[#lines + 1] = "\\("
      lines[#lines + 1] = "\\displaystyle"
      for _, l in ipairs(chunk) do
        lines[#lines + 1] = l
      end
      lines[#lines + 1] = "\\)"
    end
    lines[#lines + 1] = "\\end{document}"
  else
    lines = {
      "% auto-generated preview wrapper (lua/plugins/vimtex.lua) -- safe to delete",
      "% tex-preview-mode: text",
      "\\documentclass{article}",
      "\\usepackage{amsmath}",
      "\\usepackage{amssymb}",
      "\\usepackage{graphicx}",
      "\\usepackage{xcolor}",
      input_path,
      "\\graphicspath{{" .. srcdir .. "/}}",
      "\\begin{document}",
      input,
      "\\end{document}",
    }
  end
  local wpath = wrapper_path(src)
  vim.fn.mkdir(vim.fn.fnamemodify(wpath, ":h"), "p")
  vim.fn.writefile(lines, wpath)
end

-- live rebuild for xournal++ mode: it bakes the buffer's text into the wrapper,
-- so regenerate on every edit (debounced) to let latexmk -pvc recompile from
-- unsaved content -- no save needed. text mode \inputs the file, which -pvc
-- only re-reads on disk change, so it stays save-gated.
local uv = vim.uv or vim.loop
local rebuild_timers = {}

local function schedule_rebuild(buf)
  if not (vim.b[buf].vimtex_main and vim.b[buf].tex_preview_xournal) then
    return
  end
  local timer = rebuild_timers[buf]
  if not timer then
    timer = uv.new_timer()
    rebuild_timers[buf] = timer
  end
  timer:stop()
  timer:start(250, 0, vim.schedule_wrap(function()
    if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].tex_preview_xournal then
      write_wrapper(vim.api.nvim_buf_get_name(buf), true)
    end
  end))
end

-- remember whether continuous compilation (\ll) was left running, so it can be
-- auto-started when a tex file is opened. a global flag file (present = on),
-- kept in sync by the VimtexEventCompile{Started,Stopped} autocmds below.
local autocompile_flag = vim.fn.stdpath("cache") .. "/tex-preview/autocompile"

local function set_autocompile(on)
  if on then
    vim.fn.mkdir(vim.fn.fnamemodify(autocompile_flag, ":h"), "p")
    vim.fn.writefile({}, autocompile_flag)
  else
    vim.fn.delete(autocompile_flag)
  end
end

local function autocompile_enabled()
  return vim.fn.filereadable(autocompile_flag) == 1
end

-- a fragment is a file with no \documentclass and no "% !TEX root" comment
local function is_fragment(lines)
  for _, l in ipairs(lines) do
    if l:match("^%s*\\documentclass") or l:match("^%%%s*!%s*[Tt][Ee][Xx]%s+[Rr][Oo][Oo][Tt]") then
      return false
    end
  end
  return true
end

return {
  {
    "lervag/vimtex",
    lazy = false, -- lazy-loading is not recommended by vimtex (it lazy-loads itself per filetype)
    init = function()
      vim.g.vimtex_view_method = "zathura" -- auto-reloading pdf viewer
      vim.g.vimtex_compiler_method = "latexmk" -- continuous compilation on save
    end,
    config = function()
      local group = vim.api.nvim_create_augroup("tex_fragment_preview", { clear = true })

      -- BufReadPre so b:vimtex_main is set before vimtex initializes the buffer
      vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
        group = group,
        pattern = "*.tex",
        callback = function(ev)
          local src = vim.fn.fnamemodify(ev.file, ":p")
          local ok, lines = pcall(vim.fn.readfile, src, "", 200)
          if ok and not is_fragment(lines) then
            return -- complete document, let vimtex handle it normally
          end
          -- restore the mode from a wrapper left by a previous session
          local wpath = wrapper_path(src)
          local wrapper = vim.fn.filereadable(wpath) == 1
            and table.concat(vim.fn.readfile(wpath), "\n") or ""
          local xournal = wrapper:find("tex-preview-mode: xournal", 1, true) ~= nil
          write_wrapper(src, xournal)
          vim.b[ev.buf].vimtex_main = wpath
          vim.b[ev.buf].tex_preview_xournal = xournal
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "tex",
        callback = function(ev)
          require("keybinds").vimtex_fragment_toggle(ev.buf, function()
            if not vim.b[ev.buf].vimtex_main then
              vim.notify("not a fragment preview (file has its own \\documentclass)", vim.log.levels.WARN)
              return
            end
            local xournal = not vim.b[ev.buf].tex_preview_xournal
            vim.b[ev.buf].tex_preview_xournal = xournal
            write_wrapper(vim.api.nvim_buf_get_name(ev.buf), xournal)
            vim.notify("fragment preview: " .. (xournal and "xournal++" or "text"))
          end)
        end,
      })

      -- xournal++ mode bakes the (split) source into the wrapper, so rebuild it
      -- from the live buffer on every edit (debounced) -- this is what makes the
      -- preview update continuously without saving. text mode \inputs the source
      -- and relies on latexmk's on-save recompile, so it needs no rebuild here.
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = group,
        pattern = "*.tex",
        callback = function(ev) schedule_rebuild(ev.buf) end,
      })

      -- catch changes that don't fire TextChanged (undo/reload) and drop the timer
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = "*.tex",
        callback = function(ev)
          if vim.b[ev.buf].vimtex_main and vim.b[ev.buf].tex_preview_xournal then
            write_wrapper(vim.api.nvim_buf_get_name(ev.buf), true)
          end
        end,
      })
      vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
        group = group,
        pattern = "*.tex",
        callback = function(ev)
          local t = rebuild_timers[ev.buf]
          if t then t:stop(); t:close(); rebuild_timers[ev.buf] = nil end
        end,
      })

      -- keep the remembered \ll state in sync with what the user toggles.
      -- only continuous mode counts (a one-shot compile also fires Started).
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "VimtexEventCompileStarted",
        callback = function()
          local vt = vim.b.vimtex
          if vt and vt.compiler and vt.compiler.continuous == 1 then
            set_autocompile(true)
          end
        end,
      })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "VimtexEventCompileStopped",
        callback = function() set_autocompile(false) end,
      })

      -- auto-start continuous compilation on open if it was left on last time
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "VimtexEventInitPost",
        callback = function()
          if autocompile_enabled() then
            vim.cmd("VimtexCompile")
          end
        end,
      })
    end,
  }
}
