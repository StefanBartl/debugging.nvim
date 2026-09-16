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

    local gathered_ok, out_path = inline_debug.gather()
    H.ok(gathered_ok, "gather: succeeds against a real markdown buffer")
    H.ok(type(out_path) == "string" and out_path ~= "", "gather: returns the log path")
    H.match(last(), "wrote debug log to", "gather: notifies with the log path")

    H.eq(vim.fn.filereadable(out_path), 1, "gather: the log file actually exists")

    -- BUG: `out_path` is built as `debugfolder .. "_debuglog_" .. ts .. ".log"`
    -- with no path separator between `debugfolder`
    -- (".../debuglog/markdown_inline") and the suffix. `vim.fn.mkdir(debugfolder)`
    -- does create the "markdown_inline" directory, but the log file's actual
    -- path is a *sibling* of it ("markdown_inline_debuglog_<ts>.log" inside
    -- the parent "debuglog" folder) -- the directory it just created is never
    -- written into. Pinned here rather than fixed: fixing it changes the
    -- resulting file path (a `:Debug markdown log` regression risk) and
    -- deserves its own change.
    local data_debuglog = vim.fn.stdpath("data") .. "/debuglog"
    local unused_subdir = data_debuglog .. "/markdown_inline"
    H.eq(vim.fn.isdirectory(unused_subdir), 1, "BUG: mkdir did create markdown_inline/")
    H.ok(
      vim.fs.normalize(vim.fn.fnamemodify(out_path, ":h")) == vim.fs.normalize(data_debuglog),
      "BUG: the log file lands in debuglog/ itself, not inside markdown_inline/"
    )
    H.eq(
      #vim.fn.readdir(unused_subdir),
      0,
      "BUG: the markdown_inline/ directory mkdir created stays empty"
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
    H.ok(
      inline_debug.results.treesitter.parsers_available == false,
      "gather: nvim-treesitter is not installed in this suite -- parsers_available is false"
    )

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
