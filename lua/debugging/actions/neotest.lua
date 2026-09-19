---@module 'debugging.actions.neotest'
--- `:Debug neotest adapters|state|file|root|framework|discover` -- why is
--- neotest not finding my tests?
---
--- Six read-only reports over neotest's public surface, each answering one
--- step of that question in order: which adapters are configured and which
--- are registered (`adapters`); what neotest knows about the current buffer
--- (`state`); whether any adapter claims the current file as a test file
--- (`file`); which project root each adapter derives for it and which
--- marker files sit there (`root`); which test framework the cwd looks like
--- from its config files and `package.json` (`framework`); and how many
--- positions each adapter has discovered (`discover`).
---
--- Two neotest surfaces are read, both pcall-guarded so a neotest that is
--- absent, not yet loaded, or a version that renamed something degrades to a
--- notification: `neotest.state` (`adapter_ids`, `positions`) for what is
--- registered, and `neotest.config.adapters` -- the adapter tables handed to
--- `neotest.setup()` -- for `name`, `root(dir)` and `is_test_file(path)`.
--- The latter is what makes `file`/`root` adapter-generic: the adapters
--- themselves say whether they want a file and where its project starts,
--- rather than this module pattern-matching adapter ids against paths.
---
--- Output goes to a scratch float (`neotest.output = "float"`) or, when no
--- window can be opened or the option says so, to one notification. Every
--- action also returns its lines, which is what the spec reads.

local notify = require("lib.nvim.notify").create("[debugging.actions.neotest]")
local window = require("lib.nvim.window")
local config = require("debugging.config")

local M = {}

-- ---------------------------------------------------------------- helpers

---@internal
---@return table|nil neotest  `require("neotest")`, or nil after a notification.
local function neotest_mod()
  local ok, neotest = pcall(require, "neotest")
  if not ok or type(neotest) ~= "table" then
    notify.error("neotest is not loaded -- install nvim-neotest/neotest, or load it first")
    return nil
  end
  return neotest
end

---@internal
---Registered adapter ids, in neotest's order. Empty when neotest has none or
---the `state` consumer is missing.
---@param neotest table
---@return string[]
local function adapter_ids(neotest)
  local state = neotest.state
  if type(state) ~= "table" or type(state.adapter_ids) ~= "function" then
    return {}
  end
  local ok, ids = pcall(state.adapter_ids)
  if not ok or type(ids) ~= "table" then
    return {}
  end
  return ids
end

