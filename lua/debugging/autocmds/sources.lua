---@module 'debugging.autocmds.sources'
---@brief Static source-code audit of nvim_create_autocmd call sites.
---@description
--- Scans Lua files under a root directory (default: your nvim config `lua/`),
--- finds every `nvim_create_autocmd` definition with a light text parser, and
--- reports where each autocmd is DEFINED (path:line + implementation), grouped
--- by event. Complements `debugging.autocmds.runtime` (the live view).
---
--- Scan results are cached per root for a few seconds so repeated calls
--- (e.g. trying different `sort=`/`event=` combinations) don't rescan the
--- whole tree each time; pass `refresh=true` to force a rescan.
---
--- Ported from the former `usrcmds.list.autocmd_audit`. The text parser is
--- intentionally simple; a Tree-sitter rewrite is on the roadmap.

require("debugging.autocmds.@types")

local uv = vim.uv or vim.loop
local bo = vim.bo
local tbl_insert, tbl_concat, tbl_sort = table.insert, table.concat, table.sort

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
M.ARG_KEYS = { "event=", "sort=", "impl=", "summary=", "freq=", "root=", "refresh=" }

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

---@param abs_path string
---@param rel_path string
---@param by_event table<string, Dbg.Autocmds.SourceItem[]>
---@param all Dbg.Autocmds.SourceItem[]
local function scan_file(abs_path, rel_path, by_event, all)
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
    root = DEFAULT_ROOT, refresh = false,
  }
  for key, val in (args or ""):gmatch("(%w+)=([^%s]+)") do
    if key == "event" then opts.event = val
    elseif key == "sort" then opts.sort = val
    elseif key == "impl" then opts.show_impl = val ~= "false"
    elseif key == "summary" then opts.show_summary = val ~= "false"
    elseif key == "freq" then opts.show_freq = val ~= "false"
    elseif key == "root" then opts.root = vim.fn.expand(val)
    elseif key == "refresh" then opts.refresh = val ~= "false" end
  end
  return opts
end

---@param opts Dbg.Autocmds.SourceOpts
---@param by_event table<string, Dbg.Autocmds.SourceItem[]>
---@param all Dbg.Autocmds.SourceItem[]
---@return string[]
local function generate_output(opts, by_event, all)
  local lines = {}
  tbl_insert(lines, "=== Autocmd Source Audit ===")
  tbl_insert(lines, "")
  tbl_insert(lines, "Root: " .. opts.root)
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

  local items = opts.event and (by_event[opts.event] or {}) or all
  if #items == 0 then
    tbl_insert(lines, "No autocmds found" .. (opts.event and (" for event: " .. opts.event) or ""))
    return lines
  end

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

---Run the static source audit and show the report in a scratch buffer.
--- Results are cached per `root` for `CACHE_TTL_SECONDS`; pass `refresh=true`
--- to force a rescan.
---@param args? string  key=value args: event= sort= impl= summary= freq= root= refresh=
---@return nil
function M.run(args)
  local opts = parse_args(args or "")

  ---@type table<string, Dbg.Autocmds.SourceItem[]>, Dbg.Autocmds.SourceItem[]
  local by_event, all
  local now = os.time()
  local cache_valid = _cache
    and not opts.refresh
    and _cache.root == opts.root
    and (now - _cache.scanned_at) < CACHE_TTL_SECONDS

  if cache_valid then
    by_event, all = _cache.by_event, _cache.all
  else
    if vim.fn.isdirectory(opts.root) ~= 1 then
      vim.notify("[debugging] autocmd sources: root is not a directory: " .. opts.root, vim.log.levels.ERROR)
      return
    end
    by_event, all = {}, {}
    scan_dir(opts.root, opts.root, by_event, all)
    _cache = { root = opts.root, scanned_at = now, by_event = by_event, all = all }
  end

  local output = generate_output(opts, by_event, all)

  vim.cmd("new")
  bo.buftype = "nofile"
  bo.bufhidden = "wipe"
  bo.swapfile = false
  bo.filetype = "autocmd-audit"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
  bo.modifiable = false
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
  if key == "impl" or key == "summary" or key == "freq" or key == "refresh" then
    return { key .. "=true", key .. "=false" }
  end
  local out = {}
  for _, k in ipairs(M.ARG_KEYS) do
    if k:find(arglead, 1, true) == 1 then out[#out + 1] = k end
  end
  return out
end

return M
