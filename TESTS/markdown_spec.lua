-- TESTS/markdown_spec.lua
-- Covers `debugging.markdown.inline_debug`: M.gather() collects a real
-- environment/buffer/highlight/treesitter/lsp snapshot and writes it to
-- disk, and M.open_log() opens what it wrote. Both write under
-- stdpath("data")/debuglog/markdown_inline -- the one file gather() produces
-- is deleted again at the end of the spec so the suite leaves no trace in
-- the user's real data directory.

return function(H)
  local inline_debug = require("debugging.markdown.inline_debug")

  local orig_notify = vim.notify
  local seen = {}
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.notify = function(msg, level)
    seen[#seen + 1] = { msg = tostring(msg), level = level }
  end
  local function last()
    return seen[#seen] and seen[#seen].msg or ""
  end

  local ok, err = pcall(function()
    local buf = H.scratch("inline_debug_spec.md", "markdown")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# Title", "", "`inline code`" })
    -- Neovim's markdown ftplugin starts Tree-sitter (0.10+); start it here where
    -- it did not, so the attached-parser assertions below hold on every version.
    if vim.treesitter.highlighter.active[buf] == nil then
      vim.treesitter.start(buf, "markdown")
    end

    local gathered_ok, out_path = inline_debug.gather()
    H.ok(gathered_ok, "gather: succeeds against a real markdown buffer")
    H.ok(type(out_path) == "string" and out_path ~= "", "gather: returns the log path")
    H.match(last(), "wrote debug log to", "gather: notifies with the log path")

    H.eq(vim.fn.filereadable(out_path), 1, "gather: the log file actually exists")

    -- `out_path` is joined from `debugfolder` (".../debuglog/markdown_inline")
    -- and "debuglog_<ts>.log", so the log file lands inside the directory
    -- `mkdir(debugfolder, "p")` just created, not next to it.
    local data_debuglog = vim.fn.stdpath("data") .. "/debuglog"
    local markdown_inline_dir = data_debuglog .. "/markdown_inline"
    H.eq(vim.fn.isdirectory(markdown_inline_dir), 1, "gather: mkdir creates markdown_inline/")
    H.ok(
      vim.fs.normalize(vim.fn.fnamemodify(out_path, ":h")) == vim.fs.normalize(markdown_inline_dir),
      "gather: the log file lands inside markdown_inline/, not beside it"
    )
    H.eq(
      #vim.fn.readdir(markdown_inline_dir),
      1,
      "gather: markdown_inline/ contains exactly the log file gather() wrote"
    )

    local content = table.concat(vim.fn.readfile(out_path), "\n")
    H.match(content, "ENVIRONMENT", "gather: log has the environment section")
    H.match(content, "BUFFER", "gather: log has the buffer section")
    H.match(content, "inline code", "gather: log includes the sampled buffer lines")

    H.eq(inline_debug.bufnr, buf, "gather: M.bufnr tracks the buffer that was inspected")
    H.ok(inline_debug.results.buffer.filetype == "markdown", "gather: buffer info has the filetype")
    H.ok(
      type(inline_debug.results.highlights) == "table",
      "gather: highlight probe table is present"
    )
    -- nvim-treesitter is not installed in this suite: the treesitter section
    -- must still be filled from the core vim.treesitter API (Neovim bundles
    -- the markdown parser).
    local ts_info = inline_debug.results.treesitter
    H.eq(ts_info.parsers_available, true, "gather: treesitter info works without nvim-treesitter")
    H.eq(ts_info.filetype, "markdown", "gather: treesitter info has the filetype")
    H.eq(ts_info.lang, "markdown", "gather: treesitter info resolves the language")
    H.eq(ts_info.has_parser, true, "gather: bundled markdown parser is reported")
    H.eq(ts_info.parser_attached, true, "gather: parser for the markdown buffer is reported")
    H.eq(ts_info.attached_lang, "markdown", "gather: language of the attached parser is reported")

    -- nvim-treesitter's main-branch rewrite: `nvim-treesitter.parsers` loads but
    -- has neither `has_parser` nor `get_parser`. The collector must not depend on it.
    local collect = inline_debug._internal.collect_treesitter_info
    local saved_parsers = package.loaded["nvim-treesitter.parsers"]
    package.loaded["nvim-treesitter.parsers"] = { markdown = { install_info = {} } }
    local stub_ok, stub_info = pcall(collect, buf)
    package.loaded["nvim-treesitter.parsers"] = saved_parsers
    H.ok(stub_ok, "treesitter info: does not raise with the new nvim-treesitter.parsers shape")
    H.eq(stub_info.has_parser, true, "treesitter info: has_parser from core API, not the plugin")
    H.eq(stub_info.parser_attached, true, "treesitter info: parser_attached from core API")

    -- A filetype without any parser reports false instead of raising.
    local plain = H.scratch("inline_debug_spec.nolang", "nosuchlang_dbgspec")
    local none = collect(plain)
    H.eq(none.parsers_available, true, "treesitter info: core API available")
    H.eq(none.has_parser, false, "treesitter info: unknown language has no parser")
    H.eq(none.parser_attached, false, "treesitter info: unknown language has no attached parser")

    -- No filetype at all: no language, nothing to probe, nothing raised.
    local empty = collect(H.scratch(nil, nil))
    H.eq(empty.lang, "", "treesitter info: empty filetype has no language")
    H.eq(empty.has_parser, false, "treesitter info: empty filetype has no parser")
    H.eq(empty.parser_attached, false, "treesitter info: empty filetype has no attached parser")

    -- The probe is read-only. `vim.treesitter.get_parser()` creates a parser and
    -- attaches it to the buffer when there is none, and replaces a cached parser
    -- of another language -- a diagnosis must not create the state it reports.
    -- `c` is bundled, and its ftplugin does not start Tree-sitter.
    local c_buf = H.scratch("inline_debug_spec.c", "c")
    local lua_hl_buf = H.scratch("inline_debug_spec_lua_hl.c", "c")
    vim.treesitter.start(lua_hl_buf, "lua")
    local created = 0
    local orig_create_parser = vim.treesitter._create_parser
    vim.treesitter._create_parser = function(...)
      created = created + 1
      return orig_create_parser(...)
    end
    local c_ok, c_info = pcall(collect, c_buf)
    local lua_hl_ok, lua_hl_info = pcall(collect, lua_hl_buf)
    vim.treesitter._create_parser = orig_create_parser
    H.ok(c_ok and lua_hl_ok, "treesitter info: read-only probe does not raise")
    H.eq(created, 0, "treesitter info: probing creates no parser")
    H.eq(c_info.has_parser, true, "treesitter info: bundled c parser is reported as installed")
    H.eq(
      c_info.parser_attached,
      false,
      "treesitter info: no parser while Tree-sitter is not running"
    )
    H.eq(c_info.attached_lang, nil, "treesitter info: no attached language without a parser")
    H.eq(lua_hl_info.lang, "c", "treesitter info: language still follows the filetype")
    H.eq(lua_hl_info.parser_attached, true, "treesitter info: running highlighter is reported")
    H.eq(
      lua_hl_info.attached_lang,
      "lua",
      "treesitter info: reports the language Tree-sitter actually runs, not the filetype's"
    )

    -- Neovim 0.9's get_lang() returns nil for a filetype nobody registered; 0.10+
    -- falls back to the filetype, and to the main part of a composite one.
    -- Simulated here: a composite filetype must still probe its main language.
    local composite = H.scratch("inline_debug_spec.composite", "markdown.dbgspec")
    local orig_get_lang = vim.treesitter.language.get_lang
    vim.treesitter.language.get_lang = function()
      return nil
    end
    local comp_ok, comp_info = pcall(collect, composite)
    vim.treesitter.language.get_lang = orig_get_lang
    H.ok(comp_ok, "treesitter info: probing without a registered language does not raise")
    H.eq(comp_info.lang, "markdown", "treesitter info: composite filetype uses its main language")
    H.eq(comp_info.has_parser, true, "treesitter info: composite filetype finds the main parser")
    vim.api.nvim_set_current_buf(buf)

    -- open_log(): opens the just-written log in a new, readonly, wipe-on-hide tab.
    local tabs_before = #vim.api.nvim_list_tabpages()
    local opened_ok = inline_debug.open_log()
    H.ok(opened_ok, "open_log: succeeds after gather() has produced a log")
    H.eq(#vim.api.nvim_list_tabpages(), tabs_before + 1, "open_log: opens exactly one new tab")
    H.eq(vim.bo.readonly, true, "open_log: the opened buffer is readonly")
    vim.cmd("tabclose")

    vim.fn.delete(out_path)
    -- Best-effort: remove the debuglog dirs if this spec left them empty.
    -- Failures here are fine -- either dir may be legitimately non-empty.
    pcall(vim.fn.delete, vim.fn.stdpath("data") .. "/debuglog/markdown_inline", "d")
    pcall(vim.fn.delete, vim.fn.stdpath("data") .. "/debuglog", "d")

    -- open_log() with no prior gather() in a fresh module table (simulated by
    -- clearing out_path) reports a clear error instead of raising.
    local prior_out_path = inline_debug.out_path
    inline_debug.out_path = nil
    local no_log_ok, no_log_err = inline_debug.open_log()
    H.ok(not no_log_ok, "open_log: fails cleanly when gather() has not run")
    H.match(no_log_err or "", "run gather%(%) first", "open_log: explains why it failed")
    inline_debug.out_path = prior_out_path
  end)

  vim.notify = orig_notify
  if not ok then
    error(err, 0)
  end
end
