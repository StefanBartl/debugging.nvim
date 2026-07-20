---@module 'debugging.autocmds.sources'
---@brief Static source-code audit of nvim_create_autocmd call sites.
---@description
--- Scans Lua files under a root directory (default: your nvim config `lua/`),
--- finds every `nvim_create_autocmd` definition, and reports where each autocmd
--- is DEFINED (path:line + implementation), grouped by event. Complements
--- `debugging.autocmds.runtime` (the live view); `M.all()` fuses both.
---
--- Two scanners back this: a Tree-sitter scanner (Lua grammar, `function_call`
--- nodes named `nvim_create_autocmd`) used whenever the Lua parser is
--- available, and a light text/brace parser as fallback. The Tree-sitter path
--- is robust against multi-line and nested calls that tripped the text parser.
---
--- Scan results are cached per root for a few seconds so repeated calls
--- (e.g. trying different `sort=`/`event=` combinations) don't rescan the
--- whole tree each time; pass `refresh=true` to force a rescan.
---
--- Ported from the former `usrcmds.list.autocmd_audit`.

require("debugging.autocmds.@types")

local uv = vim.uv or vim.loop
local bo = vim.bo
local tbl_insert, tbl_concat, tbl_sort = table.insert, table.concat, table.sort
local notify = require("lib.nvim.notify").create("[debugging]")

local M = {}

---@type string
local DEFAULT_ROOT = vim.fn.stdpath("config") .. "/lua"

---@type string[]
M.KNOWN_EVENTS = {
  "BufAdd", "BufDelete", "BufEnter", "BufLeave", "BufNew", "BufNewFile",
  "BufRead", "BufReadPost", "BufReadPre", "BufUnload", "BufWinEnter",
  "BufWinLeave", "BufWipeout", "BufWrite", "BufWritePost", "BufWritePre",
  "CmdlineEnter", "CmdlineLeave", "ColorScheme", "CursorHold", "CursorHoldI",
  "CursorMoved", "CursorMovedI", "DiagnosticChanged", "DirChanged",
  "FileType", "FocusGained", "FocusLost", "InsertEnter", "InsertLeave",
  "LspAttach", "LspDetach", "ModeChanged", "OptionSet", "QuitPre",
  "TextChanged", "TextChangedI", "TextYankPost", "UIEnter", "VimEnter",
  "VimLeave", "VimResized", "WinEnter", "WinLeave",
}

---@type string[]
M.SORT_MODES = { "source", "event", "frequency" }

---@type string[]
M.ARG_KEYS = { "event=", "sort=", "impl=", "summary=", "freq=", "root=", "refresh=", "qf=" }

---@type integer  Cache TTL in seconds — repeated `sources` calls with the
--- same root within this window reuse the previous scan instead of
--- rescanning the whole directory tree.
local CACHE_TTL_SECONDS = 5

---@type Dbg.Autocmds.SourceCache|nil
local _cache = nil

