-- docs/TESTS/sources_spec.lua
-- Covers the pure parsers behind `:Debug autocmds sources`
-- (debugging.autocmds.sources) plus the argument completion.

return function(H)
  local sources = require("debugging.autocmds.sources")
  local P = sources._internal

  -- ---------------------------------------------------------------- events

  -- A single quoted event: the gmatch pass finds it, no fallback needed.
  H.eq_list(P.normalize_events([["BufEnter"]]), { "BufEnter" }, "normalize: single event")

  -- A table of events comes back sorted, so report grouping is stable
  -- regardless of the order they were written in the source file.
  H.eq_list(
    P.normalize_events([[{ "BufWritePost", "BufEnter", "VimEnter" }]]),
    { "BufEnter", "BufWritePost", "VimEnter" },
    "normalize: table of events is sorted"
  )

  -- Nothing quoted (e.g. a variable holding the events) yields no events
  -- rather than a bogus entry.
  H.eq_list(P.normalize_events("my_events"), {}, "normalize: unquoted arg yields nothing")

  -- ------------------------------------------------------------ brace block

  -- The block ends at the *matching* brace, not the first one, so nested
  -- tables in the callback stay part of the implementation text.
  local lines = {
    'vim.api.nvim_create_autocmd("BufEnter", {',
    "  group = grp,",
    "  callback = function()",
    "    local opts = { a = 1 }",
    "  end,",
    "})",
    "local after = true",
  }
  local impl, last = P.read_brace_block(lines, 1, lines[1]:find("{"))
  H.eq(last, 6, "brace block: ends on the matching closing brace")
  H.match(impl, "local opts = { a = 1 }", "brace block: keeps nested table")
  H.ok(not impl:match("local after"), "brace block: stops before following code")

  -- Unbalanced input must terminate at EOF instead of looping.
  local open_impl, open_last = P.read_brace_block({ "foo({", "  bar," }, 1, 5)
  H.eq(open_last, 2, "brace block: unterminated block stops at last line")
  H.match(open_impl, "bar", "brace block: unterminated block still returns text")

  -- ------------------------------------------------------------------ args

  local def = P.parse_args("")
  H.eq(def.event, nil, "parse_args: no event filter by default")
  H.eq(def.sort, "source", "parse_args: default sort")
  H.eq(def.show_impl, true, "parse_args: impl shown by default")
  H.eq(def.show_summary, true, "parse_args: summary shown by default")
  H.eq(def.refresh, false, "parse_args: cache used by default")

  local opts = P.parse_args("event=BufEnter sort=frequency impl=false refresh=true")
  H.eq(opts.event, "BufEnter", "parse_args: event filter")
  H.eq(opts.sort, "frequency", "parse_args: sort override")
  H.eq(opts.show_impl, false, "parse_args: impl=false")
  H.eq(opts.refresh, true, "parse_args: refresh=true")

  -- Only the literal string "false" disables a flag; anything else is truthy.
  H.eq(P.parse_args("summary=0").show_summary, true, "parse_args: only 'false' disables")

  -- Unknown keys are ignored rather than poisoning the option table.
  H.eq(P.parse_args("bogus=1").sort, "source", "parse_args: unknown key ignored")

  -- The quickfix flag defaults off and is opt-in via qf=true.
  H.eq(P.parse_args("").quickfix, false, "parse_args: quickfix off by default")
  H.eq(P.parse_args("qf=true").quickfix, true, "parse_args: qf=true enables quickfix")
  H.eq(P.parse_args("qf=false").quickfix, false, "parse_args: qf=false disables quickfix")

  -- ------------------------------------------------------ autocmd fn matching

  -- Both the bare and the vim.api-qualified call names are recognised, and
  -- unrelated names (or a lookalike prefix) are not.
  H.ok(P.is_autocmd_name("nvim_create_autocmd"), "is_autocmd_name: bare call")
  H.ok(P.is_autocmd_name("vim.api.nvim_create_autocmd"), "is_autocmd_name: qualified call")
  H.ok(not P.is_autocmd_name("nvim_create_augroup"), "is_autocmd_name: rejects augroup")
  H.ok(not P.is_autocmd_name("my_nvim_create_autocmd_wrapper"), "is_autocmd_name: rejects suffix lookalike")

  -- ------------------------------------------------------------ completion

  local ev = sources.complete("event=Buf")
  H.ok(#ev > 0, "complete: event= yields candidates")
  H.match(ev[1], "^event=Buf", "complete: event= candidates keep the key prefix")

  local sorts = sources.complete("sort=")
  H.eq_list(sorts, { "sort=source", "sort=event", "sort=frequency" }, "complete: all sort modes")

  local keys = sources.complete("ro")
  H.eq_list(keys, { "root=" }, "complete: bare arglead completes the key itself")

  -- --------------------------------------------------------------- end-to-end

  -- A real scan over a temp tree: proves scan_dir/scan_file wire the parsers
  -- together and that `root=` is honoured.
  local root = H.tmpfile("lua/plug/au.lua", {
    "local grp = vim.api.nvim_create_augroup('T', { clear = true })",
    'vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter" }, {',
    "  group = grp,",
    "  callback = function() end,",
    "})",
  })
  H.tmpfile("lua/plug/ignored.txt", { 'vim.api.nvim_create_autocmd("VimEnter", {})' }, root)

  sources.run("root=" .. root .. " refresh=true")
  local out = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  vim.cmd("bwipeout!")

  H.match(out, "BufEnter", "run: reports the events found")
  H.match(out, "BufWritePost", "run: reports every event of a multi-event call")
  H.match(out, "au%.lua", "run: reports the defining file")
  H.ok(not out:match("VimEnter"), "run: skips non-.lua files")

  -- Filtering to one event drops the others from the report body.
  sources.run("root=" .. root .. " event=BufEnter refresh=true")
  local filtered = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  vim.cmd("bwipeout!")
  H.match(filtered, "BufEnter", "run: event filter keeps the requested event")

  -- A root that does not exist must not blow up (it notifies and returns).
  -- The notify is stubbed out so the expected error does not reach stderr and
  -- make a passing run look broken.
  local missing = root .. "/does/not/exist"
  local win_before = #vim.api.nvim_list_wins()
  local orig_notify, notified = vim.notify, nil
  vim.notify = function(msg) notified = tostring(msg) end
  local ok, err = pcall(sources.run, "root=" .. missing .. " refresh=true")
  vim.notify = orig_notify
  H.ok(ok, "run: missing root does not raise: " .. tostring(err))
  H.eq(#vim.api.nvim_list_wins(), win_before, "run: missing root opens no window")
  H.match(notified or "", "not a directory", "run: missing root is reported")
end