---@internal
---The adapter tables from `neotest.setup({ adapters = ... })`, as neotest
---keeps them in `neotest.config.adapters`. Empty when unreadable.
---@return table[]
local function configured_adapters()
  local ok, cfg = pcall(require, "neotest.config")
  if not ok or type(cfg) ~= "table" or type(cfg.adapters) ~= "table" then
    return {}
  end
  local out = {}
  for _, adapter in ipairs(cfg.adapters) do
    if type(adapter) == "table" then
      out[#out + 1] = adapter
    end
  end
  return out
end

---@internal
---@param adapter table
---@return string
local function adapter_name(adapter)
  return tostring(adapter.name or "?")
end

---@internal
---The positions tree of `buf` (or, with no buffer, the whole tree) under the
---first adapter that has one.
---@param neotest table
---@param ids string[]
---@param buf integer|nil
---@return table|nil tree
---@return string|nil adapter_id
local function find_tree(neotest, ids, buf)
  local state = neotest.state
  if type(state) ~= "table" or type(state.positions) ~= "function" then
    return nil, nil
  end
  for _, id in ipairs(ids) do
    local ok, tree = pcall(state.positions, id, buf and { buffer = buf } or nil)
    if ok and tree then
      return tree, id
    end
  end
  return nil, nil
end

---@internal
---Count a tree's nodes by position type via `iter_nodes()`/`:data()`, the
---methods a `neotest.Tree` actually has (there are no `children`/`type`
---fields to read).
---@param tree table
---@return table<string, integer> counts
---@return integer total
local function count_positions(tree)
  local counts, total = {}, 0
  if type(tree.iter_nodes) ~= "function" then
    return counts, total
  end
  local ok = pcall(function()
    for _, node in tree:iter_nodes() do
      local ok_data, data = pcall(node.data, node)
      local typ = ok_data and type(data) == "table" and tostring(data.type or "?") or "?"
      counts[typ] = (counts[typ] or 0) + 1
      total = total + 1
    end
  end)
  if not ok then
    return {}, 0
  end
  return counts, total
end

---@internal
---@param counts table<string, integer>
---@return string
local function counts_line(counts)
  local keys = vim.tbl_keys(counts)
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = ("%s %d"):format(k, counts[k])
  end
  return #parts > 0 and table.concat(parts, ", ") or "(none)"
end

---@internal
---@return Dbg.Config.Neotest
local function cfg()
  return config.get().neotest or {}
end

---@internal
---The marker files present in `dir`, from `neotest.markers`.
---@param dir string
---@return string[]
local function markers_in(dir)
  local found = {}
  for _, marker in ipairs(cfg().markers or {}) do
    if vim.fn.filereadable(dir .. "/" .. marker) == 1 then
      found[#found + 1] = marker
    end
  end
  return found
end

---@internal
---Render a report: scratch float when configured and possible, one
---notification otherwise. Returns the lines either way.
---@param title string
---@param lines string[]
---@return string[]
local function render(title, lines)
  if cfg().output ~= "notify" then
    local ok, winid = pcall(window.make_scratch, {
      lines = lines,
      filetype = "debugging-neotest",
      title = (" :%s neotest %s "):format(config.get().command, title),
      title_pos = "center",
      nice_quit = { force = true },
      wo = { cursorline = true },
    })
    if ok and winid then
      return lines
    end
  end
  notify.info(table.concat(lines, "\n"))
  return lines
end

---@internal
---@return string|nil path  The current buffer's file, or nil after a warning.
local function current_file()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    notify.warn("the current buffer has no file")
    return nil
  end
  return name
end

-- ---------------------------------------------------------------- actions

---Configured adapters (from `neotest.setup`) next to the registered ids.
---@return string[]|nil lines
function M.adapters()
  local neotest = neotest_mod()
  if not neotest then
    return nil
  end
  local configured = configured_adapters()
  local ids = adapter_ids(neotest)

  local lines = { "=== neotest adapters ===", "" }
  lines[#lines + 1] = ("Configured (neotest.setup): %d"):format(#configured)
  for i, adapter in ipairs(configured) do
    lines[#lines + 1] = ("  [%d] %s"):format(i, adapter_name(adapter))
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = ("Registered (state.adapter_ids): %d"):format(#ids)
  for i, id in ipairs(ids) do
    lines[#lines + 1] = ("  [%d] %s"):format(i, id)
  end
  if #ids == 0 and #configured > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  An adapter registers once it claims a root for an opened file;"
    lines[#lines + 1] = "  none has yet -- open a test file, then `:Debug neotest root`."
  end
  return render("adapters", lines)
end

---What neotest knows about the current buffer: adapters, path, filetype,
---and whether any adapter has a positions tree for it.
---@return string[]|nil lines
function M.state()
  local neotest = neotest_mod()
  if not neotest then
    return nil
  end
  local buf = vim.api.nvim_get_current_buf()
  local ids = adapter_ids(neotest)
  local tree, owner = find_tree(neotest, ids, buf)

  local lines = { "=== neotest state ===", "" }
  lines[#lines + 1] = "Registered adapters:"
  if #ids == 0 then
    lines[#lines + 1] = "  (none)"
  end
  for _, id in ipairs(ids) do
    lines[#lines + 1] = "  - " .. id
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Current buffer:"
  lines[#lines + 1] = "  Path: " .. vim.api.nvim_buf_get_name(buf)
  lines[#lines + 1] = "  Filetype: " .. vim.bo[buf].filetype
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Positions tree for this buffer:"
  if tree then
    local ok_data, data = pcall(tree.data, tree)
    local root = ok_data and type(data) == "table" and data.name or "?"
    local counts = count_positions(tree)
    lines[#lines + 1] = "  Found: YES (" .. tostring(owner) .. ")"
    lines[#lines + 1] = "  Root: " .. tostring(root)
    lines[#lines + 1] = "  Positions: " .. counts_line(counts)
  else
    lines[#lines + 1] = "  Found: NO"
  end
  return render("state", lines)
end

---Does any adapter claim the current file as a test file?
---@return string[]|nil lines
function M.file()
  local neotest = neotest_mod()
  if not neotest then
    return nil
  end
  local path = current_file()
  if not path then
    return nil
  end
  local configured = configured_adapters()
  local ids = adapter_ids(neotest)
  local _, owner = find_tree(neotest, ids, vim.api.nvim_get_current_buf())

  local lines = { "=== neotest file ===", "" }
  lines[#lines + 1] = "File: " .. vim.fn.fnamemodify(path, ":t")
  lines[#lines + 1] = "Path: " .. path
  lines[#lines + 1] = ""
  lines[#lines + 1] = "is_test_file(path), per configured adapter:"
  if #configured == 0 then
    lines[#lines + 1] = "  (no adapters configured)"
  end
  local claimed = 0
  for _, adapter in ipairs(configured) do
    local verdict
    if type(adapter.is_test_file) ~= "function" then
      verdict = "no is_test_file()"
    else
      local ok, res = pcall(adapter.is_test_file, path)
      if not ok then
        verdict = "error: " .. tostring(res)
      elseif res then
        verdict = "YES"
        claimed = claimed + 1
      else
        verdict = "no"
      end
    end
    lines[#lines + 1] = ("  %-16s %s"):format(adapter_name(adapter), verdict)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Positions tree: " .. (owner and ("YES (" .. owner .. ")") or "NO")
  if claimed == 0 and #configured > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  No adapter wants this file: check its name pattern against"
    lines[#lines + 1] = "  the adapter's is_test_file(), not the adapter's root."
  end
  return render("file", lines)
end

---Which project root each adapter derives for the current file, and which
---marker files sit in it.
---@return string[]|nil lines
function M.root()
  local neotest = neotest_mod()
  if not neotest then
    return nil
  end
  local path = current_file()
  if not path then
    return nil
  end
  local dir = vim.fn.fnamemodify(path, ":h")
  local configured = configured_adapters()

  local lines = { "=== neotest root ===", "" }
  lines[#lines + 1] = "File: " .. path
  lines[#lines + 1] = "Dir:  " .. dir
  lines[#lines + 1] = ""
  lines[#lines + 1] = "root(dir), per configured adapter:"
  if #configured == 0 then
    lines[#lines + 1] = "  (no adapters configured)"
  end
  local roots = {}
  for _, adapter in ipairs(configured) do
    local verdict
    if type(adapter.root) ~= "function" then
      verdict = "no root()"
    else
      local ok, res = pcall(adapter.root, dir)
      if not ok then
        verdict = "error: " .. tostring(res)
      elseif type(res) == "string" and res ~= "" then
        verdict = res
        roots[res] = true
      else
        verdict = "NONE"
      end
    end
    lines[#lines + 1] = ("  %-16s %s"):format(adapter_name(adapter), verdict)
  end
  local root_list = vim.tbl_keys(roots)
  table.sort(root_list)
  for _, root in ipairs(root_list) do
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Markers in " .. root .. ":"
    local found = markers_in(root)
    if #found == 0 then
      lines[#lines + 1] = "  (none of neotest.markers)"
    end
    for _, marker in ipairs(found) do
      lines[#lines + 1] = "  + " .. marker
    end
  end
  return render("root", lines)
end

---Which test framework the cwd looks like: marker files present, and the
---frameworks `package.json` names.
---@return string[] lines
function M.framework()
  local cwd = vim.fn.getcwd()
  local lines = { "=== neotest framework ===", "" }
  lines[#lines + 1] = "CWD: " .. cwd
  lines[#lines + 1] = ""

  -- `vim.fs.dir`, not `vim.fn.glob(cwd .. "/*")`: glob reads its whole
  -- argument as a pattern, so a checkout under a directory containing `[`,
  -- `]`, `?` or `{}` lists nothing, silently. A report whose job is "show me
  -- what is here" must not have that failure mode.
  local present = {}
  local ok = pcall(function()
    for name, kind in vim.fs.dir(cwd) do
      if kind == "file" then
        present[name] = true
      end
    end
  end)
  if not ok then
    lines[#lines + 1] = "  (cwd is not readable)"
    return render("framework", lines)
  end

  lines[#lines + 1] = "Marker files (neotest.markers):"
  local any = false
  for _, marker in ipairs(cfg().markers or {}) do
    if present[marker] then
      lines[#lines + 1] = "  + " .. marker
      any = true
    end
  end
  if not any then
    lines[#lines + 1] = "  (none)"
  end
  lines[#lines + 1] = ""

  lines[#lines + 1] = "package.json:"
  if present["package.json"] then
    local ok_read, pkg_lines = pcall(vim.fn.readfile, cwd .. "/package.json")
    if ok_read and type(pkg_lines) == "table" then
      local text = table.concat(pkg_lines, "\n")
      local named = {}
      for _, fw in ipairs(cfg().package_frameworks or {}) do
        if text:find('"' .. fw .. '"', 1, true) then
          named[#named + 1] = fw
        end
      end
      lines[#lines + 1] = ("  present, %d bytes"):format(#text)
      lines[#lines + 1] = "  names: "
        .. (#named > 0 and table.concat(named, ", ") or "(no known test framework)")
    else
      lines[#lines + 1] = "  present, but not readable"
    end
  else
    lines[#lines + 1] = "  not found"
  end
  return render("framework", lines)
end

---How many positions each registered adapter has discovered, by type.
---@return string[]|nil lines
function M.discover()
  local neotest = neotest_mod()
  if not neotest then
    return nil
  end
  local ids = adapter_ids(neotest)

  local lines = { "=== neotest discover ===", "" }
  if #ids == 0 then
    lines[#lines + 1] = "No adapter registered -- nothing discovered yet."
    lines[#lines + 1] = "(`:Debug neotest adapters` for what is configured.)"
    return render("discover", lines)
  end
  local total_tests = 0
  for _, id in ipairs(ids) do
    local tree = find_tree(neotest, { id }, nil)
    if tree then
      local counts, total = count_positions(tree)
      total_tests = total_tests + (counts.test or 0)
      lines[#lines + 1] = ("%s: %d positions (%s)"):format(id, total, counts_line(counts))
    else
      lines[#lines + 1] = ("%s: no positions tree"):format(id)
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = ("Tests discovered: %d"):format(total_tests)
  return render("discover", lines)
end

return M