---@param raw string
---@return string[]
local function normalize_events(raw)
  local events = {}
  for ev in raw:gmatch([["([^"]+)"]]) do
    tbl_insert(events, ev)
  end
  if #events == 0 then
    local single = raw:match([["([^"]+)"]])
    if single then events[1] = single end
  end
  tbl_sort(events)
  return events
end

---@param lines string[]
---@param start_line integer
---@param start_col integer
---@return string, integer
local function read_brace_block(lines, start_line, start_col)
  local depth = 0
  local out = {}
  for l = start_line, #lines do
    local line = lines[l]
    local from = (l == start_line) and start_col or 1
    for i = from, #line do
      local ch = line:sub(i, i)
      if ch == "{" then depth = depth + 1 end
      if ch == "}" then depth = depth - 1 end
    end
    tbl_insert(out, line)
    if depth == 0 then
      return tbl_concat(out, "\n"), l
    end
  end
  return tbl_concat(out, "\n"), #lines
end

-- Tree-sitter scanner ---------------------------------------------------------

---@type boolean|nil  Cached result of the Lua-parser availability probe.
local _has_ts_lua = nil

---Whether a Tree-sitter Lua parser is available in this session.
---@return boolean
local function has_ts_lua()
  if _has_ts_lua ~= nil then
    return _has_ts_lua
  end
  local ok = pcall(function()
    return vim.treesitter.get_string_parser("", "lua")
  end)
  _has_ts_lua = ok and true or false
  return _has_ts_lua
end

---@type string  A function name suffix identifying autocmd registrations.
local AUTOCMD_FN = "nvim_create_autocmd"

---Does a call's function-name text refer to nvim_create_autocmd?
--- Matches both the bare `nvim_create_autocmd(...)` and the qualified
--- `vim.api.nvim_create_autocmd(...)` forms.
---@param name string
---@return boolean
local function is_autocmd_name(name)
  if name == AUTOCMD_FN then
    return true
  end
  return name:sub(-#AUTOCMD_FN - 1) == "." .. AUTOCMD_FN
end

---Tree-sitter scan of one Lua file's `nvim_create_autocmd` call sites.
---@param abs_path string
---@param rel_path string
---@param by_event table<string, Dbg.Autocmds.SourceItem[]>
---@param all Dbg.Autocmds.SourceItem[]
local function scan_file_ts(abs_path, rel_path, by_event, all)
  local ok, lines = pcall(vim.fn.readfile, abs_path)
  if not ok or type(lines) ~= "table" then return end
  local content = tbl_concat(lines, "\n")

  local parsed, parser = pcall(vim.treesitter.get_string_parser, content, "lua")
  if not parsed or not parser then return end
  local tree = parser:parse()[1]
  if not tree then return end
  local root = tree:root()

  local q_ok, query = pcall(vim.treesitter.query.parse, "lua", "(function_call) @call")
  if not q_ok or not query then return end

  local get_text = vim.treesitter.get_node_text
  for _, node in query:iter_captures(root, content, 0, -1) do
    local name_node = node:field("name")[1]
    if name_node then
      local name = get_text(name_node, content)
      if is_autocmd_name(name) then
        local args = node:field("arguments")[1]
        local events_node = args and args:named_child(0)
        local events = events_node and normalize_events(get_text(events_node, content)) or {}
        local start_row = select(1, node:range())
        local line = start_row + 1
        local impl = get_text(node, content)
        for _, ev in ipairs(events) do
          by_event[ev] = by_event[ev] or {}
          tbl_insert(by_event[ev], { path = rel_path, line = line, implementation = impl })
        end
        tbl_insert(all, { events = events, path = rel_path, line = line, implementation = impl })
      end
    end
  end
end

-- Text scanner (fallback) -----------------------------------------------------

---@param abs_path string
---@param rel_path string
---@param by_event table<string, Dbg.Autocmds.SourceItem[]>
---@param all Dbg.Autocmds.SourceItem[]
local function scan_file_text(abs_path, rel_path, by_event, all)
  local ok, lines = pcall(vim.fn.readfile, abs_path)
  if not ok or type(lines) ~= "table" then return end
  for i, line in ipairs(lines) do
    local api_call = line:find("nvim_create_autocmd", 1, true)
    if api_call then
      local event_arg = line:match("nvim_create_autocmd%s*%((.-),")
      if event_arg then
        local events = normalize_events(event_arg)
        local brace_col = line:find("{", api_call)
        if brace_col then
          local impl = read_brace_block(lines, i, brace_col)
          for _, ev in ipairs(events) do
            by_event[ev] = by_event[ev] or {}
            tbl_insert(by_event[ev], { path = rel_path, line = i, implementation = impl })
          end
          tbl_insert(all, { events = events, path = rel_path, line = i, implementation = impl })
        end
      end
    end
  end
end

---Scan one file with whichever parser is available.
---@param abs_path string
---@param rel_path string
---@param by_event table<string, Dbg.Autocmds.SourceItem[]>
---@param all Dbg.Autocmds.SourceItem[]
local function scan_file(abs_path, rel_path, by_event, all)
  if has_ts_lua() then
    scan_file_ts(abs_path, rel_path, by_event, all)
  else
    scan_file_text(abs_path, rel_path, by_event, all)
  end
end

---@param dir string
---@param root string
---@param by_event table<string, Dbg.Autocmds.SourceItem[]>
---@param all Dbg.Autocmds.SourceItem[]
local function scan_dir(dir, root, by_event, all)
  local fd = uv.fs_scandir(dir)
  if not fd then return end
  while true do
    local name, typ = uv.fs_scandir_next(fd)
    if not name then break end
    local full = dir .. "/" .. name
    if typ == "directory" then
      scan_dir(full, root, by_event, all)
    elseif typ == "file" and name:sub(-4) == ".lua" then
      scan_file(full, full:gsub("^" .. vim.pesc(root) .. "/", ""), by_event, all)
    end
  end
end

---@param args string
---@return Dbg.Autocmds.SourceOpts
local function parse_args(args)
  local opts = {
    event = nil, sort = "source",
    show_impl = true, show_summary = true, show_freq = true,
    root = DEFAULT_ROOT, refresh = false, quickfix = false,
  }
  for key, val in (args or ""):gmatch("(%w+)=([^%s]+)") do
    if key == "event" then opts.event = val
    elseif key == "sort" then opts.sort = val
    elseif key == "impl" then opts.show_impl = val ~= "false"
    elseif key == "summary" then opts.show_summary = val ~= "false"
    elseif key == "freq" then opts.show_freq = val ~= "false"
    elseif key == "root" then opts.root = vim.fn.expand(val)
    elseif key == "refresh" then opts.refresh = val ~= "false"
    elseif key == "qf" then opts.quickfix = val ~= "false" end
  end
  return opts
end

---Run the scan for `opts`, honouring the per-root cache. Returns nil when the
--- root is not a directory (after notifying).
---@param opts Dbg.Autocmds.SourceOpts
---@return table<string, Dbg.Autocmds.SourceItem[]>?, Dbg.Autocmds.SourceItem[]?
local function get_scan(opts)
  local now = os.time()
  local cache_valid = _cache
    and not opts.refresh
    and _cache.root == opts.root
    and (now - _cache.scanned_at) < CACHE_TTL_SECONDS

  if cache_valid then
    return _cache.by_event, _cache.all
  end

  if vim.fn.isdirectory(opts.root) ~= 1 then
    notify.error("autocmd sources: root is not a directory: " .. opts.root)
    return nil, nil
  end

  local by_event, all = {}, {}
  scan_dir(opts.root, opts.root, by_event, all)
  _cache = { root = opts.root, scanned_at = now, by_event = by_event, all = all }
  return by_event, all
end

---Select the report items for `opts` (event filter) and apply the sort mode.
---@param opts Dbg.Autocmds.SourceOpts
---@param by_event table<string, Dbg.Autocmds.SourceItem[]>
---@param all Dbg.Autocmds.SourceItem[]
---@return Dbg.Autocmds.SourceItem[]
local function select_items(opts, by_event, all)
  local items = opts.event and (by_event[opts.event] or {}) or all

  if opts.sort == "event" then
    tbl_sort(items, function(a, b)
      return tbl_concat(a.events or {}, ",") < tbl_concat(b.events or {}, ",")
    end)
  elseif opts.sort == "frequency" then
    local freq = {}
    for _, item in ipairs(items) do
      local key = item.path .. ":" .. item.line
      freq[key] = (freq[key] or 0) + 1
    end
    tbl_sort(items, function(a, b)
      return freq[a.path .. ":" .. a.line] > freq[b.path .. ":" .. b.line]
    end)
  end

  return items
end

---@param opts Dbg.Autocmds.SourceOpts
---@param by_event table<string, Dbg.Autocmds.SourceItem[]>
---@param all Dbg.Autocmds.SourceItem[]
---@param items Dbg.Autocmds.SourceItem[]
---@return string[]
local function generate_output(opts, by_event, all, items)
  local lines = {}
  tbl_insert(lines, "=== Autocmd Source Audit ===")
  tbl_insert(lines, "")
  tbl_insert(lines, "Root: " .. opts.root)
  tbl_insert(lines, "Parser: " .. (has_ts_lua() and "tree-sitter" or "text"))
  tbl_insert(lines, "Total autocmds found: " .. #all)
  tbl_insert(lines, "")

  if opts.show_summary then
    tbl_insert(lines, "--- Summary by Event ---")
    local events = vim.tbl_keys(by_event)
    tbl_sort(events)
    for _, ev in ipairs(events) do
      tbl_insert(lines, string.format("  %-20s : %d", ev, #by_event[ev]))
    end
    tbl_insert(lines, "")
  end

  if #items == 0 then
    tbl_insert(lines, "No autocmds found" .. (opts.event and (" for event: " .. opts.event) or ""))
    return lines
  end

  tbl_insert(lines, "--- Autocmd Details ---")
  tbl_insert(lines, "")
  for idx, item in ipairs(items) do
    tbl_insert(lines, string.format("[%d] %s", idx, tbl_concat(item.events or {}, ", ")))
    tbl_insert(lines, string.format("    %s:%d", item.path, item.line))
    if opts.show_impl then
      tbl_insert(lines, "")
      for impl_line in item.implementation:gmatch("[^\n]+") do
        tbl_insert(lines, "    " .. impl_line)
      end
    end
    tbl_insert(lines, "")
  end
  return lines
end

---Populate the quickfix list with one entry per source item and open it.
---@param opts Dbg.Autocmds.SourceOpts
---@param items Dbg.Autocmds.SourceItem[]
---@return nil
local function fill_quickfix(opts, items)
  local qf = {}
  for _, item in ipairs(items) do
    qf[#qf + 1] = {
      filename = opts.root .. "/" .. item.path,
      lnum = item.line,
      col = 1,
      text = tbl_concat(item.events or {}, ", "),
    }
  end
  vim.fn.setqflist({}, " ", {
    title = "Autocmd sources" .. (opts.event and (" (" .. opts.event .. ")") or ""),
    items = qf,
  })
  if #qf > 0 then
    vim.cmd("copen")
  else
    notify.info("autocmd sources: no call sites for the quickfix list")
  end
end

---@param output string[]
---@param filetype string
local function show_scratch(output, filetype)
  vim.cmd("new")
  bo.buftype = "nofile"
  bo.bufhidden = "wipe"
  bo.swapfile = false
  bo.filetype = filetype
  vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
  bo.modifiable = false
end

---Run the static source audit and show the report in a scratch buffer.
--- Results are cached per `root` for `CACHE_TTL_SECONDS`; pass `refresh=true`
--- to force a rescan. Pass `qf=true` to send `path:line` to the quickfix list
--- (for jump-to-definition) instead of the scratch report.
---@param args? string  key=value args: event= sort= impl= summary= freq= root= refresh= qf=
---@return nil
function M.run(args)
  local opts = parse_args(args or "")

  local by_event, all = get_scan(opts)
  if not by_event then return end

  local items = select_items(opts, by_event, all)

  if opts.quickfix then
    fill_quickfix(opts, items)
    return
  end

  local output = generate_output(opts, by_event, all, items)
  show_scratch(output, "autocmd-audit")
end

-- Combined runtime + sources view --------------------------------------------

---Group the currently-registered autocmds by event name.
---@return table<string, table[]>
local function runtime_by_event()
  local out = {}
  local ok, list = pcall(vim.api.nvim_get_autocmds, {})
  if not ok or type(list) ~= "table" then return out end
  for _, au in ipairs(list) do
    local ev = au.event or "?"
    out[ev] = out[ev] or {}
    tbl_insert(out[ev], au)
  end
  return out
end

---`:Debug autocmds all` — fuse the static source audit with the live runtime
--- view: for each event, where it is DEFINED (path:line) and what is currently
--- REGISTERED (group/pattern), plus a diff of events registered at runtime with
--- no source found (typically plugin-defined).
---@param args? string  key=value args: root= refresh= event=
---@return nil
function M.all(args)
  local opts = parse_args(args or "")

  local by_event, all = get_scan(opts)
  if not by_event then return end
  local by_event_rt = runtime_by_event()

  local lines = {}
  tbl_insert(lines, "=== Autocmds: Sources vs Runtime ===")
  tbl_insert(lines, "")
  tbl_insert(lines, "Root: " .. opts.root)
  tbl_insert(lines, "Parser: " .. (has_ts_lua() and "tree-sitter" or "text"))
  tbl_insert(lines, string.format("Source call sites: %d   Runtime registrations: %d",
    #all, (function() local n = 0 for _, v in pairs(by_event_rt) do n = n + #v end return n end)()))
  tbl_insert(lines, "")

  -- Union of event names from both views, so nothing is silently dropped.
  local seen, events = {}, {}
  for ev in pairs(by_event) do if not seen[ev] then seen[ev] = true; events[#events + 1] = ev end end
  for ev in pairs(by_event_rt) do if not seen[ev] then seen[ev] = true; events[#events + 1] = ev end end
  tbl_sort(events)

  if opts.event then
    events = vim.tbl_contains(events, opts.event) and { opts.event } or {}
  end

  local orphans = {}
  for _, ev in ipairs(events) do
    local src = by_event[ev] or {}
    local rt = by_event_rt[ev] or {}
    tbl_insert(lines, string.format("### %s  (defined %d, registered %d)", ev, #src, #rt))

    tbl_insert(lines, "  SOURCES:")
    if #src == 0 then
      tbl_insert(lines, "    (none found in source)")
    else
      for _, item in ipairs(src) do
        tbl_insert(lines, string.format("    %s:%d", item.path, item.line))
      end
    end

    tbl_insert(lines, "  RUNTIME:")
    if #rt == 0 then
      tbl_insert(lines, "    (not registered)")
    else
      for _, au in ipairs(rt) do
        tbl_insert(lines, string.format("    group=%-24s pattern=%s",
          au.group_name or "default", tostring(au.pattern or "*")))
      end
    end

    if #src == 0 and #rt > 0 then
      orphans[#orphans + 1] = ev
    end
    tbl_insert(lines, "")
  end

  if #orphans > 0 then
    tbl_insert(lines, "--- Registered at runtime with no source found ---")
    tbl_insert(lines, "(likely defined by plugins or via :autocmd / Vimscript)")
    for _, ev in ipairs(orphans) do
      tbl_insert(lines, "  " .. ev)
    end
    tbl_insert(lines, "")
  end

  show_scratch(lines, "autocmd-audit")
end

---Completion candidates for the free-form `sources` args (event=/sort=/…).
---@param arglead string
---@return string[]
function M.complete(arglead)
  local key, partial = arglead:match("^(%a+)=(.*)$")
  if key == "event" then
    local out = {}
    for _, ev in ipairs(M.KNOWN_EVENTS) do
      if ev:lower():find(partial:lower(), 1, true) == 1 then
        out[#out + 1] = "event=" .. ev
      end
    end
    return out
  end
  if key == "sort" then
    local out = {}
    for _, mode in ipairs(M.SORT_MODES) do
      if mode:find(partial, 1, true) == 1 then out[#out + 1] = "sort=" .. mode end
    end
    return out
  end
  if key == "impl" or key == "summary" or key == "freq" or key == "refresh" or key == "qf" then
    return { key .. "=true", key .. "=false" }
  end
  local out = {}
  for _, k in ipairs(M.ARG_KEYS) do
    if k:find(arglead, 1, true) == 1 then out[#out + 1] = k end
  end
  return out
end

--- The pure parsers behind `M.run()`, exposed for `docs/TESTS/sources_spec.lua`.
--- Not part of the public API — they stay local to this module for callers and
--- may change shape without notice.
M._internal = {
  normalize_events = normalize_events,
  read_brace_block = read_brace_block,
  parse_args = parse_args,
  is_autocmd_name = is_autocmd_name,
  has_ts_lua = has_ts_lua,
}

return M
